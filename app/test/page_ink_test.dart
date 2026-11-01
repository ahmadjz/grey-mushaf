import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/page_ink.dart';

import 'memory_reveal_store.dart';
import 'word_target.dart';

void main() {
  testWidgets('incoming image stays pixel snapped after fractional scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final models = [
      PageInkController(MemoryRevealStore()),
      PageInkController(MemoryRevealStore()),
    ];
    final controller = PageController();
    await tester.pumpWidget(
      MaterialApp(
        home: PageView.builder(
          controller: controller,
          itemCount: 2,
          itemBuilder: (_, index) => PaintedInkPage(
            controller: models[index],
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(700, 300));
    await gesture.moveBy(const Offset(-520.25, 0));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 5 && !models[1].hasCachedImage; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }
    expect(models[1].hasCachedImage, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, 1);
    final origin = models[1].cachedImagePhysicalOrigin!;
    expect(origin.dx, origin.dx.roundToDouble());
    expect(origin.dy, origin.dy.roundToDouble());
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    for (final model in models) {
      model.dispose();
    }
  });

  testWidgets('simultaneously painted pages both receive an image', (
    tester,
  ) async {
    final models = [
      PageInkController(MemoryRevealStore()),
      PageInkController(MemoryRevealStore()),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (final model in models)
              SizedBox(
                width: 200,
                height: 40,
                child: PaintedInkPage(
                  controller: model,
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    for (final model in models) {
      expect(model.hasCachedImage, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
    for (final model in models) {
      model.dispose();
    }
  });

  testWidgets(
    'page painter owns word geometry and semantics without word widgets',
    (tester) async {
      final model = PageInkController(MemoryRevealStore());
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 40,
              child: PaintedInkPage(
                controller: model,
                child: PaintedWordLine(
                  controller: model,
                  words: const [
                    {'id': 1, 'location': '1:1:1', 'text': 'one'},
                  ],
                  metrics: const {1: (width: 3.0, left: .2, right: 2.8)},
                  fontSize: 10,
                  height: 40,
                  inkHeight: 20,
                  baseline: 25,
                  centered: true,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Text), findsNothing);
      expect(model.words.single.id, 1);
      expect(model.words.single.box, const Rect.fromLTWH(85, 0, 30, 40));
      final semantic = testSemantics(tester, const WordTarget(1));
      expect(semantic.identifier, 'word-1');
      expect(semantic.label, '1:1:1; unrevealed; reveals 0');
      expect(
        model
            .hitAt(
              model.globalRect(model.words.single.box).center,
              shortTap: true,
            )
            ?.id,
        1,
      );
      expect(
        model.hitAt(
          model.globalRect(model.words.single.box).topLeft,
          shortTap: true,
        ),
        isNull,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(model.hasCachedImage, isTrue);
      model.changed();
      expect(model.hasCachedImage, isFalse);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
}
