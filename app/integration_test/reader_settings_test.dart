import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('device grey preference persists independently of word actions', (
    tester,
  ) async {
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
      'Preference proof device identifiers: ${store.deviceId}, ${other.deviceId}; metadata keys: device_id, identity_version, reader_grey_level. No accounts or tokens.',
    );
    expect(store.greyLevel, 176);
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
    final db = await openDatabase(filename);
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
    expect(store.greyLevel, 176);
    await store.close();
    await other.close();
    await deleteDatabase(filename);
    await deleteDatabase(otherFilename);
    debugPrint(
      'Preference proof cleanup: deleted reader-settings-proof.db and reader-settings-other-proof.db, including all listed device identifiers and metadata records.',
    );
  });
}
