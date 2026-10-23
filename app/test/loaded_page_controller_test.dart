import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/loaded_page_controller.dart';

void main() {
  testWidgets('far jump holds the rendered page until destination is ready', (
    tester,
  ) async {
    final ready = Completer<void>();
    final controller = LoadedPageController(prepare: (_) => ready.future);
    await tester.pumpWidget(
      MaterialApp(
        home: PageView.builder(
          controller: controller,
          itemCount: 604,
          itemBuilder: (_, index) => Text('page ${index + 1}'),
        ),
      ),
    );
    controller.jumpToPage(186);
    await tester.pump();
    expect(controller.page, 0);
    expect(find.text('page 1'), findsOneWidget);
    ready.complete();
    await controller.pending;
    await tester.pump();
    expect(controller.page, 186);
    expect(find.text('page 187'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('fast swipes cannot expose unloaded pages', (tester) async {
    final controller = PageController(initialPage: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: PageView.builder(
          controller: controller,
          physics: LoadedPagePhysics(first: () => 1, last: () => 3),
          itemCount: 604,
          itemBuilder: (_, index) => Text('page ${index + 1}'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.fling(find.byType(PageView), const Offset(-1000, 0), 5000);
      await tester.pumpAndSettle();
      expect(controller.page, lessThanOrEqualTo(3));
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('a manual page turn cancels a pending far jump', (tester) async {
    final ready = Completer<void>();
    final controller = LoadedPageController(prepare: (_) => ready.future);
    await tester.pumpWidget(
      MaterialApp(
        home: PageView.builder(
          controller: controller,
          itemCount: 604,
          onPageChanged: (_) => controller.cancelPendingNavigation(),
          itemBuilder: (_, index) => Text('page ${index + 1}'),
        ),
      ),
    );
    controller.jumpToPage(299);
    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    ready.complete();
    await controller.pending;
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    expect(find.text('page 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
