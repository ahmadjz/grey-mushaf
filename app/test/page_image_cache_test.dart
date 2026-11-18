import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/page_image_cache.dart';

Future<ui.Image> image() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  final picture = recorder.endRecording();
  final result = await picture.toImage(10, 10);
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('LRU includes pending bytes and rejects invalidated captures', () async {
    final cache = PageImageCache(maxBytes: 800, maxEntries: 2);
    final pending = Completer<ui.Image>();
    final first = cache.capture('a', 400, () => pending.future);
    expect(cache.bytes, 400);
    expect(await cache.capture('b', 400, image), isFalse);
    cache.remove('a');
    expect(cache.bytes, 400);
    pending.complete(await image());
    expect(await first, isFalse);
    expect(cache.bytes, 0);
    expect(await cache.capture('a', 400, image), isTrue);
    expect(await cache.capture('b', 400, image), isTrue);
    expect(cache['a'], isNotNull);
    expect(await cache.capture('c', 400, image), isTrue);
    expect(cache['b'], isNull);
    expect(cache.bytes, 800);
    expect(await cache.capture('huge', 801, image), isFalse);
    cache.clear();
    expect(cache.bytes, 0);
  });

  test('a page pushed out by the budget stays live until it changes', () async {
    final evicted = <Object>[];
    final cache = PageImageCache(
      maxBytes: 700,
      maxEntries: 4,
      onEvict: evicted.add,
    );
    expect(await cache.capture('a', 400, image), isTrue);
    expect(await cache.capture('b', 400, image), isTrue);
    expect(evicted, ['a']);
    expect(await cache.capture('a', 400, image), isFalse);
    expect(cache['b'], isNotNull);
    cache.remove('a');
    expect(await cache.capture('a', 400, image), isTrue);
    expect(evicted, ['a', 'b']);
    expect(await cache.capture('b', 400, image), isFalse);
    cache.clear();
    expect(await cache.capture('b', 400, image), isTrue);
  });
}
