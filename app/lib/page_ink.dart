import 'dart:math' as math;
import 'dart:collection';

import 'package:flutter/scheduler.dart';

import 'page_image_cache.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'flat_ink.dart';
import 'reveal_store.dart';
import 'word_marks.dart';

typedef InkMetric = ({double width, double left, double right});

typedef _ParagraphKey = ({String text, TextStyle style, double width});

class ParagraphPool {
  ParagraphPool({this.maxIdle = 1200});
  final int maxIdle;
  final _idle = <_ParagraphKey, List<TextPainter>>{};
  final _inUse = HashMap<_ParagraphKey, int>();
  int _idleCount = 0;
  @visibleForTesting
  int created = 0;

  TextPainter acquire(String text, TextStyle style, double width) {
    final key = (text: text, style: style, width: width);
    _inUse[key] = (_inUse[key] ?? 0) + 1;
    final idle = _idle[key];
    if (idle == null) return _create(key);
    _idleCount--;
    if (idle.length == 1) _idle.remove(key);
    return idle.removeLast();
  }

  void release(
    String text,
    TextStyle style,
    double width,
    TextPainter painter,
  ) {
    final key = (text: text, style: style, width: width);
    final users = _inUse[key]! - 1;
    if (users == 0) {
      _inUse.remove(key);
    } else {
      _inUse[key] = users;
    }
    _park(key, painter);
  }

  void prewarm(String text, TextStyle style, double width) {
    final key = (text: text, style: style, width: width);
    if (_inUse.containsKey(key)) return;
    final idle = _idle.remove(key);
    if (idle != null) {
      _idle[key] = idle;
    } else {
      _park(key, _create(key));
    }
  }

  void clearIdle() {
    for (final painters in _idle.values) {
      for (final painter in painters) {
        painter.dispose();
      }
    }
    _idle.clear();
    _idleCount = 0;
  }

  void _park(_ParagraphKey key, TextPainter painter) {
    _idle[key] = (_idle.remove(key) ?? [])..add(painter);
    _idleCount++;
    while (_idleCount > maxIdle) {
      final oldest = _idle.keys.first;
      final painters = _idle[oldest]!;
      painters.removeAt(0).dispose();
      _idleCount--;
      if (painters.isEmpty) _idle.remove(oldest);
    }
  }

  TextPainter _create(_ParagraphKey key) {
    created++;
    return TextPainter(
      text: TextSpan(text: key.text, style: key.style),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: key.width);
  }
}

final paragraphPool = ParagraphPool();

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
  bool blackWhite = false;
  Color markColor(MarkColor colour) =>
      blackWhite ? foreground : colour.paint(foreground);
  final words = <InkWord>[];
  final _globalRects =
      HashMap<Rect, ({RenderBox source, Offset offset, Rect local})>.identity();
  RenderBox? owner;
  @visibleForTesting
  bool get hasCachedImage => cachedImage != null;
  @visibleForTesting
  Object? get cachedImage => owner == null ? null : _PageRender._images[owner!];
  @visibleForTesting
  Offset? get cachedImagePhysicalOrigin {
    final render = owner;
    if (render is! _PageRender || !hasCachedImage) return null;
    return render.localToGlobal(render._captureBounds!.topLeft) * render.dpr;
  }

  late final painter = PageInkPainter(this);
  void changed() => notifyListeners();
  Color color(InkWord word) =>
      store.state(wordKey(word.location)).black ? foreground : dim;
  String label(InkWord word) {
    final saved = store.state(wordKey(word.location));
    final marks = store.marks(wordKey(word.location));
    return '${word.location}; ${saved.black ? 'revealed' : 'unrevealed'}; reveals ${saved.count}'
        '${[
          for (final mark in [marks.line, marks.shape])
            if (mark != null) '; ${mark.style.name} ${mark.color.name}',
        ].join()}';
  }

  void paintMarks(Canvas canvas) {
    for (final word in words) {
      final marks = store.marks(wordKey(word.location));
      if (marks.isEmpty) continue;
      final stroke = math.max(1.2, word.fontSize * .035);
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..isAntiAlias = true;
      final line = marks.line;
      if (line != null) {
        pen.color = markColor(line.color);
        final gap = stroke * 2.5;
        final lines = line.style == MarkStyle.doubleLine ? 2 : 1;
        final lowest = word.box.bottom - stroke / 2;
        final first = math.min(
          word.ink.bottom + word.fontSize * .05,
          lowest - gap * (lines - 1),
        );
        for (var i = 0; i < lines; i++) {
          final y = first + gap * i;
          canvas.drawLine(
            Offset(word.ink.left, y),
            Offset(word.ink.right, y),
            pen,
          );
        }
      }
      final shape = marks.shape;
      if (shape != null) {
        pen.color = markColor(shape.color);
        final pad = word.fontSize * .06;
        final around = word.ink.inflate(pad);
        final bounds = Rect.fromLTRB(
          around.left,
          math.max(around.top, word.box.top + stroke / 2),
          around.right,
          math.min(around.bottom, word.box.bottom - stroke / 2),
        );
        if (shape.style == MarkStyle.circle) {
          canvas.drawOval(
            Rect.fromLTRB(
              bounds.left - pad,
              bounds.top,
              bounds.right + pad,
              bounds.bottom,
            ),
            pen,
          );
        } else {
          canvas.drawRect(bounds, pen);
        }
      }
    }
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
  RenderObject createRenderObject(BuildContext context) => _PageRender(
    controller,
    MediaQuery.devicePixelRatioOf(context),
    MediaQuery.orientationOf(context) == Orientation.landscape,
    Scrollable.maybeOf(context)?.position,
  );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _PageRender).update(
      controller,
      MediaQuery.devicePixelRatioOf(context),
      MediaQuery.orientationOf(context) == Orientation.landscape,
      Scrollable.maybeOf(context)?.position,
    );
  }
}

