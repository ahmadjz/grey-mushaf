import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/loaded_page_controller.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/bundle_metrics.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('exact reader parity reference and persisted reveal matrix', (
    tester,
  ) async {
    final filename = path.join(
      await getDatabasesPath(),
      'perf-parity-proof.db',
    );
    final records = <Object>[];
    final geometry = <String, Object>{};
    final bundle = await MushafBundle.open();
    SqliteRevealStore? store;
    try {
      await binding.convertFlutterSurfaceToImage();
      for (final target in [1, 2, 50, 187, 604, 63, 49]) {
        final spread = target == 49;
        await SystemChrome.setPreferredOrientations([
          spread
              ? DeviceOrientation.landscapeLeft
              : DeviceOrientation.portraitUp,
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        for (final revealed in [false, true]) {
          for (final mode in [
            (false, 128),
            (false, 176),
            (false, 224),
            (true, 32),
            (true, 80),
            (true, 128),
          ]) {
            await deleteDatabase(filename);
            store = await SqliteRevealStore.open(databasePath: filename);
            records.add({
              'device_id': store.deviceId,
              'database': 'perf-parity-proof.db',
            });
            await store.saveGreyLevel(mode.$1 ? 176 : mode.$2);
            await store.saveDarkLevel(mode.$1 ? mode.$2 : 80);
            await bundle.loadNear(target);
            final pages = [
              bundle.pages[target - 1],
              if (spread) bundle.pages[target],
            ];
            final selected = <String>[];
            if (revealed) {
              for (final page in pages) {
                final words = [
                  for (final line in page['lines'] as List)
                    ...line['words'] as List,
                ];
                for (var i = 0; i < words.length; i++) {
                  if (i % 7 != 0 && i != words.length - 1) continue;
                  final action = WordAction(
                    wordKey(words[i]['location'] as String),
                    true,
                  );
                  await store.save(action);
                  selected.add(action.key);
                  records.add({
                    'action_uuid': action.uuid,
                    'word_key': action.key,
                  });
                }
              }
            }
            // Close/reopen the real SQLite store before every capture.
            await store.close();
            store = await SqliteRevealStore.open(databasePath: filename);
            for (final key in selected) {
              expect(store.state(key), (black: true, count: 1));
            }
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
            final controller =
                tester.widget<PageView>(find.byType(PageView)).controller!
                    as LoadedPageController;
            controller.jumpToPage(spread ? (target - 1) ~/ 2 : target - 1);
            await controller.pending;
            await tester.pumpAndSettle();
            if (mode.$1) {
              await tester.tapAt(
                Offset(
                  1,
                  tester.view.physicalSize.height /
                      tester.view.devicePixelRatio /
                      2,
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('Settings'));
              await tester.pumpAndSettle();
              tester
                  .widget<SwitchListTile>(find.byType(SwitchListTile))
                  .onChanged!(true);
              await tester.pumpAndSettle();
              await tester.tap(find.byTooltip('Close Settings'));
              await tester.pumpAndSettle();
              await tester.tapAt(
                Offset(
                  1,
                  tester.view.physicalSize.height /
                      tester.view.devicePixelRatio /
                      2,
                ),
              );
              await tester.pumpAndSettle();
            }
            expect(
              tester.view.physicalSize.width > tester.view.physicalSize.height,
              spread,
            );
            final name =
                '${spread ? 'spread-49-50' : 'page-$target'}-${mode.$1 ? 'dark' : 'light'}-${mode.$2}-${revealed ? 'mixed' : 'unrevealed'}';
            if (!revealed && !mode.$1 && mode.$2 == 128) {
              final rects = <Map<String, Object>>[];
              for (final page in pages) {
                for (final line in page['lines'] as List) {
                  for (final word in line['words'] as List) {
                    final finder = find.byKey(ValueKey('word-${word['id']}'));
                    final box = tester.getRect(finder);
                    final text = tester.widget<Text>(
                      find.descendant(of: finder, matching: find.byType(Text)),
                    );
                    final size = text.style!.fontSize!;
                    final metric = word['metrics'] as List;
                    final rect = Rect.fromLTRB(
                      box.left + (metric[1] as num) * size,
                      box.center.dy - inkHeight(page) * size / 2,
                      box.left + (metric[2] as num) * size,
                      box.center.dy + inkHeight(page) * size / 2,
                    );
                    rects.add({
                      'id': word['id'],
                      'location': word['location'],
                      'rect': [rect.left, rect.top, rect.right, rect.bottom],
                      'advanceRect': [box.left, box.top, box.right, box.bottom],
                      'fontSize': size,
                      'physicalDpr': tester.view.devicePixelRatio,
                    });
                  }
                }
              }
              final overlaps = <Object>[];
              for (var i = 0; i < rects.length; i++) {
                final a = rects[i]['rect'] as List<double>;
                for (var j = i + 1; j < rects.length; j++) {
                  final b = rects[j]['rect'] as List<double>;
                  final r = Rect.fromLTRB(
                    a[0],
                    a[1],
                    a[2],
                    a[3],
                  ).intersect(Rect.fromLTRB(b[0], b[1], b[2], b[3]));
                  if (r.width > 0 && r.height > 0) {
                    overlaps.add({
                      'a': rects[i]['location'],
                      'b': rects[j]['location'],
                      'intersection': [r.left, r.top, r.right, r.bottom],
                    });
                  }
                }
              }
              geometry['$target'] = {
                'rects': rects,
                'overlaps': overlaps,
                'note': 'Prepared horizontal ink extents; conservative page-font vertical ink bounds, logical pixels.',
              };
            }
            await Future<void>.delayed(const Duration(milliseconds: 150));
            await tester.pumpAndSettle();
            await binding.takeScreenshot('images/$name');
            await tester.pump();
            await binding.takeScreenshot('repeat/$name');
            await tester.pumpWidget(const SizedBox());
            await store.close();
            store = null;
          }
        }
      }
      binding.reportData ??= {};
      binding.reportData!['geometry'] = geometry;
      binding.reportData!['records'] = records;
      binding.reportData!['device'] = {
        'physicalWidth': tester.view.physicalSize.width,
        'physicalHeight': tester.view.physicalSize.height,
        'dpr': tester.view.devicePixelRatio,
      };
    } finally {
      await tester.pumpWidget(const SizedBox());
      await store?.close();
      await deleteDatabase(filename);
      debugPrint(
        'PARITY_CLEANUP deleted perf-parity-proof.db and all records listed in capture.json; no accounts/tokens',
      );
      await SystemChrome.setPreferredOrientations([]);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
