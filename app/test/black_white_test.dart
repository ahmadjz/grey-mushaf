import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/quran_index.dart';
import 'package:greymushaf/search_screen.dart';
import 'package:greymushaf/page_ink.dart';
import 'package:greymushaf/reader_settings.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:greymushaf/word_marks.dart';

import 'memory_reveal_store.dart';
import 'top_bar_test.dart' show insets, screen, shown;
import 'word_target.dart';

class BlackWhiteSettings implements ReaderSettings {
  BlackWhiteSettings({this.blackWhite});
  @override
  int greyLevel = 176;
  @override
  int darkLevel = 80;
  @override
  bool arrowsShown = true;
  @override
  final arrowSpots = <String, Offset>{};
  @override
  bool? blackWhite;
  @override
  Future<void> saveDarkLevel(int level) async => darkLevel = level;
  @override
  Future<void> saveGreyLevel(int level) async => greyLevel = level;
  @override
  Future<void> saveArrowsShown(bool shown) async => arrowsShown = shown;
  @override
  Future<void> saveArrowSpot(String key, Offset spot) async =>
      arrowSpots[key] = spot;
  @override
  Future<void> saveBlackWhite(bool on) async => blackWhite = on;
}

bool isGrey(Color color) => color.r == color.g && color.g == color.b;

