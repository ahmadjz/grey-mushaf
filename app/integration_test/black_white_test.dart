import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

const expectEInk = bool.fromEnvironment('EXPECT_EINK');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the device reports e-ink only on an ONYX', (tester) async {
    final eInk = await isEInkDevice();
    debugPrint('BW_PROOF isEInk=$eInk expected=$expectEInk');
    expect(eInk, expectEInk);
  });

  testWidgets('the B/W choice survives a restart and starts unset', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'bw-proof.db');
    await deleteDatabase(filename);
    var store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.blackWhite, isNull);
    for (final on in [false, true]) {
      await store.saveBlackWhite(on);
      await store.close();
      store = await SqliteRevealStore.open(databasePath: filename);
      expect(store.blackWhite, on);
    }
    await store.close();
    final db = await openDatabase(filename);
    await db.update(
      'local_metadata',
      {'value': 'junk'},
      where: 'key = ?',
      whereArgs: ['reader_black_white'],
    );
    await db.close();
    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.blackWhite, isNull);
    await store.close();
    await deleteDatabase(filename);
  });
}
