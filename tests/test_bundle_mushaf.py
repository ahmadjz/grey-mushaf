import importlib.util
import json
from pathlib import Path
import sqlite3
import struct

import pytest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bundle_mushaf', ROOT / 'scripts/bundle_mushaf.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def ink_font(empty=None):
    chars = sorted(set('glyph-abcd' + '\ufc41\ufc42\ufc43\ufc44' + '\ue000\ue001\ue002\ue003\ue009\ue070\ue071\ue072'))
    count = len(chars)
    head = bytearray(54)
    struct.pack_into('>H', head, 18, 2500)
    struct.pack_into('>hhhh', head, 36, -300, -1500, 2800, 3300)
    struct.pack_into('>h', head, 50, 1)  # long loca
    glyphs = [b''] + [struct.pack('>hhhhh', 1, 0, -100, 1000, 2000)] * count
    glyphs += [b'' if c == empty else struct.pack('>hhhhh', -1, -300, -1500, 2800, 3300) for c in chars]
    offsets = [0]
    for glyph in glyphs:
        offsets.append(offsets[-1] + len(glyph))
    codes = [ord(c) for c in chars] + [65535]
    n = len(codes)
    cmap4 = struct.pack('>7H', 4, 16 + 8*n, 0, 2*n, 0, 0, 0)
    cmap4 += struct.pack('>'+'H'*n, *codes) + b'\0\0'
    cmap4 += struct.pack('>'+'H'*n, *codes)
    cmap4 += struct.pack('>'+'H'*n, *[(i+1-c) & 65535 for i,c in enumerate(codes[:-1])], 1)
    cmap4 += bytes(2*n)
    cmap = struct.pack('>HHHHI', 0, 1, 3, 1, 12) + cmap4
    colr = struct.pack('>HHIIH', 0, count, 14, 14+6*count, count)
    colr += b''.join(struct.pack('>HHH', i+1, i, 1) for i in range(count))
    colr += b''.join(struct.pack('>HH', count+i+1, 0) for i in range(count))
    tables = {b'head': bytes(head), b'cmap': cmap, b'COLR': colr,
              b'loca': struct.pack('>'+'I'*len(offsets), *offsets), b'glyf': b''.join(glyphs)}
    result = struct.pack('>IHHHH', 0x10000, len(tables), 0, 0, 0)
    offset = 12 + 16*len(tables)
    for tag, data in tables.items():
        result += struct.pack('>4sIII', tag, 0, offset, len(data))
        offset += len(data)
    return result + b''.join(tables.values())


@pytest.fixture
def source(tmp_path, monkeypatch):
    monkeypatch.setattr(module, "ROOT", tmp_path)
    src = tmp_path / 'source'
    for directory in ('layout', 'words', 'fonts', 'surah-names'):
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
        (src / f'fonts/p{page}.ttf').write_bytes(ink_font())
    (src / 'surah-names/surah-name-v4.ttf').write_bytes(ink_font())
    monkeypatch.setattr(module, 'trace_basmallah', lambda path: {'bounds': [0, 0, 140, 19], 'commands': [['M', 0, 0], ['L', 140, 19], ['Z']]}, raising=False)
    return src


def test_bundles_only_selected_pages_preserving_words_and_non_word_lines(source, tmp_path):
    out = tmp_path / 'app/assets/mushaf'
    module.bundle(source, out, [2, 1, 2])
    assert (out / 'pages.json').exists(), 'bundler must emit a page manifest'
    assert json.loads((out / 'pages.json').read_text()) == [1, 2]
    page = json.loads((out / '1.json').read_text())
    assert page['page'] == 1
    assert page['font'] == {'unitsPerEm': 2500, 'yMin': -1500, 'yMax': 3300}
    assert page['lines'][0] == {'number': 1, 'type': 'surah_name', 'centered': True, 'surah': 1, 'words': [], 'heading': {'kind': 'surah', 'font': 'surah-name-v4', 'parts': ['surah-icon', 'surah001']}}
    assert page['lines'][1]['words'] == [
        {'id': 1, 'location': '1:1:1', 'text': 'glyph-a', 'ink': [[-300, 2800]] * 7},
        {'id': 2, 'location': '1:1:2', 'text': 'glyph-bc', 'ink': [[-300, 2800]] * 8},
    ]
    assert json.loads((out / '2.json').read_text())['lines'][0]['words'] == []
    assert (out / 'p2.ttf').read_bytes() == (source / 'fonts/p2.ttf').read_bytes()
    assert sorted(p.name for p in out.iterdir()) == ['1.json', '2.json', 'fonts.json', 'p1.ttf', 'p2.ttf', 'pages.json', 'surah-name-v4.ttf']


