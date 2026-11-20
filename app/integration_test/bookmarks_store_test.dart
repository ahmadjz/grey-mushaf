import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/bookmarks.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/word_marks.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

const _savedTables = [
  'local_metadata',
  'word_actions',
  'reveal_events',
  'word_state',
  'mark_actions',
  'word_marks',
];

Future<void> _versionOneTables(Database db) async {
  await db.execute(
    'CREATE TABLE local_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  );
  await db.execute(
    '''CREATE TABLE word_actions (
          local_seq INTEGER PRIMARY KEY AUTOINCREMENT,
          action_uuid TEXT UNIQUE NOT NULL, device_id TEXT NOT NULL,
          word_key TEXT NOT NULL, target_black INTEGER NOT NULL CHECK(target_black IN (0,1)))''',
  );
  await db.execute('CREATE INDEX actions_by_word ON word_actions(word_key)');
  await db.execute(
    '''CREATE TABLE reveal_events (
          action_uuid TEXT PRIMARY KEY NOT NULL REFERENCES word_actions(action_uuid))''',
  );
  await db.execute(
    '''CREATE TABLE word_state (
          word_key TEXT PRIMARY KEY NOT NULL,
          is_black INTEGER NOT NULL CHECK(is_black IN (0,1)),
          reveal_count INTEGER NOT NULL CHECK(reveal_count >= 0),
          last_action_uuid TEXT NOT NULL REFERENCES word_actions(action_uuid))''',
  );
  await db.insert('local_metadata', {
    'key': 'device_id',
    'value': 'old-device',
  });
  await db.insert('local_metadata', {
    'key': 'identity_version',
    'value': 'qul-v4-hafs:1',
  });
  await db.insert('local_metadata', {
    'key': 'reader_grey_level',
    'value': '200',
  });
  var seq = 0;
  Future<void> act(String word, bool black, int count) async {
    final uuid = 'old-${seq++}';
    await db.insert('word_actions', {
      'action_uuid': uuid,
      'device_id': 'old-device',
      'word_key': wordKey(word),
      'target_black': black ? 1 : 0,
    });
    if (black) await db.insert('reveal_events', {'action_uuid': uuid});
    await db.insert('word_state', {
      'word_key': wordKey(word),
      'is_black': black ? 1 : 0,
      'reveal_count': count,
      'last_action_uuid': uuid,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  await act('1:1:1', true, 1);
  await act('1:1:1', false, 1);
  await act('1:1:1', true, 2);
  await act('2:255:4', true, 1);
}

const _markCheck = '''CHECK ((style IS NULL AND color IS NULL) OR (style IS NOT NULL AND color IS NOT NULL
    AND color IN ('red','blue','green','orange','purple','black')
    AND ((kind = 'line' AND style IN ('singleLine','doubleLine'))
      OR (kind = 'shape' AND style IN ('rectangle','circle')))))''';

Future<void> _versionTwoTables(Database db) async {
  await db.execute('''CREATE TABLE mark_actions (
    local_seq INTEGER PRIMARY KEY AUTOINCREMENT,
    action_uuid TEXT UNIQUE NOT NULL, device_id TEXT NOT NULL,
    created_at INTEGER NOT NULL, word_key TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('line','shape')),
    style TEXT CHECK(style IS NULL OR style IN ('singleLine','doubleLine','rectangle','circle')), color TEXT,
    $_markCheck)''');
  await db.execute(
    'CREATE INDEX mark_actions_by_word ON mark_actions(word_key)',
  );
  await db.execute('''CREATE TABLE word_marks (
    word_key TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('line','shape')),
    style TEXT, color TEXT,
    last_action_uuid TEXT NOT NULL REFERENCES mark_actions(action_uuid),
    PRIMARY KEY (word_key, kind),
    $_markCheck)''');
  for (final (uuid, word, kind, style, color, at) in [
    ('m-0', '2:255:4', 'line', 'doubleLine', 'red', 10),
    ('m-1', '2:255:4', 'shape', 'circle', 'blue', 11),
    ('m-2', '1:1:2', 'line', 'singleLine', 'green', 12),
    ('m-3', '1:1:2', 'line', null, null, 13),
  ]) {
    await db.insert('mark_actions', {
      'action_uuid': uuid,
      'device_id': 'old-device',
      'created_at': at,
      'word_key': wordKey(word),
      'kind': kind,
      'style': style,
      'color': color,
    });
    await db.insert('word_marks', {
      'word_key': wordKey(word),
      'kind': kind,
      'style': style,
      'color': color,
      'last_action_uuid': uuid,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

Future<void> _create(String filename, int version) async {
  final db = await openDatabase(
    filename,
    version: version,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) async {
      await _versionOneTables(db);
      if (version >= 2) await _versionTwoTables(db);
    },
  );
  await db.close();
}

Future<Map<String, List<Map<String, Object?>>>> _rows(
  String filename,
  List<String> tables,
) async {
  final db = await openDatabase(filename);
  final rows = {
    for (final table in tables) table: await db.query(table, orderBy: 'rowid'),
  };
  await db.close();
  return rows;
}

Future<String> _fresh(String name) async {
  final filename = path.join(await getDatabasesPath(), name);
  await deleteDatabase(filename);
  addTearDown(() => deleteDatabase(filename));
  return filename;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'upgrade from version 2 keeps reveals and marks and adds bookmarks',
    (tester) async {
      final filename = await _fresh('bookmarks-from-v2.db');
      await _create(filename, 2);
      final before = await _rows(filename, _savedTables);

      var store = await SqliteRevealStore.open(databasePath: filename);
      expect(store.deviceId, 'old-device');
      expect(store.greyLevel, 200);
      expect(store.state(wordKey('1:1:1')), (black: true, count: 2));
      expect(store.marks(wordKey('2:255:4')), (
        line: (style: MarkStyle.doubleLine, color: MarkColor.red),
        shape: (style: MarkStyle.circle, color: MarkColor.blue),
      ));
      expect(store.marks(wordKey('1:1:2')), noMarks);
      expect(store.lastPage, 1);
      expect(store.bookmarkSavedAt, isEmpty);

      final first = BookmarkAction(50, true, createdAt: 100);
      await store.saveBookmarks([
        first,
        BookmarkAction(77, true, createdAt: 200),
      ]);
      await store.saveBookmarks([first]);
      await store.saveBookmarks([BookmarkAction(77, false, createdAt: 300)]);
      await store.saveBookmarks([BookmarkAction(604, true, createdAt: 400)]);
      await store.saveLastPage(216);
      await store.close();

      store = await SqliteRevealStore.open(databasePath: filename);
      expect(store.bookmarkSavedAt, {50: 100, 604: 400});
      expect(store.lastPage, 216);
      expect(store.state(wordKey('2:255:4')), (black: true, count: 1));
      await store.close();

      final after = await _rows(filename, [..._savedTables, 'bookmarks']);
      expect(after['local_metadata'], [
        ...before['local_metadata']!,
        {'key': 'reader_last_page', 'value': '216'},
      ]);
      for (final table in _savedTables.skip(1)) {
        expect(after[table], before[table], reason: table);
      }
      expect(
        [
          for (final row in after['bookmarks']!)
            (row['page'], row['saved'], row['saved_at']),
        ],
        [(50, 1, 100), (77, 0, 300), (604, 1, 400)],
      );
      expect(after['bookmarks']!.first['last_action_uuid'], first.uuid);
      final db = await openDatabase(filename);
      expect(await db.getVersion(), 3);
      expect((await db.query('bookmark_actions')).length, 4);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await db.close();
    },
  );

  testWidgets('upgrade straight from version 1 keeps reveals', (tester) async {
    final filename = await _fresh('bookmarks-from-v1.db');
    await _create(filename, 1);
    final tables = _savedTables.take(4).toList();
    final before = await _rows(filename, tables);
    final store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.state(wordKey('1:1:1')), (black: true, count: 2));
    await store.saveBookmarks([BookmarkAction(3, true)]);
    await store.close();
    expect(await _rows(filename, tables), before);
    final db = await openDatabase(filename);
    expect(await db.getVersion(), 3);
    expect((await db.query('bookmarks')).single['page'], 3);
    await db.close();
  });

  testWidgets('a failed upgrade to version 3 rolls back and keeps version 2', (
    tester,
  ) async {
    final filename = await _fresh('bookmarks-failed.db');
    await _create(filename, 2);
    var db = await openDatabase(filename);
    await db.execute('CREATE TABLE bookmarks (blocker INTEGER)');
    await db.close();
    final before = await _rows(filename, _savedTables);

    await expectLater(
      SqliteRevealStore.open(databasePath: filename),
      throwsA(isA<DatabaseException>()),
    );

    db = await openDatabase(filename);
    expect(await db.getVersion(), 2);
    expect(
      await db.query(
        'sqlite_master',
        where: "type = 'table' AND name = 'bookmark_actions'",
      ),
      isEmpty,
    );
    await db.close();
    expect(await _rows(filename, _savedTables), before);
  });

  testWidgets('a spread change commits both pages or neither', (tester) async {
    final filename = await _fresh('bookmarks-atomic.db');
    var store = await SqliteRevealStore.open(databasePath: filename);
    await store.saveBookmarks([
      BookmarkAction(10, true, createdAt: 1),
      BookmarkAction(11, true, createdAt: 2),
    ]);
    await store.close();
    final db = await openDatabase(filename);
    await db.execute('''CREATE TRIGGER refuse_eleven BEFORE UPDATE ON bookmarks
      WHEN NEW.page = 11 BEGIN SELECT RAISE(ABORT, 'injected'); END''');
    await db.execute(
      '''CREATE TRIGGER refuse_eleven_insert BEFORE INSERT ON bookmarks
      WHEN NEW.page = 11 BEGIN SELECT RAISE(ABORT, 'injected'); END''',
    );
    await db.close();

    store = await SqliteRevealStore.open(databasePath: filename);
    final removal = [BookmarkAction(10, false), BookmarkAction(11, false)];
    await expectLater(store.saveBookmarks(removal), throwsA(anything));
    expect(store.bookmarkSavedAt, {10: 1, 11: 2});
    await store.close();
    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.bookmarkSavedAt, {10: 1, 11: 2});
    await store.close();
  });

  testWidgets('bookmarks sort newest even after the clock steps back', (
    tester,
  ) async {
    final filename = await _fresh('bookmarks-clock.db');
    final store = await SqliteRevealStore.open(databasePath: filename);
    await store.saveBookmarks([BookmarkAction(5, true, createdAt: 1000)]);
    await store.saveBookmarks([BookmarkAction(5, false, createdAt: 900)]);
    await store.saveBookmarks([BookmarkAction(5, true, createdAt: 800)]);
    expect(store.bookmarkSavedAt, {5: 1002});
    await store.close();
  });

  testWidgets('bookmark rows refuse pages outside the mushaf', (tester) async {
    final filename = await _fresh('bookmarks-checks.db');
    await (await SqliteRevealStore.open(databasePath: filename)).close();
    final db = await openDatabase(filename);
    for (final page in [0, 605]) {
      await expectLater(
        db.insert('bookmark_actions', {
          'action_uuid': 'bad-$page',
          'device_id': 'd',
          'created_at': 1,
          'page': page,
          'saved': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
    }
    await db.insert('local_metadata', {
      'key': 'reader_last_page',
      'value': '999',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.close();
    final store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.lastPage, 1);
    await store.close();
  });

  testWidgets('a fresh database and an upgraded one share the schema', (
    tester,
  ) async {
    final fresh = await _fresh('bookmarks-fresh.db');
    final fromOne = await _fresh('bookmarks-up1.db');
    final fromTwo = await _fresh('bookmarks-up2.db');
    await (await SqliteRevealStore.open(databasePath: fresh)).close();
    await _create(fromOne, 1);
    await (await SqliteRevealStore.open(databasePath: fromOne)).close();
    await _create(fromTwo, 2);
    await (await SqliteRevealStore.open(databasePath: fromTwo)).close();
    Future<List<Map<String, Object?>>> schema(String file) async {
      final db = await openDatabase(file);
      final rows = await db.query(
        'sqlite_master',
        columns: ['type', 'name', 'sql'],
        where: "name NOT LIKE 'sqlite_%'",
        orderBy: 'name',
      );
      await db.close();
      return rows;
    }

    final expected = await schema(fresh);
    expect(await schema(fromOne), expected);
    expect(await schema(fromTwo), expected);
  });
}
