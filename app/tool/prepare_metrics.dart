// Run with: flutter test tool/prepare_metrics.dart
// Generated output is private and stays beside the bundled assets.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/main.dart';
import 'package:greymushaf/bundle_metrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('prepare global metrics with real Flutter shaping', () async {
    final pages = await loadPages();
    expect(
      pages.map((p) => p['page']),
      orderedEquals(List.generate(604, (i) => i + 1)),
    );
    final metrics = BundleMetrics.measure(pages);
    final files =
        Directory('assets/mushaf')
            .listSync()
            .whereType<File>()
            .where((f) => !f.path.endsWith('/metrics.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final hashes = <String, String>{};
    for (final file in files) {
      final result = await Process.run('sha256sum', [file.path]);
      expect(result.exitCode, 0);
      hashes[file.uri.pathSegments.last] = (result.stdout as String)
          .split(' ')
          .first;
    }
    final sourceHash = await Process.run('sha256sum', [
      'lib/bundle_metrics.dart',
    ]);
    expect(sourceHash.exitCode, 0);
    File('assets/mushaf/metrics.json').writeAsStringSync(
      jsonEncode({
        ...metrics.toJson(),
        'sha256': hashes,
        'shapingSource': (sourceHash.stdout as String).split(' ').first,
      }),
    );
  });
}