@pytest.mark.parametrize('problem', ['missing_word', 'missing_font', 'missing_page'])
def test_rejects_incomplete_inputs_before_writing_bundle(source, tmp_path, problem):
    if problem == 'missing_word':
        with sqlite3.connect(source / 'words/qpc-v4.db') as db:
            db.execute('DELETE FROM words WHERE id=2')
    elif problem == 'missing_font':
        (source / 'fonts/p1.ttf').unlink()
    out = tmp_path / 'app/assets/mushaf'
    with pytest.raises(ValueError):
        module.bundle(source, out, [3] if problem == 'missing_page' else [1])
    assert not out.exists()


def test_cleanup_only_removes_previously_manifested_files(source, tmp_path):
    out = tmp_path / 'app/assets/mushaf'
    module.bundle(source, out, [1, 2])
    (out / '99.json').write_text('unrelated')
    (out / 'p99.ttf').write_bytes(b'unrelated-font')
    module.bundle(source, out, [1])
    assert (out / '99.json').read_text() == 'unrelated'
    assert (out / 'p99.ttf').read_bytes() == b'unrelated-font'
    assert not (out / '2.json').exists()
    assert not (out / 'p2.ttf').exists()
    assert json.loads((out / 'pages.json').read_text()) == [1]


@pytest.mark.parametrize('destination', ['outside', 'public', 'traversal'])
def test_refuses_output_outside_private_asset_root(source, tmp_path, destination):
    out = {'outside': tmp_path.parent / 'outside-bundle',
           'public': tmp_path / 'docs/public-bundle',
           'traversal': tmp_path / 'app/assets/mushaf/../../public-bundle'}[destination]
    with pytest.raises(ValueError, match='output|Output'):
        module.bundle(source, out, [1])
    assert not out.exists()


@pytest.mark.parametrize('target', ['parent', 'directory', '1.json', 'p1.ttf', 'pages.json', 'p2.ttf'])
def test_refuses_symlinks_without_changing_destination(source, tmp_path, target):
    out = tmp_path / 'app/assets/mushaf'
    out.mkdir(parents=True)
    victim = tmp_path / 'victim'
    victim.mkdir()
    sentinel = victim / 'sentinel'
    sentinel.write_bytes(b'leave alone')
    if target in ('parent', 'directory'):
        if target == 'parent':
            out.rmdir()
            out.parent.rmdir()
            out.parent.symlink_to(victim, target_is_directory=True)
        else:
            out.rmdir()
            out.symlink_to(victim, target_is_directory=True)
    else:
        (out / 'pages.json').write_text('[1,2]')
        if target == 'pages.json':
            (out / target).unlink()
        (out / target).symlink_to(sentinel)
    with pytest.raises(ValueError, match='symlink'):
        module.bundle(source, out, [1])
    assert sentinel.read_bytes() == b'leave alone'
    assert list(victim.iterdir()) == [sentinel]


def test_refuses_overwriting_unowned_output(source, tmp_path):
    out = tmp_path / 'app/assets/mushaf'
    out.mkdir(parents=True)
    (out / '1.json').write_text('unrelated')
    with pytest.raises(ValueError, match='unowned'):
        module.bundle(source, out, [1])
    assert (out / '1.json').read_text() == 'unrelated'


def test_missing_glyph_is_rejected_before_any_output(source, tmp_path):
    with sqlite3.connect(source / 'words/qpc-v4.db') as db:
        db.execute("UPDATE words SET text='?' WHERE id=1")
    out = tmp_path / 'app/assets/mushaf'
    with pytest.raises(ValueError, match='glyph'):
        module.bundle(source, out, [1])
    assert not out.exists()


def test_empty_colr_glyph_in_multi_character_word(source, tmp_path):
    (source / 'fonts/p1.ttf').write_bytes(ink_font(empty='d'))
    with sqlite3.connect(source / 'words/qpc-v4.db') as db:
        db.execute("UPDATE words SET text='ad' WHERE id=1")
    out = tmp_path / 'app/assets/mushaf'
    module.bundle(source, out, [1])
    page = json.loads((out / '1.json').read_text())
    assert page['lines'][1]['words'][0]['ink'] == [[-300, 2800], None]


