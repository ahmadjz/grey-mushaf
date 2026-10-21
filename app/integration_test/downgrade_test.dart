import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('newer schema is refused without changing version, rows or file', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'downgrade-test.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    final store = await SqliteRevealStore.open(databasePath: filename);
    final action = WordAction(wordKey('1:1:1'), true);
    await store.save(action);
    debugPrint(
      'Downgrade proof identifiers: device=${store.deviceId}; action=${action.uuid}; word=${action.key}; metadata=device_id,identity_version',
    );
    final db = await openDatabase(filename);
    await db.setVersion(2);
    final beforeRows = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'local_metadata',
      'word_actions',
      'reveal_events',
      'word_state',
    ]) {
      beforeRows[table] = await db.query(table);
    }
    await store.close();
    final beforeBytes = await File(filename).readAsBytes();
    Object? failure;
    try {
      final reopened = await SqliteRevealStore.open(databasePath: filename);
      await reopened.close();
    } catch (error) {
      failure = error;
    }
    // Check preservation even when the expected error is missing.
    final inspect = await openDatabase(filename);
    final version = await inspect.getVersion();
    final afterRows = <String, List<Map<String, Object?>>>{};
    for (final table in beforeRows.keys) {
      afterRows[table] = await inspect.query(table);
    }
    await inspect.close();
    final afterBytes = await File(filename).readAsBytes();
    expect(version, 2);
    expect(afterRows, beforeRows);
    expect(afterBytes, beforeBytes);
    expect(failure, isA<StateError>());
    expect(
      failure.toString(),
      contains('Database version 2 is newer than supported version 1'),
    );
  });
}
