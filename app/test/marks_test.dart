import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reader_settings.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/word_marks.dart';

import 'memory_reveal_store.dart';
import 'word_target.dart';

class MemoryToolbar implements ToolbarSettings {
  MemoryToolbar([this.toolbar = const ToolbarPrefs()]);
  @override
  ToolbarPrefs toolbar;
  bool fail = false;
  @override
  Future<void> saveToolbar(ToolbarPrefs prefs) async {
    if (fail) throw StateError('injected');
    toolbar = prefs;
  }
}

class FailingMarkStore extends MemoryRevealStore {
  final failOn = <MarkKind>{};
  bool failReveal = false;
  final saved = <Object>[];
  final tried = <String>[];
  @override
  Future<void> save(WordAction action) async {
    tried.add(action.uuid);
    if (failReveal) throw StateError('injected');
    await super.save(action);
    saved.add(action);
  }

  @override
  Future<void> saveMark(MarkAction action) async {
    tried.add(action.uuid);
    if (failOn.contains(action.kind)) throw StateError('injected');
    await super.saveMark(action);
    saved.add(action);
  }
}

class FlakyArrowSettings implements ReaderSettings {
  bool fail = true;
  @override
  int greyLevel = 176;
  @override
  int darkLevel = 80;
  @override
  bool arrowsShown = true;
  @override
  final arrowSpots = <String, Offset>{};
  @override
  Future<void> saveDarkLevel(int level) async {}
  @override
  Future<void> saveGreyLevel(int level) async {}
  @override
  Future<void> saveArrowsShown(bool shown) async {}
  @override
  Future<void> saveArrowSpot(String key, Offset spot) async {
    if (fail) throw StateError('injected');
    arrowSpots[key] = spot;
  }
}

