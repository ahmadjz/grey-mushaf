import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';

import 'memory_reveal_store.dart';

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());
  List<Map<String, dynamic>> range(int from, int to) => pages
      .where((p) => (p['page'] as int) >= from && (p['page'] as int) <= to)
      .toList();

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(215, 220), store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool showing(int page) =>
      find.byKey(ValueKey('page-$page')).evaluate().isNotEmpty;

  Future<void> wheel(WidgetTester tester, double dy) async {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(200, 400)));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('one wheel notch turns exactly one page each way', (
    tester,
  ) async {
    await open(tester, const Size(411, 914));
    await wheel(tester, 100);
    expect(showing(216), isTrue);
    expect(showing(215), isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    await wheel(tester, -100);
    expect(showing(215), isTrue);
    expect(showing(216), isFalse);
  });

  testWidgets('a burst of wheel events turns one page', (tester) async {
    await open(tester, const Size(411, 914));
    for (var i = 0; i < 6; i++) {
      await wheel(tester, 40);
    }
    expect(showing(216), isTrue);
    expect(showing(217), isFalse);
  });

  testWidgets('left arrow key is next and right arrow key is previous', (
    tester,
  ) async {
    await open(tester, const Size(411, 914));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(showing(216), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(showing(217), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(showing(216), isTrue);
    expect(showing(217), isFalse);
  });

  testWidgets('in a spread the wheel and keys move a whole spread', (
    tester,
  ) async {
    await open(tester, const Size(914, 411));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(showing(217) && showing(218), isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    await wheel(tester, 100);
    expect(showing(219) && showing(220), isTrue);
    expect(showing(217), isFalse);
  });

  testWidgets('holding the mouse button reveals a word', (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryRevealStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(216, 216), store: store),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('page-216'))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(store.states.values.where((s) => s.black), isNotEmpty);
  });

  testWidgets('keys and the wheel wait while a word is held', (tester) async {
    await open(tester, const Size(411, 914));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('page-215'))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await wheel(tester, 100);
    expect(showing(215), isTrue);
    expect(showing(216), isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
