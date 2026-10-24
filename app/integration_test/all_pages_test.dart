import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/page_ink.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/bundle_metrics.dart';
import 'package:greymushaf/loaded_page_controller.dart';

import '../test/memory_reveal_store.dart';
import '../test/bundle_fault_test.dart' show FaultAssets;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('all-page reader device proof', (tester) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final assets = FaultAssets();
    final bundle = await MushafBundle.open(assets: assets);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: bundle.pages,
          bundle: bundle,
          store: MemoryRevealStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();

    Iterable<TextSpan> words() => tester
        .widgetList<PaintedInkPage>(find.byType(PaintedInkPage))
        .expand((page) => page.controller.words)
        .map((word) => word.paragraph.text! as TextSpan);
    final size = words().first.style!.fontSize!;
    void checkVisibleInk() {
      expect(words(), isNotEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(words().map((text) => text.style!.fontSize).toSet(), {size});
    }

    for (final number in [187, 300, 604]) {
      final controller =
          tester.widget<PageView>(find.byType(PageView)).controller!
              as LoadedPageController;
      controller.jumpToPage(number - 1);
      // The old page remains visible while a cold destination loads.
      checkVisibleInk();
      await controller.pending;
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('page-$number')), findsOneWidget);
      checkVisibleInk();
      await binding.takeScreenshot('2026-10-23-all-pages-$number-portrait');
    }

    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!
            as LoadedPageController;
    assets.failOnce.add('450.json');
    controller.jumpToPage(449);
    await controller.pending;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-604')), findsOneWidget);
    expect(find.text("Couldn't load page"), findsOneWidget);
    await binding.takeScreenshot('2026-10-23-all-pages-load-retry');
    await tester.tap(find.text('Retry'));
    await controller.pending;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-450')), findsOneWidget);
    expect(assets.calls['450.json'], 2);
    controller.jumpToPage(499);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      checkVisibleInk();
    }
    await controller.pending;
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(500, 0), 5000);
      await tester.pump(const Duration(milliseconds: 16));
      checkVisibleInk();
    }
    await tester.pumpAndSettle();
    checkVisibleInk();
    await binding.takeScreenshot('2026-10-23-all-pages-fast-paging');

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    for (
      var i = 0;
      i < 20 &&
          tester.view.physicalSize.width < tester.view.physicalSize.height;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(
      tester.view.physicalSize.width,
      greaterThan(tester.view.physicalSize.height),
    );
    await binding.takeScreenshot('2026-10-23-all-pages-landscape');

    // Verify the preparation host and Android use the same real shaped metrics.
    final allPages = await loadPages();
    for (final page in allPages) {
      for (final line in page['lines'] as List) {
        for (final word in line['words'] as List) {
          final actual = measureWord(word as Map<String, dynamic>, page);
          expect(word['metrics'], [
            actual.width,
            actual.left,
            actual.right,
          ], reason: '${word['location']}');
        }
      }
    }
    expect(BundleMetrics.measure(allPages).toJson(), bundle.metrics.toJson());
    await SystemChrome.setPreferredOrientations([]);
  });
}