class _PageImages extends PageImageCache with WidgetsBindingObserver {
  _PageImages()
    : super(
        onEvict: (key) {
          if (key is _PageRender && key.attached) key.markNeedsPaint();
        },
      ) {
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didHaveMemoryPressure() {
    clear();
    paragraphPool.clearIdle();
  }
}

class _PageRender extends RenderCustomPaint {
  _PageRender(this.controller, this.dpr, this.landscape, this.scrollPosition)
    : super(painter: controller.painter);
  static final _images = _PageImages();
  bool landscape;
  ScrollPosition? scrollPosition;
  double dpr;
  int _generation = 0;
  bool _scheduled = false;
  bool _showingCapture = false;
  Rect? _captureBounds;
  Object? _imageInputs, _paintedInputs;

  Object get _inputs => (
    controller.store,
    controller.dim,
    controller.foreground,
    controller.background,
    controller.blackWhite,
  );

  @override
  void markNeedsPaint() {
    if (!_showingCapture) {
      _generation++;
      _images.remove(this);
    }
    super.markNeedsPaint();
  }

  void _invalidate() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _scheduleCapture() {
    if (_scheduled) return;
    _scheduled = true;
    final generation = _generation;
    final inputs = _inputs;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      while (_images.isCapturing) {
        await _images.idle;
      }
      _scheduled = false;
      if (!attached || layer == null) return;
      if (generation != _generation) {
        markNeedsPaint();
        return;
      }
      var origin = localToGlobal(Offset.zero) * dpr;
      final scroll = scrollPosition;
      if (scroll != null) {
        final delta = scroll.pixels * dpr;
        origin += switch (scroll.axisDirection) {
          AxisDirection.right => Offset(delta, 0),
          AxisDirection.left => Offset(-delta, 0),
          AxisDirection.down => Offset(0, delta),
          AxisDirection.up => Offset(0, -delta),
        };
      }
      final phase = Offset(
        origin.dx - origin.dx.floor(),
        origin.dy - origin.dy.floor(),
      );
      final bounds = Rect.fromLTWH(
        -phase.dx / dpr,
        -phase.dy / dpr,
        (size.width * dpr + phase.dx).ceil() / dpr,
        (size.height * dpr + phase.dy).ceil() / dpr,
      );
      final bytes =
          (bounds.width * dpr).ceil() * (bounds.height * dpr).ceil() * 4;
      _images.maxEntries = landscape ? 4 : 2;
      try {
        final ready = await _images.capture(
          this,
          bytes,
          () => (layer! as OffsetLayer).toImage(bounds, pixelRatio: dpr),
        );
        if (ready && attached && generation == _generation) {
          _captureBounds = bounds;
          _imageInputs = inputs;
          _showingCapture = true;
          markNeedsPaint();
          _showingCapture = false;
        }
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            context: ErrorDescription('capturing page ink'),
          ),
        );
      }
    });
  }

  PageInkController controller;
  @override
  bool get isRepaintBoundary => true;
  void update(
    PageInkController next,
    double nextDpr,
    bool nextLandscape,
    ScrollPosition? nextScroll,
  ) {
    scrollPosition = nextScroll;
    if (landscape != nextLandscape || dpr != nextDpr) {
      _images.clear();
      landscape = nextLandscape;
      dpr = nextDpr;
      markNeedsLayout();
    }
    if (!identical(controller, next)) {
      if (attached) controller.removeListener(_invalidate);
      controller.owner = null;
      controller = next;
      painter = controller.painter;
      if (attached) controller.addListener(_invalidate);
      markNeedsLayout();
    }
    controller.owner = this;
    if (_paintedInputs != _inputs) _invalidate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    controller.owner = this;
    controller.addListener(_invalidate);
  }

  @override
  void detach() {
    _invalidate();
    controller.removeListener(_invalidate);
    controller.owner = null;
    super.detach();
  }

  @override
  void performLayout() {
    _invalidate();
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
    _paintedInputs = _inputs;
    final image = _images[this];
    if (image != null && _imageInputs == _paintedInputs) {
      final canvas = context.canvas;
      canvas.save();
      canvas.translate(
        offset.dx + _captureBounds!.left,
        offset.dy + _captureBounds!.top,
      );
      canvas.scale(1 / dpr);
      canvas.drawImage(
        image,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.none,
      );
      canvas.restore();
      return;
    }
    _scheduleCapture();
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
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    controller.paintMarks(canvas);
    canvas.restore();
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
    final same =
        identical(next.words, config.words) &&
        identical(next.metrics, config.metrics) &&
        next.fontSize == config.fontSize &&
        next.height == config.height &&
        next.inkHeight == config.inkHeight &&
        next.baseline == config.baseline &&
        next.centered == config.centered &&
        nextStyle == style;
    style = nextStyle;
    config = next;
    if (!same) markNeedsLayout();
  }

  void _release(
    ({TextPainter painter, double width, TextStyle style, String text}) p,
  ) => paragraphPool.release(p.text, p.style, p.width, p.painter);

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
        if (cached != null) _release(cached);
        final painter = paragraphPool.acquire(text, style, widths[i]);
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
      _release(p);
      return true;
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
  @override
  void dispose() {
    _paragraphs.values.forEach(_release);
    _paragraphs.clear();
    super.dispose();
  }
}