void main() {
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());
  List<Map<String, dynamic>> range(int from, int to) => pages
      .where((p) => (p['page'] as int) >= from && (p['page'] as int) <= to)
      .toList();

  Future<void> open(
    WidgetTester tester, {
    required bool eInk,
    BlackWhiteSettings? settings,
    MemoryRevealStore? store,
  }) async {
    screen(tester, const Size(411, 914));
    insets(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          key: ValueKey(eInk),
          pages: range(215, 218),
          store: store ?? MemoryRevealStore(),
          settings: settings ?? BlackWhiteSettings(),
          eInk: eInk,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openStrip(WidgetTester tester) async {
    final ball = tester.getRect(find.byKey(const ValueKey('toolbar-ball')));
    final screen = Offset.zero & tester.getSize(find.byType(Reader));
    await tester.tapAt(ball.intersect(screen.deflate(1)).center);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('toolbar-strip')), findsOneWidget);
  }

  bool blackWhiteSwitch(WidgetTester tester) => tester
      .widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Black & white'),
      )
      .value;

  testWidgets('a Boox starts in black and white without the colour row', (
    tester,
  ) async {
    await open(tester, eInk: true);
    await openStrip(tester);
    expect(find.byKey(const ValueKey('colour-red')), findsNothing);
  });

  testWidgets('a phone keeps the colour row and natural colours', (
    tester,
  ) async {
    await open(tester, eInk: false);
    await openStrip(tester);
    expect(find.byKey(const ValueKey('colour-red')), findsOneWidget);
    await tester.tapAt(const Offset(200, 450));
    await tester.pumpAndSettle();
    await openMenuItem(tester, 'Settings');
    expect(blackWhiteSwitch(tester), isFalse);
  });

  testWidgets('the Settings switch turns B/W off and remembers it', (
    tester,
  ) async {
    final settings = BlackWhiteSettings();
    await open(tester, eInk: true, settings: settings);
    await openMenuItem(tester, 'Settings');
    expect(blackWhiteSwitch(tester), isTrue);
    final scheme = Theme.of(tester.element(find.text('Black & white')))
        .colorScheme;
    expect(isGrey(scheme.primary), isTrue);
    expect(isGrey(scheme.secondaryContainer), isTrue);
    await tester.tap(find.text('Black & white'));
    await tester.pumpAndSettle();
    expect(settings.blackWhite, isFalse);
    expect(blackWhiteSwitch(tester), isFalse);
    expect(
      isGrey(
        Theme.of(tester.element(find.text('Black & white')))
            .colorScheme
            .primary,
      ),
      isFalse,
    );
  });

  testWidgets('a saved choice beats the device default', (tester) async {
    await open(
      tester,
      eInk: true,
      settings: BlackWhiteSettings(blackWhite: false),
    );
    await openStrip(tester);
    expect(find.byKey(const ValueKey('colour-red')), findsOneWidget);
  });

  testWidgets('a phone can turn B/W on', (tester) async {
    await open(
      tester,
      eInk: false,
      settings: BlackWhiteSettings(blackWhite: true),
    );
    await openStrip(tester);
    expect(find.byKey(const ValueKey('colour-red')), findsNothing);
  });

  testWidgets('in B/W an arrow changes the page at once', (tester) async {
    await open(tester, eInk: true);
    await tester.tap(find.byKey(const ValueKey('arrow-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byKey(const ValueKey('page-216'))).left, 0);
  });

  testWidgets('in colour an arrow also changes the page at once', (
    tester,
  ) async {
    await open(tester, eInk: false);
    await tester.tap(find.byKey(const ValueKey('arrow-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byKey(const ValueKey('page-216'))).left, 0);
  });

  testWidgets('the search shade is grey in B/W and blue in colour', (
    tester,
  ) async {
    for (final eInk in [true, false]) {
      await open(tester, eInk: eInk);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('ayah-shade-215')),
                  )
                  .painter
              as AyahShadePainter;
      expect(isGrey(painter.shade), eInk);
    }
  });

  testWidgets('B/W borders and header line are at least 1 px', (tester) async {
    await open(tester, eInk: true);
    final border = tester.widget<PageBorder>(
      find.byKey(const ValueKey('page-border-215')),
    );
    expect(border.thinnest, greaterThanOrEqualTo(1));
    final header = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('page-header-215')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      ((header.decoration as BoxDecoration).border as Border).bottom.width,
      greaterThanOrEqualTo(1),
    );
  });

  testWidgets('B/W strip tools and the tap box show no colour', (tester) async {
    final store = MemoryRevealStore();
    await open(tester, eInk: true, store: store);
    final first = tester
        .widget<PaintedInkPage>(find.byType(PaintedInkPage).first)
        .controller
        .words
        .first;
    final word = WordTarget(first.id);
    final key = wordKey(first.location);
    store.wordMarks[key] = (
      line: (style: MarkStyle.singleLine, color: MarkColor.red),
      shape: null,
    );
    await tapTarget(tester, word);
    await tester.pumpAndSettle();
    final swatch = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byKey(const ValueKey('mark-box')),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(isGrey(swatch.backgroundColor!), isTrue);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await openStrip(tester);
    final icon = tester.widget<Icon>(
      find
          .descendant(
            of: find.byKey(const ValueKey('tool-visible')),
            matching: find.byType(Icon),
          )
          .first,
    );
    expect(isGrey(icon.color!), isTrue);
  });

  testWidgets('B/W errors are not red', (tester) async {
    await open(tester, eInk: true);
    await openMenuItem(tester, 'Settings');
    final scheme = Theme.of(tester.element(find.text('Black & white')))
        .colorScheme;
    for (final colour in [
      scheme.error,
      scheme.onError,
      scheme.errorContainer,
      scheme.onErrorContainer,
    ]) {
      expect(isGrey(colour), isTrue);
    }
  });

  for (final eInk in [true, false]) {
    testWidgets(
      'rapid arrows on loaded pages land without a slide, eInk $eInk',
      (tester) async {
        screen(tester, const Size(411, 914));
        insets(tester);
        final bundle = (await tester.runAsync(() => MushafBundle.open()))!;
        await tester.pumpWidget(
          MaterialApp(
            home: Reader(
              pages: bundle.pages,
              bundle: bundle,
              store: MemoryRevealStore(),
              settings: BlackWhiteSettings(),
              eInk: eInk,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('arrow-next')));
        await tester.tap(find.byKey(const ValueKey('arrow-next')));
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump();
        }
        expect(shown(tester, 1, 10), [3]);
        expect(tester.getRect(find.byKey(const ValueKey('page-3'))).left, 0);
        await tester.tap(find.byKey(const ValueKey('arrow-previous')));
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump();
        }
        expect(shown(tester, 1, 10), [2]);
      },
    );
  }

  testWidgets('dark mode in B/W keeps a grey shade and white marks', (
    tester,
  ) async {
    await open(tester, eInk: true);
    await openMenuItem(tester, 'Dark mode');
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('ayah-shade-215')),
                )
                .painter
            as AyahShadePainter;
    expect(painter.dark, isTrue);
    expect(isGrey(painter.shade), isTrue);
    final ink = tester
        .widget<PaintedInkPage>(find.byType(PaintedInkPage).first)
        .controller;
    expect(ink.markColor(MarkColor.blue), Colors.white);
  });

  testWidgets('B/W search marks matches by weight, not colour', (tester) async {
    final index = (await tester.runAsync(() => QuranIndex.load(rootBundle)))!;
    final search = (await tester.runAsync(() => SearchIndex.load(rootBundle)))!;
    for (final blackWhite in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(blackWhite),
          home: SearchScreen(
            index: index,
            search: Future.value(search),
            blackWhite: blackWhite,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('search-field')),
        'أيها الذين',
      );
      await tester.pumpAndSettle();
      final text = tester.widget<RichText>(
        find
            .descendant(
              of: find.byKey(const ValueKey('search-ayah-2:104')),
              matching: find.byType(RichText),
            )
            .first,
      );
      final spans = <TextSpan>[];
      text.text.visitChildren((span) {
        if (span is TextSpan && span.style != null) spans.add(span);
        return true;
      });
      final match = spans.firstWhere((span) => span.text!.contains('الذين'));
      expect(match.style!.fontWeight == FontWeight.bold, blackWhite);
      expect(match.style!.decoration == TextDecoration.underline, blackWhite);
    }
  });

  test('B/W marks use the page ink, colour marks keep their colour', () {
    final ink = PageInkController(MemoryRevealStore())
      ..foreground = Colors.white;
    expect(ink.markColor(MarkColor.red), MarkColor.red.paint(Colors.white));
    ink.blackWhite = true;
    for (final colour in MarkColor.values) {
      expect(ink.markColor(colour), Colors.white);
    }
  });
}
