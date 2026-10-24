import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'rgba_diff.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reference images satisfy the selected parity gate', () async {
    final reference = Directory(Platform.environment['PARITY_REFERENCE']!);
    final candidate = Directory(Platform.environment['PARITY_CANDIDATE']!);
    final mode = Platform.environment['PARITY_MODE'] ?? 'exact';
    expect(['exact', 'r40'], contains(mode));
    var geometryMatches = true;
    if (mode == 'r40') {
      final referenceCapture = jsonDecode(
        File(
          Platform.environment['PARITY_REFERENCE_GEOMETRY'] ??
              '${reference.parent.path}/capture.json',
        ).readAsStringSync(),
      );
      final candidateCapture = jsonDecode(
        File(
          Platform.environment['PARITY_CANDIDATE_GEOMETRY'] ??
              '${candidate.parent.path}/capture.json',
        ).readAsStringSync(),
      );
      geometryMatches = sameWordGeometry(
        referenceCapture['geometry'] as Map,
        candidateCapture['geometry'] as Map,
      );
    }
    var accepted = geometryMatches;
    final files = reference
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
    expect(files.length, 84);
    final results = <String, Object>{};
    var total = 0;
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final other = File('${candidate.path}/$name');
      expect(other.existsSync(), isTrue, reason: name);
      final ac = await ui.instantiateImageCodec(await file.readAsBytes());
      final bc = await ui.instantiateImageCodec(await other.readAsBytes());
      final a = (await ac.getNextFrame()).image;
      final b = (await bc.getNextFrame()).image;
      expect([a.width, a.height], [b.width, b.height], reason: name);
      final aa = (await a.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      final bb = (await b.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      final count = differingPixels(aa, bb);
      total += count;
      final edge = mode == 'r40' ? r40Difference(aa, bb, a.width) : null;
      final imageAccepted = mode == 'exact' ? count == 0 : edge!.accepted;
      accepted = accepted && imageAccepted;
      var left = a.width, top = a.height, right = -1, bottom = -1;
      if (count > 0) {
        for (var i = 0; i < aa.length; i += 4) {
          if (aa[i] == bb[i] &&
              aa[i + 1] == bb[i + 1] &&
              aa[i + 2] == bb[i + 2] &&
              aa[i + 3] == bb[i + 3]) {
            continue;
          }
          final x = (i ~/ 4) % a.width, y = (i ~/ 4) ~/ a.width;
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
      results[name] = {
        'pixels': count,
        'totalPixels': a.width * a.height,
        'nonEdgePixels': edge?.nonEdge,
        'accepted': imageAccepted,
        'bounds': count == 0 ? null : [left, top, right, bottom],
      };
      a.dispose();
      b.dispose();
      ac.dispose();
      bc.dispose();
    }
    File(Platform.environment['PARITY_DIFF'] ?? '${candidate.path}/diff.json')
        .writeAsStringSync(
          jsonEncode({
            'mode': mode,
            'geometryMatches': geometryMatches,
            'accepted': accepted,
            'totalPixels': total,
            'images': results,
          }),
        );
    expect(
      accepted,
      isTrue,
      reason: '$mode parity and geometry required; see diff.json',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
