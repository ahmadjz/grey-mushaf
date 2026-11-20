import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/sync.dart';
import 'package:greymushaf/sync_local.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'sync_fakes.dart';

void main() {
  late FakeLocal local;
  late FakeServer server;
  late StreamController<bool> online;
  late SyncEngine engine;

  setUp(() {
    local = FakeLocal();
    server = FakeServer();
    online = StreamController<bool>();
    engine = SyncEngine(
      local,
      PocketBaseApi(
        'http://pb',
        client: MockClient(server.handle),
        retryDelay: Duration.zero,
      ),
      online: online.stream,
      poll: null,
      pageSize: 2,
    );
  });

  tearDown(() => unawaited(online.close()));

  Future<void> signIn() => engine.signIn('a@x', 'right-password');

  test('push uploads with the owner, then pull pages by seq', () async {
    local.pending.addAll([wordRecord('u1'), wordRecord('u2', black: false)]);
    server.records['word_actions']!.addAll([
      for (var i = 1; i <= 3; i++)
        {
          'uuid': 'r$i',
          'device': 'd',
          'created_at': i,
          'word': fakeWord,
          'black': true,
          'counted': true,
          'seq': i,
          'user': 'user-a',
        },
    ]);
    await signIn();
    await engine.sync();
    expect(local.uploaded, {'u1', 'u2'});
    final pushed = server.records['word_actions']!
        .where((r) => r['uuid'] == 'u2')
        .single;
    expect(pushed, containsPair('user', 'user-a'));
    expect(pushed, containsPair('device', fakeDevice));
    expect(pushed, containsPair('black', false));
    expect(local.applied.map((r) => r.uuid), ['r1', 'r2', 'r3', 'u1', 'u2']);
    expect(local.values['cursor_word'], '5');
    expect(engine.lastSync, isNotNull);
    expect(engine.waiting, 0);
    expect(engine.problem, isNull);

    local.applied.clear();
    await engine.sync();
    expect(local.applied, isEmpty);
  });

  test(
    'a retried upload that already reached the server is acknowledged',
    () async {
      final record = wordRecord('u1');
      local.pending.add(record);
      server.records['word_actions']!.add({
        'uuid': 'u1',
        'device': fakeDevice,
        'created_at': 1,
        'word': fakeWord,
        'black': true,
        'counted': true,
        'seq': 1,
        'user': 'user-a',
      });
      await signIn();
      await engine.sync();
      expect(local.uploaded, {'u1'});
      expect(engine.problem, isNull);
    },
  );

  test(
    'a uuid clash with a different payload stays waiting but pull still runs',
    () async {
      local.pending.add(wordRecord('u1'));
      server.records['word_actions']!.add({
        'uuid': 'u1',
        'device': fakeDevice,
        'created_at': 1,
        'word': fakeWord,
        'black': false,
        'counted': false,
        'seq': 1,
        'user': 'user-a',
      });
      await signIn();
      await engine.sync();
      expect(local.uploaded, isEmpty);
      expect(engine.problem, isA<Refused>());
      expect(engine.waiting, 1);
      expect(local.applied.single.fields['black'], false);
    },
  );

  test('a rejected token signs out and keeps local data (R10)', () async {
    await signIn();
    await engine.sync();
    local.pending.add(wordRecord('u1'));
    local.values['token_at'] = '0';
    server.failNextWith = 401;
    await engine.sync();
    expect(engine.signedIn, isFalse);
    expect(engine.problem, isA<SignedOut>());
    expect(local.values['owner'], 'user-a');
    expect(await local.pendingCount(), 1);
  });

  test('429 is retried, and offline keeps changes waiting', () async {
    local.pending.add(wordRecord('u1'));
    await signIn();
    await Future<void>.delayed(Duration.zero);
    server.failNextWith = 429;
    await engine.sync();
    expect(local.uploaded, {'u1'});

    final offline = SyncEngine(
      local,
      PocketBaseApi(
        'http://pb',
        client: MockClient((_) => throw http.ClientException('down')),
      ),
      online: const Stream.empty(),
      poll: null,
    );
    local.pending.add(wordRecord('u2'));
    await offline.sync();
    expect(offline.problem, isA<Offline>());
    expect(await local.pendingCount(), 1);
  });

  test('missing and null PocketBase fields are tolerated', () async {
    server.records['mark_actions']!.addAll([
      {
        'uuid': 'm1',
        'device': 'd',
        'created_at': 5,
        'word': fakeWord,
        'kind': 'shape',
        'seq': 1,
      },
      {
        'uuid': 'm2',
        'device': 'd',
        'created_at': 6,
        'word': fakeWord,
        'kind': 'line',
        'style': null,
        'color': null,
        'seq': 2,
      },
      {'uuid': 'm3', 'device': 'd', 'word': fakeWord, 'kind': 'line', 'seq': 3},
    ]);
    server.records['bookmark_actions']!.add({
      'uuid': 'b1',
      'device': 'd',
      'created_at': 7.0,
      'page': 42.0,
      'seq': 1,
    });
    await signIn();
    await engine.sync();
    expect(local.applied.map((r) => r.uuid), ['m1', 'm2', 'b1']);
    expect(local.applied[0].fields, {
      'word': fakeWord,
      'kind': 'shape',
      'style': '',
      'color': '',
    });
    expect(local.applied[2].fields, {'page': 42, 'saved': false});
    expect(local.values['cursor_mark'], '3');
  });

  test(
    'another account gets only changes made while signed out (R81)',
    () async {
      local.pending.add(wordRecord('u1'));
      await signIn();
      await engine.sync();
      local.values['cursor_word'] = '9';
      await engine.signOut();
      await signIn();
      expect(local.values['cursor_word'], '9');

      await engine.signOut();
      local.pending.add(wordRecord('u2'));
      server.user = 'user-b';
      await signIn();
      expect(local.values.containsKey('cursor_word'), isFalse);
      await engine.sync();
      expect(
        [
          for (final r in server.records['word_actions']!)
            (r['uuid'], r['user']),
        ],
        [('u1', 'user-a'), ('u2', 'user-b')],
      );
    },
  );

  test('signing out mid-upload drops the late answer', () async {
    local.pending.add(wordRecord('u1'));
    final reached = Completer<void>();
    final release = Completer<void>();
    server.pauseCreate = (_) {
      reached.complete();
      return release.future;
    };
    await signIn();
    final running = engine.sync();
    await reached.future;
    await engine.signOut();
    release.complete();
    await running;
    expect(server.records['word_actions'], hasLength(1));
    expect(local.uploaded, isEmpty);
    expect(local.applied, isEmpty);
  });

  test(
    'switching account mid-upload never sends the new data as the old user',
    () async {
      local.pending.add(wordRecord('u1'));
      final reached = Completer<void>();
      final release = Completer<void>();
      server.pauseCreate = (request) {
        if (reached.isCompleted) return Future.value();
        reached.complete();
        return release.future;
      };
      await signIn();
      final running = engine.sync();
      await reached.future;
      await engine.signOut();
      server.user = 'user-b';
      await signIn();
      local.pending.add(
        SyncRecord(SyncKind.mark, 'm1', fakeDevice, 5, {
          'word': fakeWord,
          'kind': 'shape',
          'style': '',
          'color': '',
        }),
      );
      release.complete();
      await running;
      await engine.sync();
      expect(
        server.records['mark_actions']!.map((r) => r['user']),
        everyElement('user-b'),
      );
      expect(server.records['mark_actions'], hasLength(1));
    },
  );

  test('disposing mid-upload does not notify a disposed engine', () async {
    local.pending.add(wordRecord('u1'));
    final reached = Completer<void>();
    final release = Completer<void>();
    server.pauseCreate = (_) {
      reached.complete();
      return release.future;
    };
    await signIn();
    final running = engine.sync();
    await reached.future;
    engine.dispose();
    release.complete();
    await running;
    expect(local.uploaded, isEmpty);
  });

  test('the server time of an upload is handed back to the device', () async {
    local.pending.add(wordRecord('u1', at: 99999999999999));
    server.clampTo = 1234;
    await signIn();
    await engine.sync();
    expect(local.serverTimes, {'u1': 1234});
  });

  test('a clash on the server is retried once', () async {
    await signIn();
    await engine.sync();
    local.pending.add(wordRecord('u1'));
    server.failNextWith = 400;
    await engine.sync();
    expect(local.uploaded, {'u1'});
    expect(engine.problem, isNull);
  });

  test('the poll only syncs in the foreground (R58)', () async {
    await signIn();
    await engine.sync();
    final polling = SyncEngine(
      local,
      PocketBaseApi('http://pb', client: MockClient(server.handle)),
      online: const Stream.empty(),
      poll: const Duration(milliseconds: 10),
    );
    await polling.start();
    polling.foreground = false;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final before = server.requests.length;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.requests.length, before);
    polling.foreground = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.requests.length, greaterThan(before));
    polling.dispose();
  });

  test('an unverified account is told to verify (R81)', () async {
    server.verified = false;
    await expectLater(signIn(), throwsA(isA<NotVerified>()));
    expect(engine.signedIn, isFalse);
  });

  test(
    'the connection coming back and a local change both trigger a sync',
    () async {
      await signIn();
      await Future<void>.delayed(Duration.zero);
      final quick = SyncEngine(
        local,
        PocketBaseApi('http://pb', client: MockClient(server.handle)),
        online: online.stream,
        poll: null,
        settle: Duration.zero,
      );
      await quick.start();
      final afterStart = server.requests.length;
      expect(afterStart, greaterThan(0));
      online.add(false);
      online.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final afterOnline = server.requests.length;
      expect(afterOnline, greaterThan(afterStart));
      quick.localChanged();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(server.requests.length, greaterThan(afterOnline));
      quick.dispose();
    },
  );
}
