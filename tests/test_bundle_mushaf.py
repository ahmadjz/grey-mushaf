import importlib.util
import json
from pathlib import Path
import sqlite3

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bundle_mushaf', ROOT / 'scripts/bundle_mushaf.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


@pytest.fixture
def source(tmp_path):
    src = tmp_path / 'source'
    for directory in ('layout', 'words', 'fonts'):
        (src / directory).mkdir(parents=True)
    with sqlite3.connect(src / 'layout/qpc-v4-tajweed-15-lines.db') as db:
        db.execute('CREATE TABLE pages (page_number, line_number, line_type, is_centered, first_word_id, last_word_id, surah_number)')
        db.executemany('INSERT INTO pages VALUES (?,?,?,?,?,?,?)', [
            (1, 1, 'surah_name', 1, '', '', 1),
            (1, 2, 'ayah', 1, 1, 2, ''),
            (2, 1, 'basmallah', 1, '', '', ''),
            (2, 2, 'ayah', 0, 3, 3, ''),
        ])
    with sqlite3.connect(src / 'words/qpc-v4.db') as db:
        db.execute('CREATE TABLE words (id, location, surah, ayah, word, text)')
        db.executemany('INSERT INTO words VALUES (?,?,?,?,?,?)', [
            (1, '1:1:1', 1, 1, 1, 'glyph-a'),
            (2, '1:1:2', 1, 1, 2, 'glyph-bc'),
            (3, '2:1:1', 2, 1, 1, 'glyph-d'),
        ])
    for page in (1, 2):
        (src / f'fonts/p{page}.ttf').write_bytes(f'font-{page}'.encode())
    return src


def test_bundles_only_selected_pages_preserving_words_and_non_word_lines(source, tmp_path):
    out = tmp_path / 'bundle'
    module.bundle(source, out, [2, 1, 2])
    assert (out / 'pages.json').exists(), 'bundler must emit a page manifest'
    assert json.loads((out / 'pages.json').read_text()) == [1, 2]
    page = json.loads((out / '1.json').read_text())
    assert page['page'] == 1
    assert page['lines'][0] == {'number': 1, 'type': 'surah_name', 'centered': True, 'surah': 1, 'words': []}
    assert page['lines'][1]['words'] == [
        {'id': 1, 'location': '1:1:1', 'text': 'glyph-a'},
        {'id': 2, 'location': '1:1:2', 'text': 'glyph-bc'},
    ]
    assert json.loads((out / '2.json').read_text())['lines'][0]['words'] == []
    assert (out / 'p2.ttf').read_bytes() == b'font-2'
    assert sorted(p.name for p in out.iterdir()) == ['1.json', '2.json', 'p1.ttf', 'p2.ttf', 'pages.json']


@pytest.mark.parametrize('problem', ['missing_word', 'missing_font', 'missing_page'])
def test_rejects_incomplete_inputs_before_writing_bundle(source, tmp_path, problem):
    if problem == 'missing_word':
        with sqlite3.connect(source / 'words/qpc-v4.db') as db:
            db.execute('DELETE FROM words WHERE id=2')
    elif problem == 'missing_font':
        (source / 'fonts/p1.ttf').unlink()
    out = tmp_path / 'bundle'
    with pytest.raises(ValueError):
        module.bundle(source, out, [3] if problem == 'missing_page' else [1])
    assert not out.exists()