const red = (style: MarkStyle.singleLine, color: MarkColor.red);

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async {
    pages = await loadPages();
  });

  Future<({MemoryRevealStore store, MemoryToolbar toolbar})> open(
    WidgetTester tester, {
    MemoryRevealStore? store,
    ToolbarPrefs prefs = const ToolbarPrefs(),
  }) async {
    final memory = store ?? MemoryRevealStore();
    final toolbar = MemoryToolbar(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: pages, store: memory, toolbarSettings: toolbar),
      ),
    );
    await tester.pumpAndSettle();
    return (store: memory, toolbar: toolbar);
  }

  const word = WordTarget(3);
  String label(WidgetTester tester) => testSemantics(tester, word).label;
  String key(WidgetTester tester) =>
      wordKey(label(tester).split(';').first.trim());

  Offset ballPoint(WidgetTester tester) {
    final ball = tester.getRect(find.byKey(const ValueKey('toolbar-ball')));
    final screen = Offset.zero & tester.getSize(find.byType(Reader));
    return ball.intersect(screen.deflate(1)).center;
  }

  Future<void> openStrip(WidgetTester tester) async {
    await tester.tapAt(ballPoint(tester));
    await tester.pumpAndSettle();
  }

  Future<void> dragBall(WidgetTester tester, Offset by) async {
    await tester.dragFrom(ballPoint(tester), by);
    await tester.pumpAndSettle();
  }

  testWidgets('R46/R47: one long-press applies every active tool, '
      'and only visible counts', (tester) async {
    final opened = await open(
      tester,
      prefs: const ToolbarPrefs(
        tools: [MarkTool.visible, MarkTool.doubleLine, MarkTool.circle],
        color: MarkColor.blue,
      ),
    );
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    expect(
      label(tester),
      endsWith('; revealed; reveals 1; doubleLine blue; circle blue'),
    );
    expect(opened.store.state(key(tester)), (black: true, count: 1));
  });

  testWidgets('R47: an existing mark stays, even in another colour; '
      'the partner style replaces it', (tester) async {
    final store = MemoryRevealStore();
    final opened = await open(
      tester,
      store: store,
      prefs: const ToolbarPrefs(
        tools: [MarkTool.singleLine, MarkTool.rectangle],
        color: MarkColor.green,
      ),
    );
    final k = key(tester);
    store.wordMarks[k] = (
      line: red,
      shape: (style: MarkStyle.circle, color: MarkColor.purple),
    );
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    expect(store.marks(k), (
      line: red,
      shape: (style: MarkStyle.rectangle, color: MarkColor.green),
    ));
    expect(store.state(k).black, isFalse);
    expect(opened.store.state(k).count, 0);
  });

  testWidgets('R62: with every tool off a long-press does nothing', (
    tester,
  ) async {
    final opened = await open(tester, prefs: const ToolbarPrefs(tools: []));
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    expect(opened.store.state(key(tester)), greyWord);
    expect(opened.store.marks(key(tester)), noMarks);
  });

  testWidgets('R48: a visible-only word turns grey at once on tap', (
    tester,
  ) async {
    final opened = await open(tester);
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-box')), findsNothing);
    expect(opened.store.state(key(tester)), (black: false, count: 1));
  });

  testWidgets('R48/R62: the tap box unticks, reticks and closes when empty', (
    tester,
  ) async {
    final opened = await open(
      tester,
      prefs: const ToolbarPrefs(tools: [MarkTool.visible, MarkTool.singleLine]),
    );
    final k = key(tester);
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-box')), findsOneWidget);
    expect(find.text('Visible'), findsOneWidget);
    expect(find.text('Single line'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mark-row-Single line')));
    await tester.pumpAndSettle();
    expect(opened.store.marks(k), noMarks);
    expect(find.byKey(const ValueKey('mark-box')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-row-Single line')));
    await tester.pumpAndSettle();
    expect(opened.store.marks(k).line, red);

    await tester.tap(find.byKey(const ValueKey('mark-row-Visible')));
    await tester.tap(find.byKey(const ValueKey('mark-row-Single line')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-box')), findsNothing);
    expect(opened.store.state(k), (black: false, count: 1));
    expect(find.byType(Reader), findsOneWidget);
  });

  testWidgets('R48: Clear all removes every mark and closes the box', (
    tester,
  ) async {
    final opened = await open(
      tester,
      prefs: const ToolbarPrefs(
        tools: [MarkTool.visible, MarkTool.singleLine, MarkTool.rectangle],
      ),
    );
    final k = key(tester);
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-box')), findsNothing);
    expect(find.byType(Reader), findsOneWidget);
    expect(opened.store.marks(k), noMarks);
    expect(opened.store.state(k), (black: false, count: 1));
  });

  testWidgets('R48: a grey word with only a line opens the box too', (
    tester,
  ) async {
    await open(tester, prefs: const ToolbarPrefs(tools: [MarkTool.singleLine]));
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    expect(find.text('Visible'), findsNothing);
    expect(find.text('Single line'), findsOneWidget);
  });

  testWidgets('R24: a failed mark save stops the queue and Retry resumes it', (
    tester,
  ) async {
    final store = FailingMarkStore()..failOn.add(MarkKind.line);
    await open(
      tester,
      store: store,
      prefs: const ToolbarPrefs(
        tools: [MarkTool.visible, MarkTool.singleLine, MarkTool.circle],
      ),
    );
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    expect(label(tester), endsWith('; revealed; reveals 1'));
    expect(find.text("Couldn't save"), findsOneWidget);
    expect(store.saved, hasLength(1));
    store.failOn.clear();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(label(tester), endsWith('; singleLine red; circle red'));
    expect(store.saved.map((a) => a.runtimeType), [
      WordAction,
      MarkAction,
      MarkAction,
    ]);
    final marks = store.saved.whereType<MarkAction>().toList();
    expect(marks.map((a) => a.kind), [MarkKind.line, MarkKind.shape]);
    expect(store.tried, [
      store.saved.first is WordAction
          ? (store.saved.first as WordAction).uuid
          : '',
      marks.first.uuid,
      marks.first.uuid,
      marks.last.uuid,
    ]);
  });

  test('R49: black marks paint white in dark mode, others keep colour', () {
    expect(MarkColor.black.paint(Colors.white), Colors.white);
    expect(MarkColor.black.paint(Colors.black), Colors.black);
    expect(
      MarkColor.red.paint(Colors.white),
      MarkColor.red.paint(Colors.black),
    );
    expect(MarkColor.values, hasLength(6));
  });

  testWidgets('R51: the ball opens the strip, tools toggle with partners', (
    tester,
  ) async {
    final opened = await open(tester);
    await openStrip(tester);
    expect(find.byKey(const ValueKey('toolbar-strip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tool-singleLine')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tool-doubleLine')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('colour-purple')));
    await tester.pump();
    expect(opened.toolbar.toolbar.tools, [
      MarkTool.visible,
      MarkTool.doubleLine,
    ]);
    expect(opened.toolbar.toolbar.color, MarkColor.purple);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('toolbar-ball'))).value,
      'Visible, Double line',
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('toolbar-strip')), findsNothing);
    expect(find.byKey(const ValueKey('top-bar')), findsNothing);
  });

  testWidgets('R51: the strip toggles the top bar', (tester) async {
    await open(tester);
    await openStrip(tester);
    await tester.tap(find.byKey(const ValueKey('toolbar-top-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('top-bar')), findsOneWidget);
  });

  testWidgets('R51: dragging moves the ball, the edge tucks it, '
      'and a pinned ball stays', (tester) async {
    final opened = await open(tester);
    final ball = find.byKey(const ValueKey('toolbar-ball'));
    final size = tester.getSize(find.byType(Reader));
    expect(tester.getCenter(ball).dx, closeTo(size.width, 1));
    final page = find.byKey(const ValueKey('page-1'));
    expect(page, findsOneWidget);

    await dragBall(tester, Offset(-size.width / 2, 100));
    final moved = tester.getCenter(ball);
    expect(moved.dx, closeTo(size.width / 2, 2));
    expect(page, findsOneWidget);
    expect(opened.store.states, isEmpty);
    expect(opened.toolbar.toolbar.spot!.dx, closeTo(.5, .01));

    await dragBall(tester, Offset(-size.width / 2 + 20, 0));
    expect(tester.getCenter(ball).dx, closeTo(0, 1));

    await openStrip(tester);
    await tester.tap(find.byKey(const ValueKey('toolbar-pin')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 5));
    await tester.pumpAndSettle();
    final pinned = tester.getCenter(ball);
    await dragBall(tester, const Offset(200, 0));
    expect(tester.getCenter(ball), pinned);
    expect(page, findsOneWidget);
    expect(opened.toolbar.toolbar.pinned, isTrue);
  });

  testWidgets('R51: a hidden toolbar comes back from the menu', (tester) async {
    final opened = await open(tester);
    await openStrip(tester);
    await tester.tap(find.byKey(const ValueKey('toolbar-hide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('toolbar-ball')), findsNothing);
    expect(opened.toolbar.toolbar.hidden, isTrue);
    await tester.tapAt(const Offset(200, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show toolbar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('toolbar-ball')), findsOneWidget);
    expect(opened.toolbar.toolbar.hidden, isFalse);
  });

  testWidgets('R62: a failed toolbar save offers Retry', (tester) async {
    final opened = await open(tester);
    opened.toolbar.fail = true;
    await openStrip(tester);
    await tester.tap(find.byKey(const ValueKey('colour-green')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save toolbar"), findsOneWidget);
    final message = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    for (final arrow in ['arrow-next', 'arrow-previous']) {
      expect(
        message.overlaps(tester.getRect(find.byKey(ValueKey(arrow)))),
        isFalse,
      );
    }
    opened.toolbar.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(opened.toolbar.toolbar.color, MarkColor.green);
  });

  testWidgets('R62: a failed arrow spot save offers Retry', (tester) async {
    final settings = FlakyArrowSettings();
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
    final arrow = find.byKey(const ValueKey('arrow-next'));
    final gesture = await tester.startGesture(tester.getCenter(arrow));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(100, -200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save arrow position"), findsOneWidget);
    settings.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(settings.arrowSpots, hasLength(1));
  });

  testWidgets('R24/R62: a grey word whose reveal failed ignores a tap', (
    tester,
  ) async {
    final store = FailingMarkStore()..failReveal = true;
    await open(tester, store: store);
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save"), findsOneWidget);
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    store.failReveal = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(label(tester), endsWith('; revealed; reveals 1'));
    expect(store.tried, hasLength(2));
  });

  testWidgets('R48: the box follows a slow untick and allows a retick', (
    tester,
  ) async {
    final store = _GatedStore();
    final opened = await open(
      tester,
      store: store,
      prefs: const ToolbarPrefs(tools: [MarkTool.singleLine, MarkTool.circle]),
    );
    final k = key(tester);
    store.open();
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    store.close();
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    final line = find.byKey(const ValueKey('mark-row-Single line'));
    await tester.tap(line);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(line).value, isFalse);
    await tester.tap(line);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(line).value, isTrue);
    store.open();
    await tester.pumpAndSettle();
    expect(opened.store.marks(k).line, red);
    expect(find.byKey(const ValueKey('mark-box')), findsOneWidget);
  });

  testWidgets('R48: dismissing the box during a slow save keeps the reader', (
    tester,
  ) async {
    final store = _GatedStore();
    await open(
      tester,
      store: store,
      prefs: const ToolbarPrefs(tools: [MarkTool.singleLine]),
    );
    store.open();
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    store.close();
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-row-Single line')));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 50));
    store.open();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-box')), findsNothing);
    expect(find.byType(Reader), findsOneWidget);
  });

  testWidgets('R48: Clear all also clears a mark still waiting on Retry', (
    tester,
  ) async {
    final store = FailingMarkStore()..failOn.add(MarkKind.shape);
    await open(
      tester,
      store: store,
      prefs: const ToolbarPrefs(
        tools: [MarkTool.visible, MarkTool.singleLine, MarkTool.circle],
      ),
    );
    final k = key(tester);
    await longPressTarget(tester, word);
    await tester.pumpAndSettle();
    expect(store.marks(k), (line: red, shape: null));
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    store.failOn.clear();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(store.marks(k), noMarks);
    expect(store.state(k), (black: false, count: 1));
  });

  testWidgets('saves finish after the reader closes', (tester) async {
    final store = _GatedStore();
    await open(
      tester,
      store: store,
      prefs: const ToolbarPrefs(tools: [MarkTool.singleLine, MarkTool.circle]),
    );
    final k = key(tester);
    store.close();
    await longPressTarget(tester, word);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    store.open();
    await tester.pumpAndSettle();
    expect(store.marks(k).line, red);
    expect(store.marks(k).shape?.style, MarkStyle.circle);
  });

  Future<int> countNear(WidgetTester tester, Color colour) async {
    final pixels = await wordPixels(tester, word);
    final found = word.resolve(tester);
    final box = found.word.box.inflate(found.word.fontSize * .3);
    final s = pixels.scale;
    var count = 0;
    for (var y = (box.top * s).floor(); y < (box.bottom * s).ceil(); y++) {
      for (var x = (box.left * s).floor(); x < (box.right * s).ceil(); x++) {
        if (x < 0 || y < 0 || x >= pixels.width || y >= pixels.height) continue;
        final i = (y * pixels.width + x) * 4, p = pixels.rgba;
        if (p[i + 3] < 255) continue;
        if ((p[i] - (colour.r * 255).round()).abs() < 24 &&
            (p[i + 1] - (colour.g * 255).round()).abs() < 24 &&
            (p[i + 2] - (colour.b * 255).round()).abs() < 24) {
          count++;
        }
      }
    }
    return count;
  }

  for (final spread in [false, true]) {
    testWidgets('R46/R49: marks paint into the cached page '
        '${spread ? 'on a spread' : 'in portrait'}, follow changes and '
        'turn black to white in dark mode', (tester) async {
      if (spread) {
        tester.view.physicalSize = const Size(1600, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final store = MemoryRevealStore();
      await open(tester, store: store);
      final k = key(tester);
      final model = word.resolve(tester).model;
      await waitForCachedInk(tester, word);
      final redColour = MarkColor.red.paint(Colors.black);
      final blueColour = MarkColor.blue.paint(Colors.black);
      expect(await countNear(tester, redColour), 0);

      Future<void> set(WordMarks marks) async {
        store.wordMarks[k] = marks;
        model.changed();
        await tester.pumpAndSettle();
        await waitForCachedInk(tester, word);
      }

      await set((line: red, shape: null));
      final single = await countNear(tester, redColour);
      expect(single, greaterThan(0));
      await set((
        line: (style: MarkStyle.doubleLine, color: MarkColor.blue),
        shape: null,
      ));
      expect(await countNear(tester, redColour), 0);
      expect(await countNear(tester, blueColour), greaterThan(single));
      final blackBefore = await countNear(tester, Colors.black);
      await set((
        line: null,
        shape: (style: MarkStyle.circle, color: MarkColor.black),
      ));
      expect(await countNear(tester, blueColour), 0);
      expect(await countNear(tester, Colors.black), greaterThan(blackBefore));
      await openMenuItem(tester, 'Dark mode');
      await waitForCachedInk(tester, word);
      expect(await countNear(tester, Colors.white), greaterThan(0));
      await set(noMarks);
      expect(await countNear(tester, Colors.white), 0);
    });
  }

  test('R62: toolbar prefs keep order, drop partners and survive bad data', () {
    const prefs = ToolbarPrefs(
      tools: [MarkTool.circle, MarkTool.singleLine],
      color: MarkColor.orange,
      spot: Offset(.1, .9),
      pinned: true,
    );
    final back = ToolbarPrefs.decode(prefs.encode());
    expect(back.tools, prefs.tools);
    expect(back.color, prefs.color);
    expect(back.spot, prefs.spot);
    expect(back.pinned, isTrue);
    expect(back.hidden, isFalse);
    expect(ToolbarPrefs.decode('nonsense').tools, [MarkTool.visible]);
    expect(ToolbarPrefs.decode(null).color, MarkColor.red);
    expect(
      ToolbarPrefs.decode(
        '{"tools":["singleLine","doubleLine"],"color":"red","spot":[3,0]}',
      ).tools,
      [MarkTool.singleLine],
    );
    expect(
      ToolbarPrefs.decode('{"tools":[],"color":"red","spot":[3,0]}').spot,
      isNull,
    );
  });

  testWidgets('pending marks decide the next action', (tester) async {
    final store = _PausedStore();
    final opened = await open(
      tester,
      store: store,
      prefs: const ToolbarPrefs(tools: [MarkTool.singleLine]),
    );
    await longPressTarget(tester, word);
    await tester.pump();
    await longPressTarget(tester, word);
    await tester.pump();
    store.gate.complete();
    await tester.pumpAndSettle();
    expect(store.markCalls, 1);
    expect(opened.store.marks(key(tester)).line, red);
  });
}

class _PausedStore extends MemoryRevealStore {
  final gate = Completer<void>();
  var markCalls = 0;
  @override
  Future<void> saveMark(MarkAction action) async {
    markCalls++;
    await gate.future;
    await super.saveMark(action);
  }
}

class _GatedStore extends MemoryRevealStore {
  Completer<void>? _gate;
  void open() {
    _gate?.complete();
    _gate = null;
  }

  void close() => _gate = Completer<void>();

  @override
  Future<void> saveMark(MarkAction action) async {
    final gate = _gate;
    if (gate != null) await gate.future;
    await super.saveMark(action);
  }
}
