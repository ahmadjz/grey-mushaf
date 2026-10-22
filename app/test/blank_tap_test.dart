import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/reveal_store.dart';

import 'memory_reveal_store.dart';

void main() {
  testWidgets('between-line short tap toggles bars without re-greying the word', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pages = await loadPages();
    final store = MemoryRevealStore();
    final key = wordKey('2:282:48');
    store.states[key] = (black: true, count: 3);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(pages: pages, store: store),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .widget<PageView>(find.byType(PageView))
        .controller!
        .jumpToPage(pages.indexWhere((p) => p['page'] == 48));
    await tester.pumpAndSettle();
    // Exact Medium_Phone repro, in physical pixels converted to logical pixels.
    const blank = Offset(864 / 2.625, 799 / 2.625);
    await tester.tapAt(blank);
    await tester.pumpAndSettle();
    expect(store.state(key), (black: true, count: 3));
    expect(find.text('Settings'), findsOneWidget);
    final page = pages.singleWhere((p) => p['page'] == 48);
    final word = (page['lines'] as List)
        .expand((line) => line['words'] as List)
        .singleWhere((w) => w['location'] == '2:282:48');
    await tester.tap(find.byKey(ValueKey('word-${word['id']}')));
    await tester.pumpAndSettle();
    expect(store.state(key), (black: false, count: 3));
    expect(find.text('Settings'), findsOneWidget);
    // The same blank part of the band must remain a generous long-press target.
    await tester.longPressAt(blank);
    await tester.pumpAndSettle();
    expect(store.state(key), (black: true, count: 4));
    await tester.tapAt(blank);
    await tester.pumpAndSettle();
    expect(store.state(key), (black: true, count: 4));
    expect(find.text('Settings'), findsNothing);
  });
}
