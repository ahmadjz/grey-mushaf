// Test hooks read the actual painter geometry, paragraphs and semantics builder.
// No surrogate word widgets are inserted into the application.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
SemanticsProperties testSemantics(WidgetTester tester, Object target) {
  if (target is WordTarget) {
    final found = target.resolve(tester);
    return found.model.painter
        .semanticsBuilder(found.model.owner!.size)
        .singleWhere((s) => s.key == ValueKey('word-${target.id}'))
        .properties;
  }
  return tester.widget<Semantics>(target as Finder).properties;
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

Color wordColor(WidgetTester tester, WordTarget target) {
  final found = target.resolve(tester);
  return found.model.color(found.word);
}
