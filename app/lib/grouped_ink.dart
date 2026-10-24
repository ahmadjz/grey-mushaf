import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'flat_ink.dart';

/// Bounds use prepared horizontal ink and the whole font's vertical extrema.
/// Expand by two physical pixels before both containment and overlap checks.
List<bool> groupableInk(List<Rect> boxes, List<Rect> ink, double margin) {
  final padded = [for (final rect in ink) rect.inflate(margin)];
  final result = [
    for (var i = 0; i < ink.length; i++)
      boxes[i].left <= padded[i].left &&
          boxes[i].top <= padded[i].top &&
          boxes[i].right >= padded[i].right &&
          boxes[i].bottom >= padded[i].bottom,
  ];
  for (var i = 0; i < ink.length; i++) {
    for (var j = i + 1; j < ink.length; j++) {
      if (padded[i].overlaps(padded[j])) {
        result[i] = false;
        result[j] = false;
      }
    }
  }
  return result;
}

class GroupedInkPage extends SingleChildRenderObjectWidget {
  const GroupedInkPage({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _PageInk();
}

/// The original FlatInk subtree stays intact for every fallback word.
class GroupedInkWord extends StatelessWidget {
  const GroupedInkWord({
    super.key,
    required this.color,
    required this.background,
    required this.child,
    this.ink,
  });
  final Color color;
  final Color background;
  final Widget child;
  final Rect? ink;
  @override
  Widget build(BuildContext context) => _WordSlot(
    color: color,
    background: background,
    ink: ink,
    dpr: View.of(context).devicePixelRatio,
    child: FlatInk(color: color, background: background, child: child),
  );
}

class _WordSlot extends SingleChildRenderObjectWidget {
  const _WordSlot({
    required this.color,
    required this.background,
    required this.ink,
    required this.dpr,
    required super.child,
  });
  final Color color, background;
  final Rect? ink;
  final double dpr;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _WordInk(color, background, ink, dpr);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _WordInk renderObject,
  ) {
    renderObject.update(color, background, ink, dpr);
  }
}

typedef _Entry = ({RenderBox child, Matrix4 transform});

class _PageInk extends RenderProxyBox {
  final entries = <(Color, Color), List<_Entry>>{};
  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final words = <_WordInk>[];
    void collect(RenderObject object) {
      if (object is _WordInk) {
        words.add(object);
      } else {
        object.visitChildren(collect);
      }
    }

    visitChildren(collect);
    final transforms = [for (final word in words) word.getTransformTo(this)];
    final safe = groupableInk(
      [
        for (var i = 0; i < words.length; i++)
          MatrixUtils.transformRect(transforms[i], Offset.zero & words[i].size),
      ],
      [
        for (var i = 0; i < words.length; i++)
          MatrixUtils.transformRect(
            transforms[i],
            words[i].ink ?? (Offset.zero & words[i].size),
          ),
      ],
      words.isEmpty ? 0 : 2 / words.first.dpr,
    );
    for (var i = 0; i < words.length; i++) {
      words[i].grouped = safe[i];
    }
    entries.clear();
    super.paint(context, offset);
    for (final group in entries.entries) {
      context.pushColorFilter(
        offset,
        FlatInk.mapFilter(group.key.$1, group.key.$2),
        (context, offset) {
          context.pushColorFilter(offset, FlatInk.thresholdFilter, (
            context,
            offset,
          ) {
            for (final entry in group.value) {
              context.pushTransform(false, offset, entry.transform, (
                context,
                offset,
              ) {
                context.paintChild(entry.child, offset);
              });
            }
          });
        },
      );
    }
    entries.clear();
  }
}

class _WordInk extends RenderProxyBox {
  _WordInk(this.color, this.background, this.ink, this.dpr);
  Color color, background;
  Rect? ink;
  double dpr;
  bool grouped = false;
  void update(
    Color nextColor,
    Color nextBackground,
    Rect? nextInk,
    double nextDpr,
  ) {
    if (color == nextColor &&
        background == nextBackground &&
        ink == nextInk &&
        dpr == nextDpr) {
      return;
    }
    color = nextColor;
    background = nextBackground;
    ink = nextInk;
    dpr = nextDpr;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!grouped) {
      super.paint(context, offset);
      return;
    }
    RenderObject? owner = parent;
    while (owner != null && owner is! _PageInk) {
      owner = owner.parent;
    }
    if (owner is! _PageInk) {
      throw StateError('Word ink requires its page group');
    }
    // FlatInk is precisely two proxy colour filters, with no layout offset.
    final threshold = (child! as RenderProxyBox).child! as RenderProxyBox;
    owner.entries.putIfAbsent((color, background), () => []).add((
      child: threshold.child!,
      transform: getTransformTo(owner),
    ));
  }
}
