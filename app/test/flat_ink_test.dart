import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/flat_ink.dart';

void main() {
  testWidgets(
    'flat ink removes tajweed hues but preserves pale marker backgrounds and transparency',
    (tester) async {
      // The default CPAL palette shared by the four supplied V4 page fonts.
      const palette = [
        0xFF000000,
        0xFFA5A5A5,
        0xFFA3A5A5,
        0xFFB50000,
        0xFFFF7B00,
        0xFFCE9E00,
        0xFF09B000,
        0xFF3F48E6,
        0xFF2FADFF,
        0xFFF40000,
        0xFF2CA4AB,
        0xFFFF0080,
        0xFFD8E9D8,
        0xFF000000,
        0xFF040000,
        0xFF9FA5A5,
      ];
      final boundaryKey = GlobalKey();
      for (final pair in [
        (const Color(0xFFB0B0B0), const Color(0xFFFFFFFF)),
        (const Color(0xFF000000), const Color(0xFFFFFFFF)),
        (const Color(0xFFFFFFFF), const Color(0xFF000000)),
        (const Color(0xFF202020), const Color(0xFF000000)),
        (const Color(0xFF808080), const Color(0xFF000000)),
      ]) {
        final target = pair.$1;
        final background = pair.$2;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: FlatInk(
                  color: target,
                  background: background,
                  child: SizedBox(
                    width: 340,
                    height: 20,
                    child: Row(
                      children: [
                        for (final color in palette)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: ColoredBox(color: Color(color)),
                          ),
                        const SizedBox(width: 20, height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          for (var i = 0; i < palette.length; i++) {
            final offset = (10 * 340 + i * 20 + 10) * 4;
            final expected = i == 12
                ? (background.toARGB32() & 255)
                : (target.toARGB32() & 255);
            expect(
              bytes.getUint8(offset),
              expected,
              reason: 'palette entry $i red',
            );
            expect(
              bytes.getUint8(offset + 1),
              expected,
              reason: 'palette entry $i green',
            );
            expect(
              bytes.getUint8(offset + 2),
              expected,
              reason: 'palette entry $i blue',
            );
            expect(bytes.getUint8(offset + 3), 255);
          }
          expect(
            bytes.getUint8((10 * 340 + 330) * 4 + 3),
            0,
            reason: 'outside glyph stays transparent',
          );
          image.dispose();
        });
      }
    },
  );
}
