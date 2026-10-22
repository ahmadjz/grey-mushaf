import 'package:flutter/widgets.dart';

/// Recolour QUL V4's default palette without changing the source font.
///
/// The pale marker field (#D8E9D8) is opaque, so srcIn alone hides the
/// numeral. Separate that field from ink before mapping ink to black/grey.
/// All supplied ink colours have mean RGB below .75; the field is above .80.
class FlatInk extends StatelessWidget {
  const FlatInk({
    super.key,
    required this.color,
    required this.child,
    this.background = const Color(0xFFFFFFFF),
  });
  final Color color;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grey = (color.toARGB32() & 255).toDouble();
    final scale = ((background.toARGB32() & 255) - grey) / 255;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        scale,
        0,
        0,
        0,
        grey,
        0,
        scale,
        0,
        0,
        grey,
        0,
        0,
        scale,
        0,
        grey,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          20 / 3,
          20 / 3,
          20 / 3,
          0,
          -3825,
          20 / 3,
          20 / 3,
          20 / 3,
          0,
          -3825,
          20 / 3,
          20 / 3,
          20 / 3,
          0,
          -3825,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      ),
    );
  }
}
