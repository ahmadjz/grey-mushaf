import 'dart:math' as math;

import 'package:flutter/material.dart';

TextStyle wordStyle(int page, double size) => TextStyle(
  fontFamily: 'mushaf-$page',
  fontSize: size,
  height: 1,
  color: Colors.black,
);

({double width, double left, double right}) measureWord(
  Map<String, dynamic> word,
  Map<String, dynamic> page,
) {
  const reference = 100.0;
  final text = word['text'] as String;
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: wordStyle(page['page'] as int, reference),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  final units = (page['font']['unitsPerEm'] as num).toDouble();
  final ink = word['ink'] as List;
  var left = double.infinity;
  var right = double.negativeInfinity;
  var offset = 0;
  var index = 0;
  for (final rune in text.runes) {
    final end = offset + String.fromCharCode(rune).length;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: end),
    );
    // Some QUL words include an intentionally empty glyph (e.g. page 249).
    for (final box in ink[index] == null ? <TextBox>[] : boxes) {
      left = math.min(
        left,
        box.left / reference + (ink[index][0] as num) / units,
      );
      right = math.max(
        right,
        box.left / reference + (ink[index][1] as num) / units,
      );
    }
    offset = end;
    index++;
  }
  final width = painter.width / reference;
  painter.dispose();
  if (!left.isFinite || !right.isFinite) {
    throw StateError('Missing shaped ink bounds for ${word['location']}');
  }
  return (width: width, left: left, right: right);
}

double inkHeight(Map<String, dynamic> page) {
  final font = page['font'] as Map<String, dynamic>;
  return ((font['yMax'] as num) - (font['yMin'] as num)) /
      (font['unitsPerEm'] as num);
}

/// Global layout constraints measured with Flutter's actual shaping engine.
class BundleMetrics {
  const BundleMetrics(this.widest, this.edgeInk, this.tallest);
  final double widest;
  final double edgeInk;
  final double tallest;

  factory BundleMetrics.fromJson(Map<String, dynamic> json) => BundleMetrics(
    (json['widest'] as num).toDouble(),
    (json['edgeInk'] as num).toDouble(),
    (json['tallest'] as num).toDouble(),
  );
  Map<String, double> toJson() => {
    'widest': widest,
    'edgeInk': edgeInk,
    'tallest': tallest,
  };

  static BundleMetrics measure(List<Map<String, dynamic>> pages) {
    var widest = 1.0;
    var edgeInk = 0.0;
    var tallest = 1.0;
    for (final page in pages) {
      tallest = math.max(tallest, inkHeight(page));
      for (final line in page['lines'] as List) {
        final words = line['words'] as List;
        if (words.isEmpty) continue;
        final metrics = [
          for (final word in words)
            measureWord(word as Map<String, dynamic>, page),
        ];
        final width = metrics.fold<double>(
          (words.length - 1) * .09,
          (sum, m) => sum + m.width,
        );
        widest = math.max(widest, width);
        if (line['centered'] != true) {
          edgeInk = math.max(
            edgeInk,
            (metrics.first.right - metrics.first.width - metrics.last.left) / 2,
          );
        }
      }
    }
    return BundleMetrics(widest, edgeInk, tallest);
  }
}
