import 'package:flutter/material.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/bundle_metrics.dart';
import 'package:greymushaf/loaded_page_controller.dart';

import 'memory_reveal_store.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/mushaf_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'opening loads only current spread and neighbours out of 604 pages',
    () async {
      final bundle = await MushafBundle.open();
      expect(bundle.pages.length, 604);
      expect(bundle.loadedNumbers, [1, 2, 3, 4]);
      await bundle.loadNear(187);
      expect(bundle.loadedNumbers, [185, 186, 187, 188, 189, 190]);
      expect(bundle.pages[186]['lines'], isNotEmpty);
      expect(bundle.pages.first['lines'], isNull);
    },
  );
  testWidgets(
    'prepared global size equals eager shaping, including pages 1, 2, 187, 604',
    (tester) async {
      final pages = (await tester.runAsync(loadPages))!;
      final eager = BundleMetrics.measure(pages);
      final bundle = (await tester.runAsync(MushafBundle.open))!;
      expect(bundle.metrics.toJson(), eager.toJson());
      for (final size in [const Size(411.4, 866.3), const Size(914.3, 363.4)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final number in [1, 2, 187, 604]) {
          Future<double> fontSize({required bool lazy}) async {
            if (lazy) await tester.runAsync(() => bundle.loadNear(1));
            await tester.pumpWidget(
              MaterialApp(
                home: Reader(
                  key: UniqueKey(),
                  pages: lazy ? bundle.pages : pages,
                  bundle: lazy ? bundle : null,
                  store: MemoryRevealStore(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final controller = tester
                .widget<PageView>(find.byType(PageView))
                .controller!;
            controller.jumpToPage(
              size.width > size.height ? (number - 1) ~/ 2 : number - 1,
            );
            if (controller is LoadedPageController) {
              await tester.runAsync(() => controller.pending);
            }
            await tester.pumpAndSettle();
            final word = (pages[number - 1]['lines'] as List)
                .expand((l) => l['words'] as List)
                .first;
            return tester
                .widget<Text>(
                  find.descendant(
                    of: find.byKey(ValueKey('word-${word['id']}')),
                    matching: find.byType(Text),
                  ),
                )
                .style!
                .fontSize!;
          }

          final eagerSize = await fontSize(lazy: false);
          expect(
            await fontSize(lazy: true),
            eagerSize,
            reason: 'page $number at $size',
          );
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
