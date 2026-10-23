import 'memory_reveal_store.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> pages;
  setUpAll(() async => pages = await loadPages());

  test('complete bundle includes pages 1, 2, 187, 604', () {
    expect(
      pages.map((p) => p['page']),
      orderedEquals(List.generate(604, (i) => i + 1)),
    );
    expect(pages.map((p) => p['page']), containsAll([1, 2, 187, 604]));
  });

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
      for (final page in pages) {
        final number = page['page'] as int;
        controller.jumpToPage(
          size.width > size.height ? (number - 1) ~/ 2 : number - 1,
        );
        await tester.pumpAndSettle();
        final pageRect = tester.getRect(find.byKey(ValueKey('page-$number')));
        final area = Rect.fromLTRB(
          pageRect.left + (size.width > size.height ? 2 : size.width * .02),
          pageRect.top + 2,
          pageRect.right - (size.width > size.height ? 2 : size.width * .02),
          pageRect.bottom - 2,
        );

        // Paint the actual constrained RTL paragraphs into a larger, unclipped
        // surface. Selection/advance boxes alone miss paint outside the slot.
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const margin = 300.0;
        for (final line in page['lines'] as List) {
          final words = line['words'] as List;
          if (line['heading'] != null) {
            final target = find.byKey(
              ValueKey('heading-$number-${line['number']}'),
            );
            final rect = tester.getRect(target);
            final paint = tester.widget<CustomPaint>(
              find.descendant(of: target, matching: find.byType(CustomPaint)),
            );
            canvas.save();
            canvas.translate(
              margin + rect.left - area.left,
              margin + rect.top - area.top,
            );
            paint.painter!.paint(canvas, rect.size);
            canvas.restore();
          }
          for (final word in words) {
            final target = find.byKey(ValueKey('word-${word['id']}'));
            final text = tester.widget<Text>(
              find.descendant(of: target, matching: find.byType(Text)),
            );
            final rect = tester.getRect(
              find.descendant(of: target, matching: find.byType(Text)),
            );
            final painter = TextPainter(
              text: TextSpan(text: text.data, style: text.style),
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
            )..layout(minWidth: rect.width, maxWidth: rect.width);
            painter.paint(
              canvas,
              Offset(
                margin + rect.left - area.left,
                margin + rect.top - area.top,
              ),
            );
            painter.dispose();
          }
        }
        final picture = recorder.endRecording();
        var left = double.infinity;
        var right = double.negativeInfinity;
        var top = double.infinity;
        var bottom = double.negativeInfinity;
        await tester.runAsync(() async {
          final image = await picture.toImage(
            (area.width + 2 * margin).ceil(),
            (area.height + 2 * margin).ceil(),
          );
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (bytes[(y * image.width + x) * 4 + 3] > 100) {
                final dy = area.top + y - margin;
                if (dy < top) top = dy;
                if (dy + 1 > bottom) bottom = dy + 1;
                final dx = area.left + x - margin;
                if (dx < left) left = dx;
                if (dx + 1 > right) right = dx + 1;
              }
            }
          }
          image.dispose();
        });
        picture.dispose();
        if (left < area.left - 1 ||
            right > area.right + 1 ||
            top < area.top - 1 ||
            bottom > area.bottom + 1) {
          failures.add(
            'page $number ink: vertical $top..$bottom (area $area), left overflow ${(area.left - left).clamp(0, double.infinity).toStringAsFixed(2)} dp, right overflow ${(right - area.right).clamp(0, double.infinity).toStringAsFixed(2)} dp',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
