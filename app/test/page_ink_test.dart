import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/page_ink.dart';

import 'memory_reveal_store.dart';
import 'word_target.dart';

void main() {
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
      await tester.pumpWidget(const SizedBox());
      model.dispose();
    },
  );
}
