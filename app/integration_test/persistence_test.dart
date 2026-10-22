import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greymushaf/main.dart' as app;
import 'package:greymushaf/reveal_store.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('reveal survives a fresh application startup', (tester) async {
    final filename = path.join(await getDatabasesPath(), 'reveals.db');
    await deleteDatabase(filename);
    await app.main();
    await tester.pumpAndSettle();
    final word = find.byKey(const ValueKey('word-1'));
    await tester.longPress(word);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Semantics>(word).properties.label,
      contains('; revealed; reveals 1'),
    );
    final store =
        tester.widget<app.Reader>(find.byType(app.Reader)).store
            as SqliteRevealStore;
    await tester.pumpWidget(const SizedBox());
    await store.close();
    await app.main();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Semantics>(word).properties.label,
      contains('; revealed; reveals 1'),
    );
    final reopened =
        tester.widget<app.Reader>(find.byType(app.Reader)).store
            as SqliteRevealStore;
    await tester.pumpWidget(const SizedBox());
    final db = await openDatabase(filename);
    debugPrint(
      'Startup proof identifiers: ${await db.query('local_metadata')}; ${await db.query('word_actions', columns: ['action_uuid', 'word_key'])}',
    );
    await reopened.close();
    await deleteDatabase(filename);
  });
}
