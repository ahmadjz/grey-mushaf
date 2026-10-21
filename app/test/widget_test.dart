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
