import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/flat_ink.dart';
import 'package:greymushaf/grouped_ink.dart';

void main() {
  test('hybrid excludes overhangs, near edges and both overlap partners', () {
    final boxes = [
      const Rect.fromLTWH(0, 0, 20, 20),
      const Rect.fromLTWH(30, 0, 20, 20),
      const Rect.fromLTWH(60, 0, 20, 20),
      const Rect.fromLTWH(90, 0, 20, 20),
      const Rect.fromLTWH(100, 0, 20, 20),
    ];
    final ink = [
      const Rect.fromLTWH(3, 3, 14, 14),
      const Rect.fromLTWH(29, 3, 14, 14),
      const Rect.fromLTWH(61, 3, 14, 14),
      const Rect.fromLTWH(93, 3, 14, 14),
      const Rect.fromLTWH(103, 3, 14, 14),
    ];
    expect(groupableInk(boxes, ink, 2), [true, false, false, false, false]);
  });

  testWidgets(
    'grouping preserves nonoverlapping paint and translated positions',
    (tester) async {
      final key = GlobalKey();
      Future<List<int>> render(bool grouped, Color background) async {
        final words = <Widget>[
          for (var i = 0; i < 4; i++)
            Positioned(
              left: i * 20.0 + 2.25,
              top: 3.5,
              child: grouped
                  ? GroupedInkWord(
                      ink: const Rect.fromLTWH(2, 2, 8, 10),
                      color: i.isEven
                          ? const Color(0xFFB0B0B0)
                          : const Color(0xFF000000),
                      background: background,
                      child: const SizedBox(
                        width: 12,
                        height: 14,
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: ColoredBox(color: Color(0xFFFF0080)),
                        ),
                      ),
                    )
                  : FlatInk(
                      color: i.isEven
                          ? const Color(0xFFB0B0B0)
                          : const Color(0xFF000000),
                      background: background,
                      child: const SizedBox(
                        width: 12,
                        height: 14,
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: ColoredBox(color: Color(0xFFFF0080)),
                        ),
                      ),
                    ),
            ),
        ];
        Widget content = SizedBox(
          width: 100,
          height: 50,
          child: Stack(children: words),
        );
        if (grouped) content = GroupedInkPage(child: content);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(key: key, child: content),
            ),
          ),
        );
        await tester.pump();
        return (await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          image.dispose();
          return bytes;
        }))!;
      }

      for (final background in [
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
      ]) {
        final reference = await render(false, background);
        final grouped = await render(true, background);
        expect(grouped, orderedEquals(reference));
      }
    },
  );
}