def test_page_one_font_dependency_survives_deselection(source, tmp_path):
    out = tmp_path / 'app/assets/mushaf'
    module.bundle(source, out, [1, 2])
    module.bundle(source, out, [2])
    assert json.loads((out / 'pages.json').read_text()) == [2]
    assert not (out / '1.json').exists()
    assert (out / 'p1.ttf').read_bytes() == (source / 'fonts/p1.ttf').read_bytes()
    assert json.loads((out / 'fonts.json').read_text()) == ['p1.ttf', 'p2.ttf']
    line = json.loads((out / '2.json').read_text())['lines'][0]
    assert line['words'] == []
    assert line['heading'] == {'kind': 'compact', 'font': 'mushaf-1',
                               'parts': ['\ufc41', '\ufc42', '\ufc43', '\ufc44']}


def test_tawbah_and_multiple_heading_pairs(source, tmp_path):
    with sqlite3.connect(source / 'layout/qpc-v4-tajweed-15-lines.db') as db:
        db.execute("INSERT INTO pages VALUES (187,1,'surah_name',1,'','',9)")
        for line, surah in [(1,112),(5,113),(10,114)]:
            db.execute("INSERT INTO pages VALUES (604,?,'surah_name',1,'','',?)", (line,surah))
            db.execute("INSERT INTO pages VALUES (604,?,'basmallah',1,'','','')", (line+1,))
    for page in (187,604):
        (source / f'fonts/p{page}.ttf').write_bytes(ink_font())
    out = tmp_path / 'app/assets/mushaf'
    module.bundle(source, out, [187,604])
    tawbah = json.loads((out / '187.json').read_text())['lines']
    assert len(tawbah) == 1 and tawbah[0]['heading']['parts'][1] == 'surah009'
    lines = json.loads((out / '604.json').read_text())['lines']
    assert all(line['words'] == [] for line in lines)
    assert [line['heading']['kind'] for line in lines] == ['surah','wide'] * 3
    assert all(line['heading']['asset'] == 'basmallah.json' for line in lines[1::2])
    assert (out / 'basmallah.json').exists()
    assert not (out / 'p1.ttf').exists()


def test_missing_wide_artwork_fails_before_writes(source, tmp_path, monkeypatch):
    def missing(path):
        raise ValueError('Missing page-50 .ai source')
    monkeypatch.setattr(module, 'trace_basmallah', missing, raising=False)
    with sqlite3.connect(source / 'layout/qpc-v4-tajweed-15-lines.db') as db:
        db.execute("INSERT INTO pages VALUES (50,1,'basmallah',1,'','','')")
    (source / 'fonts/p50.ttf').write_bytes(ink_font())
    out = tmp_path / 'app/assets/mushaf'
    with pytest.raises(ValueError, match='page-50'):
        module.bundle(source, out, [50])
    assert not out.exists()


@pytest.mark.parametrize('name', ['fonts.json', 'surah-name-v4.ttf', 'basmallah.json'])
def test_shared_outputs_must_be_owned(source, tmp_path, name):
    out = tmp_path / 'app/assets/mushaf'
    out.mkdir(parents=True)
    (out / name).write_text('unrelated')
    with pytest.raises(ValueError):
        module.bundle(source, out, [1,2])
    assert (out / name).read_text() == 'unrelated'


def test_vector_trace_preserves_curves_holes_and_excludes_adjacent_lines():
    svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 382.677 547.086">
    <path fill="rgb(13%, 12%, 12%)" fill-rule="evenodd" d="
    M 0 0 L 100 0 L 100 20 Z
    M 54 31 C 70 30 180 49 194 49 L 54 49 Z
    M 60 35 L 65 35 L 65 40 Z
    M 0 55 L 200 55 L 200 75 Z"/></svg>'''
    result = module.extract_basmallah(svg)
    assert result['bounds'] == [54,30,194,49]
    assert [c[0] for c in result['commands']] == ['M','C','L','Z','M','L','L','Z']
    assert result['fillRule'] == 'evenodd'
    with pytest.raises(ValueError, match='crosses'):
        module.extract_basmallah(svg.replace('L 54 49', 'L 54 55'))


def test_trace_requires_local_page50(tmp_path):
    with pytest.raises(ValueError, match='page-50'):
        module.trace_basmallah(tmp_path / 'missing.ai')
