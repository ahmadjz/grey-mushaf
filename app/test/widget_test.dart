import 'memory_reveal_store.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/flat_ink.dart';
import 'package:greymushaf/heading_ink.dart';

late List<Map<String, dynamic>> pages;

Finder word(int id, {bool skipOffstage = true}) =>
    find.byKey(ValueKey('word-$id'), skipOffstage: skipOffstage);
String status(WidgetTester tester, int id) =>
    tester.widget<Semantics>(word(id)).properties.label!;

Future<void> mount(WidgetTester tester, {bool landscape = false}) async {
  tester.view.physicalSize = landscape
      ? const Size(1200, 700)
      : const Size(600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Reader(store: MemoryRevealStore(), pages: pages),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    pages = await loadPages();
  });

  testWidgets(
    'surah painted ink fills its calibrated box without font padding',
    (tester) async {
      await tester.runAsync(() async {
        final page = pages.singleWhere((p) => p['page'] == 2);
        final painter = HeadingInk(
          page['lines'][0]['heading'] as Map<String, dynamic>,
          opening: true,
        );
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(300, 100));
        final picture = recorder.endRecording();
        final image = await picture.toImage(300, 100);
        final bytes = (await image.toByteData())!.buffer.asUint8List();
        final ys = <int>[];
        for (var y = 0; y < 100; y++) {
          for (var x = 0; x < 300; x++) {
            if (bytes[(y * 300 + x) * 4 + 3] > 128) {
              ys.add(y);
              break;
            }
          }
        }
        expect(ys.last - ys.first + 1, greaterThanOrEqualTo(97));
        image.dispose();
        picture.dispose();
        painter.dispose();
      });
    },
  );

  testWidgets('headings are black inert ink; page 1 ayah remains revealable', (
    tester,
  ) async {
    await mount(tester);
    await tester.longPress(word(1));
    await tester.pumpAndSettle();
    final before = status(tester, 1);
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    for (final index in [0, 1, 4]) {
      controller.jumpToPage(index);
      await tester.pumpAndSettle();
      final page = pages[index];
      final ids = [
        for (final line in page['lines'] as List)
          for (final w in line['words'] as List) w['id'] as int,
      ];
      final states = {for (final id in ids) id: status(tester, id)};
      for (final line in (page['lines'] as List).where(
        (l) => l['type'] != 'ayah',
      )) {
        final heading = find.byKey(
          ValueKey('heading-${page['page']}-${line['number']}'),
        );
        expect(heading, findsOneWidget);
        expect(
          find.descendant(of: heading, matching: find.byType(Semantics)),
          findsNothing,
        );
        expect(
          tester
              .widget<FlatInk>(
                find.descendant(of: heading, matching: find.byType(FlatInk)),
              )
              .color,
          Colors.black,
        );
        await tester.longPress(heading);
        await tester.pumpAndSettle();
        await tester.tap(heading);
        await tester.pumpAndSettle();
        for (final id in ids) {
          expect(status(tester, id), states[id]);
        }
      }
    }
    controller.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(status(tester, 1), before);
  });

  testWidgets('all heading forms render black pixels under FlatInk', (
    tester,
  ) async {
    for (final pair in [(2, 0), (2, 1), (50, 1)]) {
      final page = pages.singleWhere((p) => p['page'] == pair.$1);
      final painter = HeadingInk(
        page['lines'][pair.$2]['heading'] as Map<String, dynamic>,
        opening: pair.$1 <= 2,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: FlatInk(
                color: Colors.black,
                child: CustomPaint(
                  size: const Size(600, 120),
                  painter: painter,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var black = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          if (bytes[i + 3] < 250) continue;
          expect(bytes[i], bytes[i + 1]);
          expect(bytes[i], bytes[i + 2]);
          if (bytes[i] < 10) black++;
        }
        expect(black, greaterThan(100));
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      painter.dispose();
    }
  });

  testWidgets('synthetic 187 and 604 heading bands never target words', (
    tester,
  ) async {
    await mount(tester);
    final source = pages.singleWhere((p) => p['page'] == 50);
    for (final number in [187, 604]) {
      final page = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
      page['page'] = number;
      final original = page['lines'] as List;
      final lines = <Map<String, dynamic>>[];
      final starts = number == 187 ? [1] : [1, 5, 10];
      for (var n = 1; n <= 15; n++) {
        final title = starts.contains(n);
        final basmallah = number == 604 && starts.contains(n - 1);
        final line = jsonDecode(
          jsonEncode(
            original[title
                ? 0
                : basmallah
                ? 1
                : 2],
          ),
        ) as Map<String, dynamic>;
        line['number'] = n;
        if (title) {
          final surah = number == 187 ? 9 : 112 + starts.indexOf(n);
          line['surah'] = surah;
          line['heading']['parts'][1] =
              'surah${surah.toString().padLeft(3, '0')}';
        }
        if (!title && !basmallah) {
          line['words'] = [jsonDecode(jsonEncode(original[2]['words'][0]))];
          line['words'][0]['id'] = n;
        }
        lines.add(line);
      }
      page['lines'] = lines;
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(
            store: MemoryRevealStore(),
            key: ValueKey(number),
            pages: [page],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ids = [
        for (final l in lines)
          for (final w in l['words']) w['id'] as int,
      ];
      await tester.longPress(word(ids.first));
      await tester.pumpAndSettle();
      final before = {for (final id in ids) id: status(tester, id)};
      expect(before[ids.first], contains('black; reveals 1'));
      final headings = lines.where((l) => l['type'] != 'ayah').toList();
      expect(headings.length, number == 187 ? 1 : 6);
      for (final line in headings) {
        expect(line['words'], isEmpty);
        final band = find.byKey(ValueKey('line-$number-${line['number']}'));
        expect(
          find.descendant(of: band, matching: find.byType(Semantics)),
          findsNothing,
        );
        final rect = tester.getRect(band);
        for (final y in [rect.top + 1, rect.center.dy, rect.bottom - 1]) {
          await tester.longPressAt(Offset(rect.center.dx, y));
          await tester.tapAt(Offset(rect.center.dx, y));
          await tester.pumpAndSettle();
        }
      }
      for (final id in ids) {
        expect(status(tester, id), before[id]);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('short surah names retain their natural relative width', (
    tester,
  ) async {
    await mount(tester);
    final source = pages.singleWhere((p) => p['page'] == 50);
    final widths = <double>[];
    for (final name in ['surah003', 'surah050']) {
      final page = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
      page['lines'][0]['heading']['parts'][1] = name;
      if (name == 'surah050') {
        page['lines'][0]['heading']['bounds'][1] = [10, -71, 844, 630];
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(
            store: MemoryRevealStore(),
            key: ValueKey(name),
            pages: [page],
          ),
        ),
      );
      await tester.pumpAndSettle();
      widths.add(
        tester.getSize(find.byKey(const ValueKey('heading-50-1'))).width,
      );
    }
    expect(widths[1], lessThan(widths[0] * .9));
  });

  testWidgets('opening pages use the printed 47 px row pitch', (tester) async {
    await mount(tester);
    final first = tester.getRect(find.byKey(const ValueKey('line-1-2')));
    final second = tester.getRect(find.byKey(const ValueKey('line-1-3')));
    final title = tester.getRect(find.byKey(const ValueKey('heading-1-1')));
    expect((second.top - first.top) / title.width, closeTo(47 / 101, .001));
  });

  for (final landscape in [false, true]) {
    testWidgets('heading ink proportions match print, landscape=$landscape', (
      tester,
    ) async {
      await mount(tester, landscape: landscape);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      for (final entry in [
        (2, 1, 93.0, 31.0),
        (2, 2, 172.0, 40.0),
        (50, 1, 133.0, 45.0),
        (50, 2, 307.0, 40.0),
      ]) {
        controller.jumpToPage(
          entry.$1 == 2 ? (landscape ? 0 : 1) : (landscape ? 2 : 4),
        );
        await tester.pumpAndSettle();
        final heading = tester.getRect(
          find.byKey(ValueKey('heading-${entry.$1}-${entry.$2}')),
        );
        final band = find.byKey(ValueKey('line-${entry.$1}-${entry.$2}'));
        final block = tester
            .widgetList<SizedBox>(
              find.descendant(of: band, matching: find.byType(SizedBox)),
            )
            .where((b) => b.width != null && b.width!.isFinite)
            .first
            .width!;
        expect(heading.width / block, closeTo(entry.$3 / 543, .001));
        expect(heading.height / block, closeTo(entry.$4 / 543, .001));
        expect(heading.center.dx, closeTo(tester.getCenter(band).dx, .01));
      }
      final regularTitle = tester.getRect(
        find.byKey(const ValueKey('heading-50-1')),
      );
      final wide = tester.getRect(find.byKey(const ValueKey('heading-50-2')));
      final blockTop = tester
          .getTopLeft(find.byKey(const ValueKey('line-50-1')))
          .dy;
      expect(
        (regularTitle.top - blockTop) / regularTitle.width,
        closeTo(7 / 133, .001),
      );
      expect((wide.top - blockTop) / wide.width, closeTo(73 / 307, .001));
      expect(
        (wide.center.dy - regularTitle.center.dy) / wide.width,
        closeTo(63.5 / 307, .001),
      );
      controller.jumpToPage(landscape ? 0 : 1);
      await tester.pumpAndSettle();
      final a = tester.getRect(find.byKey(const ValueKey('heading-2-1')));
      final b = tester.getRect(find.byKey(const ValueKey('heading-2-2')));
      expect((b.center.dy - a.center.dy) / b.width, closeTo(136.5 / 172, .01));
    });
  }

  testWidgets(
    'grey tap does nothing; long press reveals; black tap re-greys; count increments only on reveal',
    (tester) async {
      await mount(tester);
      expect(word(1), findsOneWidget);
      expect(status(tester, 1), contains('grey; reveals 0'));
      await tester.tap(word(1));
      await tester.pump();
      expect(status(tester, 1), contains('grey; reveals 0'));
      await tester.longPress(word(1));
      await tester.pumpAndSettle();
      expect(status(tester, 1), contains('black; reveals 1'));
      await tester.longPress(word(1));
      await tester.pumpAndSettle();
      expect(status(tester, 1), contains('black; reveals 1'));
      await tester.tap(word(1));
      await tester.pump();
      expect(status(tester, 1), contains('grey; reveals 1'));
      await tester.longPress(word(1));
      await tester.pump();
      expect(status(tester, 1), contains('black; reveals 2'));
    },
  );

  testWidgets(
    'drag crosses words and line break once, locks swipe until lift, ordinary swipe then changes page',
    (tester) async {
      await mount(tester);
      expect(word(1), findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(word(1)));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(word(4)));
      await tester.pump();
      for (final id in [1, 2, 3, 4]) {
        expect(status(tester, id), contains('black; reveals 1'));
      }
      await gesture.moveTo(tester.getCenter(word(6)));
      await gesture.moveTo(tester.getCenter(word(1)));
      await tester.pump();
      expect(status(tester, 6), contains('black; reveals 1'));
      expect(status(tester, 1), contains('black; reveals 1'));
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      expect(find.byKey(const ValueKey('page-1')), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-2')), findsOneWidget);
    },
  );

  testWidgets('landscape puts odd page on right for both spreads', (
    tester,
  ) async {
    await mount(tester, landscape: true);
    expect(find.byKey(const ValueKey('page-1')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('page-1'))).dx,
      greaterThan(tester.getCenter(find.byKey(const ValueKey('page-2'))).dx),
    );
    await tester.drag(find.byType(PageView), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byKey(const ValueKey('page-47'))).dx,
      greaterThan(tester.getCenter(find.byKey(const ValueKey('page-48'))).dx),
    );
  });

  testWidgets('page 48 overhang and line-band gaps reveal the nearest word', (
    tester,
  ) async {
    await mount(tester);
    final page = pages.singleWhere((p) => p['page'] == 48);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          store: MemoryRevealStore(),
          key: const ValueKey('dense'),
          pages: [page],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lines = page['lines'] as List;
    final words = lines.first['words'] as List;
    final id =
        words[6]['id'] as int; // 2:282:7, ink overhang beyond its advance.
    final rect = tester.getRect(word(id));
    final band = tester.getRect(find.byKey(const ValueKey('line-48-1')));
    // uniFC47 extends rightward: xMax 2669 exceeds its 2371-unit advance.
    final overhang = Offset(rect.right + 0.5, rect.center.dy);
    await tester.longPressAt(overhang);
    await tester.pump();
    expect(status(tester, id), contains('black; reveals 1'));
    for (final other in words.where((w) => w['id'] != id)) {
      expect(status(tester, other['id'] as int), contains('grey; reveals 0'));
    }
    await tester.tapAt(overhang);
    await tester.pump();
    expect(status(tester, id), contains('grey; reveals 1'));
    // Entire line slot, including its top edge, belongs to words.
    final gesture = await tester.startGesture(
      Offset(rect.center.dx, band.top + 0.1),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final next = (lines[1]['words'] as List).first['id'] as int;
    await gesture.moveTo(tester.getCenter(word(next)));
    await gesture.moveTo(overhang);
    await tester.pump();
    expect(status(tester, id), contains('black; reveals 2'));
    expect(status(tester, next), contains('black; reveals 1'));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'empty gutter does nothing; dragging into each page counts once',
    (tester) async {
      await mount(tester, landscape: true);
      await tester.drag(find.byType(PageView), const Offset(1000, 0));
      await tester.pumpAndSettle();
      final right = pages.singleWhere((p) => p['page'] == 47);
      final left = pages.singleWhere((p) => p['page'] == 48);
      final rightId =
          ((right['lines'] as List).first['words'] as List).last['id'] as int;
      final leftId =
          ((left['lines'] as List).first['words'] as List).first['id'] as int;
      final a = tester.getRect(word(rightId));
      final b = tester.getRect(word(leftId));
      final gutter = Offset((a.left + b.right) / 2 + 1, a.center.dy);
      final gesture = await tester.startGesture(gutter);
      await tester.pump(const Duration(milliseconds: 600));
      expect(status(tester, rightId), contains('grey; reveals 0'));
      expect(status(tester, leftId), contains('grey; reveals 0'));
      await gesture.moveTo(b.center);
      await gesture.moveTo(a.center);
      await tester.pump();
      expect(status(tester, leftId), contains('black; reveals 1'));
      expect(status(tester, rightId), contains('black; reveals 1'));
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('visible first-word tail belongs only to 1:1:1', (tester) async {
    tester.view.physicalSize = const Size(1080 / 2.625, 2274 / 2.625);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(store: MemoryRevealStore(), pages: pages),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(word(1));
    final text = tester.widget<Text>(
      find.descendant(of: word(1), matching: find.byType(Text)),
    );
    await tester.longPressAt(
      Offset(rect.left - text.style!.fontSize! * .145, rect.center.dy),
    );
    await tester.pump();
    expect(status(tester, 1), contains('black; reveals 1'));
    for (final id in [2, 3, 4, 5]) {
      expect(status(tester, id), contains('grey; reveals 0'));
    }
  });

  testWidgets('ink reaching into page padding still belongs to its word', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080 / 2.625, 2274 / 2.625);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(store: MemoryRevealStore(), pages: pages),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
    await tester.pumpAndSettle();
    // 2:282:70 has 43 font units of right overhang into the 2 dp padding.
    final rect = tester.getRect(word(6240));
    final point = Offset(rect.right + .2, rect.center.dy);
    expect(point.dx, lessThan(tester.view.physicalSize.width));
    await tester.longPressAt(point);
    await tester.pump();
    expect(status(tester, 6240), contains('black; reveals 1'));
  });

  testWidgets('empty glyph in a multi-character word has no ink extent', (
    tester,
  ) async {
    final data = jsonDecode(jsonEncode(pages)) as List;
    final first = data[0]['lines'][1]['words'][0];
    first['text'] = '${first['text']} ';
    (first['ink'] as List).add(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          store: MemoryRevealStore(),
          pages: data.cast<Map<String, dynamic>>(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(word(1), findsOneWidget);
  });

  testWidgets('empty margin press and tap never change a word', (tester) async {
    await mount(tester);
    final margin = Offset(5, tester.getCenter(word(5)).dy);
    await tester.longPressAt(margin);
    await tester.pump();
    expect(status(tester, 5), contains('grey; reveals 0'));
    await tester.longPress(word(5));
    await tester.pump();
    await tester.tapAt(margin);
    await tester.pump();
    expect(status(tester, 5), contains('black; reveals 1'));
  });

  testWidgets('attached off-screen bands cannot receive a press', (
    tester,
  ) async {
    await mount(tester);
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    // Keep page 1 attached but slide its text off the right edge of the viewport.
    controller.jumpTo(590);
    await tester.pump();
    final rect = tester.getRect(word(5, skipOffstage: false));
    expect(rect.left, greaterThan(600));
    final detector = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.byType(PageView),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    detector.onLongPressStart!(
      LongPressStartDetails(globalPosition: rect.center),
    );
    await tester.pump();
    expect(
      tester.widget<Semantics>(word(5, skipOffstage: false)).properties.label,
      contains('grey; reveals 0'),
    );
    detector.onLongPressEnd!(const LongPressEndDetails());
    await tester.pumpAndSettle();
  });

  testWidgets('reveal drag and rotation reuse bundle measurements', (
    tester,
  ) async {
    var measurements = 0;
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          store: MemoryRevealStore(),
          pages: pages,
          onMeasureWord: () => measurements++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = measurements;
    final wordCount = pages.fold<int>(
      0,
      (sum, page) =>
          sum +
          (page['lines'] as List).fold<int>(
            0,
            (n, line) => n + (line['words'] as List).length,
          ),
    );
    expect(initial, wordCount);
    final gesture = await tester.startGesture(tester.getCenter(word(1)));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(word(4)));
    await tester.pump();
    expect(
      tester
          .widget<PopupMenuButton<int>>(
            find.byKey(const ValueKey('page-picker-1')),
          )
          .enabled,
      isFalse,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    expect(measurements, initial);
    expect(
      tester
          .widget<PopupMenuButton<int>>(
            find.byKey(const ValueKey('page-picker-1')),
          )
          .enabled,
      isTrue,
    );
  });

  for (final size in [
    const Size(1080 / 2.625, 2274 / 2.625),
    const Size(2400 / 2.625, 954 / 2.625),
    const Size(800, 1224),
    const Size(1280, 744),
  ]) {
    testWidgets(
      'reader fills $size and opening pages use normal-page font size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Reader(store: MemoryRevealStore(), pages: pages),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsNothing);
        expect(find.byKey(const ValueKey('counts')), findsNothing);
        final firstWord = tester.widget<Text>(
          find.descendant(of: word(1), matching: find.byType(Text)),
        );
        final openingSize = firstWord.style!.fontSize!;
        final openingFirst = tester.getRect(
          find.byKey(const ValueKey('line-1-2')),
        );
        final openingLast = tester.getRect(
          find.byKey(const ValueKey('line-1-8')),
        );
        expect(
          openingLast.bottom - openingFirst.top,
          lessThan(size.height * .8),
        );
        final openingPage = tester.getRect(
          find.byKey(const ValueKey('page-1')),
        );
        expect(
          (openingFirst.top + openingLast.bottom) / 2,
          closeTo(openingPage.center.dy, openingFirst.height),
        );
        final controller = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        controller.jumpToPage(size.width > size.height ? 1 : 3);
        await tester.pumpAndSettle();
        final page = tester.getRect(find.byKey(const ValueKey('page-48')));
        final first = tester.getRect(find.byKey(const ValueKey('line-48-1')));
        final last = tester.getRect(find.byKey(const ValueKey('line-48-15')));
        expect(
          page.width,
          closeTo(size.width / (size.width > size.height ? 2 : 1), 1),
        );
        expect(first.width, greaterThan(page.width - 9));
        expect(first.top - page.top, lessThanOrEqualTo(4));
        expect(page.bottom - last.bottom, lessThanOrEqualTo(26));
        for (var i = 1; i < 15; i++) {
          final a = tester.getRect(find.byKey(ValueKey('line-48-$i')));
          final b = tester.getRect(find.byKey(ValueKey('line-48-${i + 1}')));
          expect(a.bottom, closeTo(b.top, .01));
        }
        final data = pages.singleWhere((p) => p['page'] == 48);
        final sizes = <double>{};
        for (final line in data['lines'] as List) {
          for (final w in line['words'] as List) {
            final text = tester.widget<Text>(
              find.descendant(
                of: word(w['id'] as int),
                matching: find.byType(Text),
              ),
            );
            sizes.add(text.style!.fontSize!);
          }
        }
        expect(
          sizes.length,
          1,
          reason: 'uniform font size, not per-line shrink',
        );
        expect(openingSize, closeTo(sizes.single, .01));
        // Exclude stretched gaps: the words themselves must fill the limiting
        // dimension, not merely their full-width line containers.
        final firstWords = (data['lines'] as List).first['words'] as List;
        final advanceWidth = firstWords.fold<double>(
          0,
          (sum, w) => sum + tester.getSize(word(w['id'] as int)).width,
        );
        final font = data['font'] as Map<String, dynamic>;
        final inkHeight =
            ((font['yMax'] as num) - (font['yMin'] as num)) /
            (font['unitsPerEm'] as num) *
            sizes.single *
            15;
        final fraction = (advanceWidth / page.width) > (inkHeight / page.height)
            ? advanceWidth / page.width
            : inkHeight / page.height;
        expect(fraction, greaterThanOrEqualTo(.90));
        controller.jumpToPage(size.width > size.height ? 0 : 1);
        await tester.pumpAndSettle();
        final page2 = pages.singleWhere((p) => p['page'] == 2);
        final id2 =
            ((page2['lines'] as List).firstWhere(
                          (l) => (l['words'] as List).isNotEmpty,
                        )['words']
                        as List)
                    .first['id']
                as int;
        expect(
          tester
              .widget<Text>(
                find.descendant(of: word(id2), matching: find.byType(Text)),
              )
              .style!
              .fontSize,
          closeTo(openingSize, .01),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'height-limited spread keeps justified text at the shared font scale',
    (tester) async {
      await mount(tester, landscape: true);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      final page = pages.singleWhere((p) => p['page'] == 48);
      final lines = page['lines'] as List;
      final fontSize = tester
          .widget<Text>(
            find.descendant(of: word(6171), matching: find.byType(Text)),
          )
          .style!
          .fontSize!;
      // The widest bundled line at this same font size sets the text block.
      var naturalWidth = 0.0;
      for (final p in pages) {
        for (final line in p['lines'] as List) {
          final words = line['words'] as List;
          if (words.isEmpty) continue;
          var width = (words.length - 1) * fontSize * .09;
          for (final w in words) {
            final painter = TextPainter(
              text: TextSpan(
                text: w['text'] as String,
                style: TextStyle(
                  fontFamily: 'mushaf-${p['page']}',
                  fontSize: fontSize,
                  height: 1,
                ),
              ),
              textDirection: TextDirection.rtl,
            )..layout();
            width += painter.width;
            painter.dispose();
          }
          if (width > naturalWidth) naturalWidth = width;
        }
      }
      final first = (lines.first['words'] as List).first['id'] as int;
      final last = (lines.first['words'] as List).last['id'] as int;
      final span =
          tester.getRect(word(first)).right - tester.getRect(word(last)).left;
      expect(span, closeTo(naturalWidth, 1));
      expect(
        tester.getCenter(find.byKey(const ValueKey('line-48-1'))).dx,
        closeTo(
          (tester.getRect(word(first)).right +
                  tester.getRect(word(last)).left) /
              2,
          .1,
        ),
      );
      // The touch band still covers the entire page, including outside the ink.
      expect(
        tester.getSize(find.byKey(const ValueKey('line-48-1'))).width,
        596,
      );
    },
  );

  testWidgets(
    'spread drag crosses a line break, locks swiping and counts each word once',
    (tester) async {
      await mount(tester, landscape: true);
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      final dense = pages.singleWhere((p) => p['page'] == 48);
      final lines = dense['lines'] as List;
      final from = (lines[0]['words'] as List).last['id'] as int;
      final to = (lines[1]['words'] as List).first['id'] as int;
      final gesture = await tester.startGesture(tester.getCenter(word(from)));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(word(to)));
      await gesture.moveTo(tester.getCenter(word(from)));
      await tester.pump();
      for (final id in [from, to]) {
        expect(status(tester, id), contains('black; reveals 1'));
      }
      expect(controller.page, 1);
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('page-2')), findsOneWidget);
    },
  );

  testWidgets(
    'pages 1, 2, 48 render the layout database line ranges without wrapping',
    (tester) async {
      final query = Process.runSync('python3', [
        '-c',
        'import sqlite3,json; c=sqlite3.connect("../assets-src/qul-v4/layout/qpc-v4-tajweed-15-lines.db"); print(json.dumps(c.execute("select page_number,line_number,line_type,first_word_id,last_word_id from pages where page_number in (1,2,48) order by page_number,line_number").fetchall()))',
      ]);
      expect(query.exitCode, 0, reason: query.stderr.toString());
      final rows = jsonDecode(query.stdout as String) as List;
      for (final number in [1, 2, 48]) {
        final page = pages.singleWhere((p) => p['page'] == number);
        final lines = page['lines'] as List;
        final expected = rows.where((r) => r[0] == number).toList();
        expect(lines.length, expected.length);
        for (var i = 0; i < expected.length; i++) {
          final line = lines[i];
          expect(line['number'], expected[i][1]);
          expect(line['type'], expected[i][2]);
          final words = line['words'] as List;
          expect(
            words.map((w) => w['id']).toList(),
            expected[i][2] == 'ayah'
                ? [for (int id = expected[i][3]; id <= expected[i][4]; id++) id]
                : [],
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Reader(
              store: MemoryRevealStore(),
              key: ValueKey(number),
              pages: [page],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('page-$number')), findsOneWidget);
        for (final line in lines.where((l) => l['type'] == 'ayah')) {
          final words = line['words'] as List;
          final first = tester.getCenter(word(words.first['id'] as int));
          final last = tester.getCenter(word(words.last['id'] as int));
          expect(first.dy, closeTo(last.dy, 0.1));
          expect(first.dx, greaterThanOrEqualTo(last.dx));
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
