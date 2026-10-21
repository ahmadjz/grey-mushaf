import 'package:flutter/material.dart';

/// Cached, size-independent heading artwork. Coordinates are ink bounds,
/// not font advance boxes: overhangs and accents stay centred and unclipped.
class HeadingInk extends CustomPainter {
  HeadingInk(Map<String, dynamic> heading, {required bool opening}) {
    final kind = heading['kind'];
    if (kind == 'wide') {
      final drawing = heading['drawing'] as Map<String, dynamic>;
      final b = (drawing['bounds'] as List).cast<num>();
      bounds = Rect.fromLTRB(
        b[0].toDouble(),
        b[1].toDouble(),
        b[2].toDouble(),
        b[3].toDouble(),
      );
      path = Path()
        ..fillType = drawing['fillRule'] == 'evenodd'
            ? PathFillType.evenOdd
            : PathFillType.nonZero;
      for (final command in drawing['commands'] as List) {
        final c = command as List;
        double v(int i) => (c[i] as num).toDouble();
        switch (c[0]) {
          case 'M':
            path!.moveTo(v(1), v(2));
          case 'L':
            path!.lineTo(v(1), v(2));
          case 'C':
            path!.cubicTo(v(1), v(2), v(3), v(4), v(5), v(6));
          case 'Z':
            path!.close();
        }
      }
    } else if (kind == 'compact') {
      final text = _text(
        (heading['parts'] as List).join(),
        'mushaf-1',
        rtl: true,
      );
      // U+FC41..44, no ayah marker, no added spaces or cross-word kerning.
      // Union of COLR glyph bounds at 100 px, in the shaped RTL order.
      bounds = const Rect.fromLTRB(19.48, -109.08, 659.04, 40.16);
      runs.add((text, Offset(0, -text.computeLineMetrics().first.baseline)));
    } else {
      final parts = (heading['parts'] as List).cast<String>();
      final boxes = (heading['bounds'] as List)
          .map((b) => (b as List).cast<num>())
          .toList();
      // Each token uses its actual contour bounds, not IcoMoon's padded
      // one-em boxes. Align lower ink edges and retain natural name widths.
      double addRun(int part, double left, double inkHeight) {
        final b = boxes[part];
        final scale = inkHeight / (b[3] - b[1]);
        final text = _text(parts[part], 'surah-name-v4', size: scale * 1024);
        runs.add((
          text,
          Offset(
            left - b[0] * scale,
            100 -
                inkHeight +
                b[3] * scale -
                text.computeLineMetrics().first.baseline,
          ),
        ));
        return (b[2] - b[0]) * scale;
      }

      final nameWidth = addRun(1, 0, 100);
      final iconWidth = addRun(0, nameWidth + 3, opening ? 95 : 80);
      bounds = Rect.fromLTWH(0, 0, nameWidth + 3 + iconWidth, 100);
    }
  }

  late final Rect bounds;
  Path? path;
  final runs = <(TextPainter, Offset)>[];

  TextPainter _text(
    String text,
    String family, {
    double size = 100,
    bool rtl = false,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1,
        color: Colors.black,
        fontFeatures: const [FontFeature.disable('kern')],
      ),
    ),
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / bounds.width, size.height / bounds.height);
    canvas.translate(-bounds.left, -bounds.top);
    if (path != null) canvas.drawPath(path!, Paint()..color = Colors.black);
    for (final run in runs) {
      run.$1.paint(canvas, run.$2);
    }
    canvas.restore();
  }

  void dispose() {
    for (final run in runs) {
      run.$1.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant HeadingInk oldDelegate) => oldDelegate != this;
}
