import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/loaded_page_controller.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/page_ink.dart';

import 'memory_reveal_store.dart';
import 'word_target.dart';

void portrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> runIdleTasks(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

int firstWord(Map<String, dynamic> page) =>
    ((page['lines'] as List).firstWhere(
                  (l) => (l['words'] as List).isNotEmpty && l['type'] == 'ayah',
                )['words']
                as List)
            .first['id']
        as int;

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());

  testWidgets('showing the bars keeps the cached page image', (tester) async {
    portrait(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: pages, store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    final word = WordTarget(firstWord(pages[0]));
    await waitForCachedInk(tester, word);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(word.resolve(tester).model.hasCachedImage, isTrue);
  });

  testWidgets('a swipe onto a prepared neighbour shapes no new words', (
    tester,
  ) async {
    portrait(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: pages, store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(48);
    await tester.pumpAndSettle();
    await runIdleTasks(tester);
    final before = paragraphPool.created;
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-50')), findsOneWidget);
    final nextNeighbour = {
      for (final line in pages[50]['lines'] as List)
        if (line['type'] == 'ayah')
          for (final word in line['words'] as List)
            (word['text'], word['metrics'][0]),
    };
    expect(paragraphPool.created, before + nextNeighbour.length);
  });

  testWidgets('pages load after the swipe settles, not during it', (
    tester,
  ) async {
    portrait(tester);
    final bundle = (await tester.runAsync(MushafBundle.open))!;
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
    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!
            as LoadedPageController;
    controller.jumpToPage(5);
    await tester.runAsync(() => controller.pending);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final loaded = bundle.loadedNumbers;
    final gesture = await tester.startGesture(const Offset(100, 400));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(240, 0));
    await tester.pump();
    expect(controller.page, greaterThan(5.5));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(bundle.loadedNumbers, loaded);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(bundle.loadedNumbers.last, greaterThan(loaded.last));
  });

  group('paragraph pool', () {
    const style = TextStyle(fontSize: 10);
    test('reuses released painters and never shares one', () {
      final pool = ParagraphPool(maxIdle: 2);
      final a = pool.acquire('a', style, 50);
      final b = pool.acquire('a', style, 50);
      expect(identical(a, b), isFalse);
      expect(pool.created, 2);
      pool.release('a', style, 50, a);
      expect(identical(pool.acquire('a', style, 50), a), isTrue);
      expect(pool.created, 2);
    });

    test('evicts only idle painters, oldest first', () {
      final pool = ParagraphPool(maxIdle: 1);
      final used = pool.acquire('used', style, 50);
      final old = pool.acquire('old', style, 50);
      pool.release('old', style, 50, old);
      pool.prewarm('new', style, 50);
      expect(old.debugDisposed, isTrue);
      expect(used.debugDisposed, isFalse);
      final created = pool.created;
      pool.prewarm('used', style, 50);
      pool.prewarm('new', style, 50);
      expect(pool.created, created);
    });
  });
}
