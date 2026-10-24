// Run: HYBRID_REPORT=/absolute/report.json flutter test tool/hybrid_report.dart
// Uses only prepared metrics; does not load, rasterize or modify source fonts.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/bundle_metrics.dart';
import 'package:greymushaf/grouped_ink.dart';

void main() {
  test('report conservative hybrid fractions over all prepared pages', () {
    final metrics = jsonDecode(
      File('assets/mushaf/metrics.json').readAsStringSync(),
    );
    final widest = (metrics['widest'] as num).toDouble();
    final edge = (metrics['edgeInk'] as num).toDouble();
    final tallest = (metrics['tallest'] as num).toDouble();
    const dpr = 2.625;
    final output = <String, Object>{
      'device': 'Medium_Phone 1080x2400, DPR 2.625, fullscreen; two physical pixel margin',
    };
    for (final spread in [false, true]) {
      final width = (spread ? 2400 : 1080) / dpr;
      final height = (spread ? 1080 : 2400) / dpr - 4;
      final contentWidth =
          width / (spread ? 2 : 1) - (spread ? 4 : width * .04);
      final size = math.min(
        contentWidth / (widest + 2 * edge),
        (height - 14) / 15 / tallest,
      );
      final textWidth = size * widest;
      final counts = <String, Object>{};
      var total = 0, fallback = 0;
      for (var number = 1; number <= 604; number++) {
        final page = jsonDecode(
          File('assets/mushaf/$number.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final inkH = inkHeight(page) * size;
        final spare = (height / 15 - inkH) / 2;
        final strip = number <= 2 ? 0.0 : math.max(0.0, (14 - spare) * 30 / 29);
        final slot = number <= 2 ? textWidth * 47 / 543 : (height - strip) / 15;
        final boxes = <Rect>[], ink = <Rect>[];
        var row = 0;
        for (final line in page['lines'] as List) {
          final words = line['words'] as List;
          final top = number <= 2
              ? textWidth * (278.5 + ((line['number'] as int) - 2) * 47) / 543
              : row * slot;
          row++;
          if (words.isEmpty) continue;
          final widths = [
            for (final word in words) (word['metrics'][0] as num) * size,
          ];
          final used = widths.fold<double>(0, (a, b) => a + b);
          final centered = line['centered'] == true;
          final gap = centered
              ? size * .09
              : words.length == 1
              ? 0.0
              : math.max(0.0, (textWidth - used) / (words.length - 1));
          var right = centered
              ? (textWidth + used + gap * (words.length - 1)) / 2
              : textWidth;
          if (!centered) {
            final spareX = math.max(0.0, (contentWidth - textWidth) / 2);
            final first = words.first['metrics'] as List;
            final last = words.last['metrics'] as List;
            final overRight = ((first[2] as num) - (first[0] as num)) * size;
            final overLeft = (last[1] as num) * size;
            right += overRight > spareX
                ? spareX - overRight
                : overLeft < -spareX
                ? -spareX - overLeft
                : 0;
          }
          for (var i = 0; i < words.length; i++) {
            final left = right - widths[i];
            final m = words[i]['metrics'] as List;
            boxes.add(Rect.fromLTWH(left, top, widths[i], slot));
            ink.add(
              Rect.fromLTRB(
                left + (m[1] as num) * size,
                top + (slot - inkH) / 2,
                left + (m[2] as num) * size,
                top + (slot + inkH) / 2,
              ),
            );
            right = left - gap;
          }
        }
        final safe = groupableInk(boxes, ink, 2 / dpr);
        final retained = safe.where((v) => !v).length;
        counts['$number'] = {
          'words': safe.length,
          'perWord': retained,
          'fraction': retained / safe.length,
        };
        total += safe.length;
        fallback += retained;
      }
      output[spread ? 'landscape' : 'portrait'] = {
        'fontSize': size,
        'words': total,
        'perWord': fallback,
        'fraction': fallback / total,
        'pages': counts,
      };
    }
    final capturePath = Platform.environment['PARITY_GEOMETRY'];
    if (capturePath != null) {
      final capture = jsonDecode(File(capturePath).readAsStringSync());
      final parity = <String, Object>{};
      for (final entry in (capture['geometry'] as Map).entries) {
        final rects = entry.value['rects'] as List;
        Rect rect(List values) => Rect.fromLTRB(
          (values[0] as num).toDouble(),
          (values[1] as num).toDouble(),
          (values[2] as num).toDouble(),
          (values[3] as num).toDouble(),
        );
        final safe = groupableInk(
          [for (final r in rects) rect(r['advanceRect'] as List)],
          [for (final r in rects) rect(r['rect'] as List)],
          2 / dpr,
        );
        final retained = safe.where((v) => !v).length;
        parity['${entry.key}'] = {
          'words': safe.length,
          'perWord': retained,
          'fraction': retained / safe.length,
        };
        final mode =
            output[entry.key == '49' ? 'landscape' : 'portrait'] as Map;
        final pages = mode['pages'] as Map;
        final expected =
            (pages[entry.key]['perWord'] as int) +
            (entry.key == '49' ? pages['50']['perWord'] as int : 0);
        expect(
          retained,
          expected,
          reason: 'Prepared layout vs captured geometry ${entry.key}',
        );
      }
      output['capturedParity'] = parity;
    }
    File(Platform.environment['HYBRID_REPORT']!)
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  });
}
