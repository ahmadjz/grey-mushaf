import 'dart:math' as math;
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'flat_ink.dart';
import 'reveal_store.dart';

typedef InkMetric = ({double width, double left, double right});

class InkWord {
  InkWord({
    required this.id,
    required this.location,
    required this.box,
    required this.ink,
    required this.band,
    required this.origin,
    required this.paragraphOffset,
    required this.localInk,
    required this.paragraph,
    required this.fontSize,
  });
  final int id;
  final String location;
  final Rect box, ink, band;
  final Offset origin, paragraphOffset;
  final Rect localInk;
  final TextPainter paragraph;
  final double fontSize;
}

class PageInkController extends ChangeNotifier {
  PageInkController(this.store);
  RevealStore store;
  Color dim = const Color(0xFFB0B0B0),
      foreground = Colors.black,
      background = Colors.white;
  final words = <InkWord>[];
  final _globalRects =
      HashMap<Rect, ({RenderBox source, Offset offset, Rect local})>.identity();
  RenderBox? owner;
  late final painter = PageInkPainter(this);
  void changed() => notifyListeners();
  Color color(InkWord word) =>
      store.state(wordKey(word.location)).black ? foreground : dim;
  String label(InkWord word) {
    final saved = store.state(wordKey(word.location));
    return '${word.location}; ${saved.black ? 'revealed' : 'unrevealed'}; reveals ${saved.count}';
  }

  Rect globalRect(Rect rect) {
    final source = _globalRects[rect];
    if (source != null) {
      final matrix = source.source.getTransformTo(null)
        ..translateByDouble(source.offset.dx, source.offset.dy, 0, 1);
      return Rect.fromPoints(
        MatrixUtils.transformPoint(matrix, source.local.topLeft),
        MatrixUtils.transformPoint(matrix, source.local.bottomRight),
      );
    }
    return MatrixUtils.transformRect(owner!.getTransformTo(null), rect);
  }

  ({int id, double outside, double edge})? hitAt(
    Offset point, {
    required bool shortTap,
  }) {
    if (owner == null || !owner!.attached || !owner!.hasSize) return null;
    ({int id, double outside, double edge})? best;
    for (final word in words) {
      final band = globalRect(word.band), ink = globalRect(word.ink);
      if (point.dy < band.top || point.dy >= band.bottom) continue;
      if (shortTap &&
          (point.dy - band.center.dy).abs() >
              ink.height / 2 + word.fontSize * .02) {
        continue;
      }
      final outside = (point.dx - point.dx.clamp(ink.left, ink.right)).abs();
      if (outside > word.fontSize * .08) continue;
      final edge = math.min(
        (point.dx - ink.left).abs(),
        (point.dx - ink.right).abs(),
      );
      if (best == null ||
          outside < best.outside ||
          (outside == best.outside && edge < best.edge)) {
        best = (id: word.id, outside: outside, edge: edge);
      }
    }
    return best;
  }
}

/// One painter per page, using the same individually shaped paragraphs.
class PageInkPainter extends CustomPainter {
  PageInkPainter(this.controller) : super(repaint: controller);
  final PageInkController controller;
  Color? activeColor;
  @override
  void paint(Canvas canvas, Size size) {
    for (final word in controller.words) {
      if (controller.color(word) == activeColor) {
        canvas.save();
        canvas.translate(word.box.left, word.box.top);
        word.paragraph.paint(canvas, word.paragraphOffset);
        canvas.restore();
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final word in controller.words)
          CustomPainterSemantics(
            key: ValueKey('word-${word.id}'),
            rect: word.box.isEmpty
                ? Rect.fromLTWH(
                    word.ink.left,
                    word.box.top,
                    math.max(1, word.ink.width),
                    word.box.height,
                  )
                : word.box,
            properties: SemanticsProperties(
              identifier: 'word-${word.id}',
              label: controller.label(word),
              textDirection: TextDirection.rtl,
            ),
          ),
      ];
  @override
  bool shouldRepaint(covariant PageInkPainter oldDelegate) =>
      oldDelegate.controller != controller;
  @override
  bool shouldRebuildSemantics(covariant PageInkPainter oldDelegate) => true;
}

class PaintedInkPage extends SingleChildRenderObjectWidget {
  const PaintedInkPage({
    super.key,
    required this.controller,
    required super.child,
  });
  final PageInkController controller;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PageRender(controller);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _PageRender).update(controller);
  }
}

class _PageRender extends RenderCustomPaint {
  _PageRender(this.controller) : super(painter: controller.painter);
  PageInkController controller;
  @override
  bool get isRepaintBoundary => true;
  void update(PageInkController next) {
    if (!identical(controller, next)) {
      if (attached) controller.removeListener(markNeedsSemanticsUpdate);
      controller.owner = null;
      controller = next;
      painter = controller.painter;
      if (attached) controller.addListener(markNeedsSemanticsUpdate);
    }
    controller.owner = this;
    markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    controller.owner = this;
    controller.addListener(markNeedsSemanticsUpdate);
  }

  @override
  void detach() {
    controller.removeListener(markNeedsSemanticsUpdate);
    controller.owner = null;
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _collectWords();
  }

