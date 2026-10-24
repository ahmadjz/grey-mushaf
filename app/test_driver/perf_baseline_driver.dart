import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final dir = Directory(
      Platform.environment['PERF_OUT'] ??
          '../docs/runs/2026-10-24-perf-after/stage0',
    )..createSync(recursive: true);
    File('${dir.path}/frames.json').writeAsStringSync(jsonEncode(data));
    final events = <Object>[];
    final samples = data!['frame_samples_ms'] as Map<String, dynamic>;
    for (final entry in samples.entries) {
      for (final frame in entry.value as List) {
        for (var thread = 0; thread < 2; thread++) {
          events.add({
            'name': entry.key,
            'cat': thread == 0 ? 'UI' : 'raster',
            'ph': 'X',
            'pid': 1,
            'tid': thread,
            'ts': frame[2 + thread],
            'dur': frame[thread] * 1000,
          });
        }
      }
    }
    File('${dir.path}/timeline.json').writeAsStringSync(
      jsonEncode({
        'traceEvents': events,
        'displayTimeUnit': 'ms',
        'source': 'Engine FrameTiming; bounded capture, not VM event tracing',
      }),
    );
  },
);
