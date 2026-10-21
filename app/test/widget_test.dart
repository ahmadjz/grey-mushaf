import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';

late List<Map<String, dynamic>> pages;

Finder word(int id) => find.byKey(ValueKey('word-$id'));
String status(WidgetTester tester, int id) =>
    tester.widget<Semantics>(word(id)).properties.label!;

Future<void> mount(WidgetTester tester, {bool landscape = false}) async {
  tester.view.physicalSize = landscape
      ? const Size(1200, 700)
      : const Size(600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Reader(pages: pages)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    pages = [
      for (final p in [1, 2, 47, 48])
        jsonDecode(File('assets/mushaf/$p.json').readAsStringSync())
            as Map<String, dynamic>,
    ];
    for (final p in pages) {
      final number = p['page'];
      final loader = FontLoader('mushaf-$number')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/mushaf/p$number.ttf').readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
  });

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
        home: Reader(key: const ValueKey('dense'), pages: [page]),
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
    'drag through spread gutter assigns the nearest line edge without counting twice',
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
      expect(status(tester, rightId), contains('black; reveals 1'));
      await gesture.moveTo(b.center);
      await gesture.moveTo(a.center);
      await tester.pump();
      expect(status(tester, leftId), contains('black; reveals 1'));
      expect(status(tester, rightId), contains('black; reveals 1'));
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

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
        await tester.pumpWidget(MaterialApp(home: Reader(pages: pages)));
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
            home: Reader(key: ValueKey(number), pages: [page]),
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
