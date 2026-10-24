import 'dart:io' show pid;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../test/word_target.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('RESTART_PHASE', defaultValue: 'read');
  testWidgets('durable reveal across separate Android processes ($phase)', (
    tester,
  ) async {
    final filename = path.join(
      await getDatabasesPath(),
      'reader-restart-proof.db',
    );
    if (phase == 'write') await deleteDatabase(filename);
    final store = await SqliteRevealStore.open(databasePath: filename);
    final bundle = await MushafBundle.open();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(
            pages: bundle.pages,
            bundle: bundle,
            store: store,
            settings: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      const word = WordTarget(1);
      if (phase == 'write') {
        expect(store.state(wordKey('1:1:1')), (black: false, count: 0));
        await longPressTarget(tester, word);
        await tester.pumpAndSettle();
      }
      expect(store.state(wordKey('1:1:1')), (black: true, count: 1));
      expect(
        testSemantics(tester, word).label,
        contains('; revealed; reveals 1'),
      );
      final db = await openDatabase(filename);
      binding.reportData = {
        'phase': phase,
        'pid': pid,
        'database': 'reader-restart-proof.db',
        'device_id': store.deviceId,
        'records': await db.query(
          'word_actions',
          columns: ['action_uuid', 'word_key'],
        ),
        'cleanup': phase == 'read'
            ? 'database deleted at teardown'
            : 'retained for read process',
      };
    } finally {
      await tester.pumpWidget(const SizedBox());
      await store.close();
      if (phase == 'read') await deleteDatabase(filename);
    }
  });
}
