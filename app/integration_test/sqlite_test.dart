import '../test/word_target.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real SQLite: reopen, idempotency, events, rollback, stable keys', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'persistence-test.db');
    await deleteDatabase(filename);
    var store = await SqliteRevealStore.open(databasePath: filename);
    final device = store.deviceId;
    final key = wordKey('1:1:1');
    final reveal = WordAction(key, true);
    await store.save(reveal);
    await store.save(reveal);
    await store.save(WordAction(key, true));
    expect(store.state(key), (black: true, count: 1));
    await store.close();
    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.deviceId, device);
    expect(store.state(key), (black: true, count: 1));
    await store.save(WordAction(key, false));
    await store.close();
    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.state(key), (black: false, count: 1));
    await store.save(WordAction(wordKey('1:1:1'), true));
    expect(store.state(key), (black: true, count: 2));
    final db = await openDatabase(filename);
    expect((await db.query('word_actions')).length, 3);
    expect((await db.query('reveal_events')).length, 2);
    await db.execute(
      "CREATE TRIGGER fail_projection BEFORE UPDATE ON word_state BEGIN SELECT RAISE(ABORT, 'proof failure'); END",
    );
    final grey = WordAction(key, false);
    await expectLater(store.save(grey), throwsA(isA<DatabaseException>()));
    expect(store.state(key), (black: true, count: 2));
    expect((await db.query('word_actions')).length, 3);
    await db.execute('DROP TRIGGER fail_projection');
    await store.save(grey);
    await store.save(grey);
    expect(store.state(key), (black: false, count: 2));
    await db.execute(
      "CREATE TRIGGER fail_reveal BEFORE INSERT ON word_state BEGIN SELECT RAISE(ABORT, 'proof failure'); END",
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: await loadPages(), store: store),
      ),
    );
    await tester.pumpAndSettle();
    final second = WordTarget.key(const ValueKey('word-2'));
    String label() => testSemantics(tester, second).label;
    await longPressTarget(tester, second);
    for (var i = 0; i < 50 && find.text('Retry').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(label(), contains('; unrevealed; reveals 0'));
    expect(find.text("Couldn't save"), findsOneWidget);
    expect((await db.query('reveal_events')).length, 2);
    expect((await db.query('word_actions')).length, 4);
    await db.execute('DROP TRIGGER fail_reveal');
    await tester.pumpAndSettle();
    expect(find.text('Retry').hitTestable(), findsOneWidget);
    await tapTarget(tester, find.text('Retry'));
    for (var i = 0; i < 50 && !label().contains('; revealed;'); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(label(), contains('; revealed; reveals 1'));
    expect((await db.query('reveal_events')).length, 3);
    await tester.pumpWidget(const SizedBox());
    debugPrint(
      'SQLite proof identifiers: ${await db.query('local_metadata')}; ${await db.query('word_actions', columns: ['action_uuid', 'word_key'])}',
    );
    await store.close();
    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.state(key), (black: false, count: 2));
    expect(store.state(wordKey('2:1:1')), greyWord);
    await store.close();
    await deleteDatabase(filename);
  });
}