  void _collectWords() {
    controller.owner = this;
    controller.words.clear();
    controller._globalRects.clear();
    void collect(RenderObject object) {
      if (object is _LineRender) {
        final transform = object.getTransformTo(this);
        for (final word in object.words) {
          final box = MatrixUtils.transformRect(transform, word.box);
          final placed = InkWord(
            id: word.id,
            location: word.location,
            box: box,
            ink: MatrixUtils.transformRect(transform, word.ink),
            band: Rect.fromLTWH(2, box.top, size.width - 4, box.height),
            origin: MatrixUtils.transformPoint(transform, word.origin),
            paragraphOffset: word.paragraphOffset,
            localInk: word.localInk,
            paragraph: word.paragraph,
            fontSize: word.fontSize,
          );
          controller.words.add(placed);
          controller._globalRects[placed.box] = (
            source: object,
            offset: word.box.topLeft,
            local: Offset.zero & word.box.size,
          );
          controller._globalRects[placed.ink] = (
            source: object,
            offset: word.box.topLeft,
            local: word.localInk,
          );
        }
      } else {
        object.visitChildren(collect);
      }
    }

    visitChildren(collect);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _collectWords();
    if (child != null) context.paintChild(child!, offset);
    for (final color in [controller.dim, controller.foreground]) {
      if (!controller.words.any((word) => controller.color(word) == color)) {
        continue;
      }
      context.pushColorFilter(
        offset,
        FlatInk.mapFilter(color, controller.background),
        (context, offset) {
          context.pushColorFilter(offset, FlatInk.thresholdFilter, (
            context,
            offset,
          ) {
            final canvas = context.canvas;
            canvas.save();
            canvas.translate(offset.dx, offset.dy);
            controller.painter.activeColor = color;
            controller.painter.paint(canvas, size);
            canvas.restore();
          });
        },
      );
    }
  }
}

class PaintedWordLine extends LeafRenderObjectWidget {
  const PaintedWordLine({
    super.key,
    required this.controller,
    required this.words,
    required this.metrics,
    required this.fontSize,
    required this.height,
    required this.inkHeight,
    required this.baseline,
    required this.centered,
    required this.style,
  });
  final PageInkController controller;
  final List words;
  final Map<int, InkMetric> metrics;
  final double fontSize, height, inkHeight, baseline;
  final bool centered;
  final TextStyle style;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LineRender(this, DefaultTextStyle.of(context).style.merge(style));
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _LineRender).update(
      this,
      DefaultTextStyle.of(context).style.merge(style),
    );
  }
}

class _LineRender extends RenderBox {
  _LineRender(this.config, this.style);
  TextStyle style;
  PaintedWordLine config;
  final words = <InkWord>[];
  final _paragraphs =
      <
        int,
        ({TextPainter painter, double width, TextStyle style, String text})
      >{};
  void update(PaintedWordLine next, TextStyle nextStyle) {
    style = nextStyle;
    config = next;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.constrain(Size(constraints.maxWidth, config.height));
    final widths = [
      for (final word in config.words)
        config.metrics[word['id']]!.width * config.fontSize,
    ];
    var used = 0.0;
    for (var i = 0; i < widths.length; i++) {
      if (i > 0 && config.centered) used += config.fontSize * .09;
      used += widths[i];
    }
    final free = math.max(0.0, size.width - used);
    var position = config.centered
        ? free / 2
        : widths.length == 1
        ? free
        : 0.0;
    final gap = config.centered
        ? config.fontSize * .09
        : widths.length > 1
        ? free / (widths.length - 1)
        : 0.0;
    // RenderFlex places RTL children in reverse order from the left edge.
    // Preserve its floating-point addition order as well as its geometry.
    final lefts = List<double>.filled(widths.length, 0);
    for (var i = widths.length - 1; i >= 0; i--) {
      lefts[i] = position;
      position += widths[i] + (config.centered ? 0 : gap);
      if (config.centered && i > 0) position += gap;
    }
    words.clear();
    final retained = <int>{};
    for (var i = 0; i < widths.length; i++) {
      final word = config.words[i], id = word['id'] as int;
      retained.add(id);
      final metric = config.metrics[id]!;
      final text = word['text'] as String;
      var cached = _paragraphs[id];
      if (cached == null ||
          cached.width != widths[i] ||
          cached.style != style ||
          cached.text != text) {
        cached?.painter.dispose();
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: widths[i]);
        cached = (painter: painter, width: widths[i], style: style, text: text);
        _paragraphs[id] = cached;
      }
      final left = lefts[i];
      words.add(
        InkWord(
          id: id,
          location: word['location'] as String,
          box: Rect.fromLTWH(left, 0, widths[i], config.height),
          ink: Rect.fromLTRB(
            left + metric.left * config.fontSize,
            (config.height - config.inkHeight) / 2,
            left + metric.right * config.fontSize,
            (config.height + config.inkHeight) / 2,
          ),
          band: Offset.zero & size,
          origin: Offset(
            left,
            config.baseline -
                cached.painter.computeDistanceToActualBaseline(
                  TextBaseline.alphabetic,
                ),
          ),
          paragraphOffset: Offset(
            0,
            config.baseline -
                cached.painter.computeDistanceToActualBaseline(
                  TextBaseline.alphabetic,
                ),
          ),
          localInk: Rect.fromLTRB(
            metric.left * config.fontSize,
            (config.height - config.inkHeight) / 2,
            metric.right * config.fontSize,
            (config.height + config.inkHeight) / 2,
          ),
          paragraph: cached.painter,
          fontSize: config.fontSize,
        ),
      );
    }
    _paragraphs.removeWhere((id, p) {
      if (retained.contains(id)) return false;
      p.painter.dispose();
      return true;
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
  @override
  void dispose() {
    for (final p in _paragraphs.values) {
      p.painter.dispose();
    }
    super.dispose();
  }
}
