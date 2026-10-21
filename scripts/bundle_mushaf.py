"""Bundle owner-supplied QUL V4 data and unchanged fonts; never fetch at runtime."""
import argparse
import json
from pathlib import Path
import shutil
import sqlite3
import struct

ROOT = Path(__file__).resolve().parents[1]


def font_metrics(path: Path) -> dict[str, int]:
    """Read the TrueType head ink bounds; keep the font itself unchanged."""
    data = path.read_bytes()
    try:
        count = struct.unpack_from('>H', data, 4)[0]
        for index in range(count):
            tag, _, offset, length = struct.unpack_from('>4sIII', data, 12 + index * 16)
            if tag == b'head' and length >= 54 and offset + length <= len(data):
                units = struct.unpack_from('>H', data, offset + 18)[0]
                low = struct.unpack_from('>h', data, offset + 38)[0]
                high = struct.unpack_from('>h', data, offset + 42)[0]
                if units > 0 and high > low:
                    return {'unitsPerEm': units, 'yMin': low, 'yMax': high}
    except struct.error as exc:
        raise ValueError(f'Invalid font metrics: {path}') from exc
    raise ValueError(f'Missing font metrics: {path}')


def glyph_ink(path: Path) -> dict[int, list[int] | None]:
    """Horizontal ink bounds of QUL's Unicode TrueType glyphs, including COLR layers.

    Composite glyph headers already bound their transformed components. Positions
    within a word are deliberately left to the app's shaping engine (GPOS/RTL).
    """
    data = path.read_bytes()
    try:
        count = struct.unpack_from('>H', data, 4)[0]
        tables = {}
        for i in range(count):
            tag, _, offset, length = struct.unpack_from('>4sIII', data, 12 + i*16)
            if offset + length > len(data):
                raise ValueError('Truncated font table')
            tables[tag] = data[offset:offset+length]
        cmap = tables[b'cmap']
        mapping = {}
        for i in range(struct.unpack_from('>H', cmap, 2)[0]):
            platform, encoding, offset = struct.unpack_from('>HHI', cmap, 4+i*8)
            if platform != 0 and (platform, encoding) not in ((3, 1), (3, 10)):
                continue
            fmt = struct.unpack_from('>H', cmap, offset)[0]
            if fmt == 4:
                n = struct.unpack_from('>H', cmap, offset+6)[0] // 2
                for j in range(n):
                    end = struct.unpack_from('>H', cmap, offset+14+2*j)[0]
                    start = struct.unpack_from('>H', cmap, offset+16+2*n+2*j)[0]
                    delta = struct.unpack_from('>h', cmap, offset+16+4*n+2*j)[0]
                    ro = offset+16+6*n+2*j
                    distance = struct.unpack_from('>H', cmap, ro)[0]
                    for code in range(start, min(end+1, 65535)):
                        gid = struct.unpack_from('>H', cmap, ro+distance+2*(code-start))[0] if distance else code
                        mapping[code] = (gid+delta) & 65535 if gid else 0
            elif fmt == 12:
                for j in range(struct.unpack_from('>I', cmap, offset+12)[0]):
                    start, end, gid = struct.unpack_from('>III', cmap, offset+16+12*j)
                    mapping.update((code, gid+code-start) for code in range(start, end+1))
        if not mapping:
            raise ValueError('Missing Unicode glyph map')
        loca = tables[b'loca']
        long_loca = struct.unpack_from('>h', tables[b'head'], 50)[0] == 1
        def glyph_bounds(gid):
            step, fmt = (4, '>I') if long_loca else (2, '>H')
            start = struct.unpack_from(fmt, loca, gid*step)[0]
            end = struct.unpack_from(fmt, loca, (gid+1)*step)[0]
            if start == end:
                return None
            start *= 1 if long_loca else 2
            _, x_min, _, x_max, _ = struct.unpack_from('>hhhhh', tables[b'glyf'], start)
            return [x_min, x_max]
        layers = {}
        if b'COLR' in tables:
            colr = tables[b'COLR']
            version, n, base_offset, layer_offset, _ = struct.unpack_from('>HHIIH', colr)
            if version != 0:
                raise ValueError('Unsupported COLR version')
            for i in range(n):
                gid, first, length = struct.unpack_from('>HHH', colr, base_offset+6*i)
                layers[gid] = [struct.unpack_from('>H', colr, layer_offset+4*j)[0]
                               for j in range(first, first+length)]
        result = {}
        for code, gid in mapping.items():
            if not gid:
                continue
            bounds = [b for layer in layers.get(gid, [gid]) if (b := glyph_bounds(layer))]
            result[code] = [min(b[0] for b in bounds), max(b[1] for b in bounds)] if bounds else None
        return result
    except (struct.error, KeyError, IndexError) as exc:
        raise ValueError(f'Invalid glyph metrics: {path}') from exc


