"""Write the surah/ayah/page index and the Imlaei search text from owner-supplied QUL data."""
import argparse
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = 'layout/qpc-v4-tajweed-15-lines.db'
WORDS = 'words/qpc-v4.db'


def _read_only(path: Path) -> sqlite3.Connection:
    if not path.is_file():
        raise ValueError(f'Missing {path}')
    return sqlite3.connect(f'{path.resolve().as_uri()}?mode=ro', uri=True)


def _ayah(location: str) -> tuple[int, int]:
    surah, ayah, _ = location.split(':')
    return int(surah), int(ayah)


def build_index(source: Path, page_count: int = 604) -> dict:
    with _read_only(source / LAYOUT) as layout, _read_only(source / WORDS) as words:
        locations = dict(words.execute('SELECT id, location FROM words'))
        rows = layout.execute(
            'SELECT page_number, line_type, first_word_id, last_word_id, surah_number '
            'FROM pages ORDER BY page_number, line_number').fetchall()
    surah_pages: dict[int, int] = {}
    ayah_pages: dict[tuple[int, int], int] = {}
    page_starts: dict[int, tuple[int, int]] = {}
    for page, kind, first, last, surah in rows:
        if kind == 'surah_name':
            surah_pages.setdefault(int(surah), page)
        if kind != 'ayah':
            continue
        for word in range(int(first), int(last) + 1):
            if word not in locations:
                raise ValueError(f'Unknown word {word} on page {page}')
            ayah = _ayah(locations[word])
            ayah_pages.setdefault(ayah, page)
            page_starts.setdefault(page, ayah)
    for page in range(1, page_count + 1):
        if page not in page_starts:
            raise ValueError(f'No ayah words on page {page}')
    surahs = []
    for surah in range(1, max(s for s, _ in ayah_pages) + 1):
        count = max((a for s, a in ayah_pages if s == surah), default=0)
        if surah not in surah_pages or count == 0 or any((surah, a) not in ayah_pages for a in range(1, count + 1)):
            raise ValueError(f'Incomplete surah {surah}')
        surahs.append({'page': surah_pages[surah],
                       'ayahPages': [ayah_pages[(surah, a)] for a in range(1, count + 1)]})
    return {'surahs': surahs, 'pages': [list(page_starts[p]) for p in range(1, page_count + 1)]}


def build_search(imlaei: Path, index: dict) -> list:
    texts: dict[tuple[int, int], list[str]] = {}
    with _read_only(imlaei) as db:
        for location, text in db.execute('SELECT location, text FROM words ORDER BY id'):
            word = text.replace('‏', '').strip()
            if not word or word.isdigit() or word in '۞۩':
                continue
            texts.setdefault(_ayah(location), []).append(word)
    result = []
    for surah, entry in enumerate(index['surahs'], start=1):
        for ayah, page in enumerate(entry['ayahPages'], start=1):
            if (surah, ayah) not in texts:
                raise ValueError(f'Missing Imlaei text for {surah}:{ayah}')
            result.append([surah, ayah, page, ' '.join(texts[(surah, ayah)])])
    return result


def write(source: Path, imlaei: Path | None, output: Path, page_count: int = 604) -> None:
    allowed = (ROOT / 'app/assets/index').resolve()
    if '..' in output.parts or output.absolute() != allowed:
        raise ValueError(f'Output must be {allowed}')
    index = build_index(source, page_count)
    search = build_search(imlaei, index) if imlaei else None
    output.mkdir(parents=True, exist_ok=True)
    (output / 'index.json').write_text(json.dumps(index, separators=(',', ':')))
    if search is not None:
        (output / 'search.json').write_text(
            json.dumps(search, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'assets-src/qul-v4')
    parser.add_argument('--imlaei', type=Path, default=ROOT / 'assets-src/qul-v4/words/imlaei-simple.db')
    parser.add_argument('--output', type=Path, default=ROOT / 'app/assets/index')
    args = parser.parse_args()
    write(args.source, args.imlaei if args.imlaei.is_file() else None, args.output)
