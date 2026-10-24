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
