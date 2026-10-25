import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_tokens.dart';

/// Border of a Darwin text field: a rounded filled shape with no outline at
/// rest; [borderSide] draws a ring all around (macOS focus ring, error edge).
///
/// It reports [isOutline] `false`, so the `InputDecorator` keeps the label
/// inside the fill (like a filled field) instead of notching it into the
/// top edge as `OutlineInputBorder` does.
class GlassFieldBorder extends InputBorder {
  const GlassFieldBorder({
    super.borderSide = BorderSide.none,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(GlassTokens.inputRadius),
    ),
  });

  final BorderRadius borderRadius;

  @override
  bool get isOutline => false;

  @override
  GlassFieldBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
  }) =>
      GlassFieldBorder(
        borderSide: borderSide ?? this.borderSide,
        borderRadius: borderRadius ?? this.borderRadius,
      );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  GlassFieldBorder scale(double t) => GlassFieldBorder(
        borderSide: borderSide.scale(t),
        borderRadius: borderRadius * t,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(
      borderRadius
          .resolve(textDirection)
          .toRRect(rect)
          .deflate(borderSide.strokeInset),
    );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.resolve(textDirection).toRRect(rect));

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawRRect(borderRadius.resolve(textDirection).toRRect(rect), paint);
  }

  @override
  bool get preferPaintInterior => true;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is GlassFieldBorder) {
      return GlassFieldBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is GlassFieldBorder) {
      return GlassFieldBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none || borderSide.width == 0) return;
    // The ring sits inside the shape, so it never grows the field.
    final rrect = borderRadius
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(borderSide.width / 2);
    canvas.drawRRect(rrect, borderSide.toPaint());
  }

  @override
  bool operator ==(Object other) =>
      other is GlassFieldBorder &&
      other.borderSide == borderSide &&
      other.borderRadius == borderRadius;

  @override
  int get hashCode => Object.hash(borderSide, borderRadius);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'GlassFieldBorder')}($borderSide, $borderRadius)';
}
