import 'dart:convert';
import 'dart:ui';

import 'package:uuid/uuid.dart';

enum MarkKind { line, shape }

enum MarkStyle {
  singleLine(MarkKind.line),
  doubleLine(MarkKind.line),
  rectangle(MarkKind.shape),
  circle(MarkKind.shape);

  const MarkStyle(this.kind);
  final MarkKind kind;
}

enum MarkColor {
  red(Color(0xFFD32F2F)),
  blue(Color(0xFF1976D2)),
  green(Color(0xFF388E3C)),
  orange(Color(0xFFF57C00)),
  purple(Color(0xFF7B1FA2)),
  black(null);

  const MarkColor(this._fixed);
  final Color? _fixed;
  Color paint(Color foreground) => _fixed ?? foreground;
}

typedef Mark = ({MarkStyle style, MarkColor color});
typedef WordMarks = ({Mark? line, Mark? shape});
const WordMarks noMarks = (line: null, shape: null);

extension WordMarksAccess on WordMarks {
  Mark? of(MarkKind kind) => kind == MarkKind.line ? line : shape;
  WordMarks withMark(MarkKind kind, Mark? mark) => kind == MarkKind.line
      ? (line: mark, shape: shape)
      : (line: line, shape: mark);
  bool get isEmpty => line == null && shape == null;
}

class MarkAction {
  MarkAction(this.key, this.kind, this.mark)
    : uuid = const Uuid().v4(),
      createdAt = DateTime.now().toUtc().millisecondsSinceEpoch {
    if (mark != null && mark!.style.kind != kind) {
      throw ArgumentError('${mark!.style} is not a $kind mark');
    }
  }
  final String key;
  final MarkKind kind;
  final Mark? mark;
  final String uuid;
  final int createdAt;
}

enum MarkTool {
  visible(null),
  singleLine(MarkStyle.singleLine),
  doubleLine(MarkStyle.doubleLine),
  rectangle(MarkStyle.rectangle),
  circle(MarkStyle.circle);

  const MarkTool(this.style);
  final MarkStyle? style;
  MarkTool? get partner => switch (this) {
    visible => null,
    singleLine => doubleLine,
    doubleLine => singleLine,
    rectangle => circle,
    circle => rectangle,
  };
}

class ToolbarPrefs {
  const ToolbarPrefs({
    this.tools = const [MarkTool.visible],
    this.color = MarkColor.red,
    this.spot,
    this.pinned = false,
    this.hidden = false,
  });

  final List<MarkTool> tools;
  final MarkColor color;
  final Offset? spot;
  final bool pinned, hidden;

  ToolbarPrefs copyWith({
    List<MarkTool>? tools,
    MarkColor? color,
    Offset? spot,
    bool? pinned,
    bool? hidden,
  }) => ToolbarPrefs(
    tools: tools ?? this.tools,
    color: color ?? this.color,
    spot: spot ?? this.spot,
    pinned: pinned ?? this.pinned,
    hidden: hidden ?? this.hidden,
  );

  ToolbarPrefs toggle(MarkTool tool) {
    if (tools.contains(tool)) {
      return copyWith(tools: [...tools]..remove(tool));
    }
    return copyWith(
      tools: [
        for (final other in tools)
          if (other != tool.partner) other,
        tool,
      ],
    );
  }

  String encode() => jsonEncode({
    'tools': [for (final tool in tools) tool.name],
    'color': color.name,
    if (spot != null) 'spot': [spot!.dx, spot!.dy],
    'pinned': pinned,
    'hidden': hidden,
  });

  static ToolbarPrefs decode(String? text) {
    try {
      final json = jsonDecode(text!) as Map<String, dynamic>;
      final tools = <MarkTool>[];
      for (final name in json['tools'] as List) {
        final tool = MarkTool.values.byName(name as String);
        if (!tools.contains(tool) && !tools.contains(tool.partner)) {
          tools.add(tool);
        }
      }
      final spot = json['spot'] as List?;
      final x = (spot?[0] as num?)?.toDouble(),
          y = (spot?[1] as num?)?.toDouble();
      return ToolbarPrefs(
        tools: tools,
        color: MarkColor.values.byName(json['color'] as String),
        spot: x != null && y != null && _fraction(x) && _fraction(y)
            ? Offset(x, y)
            : null,
        pinned: json['pinned'] == true,
        hidden: json['hidden'] == true,
      );
    } catch (_) {
      return const ToolbarPrefs();
    }
  }

  static bool _fraction(double value) => value >= 0 && value <= 1;
}

abstract class ToolbarSettings {
  ToolbarPrefs get toolbar;
  Future<void> saveToolbar(ToolbarPrefs prefs);
}
