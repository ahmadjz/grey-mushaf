// Geometry hooks locate words; assertions read rendered semantics and layers.
// No surrogate word widgets are inserted into the application.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greymushaf/page_ink.dart';

class WordTarget {
  const WordTarget(this.id, {this.skipOffstage = true});
  WordTarget.key(ValueKey key, {this.skipOffstage = true})
    : id = int.parse((key.value as String).substring(5));
  final int id;
  final bool skipOffstage;
  ({PageInkController model, InkWord word}) resolve(WidgetTester tester) {
    final pages = tester.widgetList<PaintedInkPage>(
      find.byType(PaintedInkPage, skipOffstage: skipOffstage),
    );
    for (final page in pages) {
      for (final word in page.controller.words) {
        if (word.id == id) return (model: page.controller, word: word);
      }
    }
    throw StateError('No painted word-$id');
  }

  bool exists(WidgetTester tester) {
    try {
      resolve(tester);
      return true;
    } on StateError {
      return false;
    }
  }
}

class _WordTextTarget {
  const _WordTextTarget(this.word);
  final WordTarget word;
}

dynamic testDescendant({
  required Object of,
  required Finder matching,
  bool skipOffstage = true,
  bool matchRoot = false,
}) => of is WordTarget
    ? _WordTextTarget(of)
    : find.descendant(
        of: of as Finder,
        matching: matching,
        skipOffstage: skipOffstage,
        matchRoot: matchRoot,
      );
Rect testRect(WidgetTester tester, Object target) {
  if (target is WordTarget) {
    final found = target.resolve(tester);
    return found.model.globalRect(found.word.box);
  }
  if (target is _WordTextTarget) {
    final found = target.word.resolve(tester);
    return found.model.globalRect(
      found.word.origin & found.word.paragraph.size,
    );
  }
  return tester.getRect(target as Finder);
}

Offset testCenter(WidgetTester tester, Object target) =>
    testRect(tester, target).center;
Size testSize(WidgetTester tester, Object target) =>
    testRect(tester, target).size;
Future<void> tapTarget(WidgetTester tester, Object target) =>
    target is WordTarget
    ? tester.tapAt(testCenter(tester, target))
    : tester.tap(target as Finder);
Future<void> longPressTarget(WidgetTester tester, Object target) =>
    target is WordTarget
    ? tester.longPressAt(testCenter(tester, target))
    : tester.longPress(target as Finder);
SemanticsNode testSemantics(WidgetTester tester, Object target) {
  if (target is WordTarget) {
    return find.semantics
        .byPredicate((node) => node.identifier == 'word-${target.id}')
        .evaluate()
        .single;
  }
  return tester.getSemantics(target as Finder);
}

({String? data, TextStyle? style}) testText(
  WidgetTester tester,
  Object target,
) {
  if (target is _WordTextTarget) {
    final paragraph = target.word.resolve(tester).word.paragraph;
    return (data: paragraph.text!.toPlainText(), style: paragraph.text!.style);
  }
  final text = tester.widget<Text>(target as Finder);
  return (data: text.data, style: text.style);
}

/// Captures the already-painted production page layer, never the painter/model colour.
Future<({Uint8List rgba, int width, int height, Rect ink, double scale})>
wordPixels(WidgetTester tester, WordTarget target) async {
  final found = target.resolve(tester);
  final owner = found.model.owner!;
  const scale = 3.0;
  return (await tester.runAsync(() async {
    final image = await (owner.debugLayer! as OffsetLayer).toImage(
      Offset.zero & owner.size,
      pixelRatio: scale,
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = (
      rgba: Uint8List.fromList(bytes.buffer.asUint8List()),
      width: image.width,
      height: image.height,
      ink: found.word.ink,
      scale: scale,
    );
    image.dispose();
    return result;
  }))!;
}

Future<Color> wordColor(WidgetTester tester, WordTarget target) async {
  final pixels = await wordPixels(tester, target);
  final counts = <int, int>{};
  final r = pixels.ink, s = pixels.scale;
  final rect = Rect.fromLTRB(r.left * s, r.top * s, r.right * s, r.bottom * s);
  for (
    var y = rect.top.ceil().clamp(0, pixels.height);
    y < rect.bottom.floor().clamp(0, pixels.height);
    y++
  ) {
    for (
      var x = rect.left.ceil().clamp(0, pixels.width);
      x < rect.right.floor().clamp(0, pixels.width);
      x++
    ) {
      final i = (y * pixels.width + x) * 4, rgba = pixels.rgba;
      if (rgba[i + 3] < 255) continue;
      final rgb = (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
      counts.update(rgb, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  expect(counts, isNotEmpty, reason: 'word must have opaque rendered ink');
  final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return Color(0xff000000 | dominant.key);
}
