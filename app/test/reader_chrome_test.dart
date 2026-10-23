import 'dart:async';

import 'package:greymushaf/flat_ink.dart';
import 'package:greymushaf/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';

import 'memory_reveal_store.dart';

class TestSettings implements ReaderSettings {
  @override
  int greyLevel = 176;
  @override
  int darkLevel = 80;
  @override
  Future<void> saveDarkLevel(int level) async {
    darkLevel = level;
  }

  final writes = <int>[];
  Completer<void>? pending;
  @override
  Future<void> saveGreyLevel(int level) async {
    writes.add(level);
    if (pending != null) await pending!.future;
    greyLevel = level;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> pages;
  setUpAll(
    () async => pages = (await loadPages())
        .where((page) => [1, 2, 47, 48, 50].contains(page['page']))
        .toList(),
  );
  testWidgets(
    'blank taps toggle overlay bars without moving text; words retain gestures',
    (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final calls = <bool>[];
      const channel = MethodChannel('tech.ahmadjz.greymushaf/reader');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'setBarsVisible') calls.add(call.arguments as bool);
        return <String, double>{
          'left': 0,
          'top': 0,
          'right': 0,
          'bottom': 0,
          'statusTop': 24,
        };
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(pages: pages, store: MemoryRevealStore()),
        ),
      );
      await tester.pumpAndSettle();
      final word = find.byKey(const ValueKey('word-1'));
      final before = tester.getRect(word);
      expect(find.byType(PopupMenuButton<int>), findsNothing);
      expect(find.text('١'), findsOneWidget);
      expect(calls, [false]);
      await tester.tapAt(const Offset(3, 450));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(calls.last, true);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      await tester.pumpAndSettle();
      expect(tester.getRect(word), before);
      await tester.tap(word);
      await tester.pumpAndSettle();
      expect(calls.last, true);
      await tester.longPress(word);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(word).properties.label,
        contains('; revealed; reveals 1'),
      );
      await tester.tap(word);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(word).properties.label,
        contains('; unrevealed; reveals 1'),
      );
      await tester.tapAt(const Offset(3, 450));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsNothing);
      expect(calls.last, false);
      expect(tester.getRect(word), before);
    },
  );
  testWidgets('settings previews both grey endpoints', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = TestSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: pages,
          store: MemoryRevealStore(),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(3, 450));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final word = find.byKey(const ValueKey('word-1'));
    final before = tester.getRect(word);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 128);
    expect(slider.max, 224);
    expect(slider.value, 176);
    for (final value in [128.0, 224.0]) {
      slider.onChanged!(value);
      await tester.pump();
      expect(tester.getRect(word), before);
      final ink = tester.widget<FlatInk>(
        find.descendant(of: word, matching: find.byType(FlatInk)),
      );
      expect(
        ink.color,
        Color.fromARGB(255, value.toInt(), value.toInt(), value.toInt()),
      );
      for (final heading
          in find
              .byType(FlatInk)
              .evaluate()
              .where(
                (element) => (element.widget as FlatInk).child is CustomPaint,
              )) {
        expect((heading.widget as FlatInk).color, Colors.black);
      }
      slider.onChangeEnd!(value);
      await tester.pump();
      expect(settings.greyLevel, value.toInt());
      expect(tester.widget<Slider>(find.byType(Slider)).value, value);
    }
  });
  for (final size in [const Size(411, 914), const Size(914, 411)]) {
    testWidgets('page numbers fit below ink within their own pages at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(pages: pages, store: MemoryRevealStore()),
        ),
      );
      await tester.pumpAndSettle();
      final spread = size.width > size.height;
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      for (final number in [1, 2, 47, 48, 50]) {
        controller.jumpToPage(
          spread
              ? (number <= 2
                    ? 0
                    : number == 50
                    ? 2
                    : 1)
              : pages.indexWhere((p) => p['page'] == number),
        );
        await tester.pumpAndSettle();
        final area = tester.getRect(find.byKey(ValueKey('page-$number')));
        final label = tester.getRect(
          find.byKey(ValueKey('page-number-$number')),
        );
        expect(label.center.dx, closeTo(area.center.dx, .01));
        expect(label.bottom, lessThanOrEqualTo(area.bottom));
        final page = pages.singleWhere((p) => p['page'] == number);
        final font = page['font'] as Map<String, dynamic>;
        for (final line in page['lines'] as List) {
          for (final w in line['words'] as List) {
            final target = find.byKey(ValueKey('word-${w['id']}'));
            final rect = tester.getRect(target);
            final text = tester.widget<Text>(
              find.descendant(of: target, matching: find.byType(Text)),
            );
            final inkHeight =
                ((font['yMax'] as num) - (font['yMin'] as num)) /
                (font['unitsPerEm'] as num) *
                text.style!.fontSize!;
            expect(
              rect.center.dy + inkHeight / 2 + 1,
              lessThanOrEqualTo(label.top),
            );
          }
        }
      }
    });
  }
}
