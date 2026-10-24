import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/rgba_diff.dart';

void main() {
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
