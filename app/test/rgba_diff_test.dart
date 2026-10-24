import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/rgba_diff.dart';

void main() {
  test('R40 permits at most five edge changes, never flat-field changes', () {
    final reference = Uint8List.fromList([
      for (var y = 0; y < 5; y++)
        for (var x = 0; x < 5; x++) ...[
          x < 2 ? 0 : 255,
          x < 2 ? 0 : 255,
          x < 2 ? 0 : 255,
          255,
        ],
    ]);
    final edge = Uint8List.fromList(reference);
    for (var y = 0; y < 5; y++) {
      edge[(y * 5 + 2) * 4] = 254;
    }
    expect(r40Difference(reference, edge, 5).accepted, isTrue);
    expect(r40Difference(reference, edge, 5).changed, 5);
    edge[(2 * 5 + 1) * 4] = 1;
    expect(r40Difference(reference, edge, 5).accepted, isFalse);
    final interior = Uint8List.fromList(reference)..[0] = 1;
    expect(r40Difference(reference, interior, 5).nonEdge, 1);
    expect(r40Difference(reference, interior, 5).accepted, isFalse);
    // Neighbours must not wrap from one row to the next.
    final flat = Uint8List.fromList([
      for (var i = 0; i < 9; i++) ...[0, 0, 0, 255],
    ]);
    flat[3 * 4] = 255;
    final changed = Uint8List.fromList(flat)..[2 * 4] = 1;
    expect(r40Difference(flat, changed, 3).nonEdge, 1);
  });
  test('geometry gate rejects moves, sizes, identities and missing cases', () {
    Map<String, dynamic> geometry([
      double right = 3,
      String location = '1:1:1',
    ]) => {
      '1': {
        'rects': [
          {
            'id': 1,
            'location': location,
            'rect': [1.0, 2.0, right, 4.0],
          },
        ],
      },
    };
    expect(sameWordGeometry(geometry(), geometry()), isTrue);
    expect(sameWordGeometry(geometry(), geometry(3.001)), isFalse);
    expect(sameWordGeometry(geometry(), geometry(3, '1:1:2')), isFalse);
    expect(sameWordGeometry(geometry(), {}), isFalse);
  });
  test(
    'exact diff counts pixels once and includes alpha and one-level changes',
    () {
      final a = Uint8List.fromList([0, 1, 2, 255, 3, 4, 5, 255]);
      expect(differingPixels(a, a), 0);
      expect(
        differingPixels(a, Uint8List.fromList([1, 2, 2, 255, 3, 4, 5, 254])),
        2,
      );
      expect(() => differingPixels(a, Uint8List(4)), throwsArgumentError);
    },
  );
}
