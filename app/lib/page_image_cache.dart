import 'dart:async';
import 'dart:ui' as ui;

/// Pixel accounting includes the single in-flight allocation, even after eviction.
class PageImageCache {
  PageImageCache({
    this.maxBytes = 24 * 1024 * 1024,
    this.maxEntries = 2,
    this.onEvict,
  });
  final void Function(Object key)? onEvict;
  final int maxBytes;
  int maxEntries;
  final _images = <Object, ui.Image>{};
  Object? _pending;
  Completer<void>? _pendingDone;
  bool get isCapturing => _pending != null;
  Future<void> get idle => _pendingDone?.future ?? Future<void>.value();
  int _pendingBytes = 0;
  bool _cancelled = false;
  int get bytes =>
      _pendingBytes +
      _images.values.fold(0, (n, i) => n + i.width * i.height * 4);

  ui.Image? operator [](Object key) {
    final image = _images.remove(key);
    if (image != null) _images[key] = image;
    return image;
  }

  Future<bool> capture(
    Object key,
    int bytes,
    Future<ui.Image> Function() create,
  ) async {
    if (_pending != null || bytes > maxBytes || maxEntries < 1) return false;
    remove(key);
    while (_images.isNotEmpty &&
        (this.bytes + bytes > maxBytes || _images.length >= maxEntries)) {
      remove(_images.keys.first);
    }
    _pending = key;
    _pendingDone = Completer<void>();
    _pendingBytes = bytes;
    _cancelled = false;
    try {
      final image = await create();
      if (_cancelled || image.width * image.height * 4 != bytes) {
        image.dispose();
        return false;
      }
      _images[key] = image;
      return true;
    } finally {
      _pending = null;
      _pendingBytes = 0;
      _pendingDone!.complete();
      _pendingDone = null;
    }
  }

  void remove(Object key) {
    final image = _images.remove(key);
    if (image != null) {
      image.dispose();
      onEvict?.call(key);
    }
    if (_pending == key) _cancelled = true;
  }

  void clear() {
    for (final key in _images.keys.toList()) {
      remove(key);
    }
    if (_pending != null) _cancelled = true;
  }
}
