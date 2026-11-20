import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.error
import urllib.request
import uuid

import pytest

ROOT = Path(__file__).resolve().parents[1]
PB_BIN = os.environ.get('PB_BIN')
pytestmark = pytest.mark.skipif(not PB_BIN, reason='set PB_BIN to a PocketBase 0.40 binary')
ADMIN = ('admin@test.local', 'admin-password-123')
WORD = 'qul-v4-hafs:2:255:1'


def call(base, method, path, body=None, token=None):
    request = urllib.request.Request(
        base + path,
        method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={'Content-Type': 'application/json', **({'Authorization': token} if token else {})},
    )
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        raw = error.read()
        return error.code, json.loads(raw) if raw else None


@pytest.fixture(scope='module')
def server(tmp_path_factory):
    data = tmp_path_factory.mktemp('pb_data')
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    args = [f'--dir={data}', f'--migrationsDir={ROOT}/server/pb_migrations',
            f'--hooksDir={ROOT}/server/pb_hooks']
    subprocess.run([PB_BIN, 'migrate', 'up', *args], check=True, capture_output=True)
    subprocess.run([PB_BIN, 'superuser', 'upsert', *ADMIN, f'--dir={data}'],
                   check=True, capture_output=True)
    process = subprocess.Popen([PB_BIN, 'serve', f'--http=127.0.0.1:{port}', *args],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    base = f'http://127.0.0.1:{port}'
    for _ in range(100):
        try:
            urllib.request.urlopen(base + '/api/health')
            break
        except OSError:
            time.sleep(0.1)
    status, auth = call(base, 'POST', '/api/collections/_superusers/auth-with-password',
                        {'identity': ADMIN[0], 'password': ADMIN[1]})
    assert status == 200
    status, settings = call(base, 'GET', '/api/settings', None, auth['token'])
    assert settings['rateLimits']['enabled'] is True
    labels = {rule['label']: rule['maxRequests'] for rule in settings['rateLimits']['rules']}
    assert labels['word_actions:create'] == 300
    assert '*:auth' in labels
    assert settings['meta']['appURL'] == 'https://mushaf.ahmadjz.tech'
    assert settings['batch']['enabled'] is False
    call(base, 'PATCH', '/api/settings', {'rateLimits': {'enabled': False}}, auth['token'])
    yield base, auth['token']
    process.terminate()
    process.wait()


def sign_up(base, admin, verified=True):
    email = f'{uuid.uuid4().hex[:10]}@test.local'
    password = 'user-password-123'
    status, user = call(base, 'POST', '/api/collections/users/records',
                        {'email': email, 'password': password, 'passwordConfirm': password}, admin)
    assert status == 200, user
    if verified:
        assert call(base, 'PATCH', f'/api/collections/users/records/{user["id"]}',
                    {'verified': True}, admin)[0] == 200
        status, auth = call(base, 'POST', '/api/collections/users/auth-with-password',
                            {'identity': email, 'password': password})
        assert status == 200, auth
        return user['id'], auth['token']
    return user['id'], email, password


def word_action(user, **overrides):
    return {'user': user, 'uuid': str(uuid.uuid4()), 'device': str(uuid.uuid4()),
            'created_at': 1000, 'word': WORD, 'black': True, 'counted': True, **overrides}


def test_an_unverified_account_cannot_sign_in(server):
    base, admin = server
    _, email, password = sign_up(base, admin, verified=False)
    status, _ = call(base, 'POST', '/api/collections/users/auth-with-password',
                     {'identity': email, 'password': password})
    assert status in (400, 403)


def test_another_user_cannot_read_or_write_my_records(server):
    base, admin = server
    me, mine = sign_up(base, admin)
    other, theirs = sign_up(base, admin)
    status, record = call(base, 'POST', '/api/collections/word_actions/records',
                          word_action(me), mine)
    assert status == 200, record

    for collection in ['word_actions', 'mark_actions', 'bookmark_actions']:
        status, listing = call(base, 'GET', f'/api/collections/{collection}/records', None, theirs)
        assert status == 200 and listing['items'] == []
    path = '/api/collections/word_actions/records'
    assert call(base, 'GET', f'{path}?filter=(user="{me}")&expand=user', None, theirs)[1]['items'] == []
    assert call(base, 'GET', f'{path}?filter=(uuid="{record["uuid"]}")', None, theirs)[1]['totalItems'] == 0
    assert call(base, 'GET', f'{path}/{record["id"]}', None, theirs)[0] == 404
    assert call(base, 'GET', f'/api/collections/users/records/{me}', None, theirs)[0] == 404
    assert call(base, 'GET', '/api/collections/users/records', None, theirs)[1]['totalItems'] == 1
    assert call(base, 'POST', path, word_action(me), theirs)[0] in (400, 403)
    assert call(base, 'GET', path, None, None)[1]['items'] == []
    assert call(base, 'POST', path, word_action(me), None)[0] in (400, 403)
    assert call(base, 'GET', f'{path}?filter=(user="{other}")', None, theirs)[1]['items'] == []


def test_actions_are_append_only(server):
    base, admin = server
    me, mine = sign_up(base, admin)
    path = '/api/collections/word_actions/records'
    _, record = call(base, 'POST', path, word_action(me), mine)
    assert call(base, 'PATCH', f'{path}/{record["id"]}', {'black': False}, mine)[0] in (403, 404)
    assert call(base, 'DELETE', f'{path}/{record["id"]}', None, mine)[0] in (403, 404)


def test_records_must_be_well_formed(server):
    base, admin = server
    me, mine = sign_up(base, admin)
    words = '/api/collections/word_actions/records'
    marks = '/api/collections/mark_actions/records'
    pages = '/api/collections/bookmark_actions/records'
    assert call(base, 'POST', words, word_action(me, black=False, counted=False, created_at=0), mine)[0] == 200
    assert call(base, 'POST', words, word_action(me, black=False, counted=True), mine)[0] == 400
    assert call(base, 'POST', words, word_action(me, word='2:255:1'), mine)[0] == 400
    assert call(base, 'POST', words, word_action(me, uuid='not-a-uuid'), mine)[0] == 400

    def mark(**fields):
        body = {'user': me, 'uuid': str(uuid.uuid4()), 'device': str(uuid.uuid4()),
                'created_at': 5, 'word': WORD, **fields}
        return call(base, 'POST', marks, body, mine)[0]

    assert mark(kind='line', style='doubleLine', color='red') == 200
    assert mark(kind='shape', style='', color='') == 200
    assert mark(kind='shape') == 200
    assert mark(kind='line', style='circle', color='red') == 400
    assert mark(kind='line', style='singleLine', color='') == 400
    assert mark(kind='shape', style='', color='blue') == 400
    assert mark(kind='line', style='singleLine', color='pink') == 400

    def bookmark(**fields):
        body = {'user': me, 'uuid': str(uuid.uuid4()), 'device': str(uuid.uuid4()),
                'created_at': 5, **fields}
        return call(base, 'POST', pages, body, mine)[0]

    assert bookmark(page=604, saved=False) == 200
    assert bookmark(page=605, saved=True) == 400
    assert bookmark(page=0, saved=True) == 400


def test_a_repeated_uuid_is_refused_per_user_only(server):
    base, admin = server
    me, mine = sign_up(base, admin)
    other, theirs = sign_up(base, admin)
    path = '/api/collections/word_actions/records'
    action = word_action(me)
    assert call(base, 'POST', path, action, mine)[0] == 200
    status, error = call(base, 'POST', path, action, mine)
    assert status == 400
    assert error['data']['uuid']['code'] == 'validation_not_unique'
    assert call(base, 'POST', path, {**action, 'user': other}, theirs)[0] == 200


def test_seq_grows_per_user_and_the_future_is_clamped(server):
    base, admin = server
    me, mine = sign_up(base, admin)
    path = '/api/collections/word_actions/records'
    seqs = []
    for body in [word_action(me), word_action(me, seq=999), word_action(me, created_at=10**15)]:
        status, record = call(base, 'POST', path, body, mine)
        assert status == 200, record
        seqs.append(record['seq'])
    assert seqs == [1, 2, 3]
    assert record['created_at'] <= time.time() * 1000 + 1000
    _, listing = call(base, 'GET', f'{path}?filter=(seq>1)&sort=seq', None, mine)
    assert [item['seq'] for item in listing['items']] == [2, 3]


def test_only_the_owner_creates_accounts(server):
    base, admin = server
    password = 'user-password-123'
    body = {'email': 'stranger@test.local', 'password': password, 'passwordConfirm': password}
    assert call(base, 'POST', '/api/collections/users/records', body)[0] in (400, 403)
    _, mine = sign_up(base, admin)
    assert call(base, 'POST', '/api/collections/users/records', body, mine)[0] in (400, 403)
