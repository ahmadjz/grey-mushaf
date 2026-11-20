import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/bookmarks.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/sync_local.dart';
import 'package:greymushaf/word_marks.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

Future<String> _fresh(String name) async {
  final filename = path.join(await getDatabasesPath(), name);
  await deleteDatabase(filename);
  addTearDown(() => deleteDatabase(filename));
  return filename;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a replayed no-op reveal never counts again', (tester) async {
    final store = await SqliteRevealStore.open(
      databasePath: await _fresh('sync-noop.db'),
    );
    final key = wordKey('2:255:1');
    await store.save(WordAction(key, true));
    final replayed = WordAction(key, true);
    await store.save(replayed);
    await store.save(WordAction(key, false));
    await store.save(replayed);
    expect(store.state(key), (black: false, count: 1));
    await store.close();
  });

  testWidgets('replayed no-op marks and bookmarks change nothing', (
    tester,
  ) async {
    final store = await SqliteRevealStore.open(
      databasePath: await _fresh('sync-noop-marks.db'),
    );
    final key = wordKey('2:255:2');
    const red = (style: MarkStyle.singleLine, color: MarkColor.red);
    await store.saveMark(MarkAction(key, MarkKind.line, red));
    final replayedMark = MarkAction(key, MarkKind.line, red);
    await store.saveMark(replayedMark);
    await store.saveMark(MarkAction(key, MarkKind.line, null));
    await store.saveMark(replayedMark);
    expect(store.marks(key), noMarks);

    await store.saveBookmarks([BookmarkAction(9, true)]);
    final replayedBookmark = BookmarkAction(9, true);
    await store.saveBookmarks([replayedBookmark]);
    await store.saveBookmarks([BookmarkAction(9, false)]);
    await store.saveBookmarks([replayedBookmark]);
    expect(store.bookmarkSavedAt, isEmpty);
    await store.close();
  });

  SyncRecord word(
    String uuid,
    String key,
    bool black,
    int at, {
    bool? counted,
  }) => SyncRecord(SyncKind.word, uuid, 'other-device', at, {
    'word': key,
    'black': black,
    'counted': counted ?? black,
  });

  testWidgets('the newest change wins and every reveal counts (R77, R6)', (
    tester,
  ) async {
    final store = await SqliteRevealStore.open(
      databasePath: await _fresh('sync-newest.db'),
    );
    final key = wordKey('2:255:3');
    await store.save(WordAction(key, true, createdAt: 1000));
    final changes = <SyncChange>[];
    final listening = store.remoteChanges.listen(changes.add);

    await store.applyRemote([
      word('11111111-1111-4111-8111-111111111111', key, false, 900),
    ]);
    expect(store.state(key), (black: true, count: 1));

    await store.applyRemote([
      word('22222222-2222-4222-8222-222222222222', key, true, 950),
    ]);
    expect(store.state(key), (black: true, count: 2));

    final grey = word('33333333-3333-4333-8333-333333333333', key, false, 2000);
    await store.applyRemote([grey, grey]);
    await store.applyRemote([grey]);
    expect(store.state(key), (black: false, count: 2));
    await tester.pump();
    expect(changes.map((c) => c.words).toList(), [
      {key},
      {key},
      {key},
    ]);

    await store.save(WordAction(key, true, createdAt: 1500));
    expect(store.state(key), (black: false, count: 3));
    await store.save(WordAction(key, true, createdAt: 2500));
    expect(store.state(key), (black: true, count: 4));
    await listening.cancel();
    await store.close();

    final reopened = await SqliteRevealStore.open(
      databasePath: path.join(await getDatabasesPath(), 'sync-newest.db'),
    );
    expect(reopened.state(key), (black: true, count: 4));
    await reopened.close();
  });

  testWidgets('remote marks and bookmarks follow the newest change', (
    tester,
  ) async {
    final store = await SqliteRevealStore.open(
      databasePath: await _fresh('sync-marks.db'),
    );
    final key = wordKey('3:1:1');
    const blue = (style: MarkStyle.circle, color: MarkColor.blue);
    await store.saveMark(MarkAction(key, MarkKind.shape, blue, createdAt: 500));
    await store.applyRemote([
      SyncRecord(
        SyncKind.mark,
        '44444444-4444-4444-8444-444444444444',
        'b',
        400,
        {'word': key, 'kind': 'line', 'style': 'doubleLine', 'color': 'green'},
      ),
      SyncRecord(
        SyncKind.mark,
        '55555555-5555-4555-8555-555555555555',
        'b',
        600,
        {'word': key, 'kind': 'shape', 'style': '', 'color': ''},
      ),
      SyncRecord(
        SyncKind.bookmark,
        '66666666-6666-4666-8666-666666666666',
        'b',
        700,
        {'page': 42, 'saved': true},
      ),
    ]);
    expect(store.marks(key), (
      line: (style: MarkStyle.doubleLine, color: MarkColor.green),
      shape: null,
    ));
    expect(store.bookmarkSavedAt, {42: 700});
    await store.saveBookmarks([BookmarkAction(42, false, createdAt: 650)]);
    expect(store.bookmarkSavedAt, {42: 700});
    await store.close();
  });

  testWidgets('malformed remote records are skipped, not stored', (
    tester,
  ) async {
    final store = await SqliteRevealStore.open(
      databasePath: await _fresh('sync-malformed.db'),
    );
    final change = await store.applyRemote([
      word('77777777-7777-4777-8777-777777777771', 'not-a-word', true, 1),
      word(
        '77777777-7777-4777-8777-777777777772',
        wordKey('1:1:1'),
        false,
        1,
        counted: true,
      ),
      SyncRecord(
        SyncKind.word,
        '77777777-7777-4777-8777-777777777773',
        'b',
        1,
        {'word': wordKey('1:1:1'), 'black': null},
      ),
      SyncRecord(
        SyncKind.mark,
        '77777777-7777-4777-8777-777777777774',
        'b',
        1,
        {
          'word': wordKey('1:1:1'),
          'kind': 'line',
          'style': 'circle',
          'color': 'red',
        },
      ),
      SyncRecord(
        SyncKind.mark,
        '77777777-7777-4777-8777-777777777775',
        'b',
        1,
        {'word': wordKey('1:1:1'), 'kind': 'shape'},
      ),
      SyncRecord(
        SyncKind.bookmark,
        '77777777-7777-4777-8777-777777777776',
        'b',
        1,
        {'page': 605, 'saved': true},
      ),
    ]);
    expect(change.isEmpty, isTrue);
    expect(await store.pendingCount(), 0);
    expect(store.state(wordKey('1:1:1')), greyWord);
    await store.close();
  });

  testWidgets('only local actions wait for upload until acknowledged', (
    tester,
  ) async {
    final filename = await _fresh('sync-pending.db');
    var store = await SqliteRevealStore.open(databasePath: filename);
    final key = wordKey('4:1:1');
    final reveal = WordAction(key, true, createdAt: 10);
    await store.save(reveal);
    await store.save(WordAction(key, false, createdAt: 20));
    await store.saveMark(
      MarkAction(key, MarkKind.line, (
        style: MarkStyle.singleLine,
        color: MarkColor.red,
      ), createdAt: 30),
    );
    await store.saveBookmarks([BookmarkAction(3, true, createdAt: 40)]);
    await store.applyRemote([
      word('88888888-8888-4888-8888-888888888888', key, true, 50),
    ]);
    expect(await store.pendingCount(), 4);

    final words = await store.pendingUploads(SyncKind.word);
    expect(
      [for (final r in words) (r.uuid, r.createdAt)],
      [(reveal.uuid, 10), (words[1].uuid, 20)],
    );
    expect(
      [for (final r in words) r.fields],
      [
        {'word': key, 'black': true, 'counted': true},
        {'word': key, 'black': false, 'counted': false},
      ],
    );
    expect(words.every((r) => r.device == store.deviceId), isTrue);
    expect((await store.pendingUploads(SyncKind.mark)).single.fields, {
      'word': key,
      'kind': 'line',
      'style': 'singleLine',
      'color': 'red',
    });
    expect((await store.pendingUploads(SyncKind.bookmark)).single.fields, {
      'page': 3,
      'saved': true,
    });

    await store.markUploaded([reveal.uuid, reveal.uuid]);
    await store.saveSyncValues({'cursor': '7', 'gone': 'x'});
    await store.saveSyncValues({'gone': null});
    await store.close();
    store = await SqliteRevealStore.open(databasePath: filename);
    expect(await store.pendingCount(), 3);
    expect(store.syncValue('cursor'), '7');
    expect(store.syncValue('gone'), isNull);

    await store.forgetUploads();
    expect(await store.pendingCount(), 5);
    await store.close();
  });

  testWidgets(
    'upgrade from version 3 keeps reveals and orders old actions first',
    (tester) async {
      final filename = await _fresh('sync-from-v3.db');
      var store = await SqliteRevealStore.open(databasePath: filename);
      final key = wordKey('5:1:1');
      await store.save(WordAction(key, true));
      await store.save(WordAction(key, false));
      await store.save(WordAction(key, true));
      await store.close();
      final db = await openDatabase(filename);
      await db.execute('DROP TABLE word_action_times');
      await db.execute('DROP TABLE uploaded_actions');
      await db.setVersion(3);
      await db.close();

      store = await SqliteRevealStore.open(databasePath: filename);
      expect(store.state(key), (black: true, count: 2));
      final old = await store.pendingUploads(SyncKind.word);
      expect([for (final r in old) r.createdAt], [1, 2, 3]);
      await store.applyRemote([
        word('99999999-9999-4999-8999-999999999999', key, false, 4),
      ]);
      expect(store.state(key), (black: false, count: 2));
      await store.save(WordAction(key, true, createdAt: 10));
      expect(store.state(key), (black: true, count: 3));
      await store.close();
    },
  );
}
