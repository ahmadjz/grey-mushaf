import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/bookmarks.dart';
import 'package:greymushaf/loaded_page_controller.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/quran_index.dart';

import 'memory_reveal_store.dart';
import 'word_target.dart';

class PausedAssets extends CachingAssetBundle {
  final pauses = <String, Completer<void>>{};
  @override
  Future<ByteData> load(String key) async {
    await pauses[key.split('/').last]?.future;
    return rootBundle.load(key);
  }
}

class MemoryNavigation implements NavigationStore {
  MemoryNavigation({this.lastPage = 1});
  @override
  int lastPage;
  final saved = <int, int>{};
  final attempts = <List<String>>[];
  final lastPages = <int>[];
  bool fail = false;

  @override
  Future<void> saveLastPage(int page) async {
    lastPages.add(page);
    lastPage = page;
  }

  @override
  Map<int, int> get bookmarkSavedAt => Map.unmodifiable(saved);

  @override
  Future<void> saveBookmarks(List<BookmarkAction> actions) async {
    attempts.add([for (final a in actions) a.uuid]);
    if (fail) throw StateError('injected');
    for (final action in actions) {
      if (action.saved) {
        saved[action.page] = action.createdAt;
      } else {
        saved.remove(action.page);
      }
    }
  }
}

void main() {
  late MushafBundle bundle;
  late QuranIndex index;
  late SearchIndex search;

  setUpAll(() async {
    index = await QuranIndex.load(rootBundle);
    search = (await SearchIndex.load(rootBundle))!;
  });

  void screen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<MemoryNavigation> open(
    WidgetTester tester, {
    MemoryNavigation? navigation,
    Size size = const Size(411, 914),
    AssetBundle? assets,
  }) async {
    screen(tester, size);
    final store = navigation ?? MemoryNavigation();
    bundle = (await tester.runAsync(
      () => MushafBundle.open(assets: assets, near: store.lastPage),
    ))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: bundle.pages,
          bundle: bundle,
          store: MemoryRevealStore(),
          navigation: store,
          index: index,
          loadSearch: () async => search,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> settleJump(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller;
    if (controller is LoadedPageController) {
      await tester.runAsync(() => controller.pending);
    }
    await tester.pumpAndSettle();
  }

  Future<void> showBars(WidgetTester tester) async {
    if (find.byKey(const ValueKey('top-bar')).evaluate().isNotEmpty) return;
    await tester.tapAt(Offset(3, tester.view.physicalSize.height / 2));
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String label) async {
    await showBars(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  bool shown(int page) =>
      find.byKey(ValueKey('page-$page')).evaluate().isNotEmpty;

  List<Rect> shade(WidgetTester tester, int page) =>
      (tester
                  .widget<CustomPaint>(find.byKey(ValueKey('ayah-shade-$page')))
                  .painter!
              as AyahShadePainter)
          .runs();

  testWidgets('R63: the reader opens on the page last read and remembers it', (
    tester,
  ) async {
    final store = await open(
      tester,
      navigation: MemoryNavigation(lastPage: 216),
    );
    expect(shown(216), isTrue);
    await tester.fling(find.byType(PageView), const Offset(400, 0), 2000);
    await settleJump(tester);
    expect(shown(217), isTrue);
    expect(store.lastPages.last, 217);
  });

  testWidgets('R27/R66: the surah list marks each juz and opens a surah', (
    tester,
  ) async {
    await open(tester);
    await showBars(tester);
    await tester.tap(find.byTooltip('Surah list'));
    await tester.pumpAndSettle();
    expect(find.text('سورة الفاتحة'), findsOneWidget);
    expect(find.text('مكية - ٧ آيات'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('surah-8')),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    final arafTop = tester.getRect(find.byKey(const ValueKey('surah-7'))).top;
    final juzTop = tester.getRect(find.byKey(const ValueKey('juz-9'))).top;
    final anfalTop = tester.getRect(find.byKey(const ValueKey('surah-8'))).top;
    expect(arafTop < juzTop && juzTop < anfalTop, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('juz-9')),
        matching: find.text('١٦٢'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('surah-8')));
    await settleJump(tester);
    expect(find.byType(Reader), findsOneWidget);
    expect(shown(177), isTrue);
  });

  testWidgets(
    'R53/R64: the bookmark icon saves the page and the tab lists it',
    (tester) async {
      final store = await open(
        tester,
        navigation: MemoryNavigation(lastPage: 50),
      );
      await showBars(tester);
      await tester.tap(find.byTooltip('Bookmark page'));
      await tester.pumpAndSettle();
      expect(store.saved.keys, [50]);
      expect(find.byTooltip('Remove bookmark'), findsOneWidget);
      await tester.tap(find.byTooltip('Surah list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العلامات'));
      await tester.pumpAndSettle();
      expect(find.text('صفحة ٥٠'), findsOneWidget);
      expect(find.text('سورة آل عمران، جزء ٣'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);
      expect(find.text('لا توجد علامات'), findsOneWidget);
    },
  );

  testWidgets(
    'R24/R53: a failed bookmark keeps the icon and Retry resends it',
    (tester) async {
      final store =
          await open(tester, navigation: MemoryNavigation(lastPage: 50))
            ..fail = true;
      await showBars(tester);
      await tester.tap(find.byTooltip('Bookmark page'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Bookmark page'), findsOneWidget);
      expect(find.text("Couldn't save bookmark"), findsOneWidget);
      store.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(store.saved.keys, [50]);
      expect(store.attempts, hasLength(2));
      expect(store.attempts[1], store.attempts[0]);
      expect(find.byTooltip('Remove bookmark'), findsOneWidget);
    },
  );

  testWidgets(
    'R66: a spread saves its right-hand page and removes both pages',
    (tester) async {
      final store = await open(
        tester,
        navigation: MemoryNavigation(lastPage: 21),
        size: const Size(914, 411),
      );
      await showBars(tester);
      await tester.tap(find.byTooltip('Bookmark page'));
      await tester.pumpAndSettle();
      expect(store.saved.keys, [21]);
      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);

      final both = MemoryNavigation(lastPage: 22)..saved.addAll({21: 1, 22: 2});
      await tester.pumpWidget(const SizedBox());
      await open(tester, navigation: both, size: const Size(914, 411));
      await showBars(tester);
      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.pumpAndSettle();
      expect(both.saved, isEmpty);
      expect(both.attempts.single, hasLength(2));
    },
  );

  testWidgets('R54: quick jump goes to a page or to a surah and ayah', (
    tester,
  ) async {
    await open(tester);
    await menu(tester, 'Quick jump');
    await tester.enterText(find.byKey(const ValueKey('jump-page')), '٣٠٠');
    await tester.tap(find.byKey(const ValueKey('jump-go')));
    await settleJump(tester);
    expect(shown(300), isTrue);

    await menu(tester, 'Quick jump');
    await tester.enterText(find.byKey(const ValueKey('jump-page')), '700');
    await tester.tap(find.byKey(const ValueKey('jump-go')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('jump-error')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('jump-page')), '22');
    await tester.tap(find.byKey(const ValueKey('jump-go')));
    await settleJump(tester);
    await menu(tester, 'Quick jump');
    expect(find.text('٢. البقرة'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('jump-ayah')), '255');
    await tester.tap(find.byKey(const ValueKey('jump-go')));
    await settleJump(tester);
    final page = index.pageOf(2, 255)!;
    expect(shown(page), isTrue);
    expect(shade(tester, page), isNotEmpty);
  });

  testWidgets('R55/R65: search suggests five ayahs, then lists every result', (
    tester,
  ) async {
    await open(tester);
    await menu(tester, 'Search');
    await tester.enterText(
      find.byKey(const ValueKey('search-field')),
      'أيها الذين',
    );
    await tester.pumpAndSettle();
    final all = search.find('أيها الذين');
    expect(all.length, greaterThan(5));
    expect(find.byKey(const ValueKey('search-ayah-2:104')), findsOneWidget);
    expect(find.text('سورة (٢) البقرة: ١٠٤ (صفحة ١٦)'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-full')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('search-ayah-'),
      ),
      findsNWidgets(5),
    );
    await tester.tap(find.byKey(const ValueKey('search-full')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        '${all.length}'.replaceAllMapped(
          RegExp(r'\d'),
          (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('search-ayah-2:104')));
    await settleJump(tester);
    expect(shown(16), isTrue);
    final runs = shade(tester, 16);
    expect(runs, isNotEmpty);
    await tester.tapAt(const Offset(3, 450));
    await tester.pumpAndSettle();
    expect(shade(tester, 16), isEmpty);
  });

  testWidgets('R55/R66: search finds a page, a juz and a surah name', (
    tester,
  ) async {
    await open(tester);
    await menu(tester, 'Search');
    await tester.enterText(find.byKey(const ValueKey('search-field')), '٣٠');
    await tester.pumpAndSettle();
    expect(find.text('صفحة ٣٠'), findsOneWidget);
    expect(find.text('الجزء ٣٠'), findsOneWidget);
    await tester.tap(find.text('الجزء ٣٠'));
    await settleJump(tester);
    expect(shown(index.juzPage(30)), isTrue);

    await menu(tester, 'Search');
    await tester.enterText(
      find.byKey(const ValueKey('search-field')),
      'البقره',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-surah-2')));
    await settleJump(tester);
    expect(shown(2), isTrue);
  });

  int wordId(int page, String prefix) =>
      ((bundle.pages[page - 1]['lines'] as List)
                  .expand((line) => line['words'] as List)
                  .firstWhere(
                    (w) => (w['location'] as String).startsWith(prefix),
                  )
              as Map)['id']
          as int;

  testWidgets('R65: the shade sits behind the words, which keep their grey', (
    tester,
  ) async {
    await open(tester, navigation: MemoryNavigation(lastPage: 16));
    final target = WordTarget(wordId(16, '2:104:'));
    expect(await wordColor(tester, target), const Color(0xFFB0B0B0));
    await menu(tester, 'Search');
    await tester.enterText(find.byKey(const ValueKey('search-field')), 'راعنا');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-ayah-2:104')));
    await settleJump(tester);
    expect(shade(tester, 16), isNotEmpty);
    expect(await wordColor(tester, target), const Color(0xFFB0B0B0));
    final runs = shade(tester, 16)..sort((a, b) => a.top.compareTo(b.top));
    for (var i = 1; i < runs.length; i++) {
      expect(runs[i].top, greaterThanOrEqualTo(runs[i - 1].bottom));
    }
  });

  testWidgets(
    'R54: a jump to the shown page cancels a far jump still loading',
    (tester) async {
      final assets = PausedAssets()..pauses['p300.ttf'] = Completer<void>();
      await open(tester, assets: assets);
      await menu(tester, 'Quick jump');
      await tester.enterText(find.byKey(const ValueKey('jump-page')), '300');
      await tester.tap(find.byKey(const ValueKey('jump-go')));
      await tester.pumpAndSettle();
      await menu(tester, 'Quick jump');
      await tester.enterText(find.byKey(const ValueKey('jump-page')), '1');
      await tester.tap(find.byKey(const ValueKey('jump-go')));
      await tester.pumpAndSettle();
      assets.pauses.remove('p300.ttf')!.complete();
      await settleJump(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(shown(1), isTrue);
      expect(shown(300), isFalse);
    },
  );

  testWidgets('R63: an even page reached in a spread stays after rotating', (
    tester,
  ) async {
    final store = await open(tester, size: const Size(914, 411));
    await menu(tester, 'Quick jump');
    await tester.enterText(find.byKey(const ValueKey('jump-page')), '22');
    await tester.tap(find.byKey(const ValueKey('jump-go')));
    await settleJump(tester);
    expect(shown(21) && shown(22), isTrue);
    expect(store.lastPage, 22);
    tester.view.physicalSize = const Size(411, 914);
    await settleJump(tester);
    expect(shown(22), isTrue);
    expect(shown(21), isFalse);
  });

  testWidgets('R64/R66: bookmarks list newest first and open their page', (
    tester,
  ) async {
    final store = MemoryNavigation()..saved.addAll({100: 1, 300: 3, 200: 2});
    await open(tester, navigation: store);
    await showBars(tester);
    await tester.tap(find.byTooltip('Surah list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العلامات'));
    await tester.pumpAndSettle();
    final tops = [
      for (final page in [300, 200, 100])
        tester.getRect(find.byKey(ValueKey('bookmark-$page'))).top,
    ];
    expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue);
    store.fail = true;
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('bookmark-200')),
        matching: find.byTooltip('Remove bookmark'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save bookmark"), findsOneWidget);
    final remove = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('bookmark-200')),
        matching: find.byType(IconButton),
      ),
    );
    expect(remove.onPressed, isNotNull);
    store.fail = false;
    await tester.tap(find.byKey(const ValueKey('bookmark-200')));
    await settleJump(tester);
    expect(find.byType(Reader), findsOneWidget);
    expect(shown(200), isTrue);
    expect(find.text("Couldn't save bookmark"), findsNothing);
  });

  testWidgets('R27: a juz row opens its first page', (tester) async {
    await open(tester);
    await showBars(tester);
    await tester.tap(find.byTooltip('Surah list'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('juz-2')),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('juz-2')));
    await settleJump(tester);
    expect(shown(index.juzPage(2)), isTrue);
  });

  testWidgets('R38: quick jump is dark in dark mode', (tester) async {
    await open(tester);
    await menu(tester, 'Dark mode');
    await menu(tester, 'Quick jump');
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('jump-page'))))
          .brightness,
      Brightness.dark,
    );
  });
}
