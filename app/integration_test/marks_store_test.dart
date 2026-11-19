import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/word_marks.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../test/word_target.dart';

const _revealTables = [
  'local_metadata',
  'word_actions',
  'reveal_events',
  'word_state',
];

Future<void> _createVersionOne(String filename) async {
  final db = await openDatabase(
    filename,
    version: 1,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE local_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await db.execute(
        '''CREATE TABLE word_actions (
          local_seq INTEGER PRIMARY KEY AUTOINCREMENT,
          action_uuid TEXT UNIQUE NOT NULL, device_id TEXT NOT NULL,
          word_key TEXT NOT NULL, target_black INTEGER NOT NULL CHECK(target_black IN (0,1)))''',
      );
      await db.execute(
        'CREATE INDEX actions_by_word ON word_actions(word_key)',
      );
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
      Future<void> act(String word, bool black) async {
        final uuid = 'old-${seq++}';
        await db.insert('word_actions', {
          'action_uuid': uuid,
          'device_id': 'old-device',
          'word_key': wordKey(word),
          'target_black': black ? 1 : 0,
        });
        if (black) await db.insert('reveal_events', {'action_uuid': uuid});
        final count = (await db.rawQuery(
          'SELECT COUNT(*) AS n FROM reveal_events JOIN word_actions USING (action_uuid) WHERE word_key = ?',
          [wordKey(word)],
        )).single['n'];
        await db.insert('word_state', {
          'word_key': wordKey(word),
          'is_black': black ? 1 : 0,
          'reveal_count': count,
          'last_action_uuid': uuid,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await act('1:1:1', true);
      await act('1:1:1', false);
      await act('1:1:1', true);
      await act('2:255:3', true);
      await act('2:255:4', true);
      await act('2:255:4', false);
    },
  );
  await db.close();
}

Future<Map<String, List<Map<String, Object?>>>> _rows(String filename) async {
  final db = await openDatabase(filename);
  final rows = {
    for (final table in _revealTables)
      table: await db.query(table, orderBy: 'rowid'),
  };
  await db.close();
  return rows;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('upgrade from version 1 keeps every reveal row and adds marks', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'marks-upgrade.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    await _createVersionOne(filename);
    final before = await _rows(filename);

    var store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.deviceId, 'old-device');
    expect(store.greyLevel, 200);
    expect(store.state(wordKey('1:1:1')), (black: true, count: 2));
    expect(store.state(wordKey('2:255:3')), (black: true, count: 1));
    expect(store.state(wordKey('2:255:4')), (black: false, count: 1));
    await store.close();
    expect(await _rows(filename), before);

    store = await SqliteRevealStore.open(databasePath: filename);
    final key = wordKey('2:255:4');
    const red = (style: MarkStyle.doubleLine, color: MarkColor.red);
    final line = MarkAction(key, MarkKind.line, red);
    await store.saveMark(line);
    await store.saveMark(line);
    await store.saveMark(
      MarkAction(key, MarkKind.shape, (
        style: MarkStyle.circle,
        color: MarkColor.black,
      )),
    );
    await store.saveMark(MarkAction(key, MarkKind.line, null));
    await store.saveMark(MarkAction(key, MarkKind.line, red));
    expect(store.marks(key), (
      line: red,
      shape: (style: MarkStyle.circle, color: MarkColor.black),
    ));
    expect(store.state(key), (black: false, count: 1));
    await store.close();

    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.marks(key), (
      line: red,
      shape: (style: MarkStyle.circle, color: MarkColor.black),
    ));
    expect(store.state(key), (black: false, count: 1));
    await store.close();
    expect(await _rows(filename), before);

    final db = await openDatabase(filename);
    expect(await db.getVersion(), 2);
    expect((await db.query('mark_actions')).length, 4);
    await db.close();
  });

  testWidgets('a failed upgrade rolls back and leaves version 1 intact', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'marks-failed.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    await _createVersionOne(filename);
    var db = await openDatabase(filename);
    await db.execute('CREATE TABLE word_marks (blocker INTEGER)');
    await db.close();
    final before = await _rows(filename);

    await expectLater(
      SqliteRevealStore.open(databasePath: filename),
      throwsA(isA<DatabaseException>()),
    );

    db = await openDatabase(filename);
    expect(await db.getVersion(), 1);
    final tables = (await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name = 'mark_actions'",
    ));
    expect(tables, isEmpty);
    await db.close();
    expect(await _rows(filename), before);
  });

  testWidgets('mark rows refuse impossible combinations', (tester) async {
    final filename = path.join(await getDatabasesPath(), 'marks-checks.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    final store = await SqliteRevealStore.open(databasePath: filename);
    await store.close();
    final db = await openDatabase(filename);
    Future<void> insert(String? style, String? color, [String kind = 'line']) =>
        db.insert('mark_actions', {
          'action_uuid': 'bad-$kind-$style-$color',
          'device_id': 'd',
          'created_at': 0,
          'word_key': wordKey('1:1:1'),
          'kind': kind,
          'style': style,
          'color': color,
        });
    for (final bad in [
      () => insert('circle', 'red'),
      () => insert('singleLine', 'red', 'shape'),
      () => insert('singleLine', null),
      () => insert(null, 'red'),
      () => insert('singleLine', 'pink'),
      () => insert('singleLine', 'red', 'other'),
    ]) {
      await expectLater(bad(), throwsA(isA<DatabaseException>()));
    }
    await insert('singleLine', 'red');
    await insert(null, null, 'shape');
    await db.close();
  });

  testWidgets('toolbar preferences survive reopening', (tester) async {
    final filename = path.join(await getDatabasesPath(), 'marks-toolbar.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    var store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.toolbar.tools, [MarkTool.visible]);
    expect(store.toolbar.color, MarkColor.red);
    await store.saveToolbar(
      const ToolbarPrefs(
        tools: [MarkTool.circle, MarkTool.singleLine],
        color: MarkColor.purple,
        spot: Offset(.2, .7),
        pinned: true,
        hidden: true,
      ),
    );
    await store.close();
    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.toolbar.tools, [MarkTool.circle, MarkTool.singleLine]);
    expect(store.toolbar.color, MarkColor.purple);
    expect(store.toolbar.spot, const Offset(.2, .7));
    expect(store.toolbar.pinned, isTrue);
    expect(store.toolbar.hidden, isTrue);
    await store.close();
  });

  testWidgets('marks made in the reader survive a restart through SQLite', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'marks-reader.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    final pages = await loadPages();
    var store = await SqliteRevealStore.open(databasePath: filename);
    await store.saveToolbar(
      const ToolbarPrefs(
        tools: [MarkTool.visible, MarkTool.doubleLine, MarkTool.rectangle],
        color: MarkColor.green,
      ),
    );
    Future<void> show(SqliteRevealStore store) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(
            pages: pages,
            store: store,
            settings: store,
            toolbarSettings: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const word = WordTarget(3);
    await show(store);
    await longPressTarget(tester, word);
    for (
      var i = 0;
      i < 50 && !testSemantics(tester, word).label.contains('rectangle');
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox());
    await store.close();

    store = await SqliteRevealStore.open(databasePath: filename);
    await show(store);
    expect(
      testSemantics(tester, word).label,
      endsWith('; revealed; reveals 1; doubleLine green; rectangle green'),
    );
    final key = wordKey(
      testSemantics(tester, word).label.split(';').first.trim(),
    );
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-row-Double line')));
    for (
      var i = 0;
      i < 50 &&
          store.marks(key).line !=
              null;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox());
    await store.close();

    store = await SqliteRevealStore.open(databasePath: filename);
    await show(store);
    expect(
      testSemantics(tester, word).label,
      endsWith('; revealed; reveals 1; rectangle green'),
    );
    await tester.pumpWidget(const SizedBox());
    final db = await openDatabase(filename);
    final tombstones = await db.query('word_marks', where: 'style IS NULL');
    expect(tombstones, hasLength(1));
    expect(tombstones.single['kind'], 'line');
    await db.close();
    await store.close();
  });

  testWidgets('a failed mark write leaves no row and no projection', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'marks-txn.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    final store = await SqliteRevealStore.open(databasePath: filename);
    final db = await openDatabase(filename);
    await db.execute(
      "CREATE TRIGGER fail_marks BEFORE INSERT ON word_marks BEGIN SELECT RAISE(ABORT, 'proof failure'); END",
    );
    final key = wordKey('1:1:2');
    final action = MarkAction(key, MarkKind.shape, (
      style: MarkStyle.rectangle,
      color: MarkColor.orange,
    ));
    await expectLater(
      store.saveMark(action),
      throwsA(isA<DatabaseException>()),
    );
    expect(store.marks(key), noMarks);
    expect(await db.query('mark_actions'), isEmpty);
    await db.execute('DROP TRIGGER fail_marks');
    await store.saveMark(action);
    expect(store.marks(key).shape?.color, MarkColor.orange);
    expect((await db.query('mark_actions')).single['action_uuid'], action.uuid);
    await db.close();
    await store.close();
  });

  testWidgets('a removal after a clock step back still sorts last', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'marks-clock.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    final store = await SqliteRevealStore.open(databasePath: filename);
    final key = wordKey('1:1:3');
    final add = MarkAction(key, MarkKind.line, (
      style: MarkStyle.singleLine,
      color: MarkColor.red,
    ), createdAt: 5000);
    final remove = MarkAction(key, MarkKind.line, null, createdAt: 1000);
    await store.saveMark(add);
    await store.saveMark(remove);
    final db = await openDatabase(filename);
    final rows = await db.query('mark_actions', orderBy: 'local_seq');
    expect(rows.map((r) => r['created_at']), [5000, 5001]);
    expect(rows.map((r) => r['device_id']).toSet(), {store.deviceId});
    expect(rows.last['style'], isNull);
    await db.close();
    await store.close();
  });

  testWidgets('a fresh database and an upgraded one share the mark schema', (
    tester,
  ) async {
    final fresh = path.join(await getDatabasesPath(), 'marks-fresh.db');
    final upgraded = path.join(await getDatabasesPath(), 'marks-upgraded.db');
    for (final file in [fresh, upgraded]) {
      await deleteDatabase(file);
      addTearDown(() => deleteDatabase(file));
    }
    await (await SqliteRevealStore.open(databasePath: fresh)).close();
    await _createVersionOne(upgraded);
    await (await SqliteRevealStore.open(databasePath: upgraded)).close();
    Future<List<Map<String, Object?>>> schema(String file) async {
      final db = await openDatabase(file);
      final rows = await db.query(
        'sqlite_master',
        columns: ['type', 'name', 'sql'],
        orderBy: 'name',
      );
      await db.close();
      return rows;
    }

    expect(await schema(upgraded), await schema(fresh));
  });
}
