import importlib.util
import json
from pathlib import Path
import sqlite3

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bundle_index', ROOT / 'scripts/bundle_index.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

WORDS = [
    (1, '1:1:1', 'بسم'), (2, '1:1:2', 'الله'), (3, '1:1:3', '١'),
    (4, '1:2:1', 'الحمد'), (5, '1:2:2', '٢'),
    (6, '2:1:1', 'الم'), (7, '2:1:2', '١'),
    (8, '2:2:1', 'ذلك'), (9, '2:2:2', 'الكتاب'), (10, '2:2:3', '۞'), (11, '2:2:4', '٢'),
]
LAYOUT = [
    (1, 1, 'surah_name', 1, '', '', 1), (1, 2, 'ayah', 1, 1, 5, ''),
    (2, 1, 'surah_name', 1, '', '', 2), (2, 2, 'basmallah', 1, '', '', ''),
    (2, 3, 'ayah', 0, 6, 7, ''),
    (3, 1, 'ayah', 0, 8, 9, ''), (4, 1, 'ayah', 0, 10, 11, ''),
]


@pytest.fixture
def source(tmp_path):
    src = tmp_path / 'source'
    (src / 'layout').mkdir(parents=True)
    (src / 'words').mkdir()
    with sqlite3.connect(src / 'layout/qpc-v4-tajweed-15-lines.db') as db:
        db.execute('CREATE TABLE pages (page_number, line_number, line_type, is_centered, first_word_id, last_word_id, surah_number)')
        db.executemany('INSERT INTO pages VALUES (?,?,?,?,?,?,?)', LAYOUT)
    with sqlite3.connect(src / 'words/qpc-v4.db') as db:
        db.execute('CREATE TABLE words (id, location, surah, ayah, word, text)')
        db.executemany('INSERT INTO words VALUES (?,?,0,0,0,?)', [(i, loc, 'x') for i, loc, _ in WORDS])
    imlaei = tmp_path / 'imlaei.db'
    with sqlite3.connect(imlaei) as db:
        db.execute('CREATE TABLE words (id, location, surah, ayah, word, text)')
        db.executemany('INSERT INTO words VALUES (?,?,0,0,0,?)', [(i, loc, t) for i, loc, t in WORDS])
    return src, imlaei


def test_index_maps_surahs_ayahs_and_page_starts(source):
    src, _ = source
    index = module.build_index(src, page_count=4)
    assert index['surahs'] == [{'page': 1, 'ayahPages': [1, 1]}, {'page': 2, 'ayahPages': [2, 3]}]
    assert index['pages'] == [[1, 1], [2, 1], [2, 2], [2, 2]]


def test_search_text_skips_ayah_numbers_and_symbols(source):
    src, imlaei = source
    index = module.build_index(src, page_count=4)
    assert module.build_search(imlaei, index) == [
        [1, 1, 1, 'بسم الله'], [1, 2, 1, 'الحمد'], [2, 1, 2, 'الم'], [2, 2, 3, 'ذلك الكتاب'],
    ]


def test_missing_ayah_text_is_refused(source):
    src, imlaei = source
    with sqlite3.connect(imlaei) as db:
        db.execute("DELETE FROM words WHERE location LIKE '2:2:%'")
    with pytest.raises(ValueError, match='2:2'):
        module.build_search(imlaei, module.build_index(src, page_count=4))


def test_page_without_ayah_words_is_refused(source):
    src, _ = source
    with pytest.raises(ValueError, match='page 5'):
        module.build_index(src, page_count=5)


def test_write_refuses_output_outside_index_dir(tmp_path, source):
    src, imlaei = source
    with pytest.raises(ValueError, match='Output'):
        module.write(src, imlaei, tmp_path / 'elsewhere', page_count=4)


def test_write_outputs_both_files(tmp_path, source, monkeypatch):
    src, imlaei = source
    monkeypatch.setattr(module, 'ROOT', tmp_path)
    output = tmp_path / 'app/assets/index'
    module.write(src, imlaei, output, page_count=4)
    assert json.loads((output / 'index.json').read_text())['pages'][0] == [1, 1]
    assert json.loads((output / 'search.json').read_text(encoding='utf-8'))[0][3] == 'بسم الله'
