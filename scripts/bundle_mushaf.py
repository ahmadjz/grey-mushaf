"""Bundle owner-supplied QUL V4 data and unchanged fonts; never fetch at runtime."""
import argparse
import json
from pathlib import Path
import shutil
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def bundle(source: Path, output: Path, pages: list[int]) -> None:
    selected = sorted(set(pages))
    if not selected or any(p < 1 or p > 604 for p in selected):
        raise ValueError('Choose pages between 1 and 604')
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
            documents[page] = {'page': page, 'lines': lines}
    # Validate every selected page before writing any outputs.
    output.mkdir(parents=True, exist_ok=True)
    for page, document in documents.items():
        (output / f'{page}.json').write_text(json.dumps(document, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
        shutil.copyfile(source / f'fonts/p{page}.ttf', output / f'p{page}.ttf')
    # Remove only generated page/font files from an earlier selection.
    for item in output.iterdir():
        stem = item.stem.removeprefix('p') if item.suffix == '.ttf' else item.stem
        if item.suffix in {'.json', '.ttf'} and stem.isdecimal() and int(stem) not in selected:
            item.unlink()
    (output / 'pages.json').write_text(json.dumps(selected, separators=(',', ':')), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'assets-src/qul-v4')
    parser.add_argument('--output', type=Path, default=ROOT / 'app/assets/mushaf')
    parser.add_argument('--pages', type=int, nargs='+', default=[1, 2, 47, 48])
    parser.add_argument('--all', action='store_true', help='Bundle all 604 pages')
    args = parser.parse_args()
    bundle(args.source, args.output, list(range(1, 605)) if args.all else args.pages)
