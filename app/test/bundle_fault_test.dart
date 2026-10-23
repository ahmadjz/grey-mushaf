import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/loaded_page_controller.dart';

import 'memory_reveal_store.dart';

class FaultAssets extends CachingAssetBundle {
  final pauses = <String, Completer<void>>{};
  final entered = <String, Completer<void>>{};
  final completed = <String, Completer<void>>{};
  Future<void> finished(String name) =>
      completed.putIfAbsent(name, Completer<void>.new).future;
  final calls = <String, int>{};
  final failOnce = <String>{};
  final cachedPages = <String>[];
  Future<void> reached(String name) =>
      entered.putIfAbsent(name, Completer<void>.new).future;

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (cache && RegExp(r'/\d+\.json$').hasMatch(key)) cachedPages.add(key);
    return super.loadString(key, cache: cache);
  }

  @override
  Future<ByteData> load(String key) async {
    final name = key.split('/').last;
    calls.update(name, (v) => v + 1, ifAbsent: () => 1);
    final signal = entered.putIfAbsent(name, Completer<void>.new);
    if (!signal.isCompleted) signal.complete();
    try {
      await pauses[name]?.future;
      if (failOnce.remove(name)) throw StateError('injected $name failure');
      return await rootBundle.load(key);
    } finally {
      final done = completed.putIfAbsent(name, Completer<void>.new);
      if (!done.isCompleted) done.complete();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('page JSON is uncached and a failed JSON read can be retried', () async {
    final assets = FaultAssets();
    final bundle = await MushafBundle.open(assets: assets);
    assets.failOnce.add('187.json');
    await expectLater(bundle.loadNear(187), throwsStateError);
    await bundle.loadNear(187);
    expect(bundle.pages[186]['lines'], isNotEmpty);
    expect(assets.calls['187.json'], 2);
    expect(assets.cachedPages, isEmpty);
  });

  test('superseding a request preserves an older pending font load', () async {
    final assets = FaultAssets();
    final bundle = await MushafBundle.open(assets: assets);
    final gate = assets.pauses['p187.ttf'] = Completer<void>();
    final first = bundle.loadNear(187);
    await assets.reached('p187.ttf');
    await bundle.loadNear(300);
    final second = bundle.loadNear(187);
    // Re-requesting synchronously starts JSON early in the broken code.
    final prematureJson = assets.calls['187.json'] ?? 0;
    final visibleBeforeFont = bundle.loadedNumbers.contains(187);
    gate.complete();
    await Future.wait([first, second]);
    expect(prematureJson, 0);
    expect(visibleBeforeFont, isFalse);
    expect(assets.calls['p187.ttf'], 1);
    expect(bundle.pages[186]['lines'], isNotEmpty);
  });

  testWidgets(
    'rotation cancels a paused far jump without evicting the visible spread',
    (tester) async {
      final assets = FaultAssets();
      final bundle = (await tester.runAsync(
        () => MushafBundle.open(assets: assets),
      ))!;
      tester.view.physicalSize = const Size(411, 866);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      final gate = assets.pauses['p187.ttf'] = Completer<void>();
      final old =
          tester.widget<PageView>(find.byType(PageView)).controller!
              as LoadedPageController;
      await tester.runAsync(() async {
        old.jumpToPage(186);
        await assets.reached('p187.ttf');
      });
      tester.view.physicalSize = const Size(866, 411);
      await tester.pump();
      await tester.runAsync(() async {
        gate.complete();
        await old.pending;
      });
      await tester.pump();
      expect(bundle.loadedNumbers, [1, 2, 3, 4]);
      expect(find.byKey(const ValueKey('page-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('page-2')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'rotation during swipe prefetch must still permit forward navigation',
    (tester) async {
      final assets = FaultAssets();
      final bundle = (await tester.runAsync(
        () => MushafBundle.open(assets: assets),
      ))!;
      tester.view.physicalSize = const Size(411, 866);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      final gate = assets.pauses['5.json'] = Completer<void>();
      await tester.drag(find.byType(PageView), const Offset(411, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(411, 0));
      await tester.runAsync(() => assets.reached('5.json'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(866, 411);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        gate.complete();
        await assets.finished('5.json');
      });
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(866, 0));
      await tester.pumpAndSettle();
      expect(bundle.loadedNumbers, containsAll([3, 4, 5, 6]));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('page-5')), findsOneWidget);
    },
  );

  testWidgets('failed far jump keeps page visible and offers a working retry', (
    tester,
  ) async {
    final assets = FaultAssets();
    final bundle = (await tester.runAsync(
      () => MushafBundle.open(assets: assets),
    ))!;
    tester.view.physicalSize = const Size(411, 866);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    assets.failOnce.add('187.json');
    await tester.runAsync(() async {
      controller.jumpToPage(186);
      await controller.pending;
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-1')), findsOneWidget);
    expect(find.text("Couldn't load page"), findsOneWidget);
    tester.view.physicalSize = const Size(866, 411);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.runAsync(() => controller.pending);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-187')), findsOneWidget);
    expect(assets.calls['187.json'], 2);
  });
  testWidgets('swipe prefetch failure is caught and its retry reloads JSON', (
    tester,
  ) async {
    final assets = FaultAssets();
    final bundle = (await tester.runAsync(
      () => MushafBundle.open(assets: assets),
    ))!;
    tester.view.physicalSize = const Size(411, 866);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    final gate = assets.pauses['5.json'] = Completer<void>();
    assets.failOnce.add('5.json');
    await tester.drag(find.byType(PageView), const Offset(411, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(411, 0));
    await tester.runAsync(() async {
      await assets.reached('5.json');
      await assets.finished('6.json');
      gate.complete();
      await assets.finished('5.json');
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-3')), findsOneWidget);
    expect(find.text("Couldn't load page"), findsOneWidget);
    // The next approach also retries, with an awaitable controller load.
    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!
            as LoadedPageController;
    await tester.runAsync(() async {
      controller.jumpToPage(20);
      await controller.pending;
    });
    await tester.pumpAndSettle();
    final oldReads = assets.calls['3.json'];
    await tester.tap(find.text('Retry'));
    expect(
      assets.calls['3.json'],
      oldReads,
      reason: 'a stale prefetch retry must keep the current window',
    );
    expect(find.byKey(const ValueKey('page-21')), findsOneWidget);
    await tester.runAsync(() async {
      controller.jumpToPage(4);
      await controller.pending;
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-5')), findsOneWidget);
    expect(assets.calls['5.json'], 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('navigation uses prepared word metrics without runtime shaping', (
    tester,
  ) async {
    final bundle = (await tester.runAsync(MushafBundle.open))!;
    var measured = 0;
    tester.view.physicalSize = const Size(411, 866);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: bundle.pages,
          bundle: bundle,
          store: MemoryRevealStore(),
          onMeasureWord: () => measured++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(measured, 0, reason: 'opening uses prepared real-shaped metrics');
    final initial = measured;
    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!
            as LoadedPageController;
    await tester.runAsync(() async {
      controller.jumpToPage(1);
      await controller.pending;
    });
    await tester.pumpAndSettle();
    expect(measured, initial, reason: 'page 2 was already measured');
    await tester.runAsync(() async {
      controller.jumpToPage(2);
      await controller.pending;
    });
    await tester.pumpAndSettle();
    expect(
      measured,
      initial,
      reason: 'new pages use prepared real-shaped metrics',
    );
  });
}
