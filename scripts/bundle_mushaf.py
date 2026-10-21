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
            lines = []
            for number, kind, centered, first, last, surah in rows:
                try:
                    entries = [all_words[i] for i in range(int(first), int(last) + 1)] if kind == 'ayah' else []
                except (KeyError, TypeError, ValueError) as exc:
                    raise ValueError(f'Incomplete word range on page {page}, line {number}') from exc
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
