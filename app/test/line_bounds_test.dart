import 'memory_reveal_store.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());

  for (final size in [
    const Size(1080 / 2.625, 2274 / 2.625),
    const Size(800, 1224),
    const Size(914.3, 363.4),
    const Size(1280, 744),
  ]) {
    testWidgets('all line ink fits the page at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Reader(store: MemoryRevealStore(), pages: pages),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      final failures = <String>[];
      for (final number in [1, 2, 47, 48, 50]) {
        controller.jumpToPage(
          size.width > size.height
              ? (number <= 2
                    ? 0
                    : number == 50
                    ? 2
                    : 1)
              : pages.indexWhere((p) => p['page'] == number),
        );
        await tester.pumpAndSettle();
        final page = pages.singleWhere((p) => p['page'] == number);
        final area = tester
            .getRect(find.byKey(ValueKey('page-$number')))
            .deflate(2);
        for (final line in page['lines'] as List) {
          final words = line['words'] as List;
          if (words.isEmpty) continue;
          // Paint the actual constrained RTL paragraphs into a larger, unclipped
          // surface. Selection/advance boxes alone miss paint outside the slot.
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          const margin = 300.0;
          for (final word in words) {
            final target = find.byKey(ValueKey('word-${word['id']}'));
            final text = tester.widget<Text>(
              find.descendant(of: target, matching: find.byType(Text)),
            );
            final rect = tester.getRect(target);
            final painter = TextPainter(
              text: TextSpan(text: text.data, style: text.style),
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
            )..layout(minWidth: rect.width, maxWidth: rect.width);
            painter.paint(canvas, Offset(margin + rect.left - area.left, 100));
            painter.dispose();
          }
          final picture = recorder.endRecording();
          var left = double.infinity;
          var right = double.negativeInfinity;
          await tester.runAsync(() async {
            final image = await picture.toImage(
              (area.width + 2 * margin).ceil(),
              400,
            );
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                if (bytes[(y * image.width + x) * 4 + 3] > 100) {
                  final dx = area.left + x - margin;
                  if (dx < left) left = dx;
                  if (dx + 1 > right) right = dx + 1;
                }
              }
            }
            image.dispose();
          });
          picture.dispose();
          if (left < area.left - 1 || right > area.right + 1) {
            failures.add(
              'page $number line ${line['number']}: left overflow ${(area.left - left).clamp(0, double.infinity).toStringAsFixed(2)} dp, right overflow ${(right - area.right).clamp(0, double.infinity).toStringAsFixed(2)} dp',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
