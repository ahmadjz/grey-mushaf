import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_index.dart';
import 'package:greymushaf/reader_settings.dart';

import 'memory_reveal_store.dart';
import 'word_target.dart';

class ArrowSettings implements ReaderSettings {
  @override
  int greyLevel = 176;
  @override
  int darkLevel = 80;
  @override
  bool arrowsShown = true;
  @override
  final arrowSpots = <String, Offset>{};
  @override
  Future<void> saveDarkLevel(int level) async => darkLevel = level;
  @override
  Future<void> saveGreyLevel(int level) async => greyLevel = level;
  @override
  Future<void> saveArrowsShown(bool shown) async => arrowsShown = shown;
  @override
  Future<void> saveArrowSpot(String key, Offset spot) async =>
      arrowSpots[key] = spot;
}

void screen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void insets(WidgetTester tester, {double left = 0, double statusTop = 0}) {
  const channel = MethodChannel('tech.ahmadjz.greymushaf/reader');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => <String, double>{
      'left': left,
      'top': 0,
      'right': 0,
      'bottom': 0,
      'statusTop': statusTop,
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());
  List<Map<String, dynamic>> range(int from, int to) => pages
      .where((p) => (p['page'] as int) >= from && (p['page'] as int) <= to)
      .toList();

  test('page place is the surah and juz of its first ayah', () {
    expect(pagePlace(pages[215]), (surah: 10, juz: 11));
    expect(pagePlace(pages[0]), (surah: 1, juz: 1));
    expect(pagePlace(pages[200]), (surah: 9, juz: 10));
    expect(pagePlace(pages[603]), (surah: 112, juz: 30));
    expect(surahNames[9], 'يونس');
  });

  testWidgets('the top bar spans the screen from the very top', (tester) async {
    screen(tester, const Size(914, 411));
    insets(tester, left: 30, statusTop: 24);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(215, 218), store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(457, 200));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byKey(const ValueKey('top-bar')));
    expect(bar.left, 0);
    expect(bar.top, 0);
    expect(bar.width, 914);
    expect(bar.height, greaterThan(24 + 40));
    expect(find.text('يونس'), findsWidgets);
    expect(find.text('صفحة ٢١٥، جزء ١١'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('the bar title follows the page after a swipe', (tester) async {
    screen(tester, const Size(411, 914));
    insets(tester, statusTop: 24);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(215, 218), store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(3, 450));
    await tester.pumpAndSettle();
    expect(find.text('صفحة ٢١٥، جزء ١١'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('صفحة ٢١٦، جزء ١١'), findsOneWidget);
  });

  testWidgets('the menu holds the dark mode switch and Settings', (
    tester,
  ) async {
    screen(tester, const Size(411, 914));
    insets(tester);
    final settings = ArrowSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: range(215, 218),
          store: MemoryRevealStore(),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(3, 450));
    await tester.pumpAndSettle();
    await openMenuItem(tester, 'Dark mode');
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      Colors.black,
    );
    await openMenuItem(tester, 'Settings');
    expect(find.text('Dark mode'), findsNothing);
    final arrows = find.widgetWithText(SwitchListTile, 'Page-turn arrows');
    expect(tester.widget<SwitchListTile>(arrows).value, isTrue);
    await tapTarget(tester, arrows);
    await tester.pumpAndSettle();
    expect(settings.arrowsShown, isFalse);
    expect(find.byKey(const ValueKey('arrow-next')), findsNothing);
  });

  testWidgets('each page has a header line and an outer-edge border', (
    tester,
  ) async {
    screen(tester, const Size(411, 914));
    insets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(215, 218), store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('page-header-215'));
    expect(
      find.descendant(of: header, matching: find.text('الجزء ١١')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('يونس')),
      findsOneWidget,
    );
    final juz = tester.getRect(
      find.descendant(of: header, matching: find.text('الجزء ١١')),
    );
    final name = tester.getRect(
      find.descendant(of: header, matching: find.text('يونس')),
    );
    expect(juz.left, greaterThan(name.right));
    final border = tester.widget<PageBorder>(
      find.byKey(const ValueKey('page-border-215')),
    );
    expect((border.left, border.right), (false, true));
    final line = tester.getRect(find.byKey(const ValueKey('line-215-1')));
    expect(line.top, greaterThanOrEqualTo(tester.getRect(header).bottom));
  });

  testWidgets('landscape borders the outer edges and the spine once', (
    tester,
  ) async {
    screen(tester, const Size(914, 411));
    insets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(215, 218), store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    PageBorder border(int page) =>
        tester.widget<PageBorder>(find.byKey(ValueKey('page-border-$page')));
    expect((border(215).left, border(215).right), (true, true));
    expect((border(216).left, border(216).right), (true, false));
    expect(find.byKey(const ValueKey('page-header-216')), findsOneWidget);
  });

  testWidgets('arrows turn pages without revealing or showing the bars', (
    tester,
  ) async {
    screen(tester, const Size(411, 914));
    insets(tester);
    final store = MemoryRevealStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(215, 218), store: store),
      ),
    );
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('arrow-next'));
    final previous = find.byKey(const ValueKey('arrow-previous'));
    expect(tester.getCenter(next).dx, lessThan(tester.getCenter(previous).dx));
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-215')), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-216')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-215')), findsNothing);
    expect(find.byKey(const ValueKey('top-bar')), findsNothing);
    expect(store.states, isEmpty);
    for (var i = 0; i < 4; i++) {
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-218')), findsOneWidget);
  });

  testWidgets('a landscape arrow moves a whole spread', (tester) async {
    screen(tester, const Size(914, 411));
    insets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: range(215, 218), store: MemoryRevealStore()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arrow-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-217')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-218')), findsOneWidget);
  });

  testWidgets('a long-press drags an arrow and remembers it per orientation', (
    tester,
  ) async {
    screen(tester, const Size(411, 914));
    insets(tester);
    final settings = ArrowSettings();
    final store = MemoryRevealStore();
    Widget app() => MaterialApp(
      home: Reader(pages: range(215, 218), store: store, settings: settings),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('arrow-next'));
    final start = tester.getCenter(next);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveBy(const Offset(100, -300));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      (tester.getCenter(next) - start - const Offset(100, -300)).distance,
      lessThan(.01),
    );
    expect(find.byKey(const ValueKey('page-215')), findsOneWidget);
    expect(find.byKey(const ValueKey('top-bar')), findsNothing);
    expect(store.states, isEmpty);
    expect(settings.arrowSpots.keys, ['portrait-next']);
    tester.view.physicalSize = const Size(914, 411);
    await tester.pumpAndSettle();
    final landscape = tester.getCenter(next);
    expect(landscape.dy, greaterThan(300));
    tester.view.physicalSize = const Size(411, 914);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      (tester.getCenter(next) - start - const Offset(100, -300)).distance,
      lessThan(.01),
    );
  });

  testWidgets('a dragged arrow stays on screen after rotating', (tester) async {
    screen(tester, const Size(411, 914));
    insets(tester);
    final settings = ArrowSettings()
      ..arrowSpots['landscape-previous'] = const Offset(1, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: range(215, 218),
          store: MemoryRevealStore(),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(914, 411);
    await tester.pumpAndSettle();
    final arrow = tester.getRect(find.byKey(const ValueKey('arrow-previous')));
    expect(arrow.right, lessThanOrEqualTo(914));
    expect(arrow.bottom, lessThanOrEqualTo(411));
  });
}
