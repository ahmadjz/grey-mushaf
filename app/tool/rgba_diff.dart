import 'dart:typed_data';

/// Compare raw RGBA pixels exactly: no threshold, mask, or registration.
int differingPixels(Uint8List a, Uint8List b) {
  if (a.length != b.length || a.length % 4 != 0) {
    throw ArgumentError('RGBA dimensions must match');
  }
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] ||
        a[i + 1] != b[i + 1] ||
        a[i + 2] != b[i + 2] ||
        a[i + 3] != b[i + 3]) {
      count++;
    }
  }
  return count;
}

/// R40: a differing pixel must touch a different reference colour in its
/// 8-neighbourhood. A flat background is not an ink edge, even at the image rim.
({int changed, int nonEdge, bool accepted}) r40Difference(
  Uint8List reference,
  Uint8List candidate,
  int width,
) {
  final changed = differingPixels(reference, candidate);
  if (width <= 0 || reference.length % (width * 4) != 0) {
    throw ArgumentError('Invalid RGBA width');
  }
  final height = reference.length ~/ (width * 4);
  bool differs(Uint8List a, int i, Uint8List b, int j) {
    for (var c = 0; c < 4; c++) {
      if (a[i + c] != b[j + c]) return true;
    }
    return false;
  }

  var nonEdge = 0;
  for (var i = 0; i < reference.length; i += 4) {
    if (!differs(reference, i, candidate, i)) continue;
    final x = (i ~/ 4) % width, y = (i ~/ 4) ~/ width;
    var edge = false;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (differs(reference, i, reference, (ny * width + nx) * 4)) {
          edge = true;
        }
      }
    }
    if (!edge) nonEdge++;
  }
  return (
    changed: changed,
    nonEdge: nonEdge,
    accepted: changed <= 5 && nonEdge == 0,
  );
}

/// Compare every captured word's identity and exact logical ink rectangle.
/// Case keys distinguish portrait pages from the landscape spread.
bool sameWordGeometry(Map reference, Map candidate) {
  if (reference.isEmpty || reference.length != candidate.length) return false;
  for (final key in reference.keys) {
    if (!candidate.containsKey(key)) return false;
    final a = reference[key]['rects'] as List;
    final b = candidate[key]['rects'] as List;
    if (a.isEmpty || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] || a[i]['location'] != b[i]['location']) {
        return false;
      }
      final ar = a[i]['rect'] as List, br = b[i]['rect'] as List;
      if (ar.length != 4 || br.length != 4) return false;
      for (var j = 0; j < 4; j++) {
        if (ar[j] != br[j]) return false;
      }
    }
  }
  return true;
}
