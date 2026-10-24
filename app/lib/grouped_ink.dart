import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'flat_ink.dart';

class GroupedInkPage extends SingleChildRenderObjectWidget {
  const GroupedInkPage({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _PageInk();
}

/// Preserve word layout; composite ink once per page and colour.
class GroupedInkWord extends SingleChildRenderObjectWidget {
  const GroupedInkWord({
    super.key,
    required this.color,
    required this.background,
    this.ink,
    required super.child,
  });
  final Color color, background;
  final Rect? ink;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _WordInk(color, background);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _WordInk).update(color, background);
  }
}

typedef _Entry = ({RenderBox child, Matrix4 transform});

class _PageInk extends RenderProxyBox {
  final entries = <(Color, Color), List<_Entry>>{};
  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    entries.clear();
    super.paint(context, offset);
    int foreground(Color color) =>
        color == const Color(0xFF000000) || color == const Color(0xFFFFFFFF)
        ? 1
        : 0;
    final groups = entries.entries.toList()
      ..sort((a, b) => foreground(a.key.$1).compareTo(foreground(b.key.$1)));
    for (final group in groups) {
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
  _WordInk(this.color, this.background);
  Color color, background;
  void update(Color nextColor, Color nextBackground) {
    if (color == nextColor && background == nextBackground) {
      return;
    }
    color = nextColor;
    background = nextBackground;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderObject? owner = parent;
    while (owner != null && owner is! _PageInk) {
      owner = owner.parent;
    }
    if (owner is! _PageInk) {
      throw StateError('Word ink requires its page group');
    }
    if (child != null) {
      owner.entries.putIfAbsent((color, background), () => []).add((
        child: child!,
        transform: getTransformTo(owner),
      ));
    }
  }
}
