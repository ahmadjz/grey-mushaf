import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/word_marks.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../test/word_target.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('marks seen live with the strip open', (tester) async {
    final filename = path.join(await getDatabasesPath(), 'marks-live.db');
    await deleteDatabase(filename);
    final store = await SqliteRevealStore.open(databasePath: filename);
    final bundle = await MushafBundle.open();
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: bundle.pages,
          bundle: bundle,
          store: store,
          settings: store,
          toolbarSettings: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Offset ballPoint() {
      final ball = tester.getRect(find.byKey(const ValueKey('toolbar-ball')));
      return ball
          .intersect(
            Offset.zero &
                tester.view.physicalSize / tester.view.devicePixelRatio,
          )
          .center;
    }

    Future<void> apply(List<MarkTool> tools, MarkColor color, int id) async {
      await tester.tapAt(ballPoint());
      await tester.pumpAndSettle();
      for (final tool in MarkTool.values) {
        final on = store.toolbar.tools.contains(tool);
        if (on != tools.contains(tool)) {
          await tester.tap(find.byKey(ValueKey('tool-${tool.name}')));
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.byKey(ValueKey('colour-${color.name}')));
      await tester.pumpAndSettle();
      expect(store.toolbar.tools.toSet(), tools.toSet());
      await tester.tapAt(const Offset(200, 5));
      await tester.pumpAndSettle();
      await longPressTarget(tester, WordTarget(id));
      await tester.pumpAndSettle();
    }

    await apply([MarkTool.visible], MarkColor.red, 1);
    await apply([MarkTool.visible, MarkTool.singleLine], MarkColor.red, 2);
    await apply([MarkTool.doubleLine], MarkColor.blue, 3);
    await apply([MarkTool.visible, MarkTool.rectangle], MarkColor.green, 5);
    await apply([MarkTool.circle], MarkColor.purple, 6);
    await apply(
      [MarkTool.visible, MarkTool.singleLine, MarkTool.circle],
      MarkColor.black,
      7,
    );
    debugPrint('MARKS_LIVE light');
    await tester.pump(const Duration(seconds: 6));
    await tester.tapAt(ballPoint());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.tapAt(const Offset(200, 5));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    debugPrint('MARKS_LIVE dark');
    await tester.pump(const Duration(seconds: 6));
    await store.close();
    await deleteDatabase(filename);
  });
}