def checked_output(output: Path, selected: list[int]) -> tuple[Path, set[int]]:
    """Only the fixed, gitignored asset tree can hold generated bundles."""
    root = ROOT.resolve()
    allowed = root / 'app/assets/mushaf'
    output = output.absolute()
    if '..' in output.parts or not output.is_relative_to(allowed):
        raise ValueError(f'Output must be under {allowed}')
    for path in [output, *output.parents]:
        if path.is_symlink():
            raise ValueError(f'Refusing symlink in output path: {path}')
    if output.exists():
        if not output.is_dir():
            raise ValueError('Output must be a directory')
        for path in output.iterdir():
            if path.is_symlink():
                raise ValueError(f'Refusing symlinked output: {path}')
    manifest = output / 'pages.json'
    previous = json.loads(manifest.read_text()) if manifest.exists() else []
    if not isinstance(previous, list) or any(type(p) is not int or not 1 <= p <= 604 for p in previous):
        raise ValueError('Invalid output manifest')
    for page in selected:
        for name in (f'{page}.json', f'p{page}.ttf'):
            target = output / name
            if target.exists() and (page not in previous or not target.is_file()):
                raise ValueError(f'Refusing to overwrite unowned output: {target}')
    return output, set(previous)


def bundle(source: Path, output: Path, pages: list[int]) -> None:
    selected = sorted(set(pages))
    if not selected or any(p < 1 or p > 604 for p in selected):
        raise ValueError('Choose pages between 1 and 604')
    output, previous = checked_output(output, selected)
    documents = {}
    with sqlite3.connect(f'{(source / "layout/qpc-v4-tajweed-15-lines.db").resolve().as_uri()}?mode=ro', uri=True) as layout, sqlite3.connect(f'{(source / "words/qpc-v4.db").resolve().as_uri()}?mode=ro', uri=True) as words:
        words.row_factory = sqlite3.Row
        all_words = {r['id']: {'id': r['id'], 'location': r['location'], 'text': r['text']}
                     for r in words.execute('SELECT id, location, text FROM words')}
        for page in selected:
            rows = layout.execute('SELECT line_number, line_type, is_centered, first_word_id, last_word_id, surah_number FROM pages WHERE page_number=? ORDER BY line_number', (page,)).fetchall()
            if not rows or not (source / f'fonts/p{page}.ttf').is_file():
                raise ValueError(f'Missing layout or font for page {page}')
            ink = glyph_ink(source / f'fonts/p{page}.ttf')
            lines = []
            for number, kind, centered, first, last, surah in rows:
                try:
                    entries = [all_words[i] for i in range(int(first), int(last) + 1)] if kind == 'ayah' else []
                except (KeyError, TypeError, ValueError) as exc:
                    raise ValueError(f'Incomplete word range on page {page}, line {number}') from exc
                try:
                    entries = [{**w, 'ink': [ink[ord(c)] for c in w['text']]} for w in entries]
                except KeyError as exc:
                    raise ValueError(f'Missing ink glyph on page {page}') from exc
                if kind == 'ayah' and not entries:
                    raise ValueError(f'Empty ayah on page {page}, line {number}')
                lines.append({'number': number, 'type': kind, 'centered': bool(centered),
                              'surah': int(surah) if surah else None, 'words': entries})
            documents[page] = {'page': page, 'font': font_metrics(source / f'fonts/p{page}.ttf'), 'lines': lines}
    # Validate every selected page before writing any outputs.
    output.mkdir(parents=True, exist_ok=True)
    for page, document in documents.items():
        (output / f'{page}.json').write_text(json.dumps(document, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
        shutil.copyfile(source / f'fonts/p{page}.ttf', output / f'p{page}.ttf')
    # Only entries named by our previous manifest are eligible for deletion.
    for page in previous - set(selected):
        for name in (f'{page}.json', f'p{page}.ttf'):
            (output / name).unlink(missing_ok=True)
    (output / 'pages.json').write_text(json.dumps(selected, separators=(',', ':')), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'assets-src/qul-v4')
    parser.add_argument('--output', type=Path, default=ROOT / 'app/assets/mushaf')
    parser.add_argument('--pages', type=int, nargs='+', default=[1, 2, 47, 48])
    parser.add_argument('--all', action='store_true', help='Bundle all 604 pages')
    args = parser.parse_args()
    bundle(args.source, args.output, list(range(1, 605)) if args.all else args.pages)
