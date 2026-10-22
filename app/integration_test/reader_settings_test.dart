import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'device light and dark preferences persist independently of word actions',
    (tester) async {
      final filename = path.join(
        await getDatabasesPath(),
        'reader-settings-proof.db',
      );
      final otherFilename = path.join(
        await getDatabasesPath(),
        'reader-settings-other-proof.db',
      );
      await deleteDatabase(filename);
      await deleteDatabase(otherFilename);
      var store = await SqliteRevealStore.open(databasePath: filename);
      final other = await SqliteRevealStore.open(databasePath: otherFilename);
      debugPrint(
        'Preference proof device identifiers: ${store.deviceId}, ${other.deviceId}; metadata keys: device_id, identity_version, reader_grey_level, reader_dark_level. No accounts or tokens.',
      );
      expect(store.greyLevel, 176);
      expect(store.darkLevel, 80);
      final pages = await loadPages();
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(pages: pages, store: store, settings: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        Offset(
          3,
          tester.view.physicalSize.height / tester.view.devicePixelRatio / 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      for (final value in [128.0, 224.0]) {
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChanged!(value);
        slider.onChangeEnd!(value);
        for (var i = 0; i < 50 && store.greyLevel != value.toInt(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(store.greyLevel, value.toInt());
      }
      await tester.pumpWidget(const SizedBox());
      await store.close();
      store = await SqliteRevealStore.open(databasePath: filename);
      expect(store.greyLevel, 224);
      expect(other.greyLevel, 176);
      var db = await openDatabase(filename);
      expect(await db.query('word_actions'), isEmpty);
      expect(await db.query('reveal_events'), isEmpty);
      expect(await db.query('word_state'), isEmpty);
      await db.execute(
        "CREATE TRIGGER fail_preference BEFORE INSERT ON local_metadata WHEN NEW.key = 'reader_grey_level' BEGIN SELECT RAISE(ABORT, 'proof failure'); END",
      );
      await expectLater(
        store.saveGreyLevel(128),
        throwsA(isA<DatabaseException>()),
      );
      expect(store.greyLevel, 224);
      await db.execute('DROP TRIGGER fail_preference');
      await store.saveGreyLevel(128);
      await expectLater(store.saveGreyLevel(255), throwsRangeError);
      expect(store.greyLevel, 128);
      await db.update(
        'local_metadata',
        {'value': 'invalid'},
        where: 'key = ?',
        whereArgs: ['reader_grey_level'],
      );
      await store.close();
      store = await SqliteRevealStore.open(databasePath: filename);
      db = await openDatabase(filename);
      expect(store.greyLevel, 176);

      // Independent preferences must not change even populated word tables.
      final action = WordAction(wordKey('1:1:1'), true);
      await store.save(action);
      debugPrint(
        'Dark preference proof word: ${action.key}; action: ${action.uuid}',
      );
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in ['word_actions', 'word_state', 'reveal_events']) {
        before[table] = await db.query(table);
      }
      await store.saveGreyLevel(200);
      await store.saveDarkLevel(32);
      await store.saveDarkLevel(128);
      await store.close();
      store = await SqliteRevealStore.open(databasePath: filename);
      db = await openDatabase(filename);
      expect(store.greyLevel, 200);
      expect(store.darkLevel, 128);
      expect(other.darkLevel, 80);
      for (final table in before.keys) {
        expect(await db.query(table), before[table]);
      }
      await expectLater(store.saveDarkLevel(31), throwsRangeError);
      await expectLater(store.saveDarkLevel(129), throwsRangeError);
      await db.execute(
        "CREATE TRIGGER fail_dark BEFORE INSERT ON local_metadata WHEN NEW.key = 'reader_dark_level' BEGIN SELECT RAISE(ABORT, 'proof failure'); END",
      );
      await expectLater(
        store.saveDarkLevel(50),
        throwsA(isA<DatabaseException>()),
      );
      expect(store.darkLevel, 128);
      await db.execute('DROP TRIGGER fail_dark');
      for (final bad in ['invalid', '31', '129']) {
        await db.update(
          'local_metadata',
          {'value': bad},
          where: 'key = ?',
          whereArgs: ['reader_dark_level'],
        );
        await store.close();
        store = await SqliteRevealStore.open(databasePath: filename);
        db = await openDatabase(filename);
        expect(store.darkLevel, 80);
        expect(store.greyLevel, 200);
      }
      await store.close();
      await other.close();
      await deleteDatabase(filename);
      await deleteDatabase(otherFilename);
      debugPrint(
        'Preference proof cleanup: deleted reader-settings-proof.db and reader-settings-other-proof.db, including all listed device identifiers and metadata records.',
      );
    },
  );
}
