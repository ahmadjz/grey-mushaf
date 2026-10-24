import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/loaded_page_controller.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/page_ink.dart';
import 'package:greymushaf/reveal_store.dart';

import 'memory_reveal_store.dart';
import 'save_feedback_test.dart' show ControlledStore;
import 'word_target.dart';

void view(WidgetTester tester, {bool spread = false}) {
  tester.view.physicalSize = spread
      ? const Size(1200, 800)
      : const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());

  for (final first in [1, 49]) {
    testWidgets(
      'drag across spread $first|${first + 1} gutter counts each word once',
      (tester) async {
        view(tester, spread: true);
        final store = MemoryRevealStore();
        final pair = pages
            .where((p) => p['page'] == first || p['page'] == first + 1)
            .toList();
        await tester.pumpWidget(
          MaterialApp(
            home: Reader(pages: pair, store: store),
          ),
        );
        await tester.pumpAndSettle();
        final models = tester
            .widgetList<PaintedInkPage>(find.byType(PaintedInkPage))
            .map((p) => p.controller)
            .toList();
        final right = models.firstWhere(
          (p) => p.globalRect(Offset.zero & p.owner!.size).center.dx > 600,
        );
        final left = models.firstWhere((p) => p != right);
        // Use a middle text line; select the two words nearest the gutter.
        final rw = right.words.reduce(
          (a, b) =>
              (a.box.center.dy - right.owner!.size.height / 2).abs() <
                  (b.box.center.dy - right.owner!.size.height / 2).abs()
              ? a
              : b,
        );
        final rightLine =
            right.words.where((w) => w.band.top == rw.band.top).toList()
              ..sort((a, b) => a.ink.left.compareTo(b.ink.left));
        final r = rightLine.first;
        final ry = right.globalRect(r.ink).center.dy;
        final lw = left.words.reduce(
          (a, b) =>
              (left.globalRect(a.ink).center.dy - ry).abs() <
                  (left.globalRect(b.ink).center.dy - ry).abs()
              ? a
              : b,
        );
        final leftLine =
            left.words.where((w) => w.band.top == lw.band.top).toList()
              ..sort((a, b) => b.ink.right.compareTo(a.ink.right));
        final l = leftLine.first;
        final gutter = Offset(600, ry);
        await tester.longPressAt(gutter);
        await tester.pumpAndSettle();
        expect(store.states, isEmpty);
        final gesture = await tester.startGesture(gutter);
        await tester.pump(const Duration(milliseconds: 600));
        for (final point in [
          right.globalRect(r.ink).center,
          left.globalRect(l.ink).center,
          right.globalRect(r.ink).center,
          left.globalRect(l.ink).center,
        ]) {
          await gesture.moveTo(point);
          await tester.pump();
        }
        expect(
          tester.widget<PageView>(find.byType(PageView)).physics,
          isA<NeverScrollableScrollPhysics>(),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).physics,
          isNot(isA<NeverScrollableScrollPhysics>()),
        );
        expect(store.states.length, greaterThanOrEqualTo(2));
        for (final state in store.states.values) {
          expect(state, (black: true, count: 1));
        }
        for (final word in [r, l]) {
          expect(
            testSemantics(tester, WordTarget(word.id)).label,
            contains('; revealed; reveals 1'),
          );
          expect(await wordColor(tester, WordTarget(word.id)), Colors.black);
        }
        expect(find.byKey(ValueKey('page-$first')), findsOneWidget);
        expect(find.byKey(ValueKey('page-${first + 1}')), findsOneWidget);
      },
    );
  }

  testWidgets(
    '0.08em ink-edge tolerance includes inside and excludes outside',
    (tester) async {
      view(tester);
      final store = MemoryRevealStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(pages: [pages.first], store: store),
        ),
      );
      await tester.pumpAndSettle();
      const target = WordTarget(1);
      final found = target.resolve(tester),
          em = target.resolve(tester).word.fontSize;
      final rect = found.model.globalRect(found.word.ink);
      await tester.longPressAt(
        Offset(rect.right + em * .080001, rect.center.dy),
      );
      await tester.pumpAndSettle();
      expect(store.states, isEmpty);
      expect(
        testSemantics(tester, target).label,
        contains('; unrevealed; reveals 0'),
      );
      await tester.longPressAt(
        Offset(rect.right + em * .079999, rect.center.dy),
      );
      await tester.pumpAndSettle();
      expect(store.state(wordKey('1:1:1')), (black: true, count: 1));
      expect(
        testSemantics(tester, target).label,
        contains('; revealed; reveals 1'),
      );
      expect(await wordColor(tester, target), Colors.black);
    },
  );

  testWidgets('tap between words on a line toggles bars without re-greying', (
    tester,
  ) async {
    view(tester);
    final store = MemoryRevealStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: [pages[48]], store: store),
      ),
    );
    await tester.pumpAndSettle();
    final model = tester
        .widget<PaintedInkPage>(find.byType(PaintedInkPage))
        .controller;
    (InkWord, InkWord)? gap;
    for (final a in model.words) {
      for (final b in model.words) {
        if (a.band.top != b.band.top || b.ink.left <= a.ink.right) continue;
        final width = b.ink.left - a.ink.right;
        if (width > a.fontSize * .16 + 1 &&
            (gap == null || width < gap.$2.ink.left - gap.$1.ink.right)) {
          gap = (a, b);
        }
      }
    }
    expect(
      gap,
      isNotNull,
      reason: 'fixture needs a blank gap beyond both hit tolerances',
    );
    final (a, b) = gap!;
    await longPressTarget(tester, WordTarget(a.id));
    await longPressTarget(tester, WordTarget(b.id));
    await tester.pumpAndSettle();
    final before = Map.of(store.states);
    final ar = model.globalRect(a.ink), br = model.globalRect(b.ink);
    final blank = Offset((ar.right + br.left) / 2, ar.center.dy);
    await tester.tapAt(blank);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(store.states, before);
    for (final w in [a, b]) {
      expect(
        testSemantics(tester, WordTarget(w.id)).label,
        contains('; revealed; reveals 1'),
      );
    }
    await tester.tapAt(blank);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNothing);
    expect(store.states, before);
  });

  testWidgets('save finishes after swiped page disposal and survives return', (
    tester,
  ) async {
    view(tester);
    final bundle = (await tester.runAsync(MushafBundle.open))!;
    final store = ControlledStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: bundle.pages, bundle: bundle, store: store),
      ),
    );
    await tester.pumpAndSettle();
    const target = WordTarget(1);
    final old = target.resolve(tester).model;
    await longPressTarget(tester, target);
    await tester.pumpAndSettle();
    expect(await wordColor(tester, target), const Color(0xffb0b0b0));
    for (var n = 2; n <= 7; n++) {
      await tester.drag(find.byType(PageView), const Offset(380, 0));
      await tester.pumpAndSettle();
      // Let actual asset/font IO finish; wait on the published bounded window.
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        final last = (n.isOdd ? n : n - 1) + 3;
        while (!bundle.loadedNumbers.contains(last)) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('prefetch page $last timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('page-$n')), findsOneWidget);
    }
    expect(target.exists(tester), isFalse);
    expect(old.owner, isNull);
    expect(
      () => ChangeNotifier.debugAssertNotDisposed(old),
      throwsFlutterError,
      reason: 'disposed page notifier must release all listener registrations',
    );
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.state(wordKey('1:1:1')), (black: true, count: 1));
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    controller.jumpToPage(0);
    await tester.runAsync(() async {
      // LoadedPageController publishes completion after data preparation/navigation.
      await (controller as LoadedPageController).pending;
    });
    await tester.pumpAndSettle();
    expect(identical(target.resolve(tester).model, old), isFalse);
    expect(
      testSemantics(tester, target).label,
      contains('; revealed; reveals 1'),
    );
    expect(await wordColor(tester, target), Colors.black);
    expect(tester.takeException(), isNull);
  });
}
