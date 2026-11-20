import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/loaded_page_controller.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/mushaf_bundle.dart';
import 'package:greymushaf/quran_index.dart';
import 'package:greymushaf/reveal_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

Future<void> hold(WidgetTester tester, String shot) async {
  debugPrint('SHOT_READY $shot');
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 6)));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search opens the ayah shaded and the place survives a reopen', (
    tester,
  ) async {
    final filename = path.join(await getDatabasesPath(), 'navigation-live.db');
    await deleteDatabase(filename);
    addTearDown(() => deleteDatabase(filename));
    var store = await SqliteRevealStore.open(databasePath: filename);
    final bundle = await MushafBundle.open();
    final index = await QuranIndex.load(rootBundle);
    final search = await SearchIndex.load(rootBundle);
    expect(search, isNotNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Reader(
          pages: bundle.pages,
          bundle: bundle,
          store: store,
          settings: store,
          toolbarSettings: store,
          navigation: store,
          index: index,
          loadSearch: () async => search,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(Reader));
    await tester.tapAt(Offset(3, size.height / 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('search-field')),
      'أيها الذين',
    );
    await tester.pumpAndSettle();
    await hold(tester, 'suggestions');
    await tester.tap(find.byKey(const ValueKey('search-full')));
    await tester.pumpAndSettle();
    await hold(tester, 'results');
    await tester.tap(find.byKey(const ValueKey('search-ayah-2:178')));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller;
    if (controller is LoadedPageController) {
      await tester.runAsync(() => controller.pending);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-27')), findsOneWidget);
    final shade =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('ayah-shade-27')),
                )
                .painter!
            as AyahShadePainter;
    expect(shade.runs(), hasLength(greaterThanOrEqualTo(4)));
    await hold(tester, 'shade');
    await tester.tapAt(Offset(3, size.height / 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmark page'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpWidget(const SizedBox());
    await store.close();

    store = await SqliteRevealStore.open(databasePath: filename);
    expect(store.lastPage, 27);
    expect(store.bookmarkSavedAt.keys, [27]);
    await store.close();
  });
}
