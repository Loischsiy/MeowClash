import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass_accessibility.dart';
import 'glass_refraction.dart';
import 'glass_tokens.dart';

/// How a [GlassSurface] obtains its translucency.
enum GlassBackdrop {
  /// Blurs whatever Flutter painted below it with one `BackdropFilter`.
  /// Use for floating chrome over app content (iOS tab bar, sheets, menus).
  blur,

  /// Paints only a faint tint and lets the native AppKit glass behind the
  /// transparent Flutter view show through (macOS sidebar and title bar).
  /// Costs no `BackdropFilter` at all.
  native,
}

/// The single glass primitive of the Darwin chrome.
///
/// Layer order, outermost first: an outer-only shadow, the clip, one
/// `BackdropFilter`, the tinted fill, the child and a specular rim. There is
/// never more than one `BackdropFilter` per surface, never an `Opacity` wrapper,
/// and the surface must not be placed inside scrolling content.
///
/// When [GlassAccessibility.opaque] is set (Reduce Transparency, Increase
/// Contrast or the `GlassFlags.backdropBlurEnabled` kill switch) the surface
/// paints an opaque fill instead and skips the filter entirely.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.sigma = GlassTokens.barSigma,
    this.borderRadius = BorderRadius.zero,
    this.backdrop = GlassBackdrop.blur,
    this.color,
    this.opaqueColor,
    this.rim = true,
    this.shadow = false,
    this.shadows,
    this.refraction,
    this.tintOpacity,
    this.presence = 1,
  }) : assert(presence >= 0 && presence <= 1, 'presence is 0..1');

  final Widget child;

  /// Blur strength for [GlassBackdrop.blur]; pick one of the [GlassTokens]
  /// sigmas.
  final double sigma;

  /// Continuous (superellipse) corners, like Apple's glass shapes.
  final BorderRadius borderRadius;

  final GlassBackdrop backdrop;

  /// Base color of the tint. Defaults to the theme surface color.
  final Color? color;

  /// Fill used when glass is disabled. Defaults to the theme surface color.
  final Color? opaqueColor;

  /// Draw the 1px specular edge.
  final bool rim;

  /// Cast [GlassTokens.floatingShadow] around the shape (floating chrome).
  final bool shadow;

  /// Replaces [GlassTokens.floatingShadow] when [shadow] is set (lighter
  /// shadows of small chrome such as toolbar capsules).
  final List<BoxShadow>? shadows;

  /// Edge refraction on top of the blur, in the same single backdrop layer.
  /// Applies to [GlassBackdrop.blur] only, and only where
  /// [GlassRefractionShader.supported]; otherwise the surface keeps the plain
  /// blur. The iOS tab bar is the only user.
  final GlassRefraction? refraction;

  /// Alpha of the tint over the blur; defaults to
  /// [GlassTokens.tintOpacity]. Denser panels (dialogs) pass their own.
  final double? tintOpacity;

  /// How far the surface has appeared, 0..1. Below 1 the blur strength, the
  /// fill, the rim and the shadow scale down together, so a surface can fade
  /// in without an `Opacity` above its `BackdropFilter` (which would hide the
  /// blur until the fade ends). Fade the child separately, inside the
  /// surface.
  final double presence;

  /// Whether [context] is painted inside a [GlassSurface] that blurs.
  ///
  /// Small glass inside it (e.g. toolbar capsules of a page shown in a glass
  /// sheet) must not blur again: no blur inside a blurred surface.
  static bool isOverBlur(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassBlurScope>()?.blurs ??
      false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final opaque = accessibility.opaque;
    final base = color ?? theme.colorScheme.surface;
    final Color fill;
    if (opaque) {
      final solid = opaqueColor ?? theme.colorScheme.surface;
      fill = presence == 1 ? solid : solid.withValues(alpha: solid.a * presence);
    } else {
      final alpha = switch (backdrop) {
        GlassBackdrop.blur => tintOpacity ?? GlassTokens.tintOpacity(brightness),
        GlassBackdrop.native => GlassTokens.nativeBackdropTint(brightness),
      };
      fill = base.withValues(alpha: alpha * presence);
    }
    final sigma = this.sigma * presence;

    Widget surface = CustomPaint(
      painter: _GlassFillPainter(color: fill, borderRadius: borderRadius),
      foregroundPainter: rim
          ? _GlassRimPainter(
              borderRadius: borderRadius,
              brightness: brightness,
              opaque: opaque,
              presence: presence,
            )
          : null,
      // Always present, so toggling [opaque] keeps the child's state.
      child: _GlassBlurScope(
        blurs: !opaque && backdrop == GlassBackdrop.blur,
        child: child,
      ),
    );

    final refraction = this.refraction;
    if (!opaque &&
        backdrop == GlassBackdrop.blur &&
        refraction != null &&
        GlassRefractionShader.supported) {
      // Until the program has loaded, [GlassRefractionBackdrop] is the same
      // plain blur, so the widget tree does not change when it arrives.
      surface = ValueListenableBuilder<ui.FragmentProgram?>(
        valueListenable: GlassRefractionShader.program,
        builder: (context, program, child) => GlassRefractionBackdrop(
          program: program,
          sigma: sigma,
          radius: borderRadius.topLeft.x,
          refraction: refraction,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          child: child,
        ),
        child: surface,
      );
    } else if (!opaque && backdrop == GlassBackdrop.blur) {
      // `grouped` shares one backdrop read with sibling surfaces when an
      // ancestor [BackdropGroup] exists, and behaves like the plain
      // constructor otherwise.
      surface = BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
        child: surface,
      );
    }

    surface = borderRadius == BorderRadius.zero
        ? ClipRect(child: surface)
        : ClipRSuperellipse(borderRadius: borderRadius, child: surface);

    if (shadow) {
      surface = CustomPaint(
        painter: _OuterShadowPainter(
          borderRadius: borderRadius,
          shadows: _scaled(
            shadows ?? GlassTokens.floatingShadow(brightness),
            presence,
          ),
        ),
        child: surface,
      );
    }
    return surface;
  }
}

List<BoxShadow> _scaled(List<BoxShadow> shadows, double presence) {
  if (presence == 1) return shadows;
  return [
    for (final shadow in shadows)
      shadow.copyWith(color: shadow.color.withValues(alpha: shadow.color.a * presence)),
  ];
}

class _GlassBlurScope extends InheritedWidget {
  const _GlassBlurScope({required this.blurs, required super.child});

  final bool blurs;

  @override
  bool updateShouldNotify(_GlassBlurScope oldWidget) =>
      oldWidget.blurs != blurs;
}

ui.RSuperellipse _shape(Rect rect, BorderRadius radius) =>
    radius.toRSuperellipse(rect);

class _GlassFillPainter extends CustomPainter {
  const _GlassFillPainter({required this.color, required this.borderRadius});

  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final paint = Paint()..color = color;
    if (borderRadius == BorderRadius.zero) {
      canvas.drawRect(Offset.zero & size, paint);
    } else {
      canvas.drawRSuperellipse(_shape(Offset.zero & size, borderRadius), paint);
    }
  }

  @override
  bool shouldRepaint(_GlassFillPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
}

/// A 1px edge that is brighter at the top, as light catches real glass.
class _GlassRimPainter extends CustomPainter {
  const _GlassRimPainter({
    required this.borderRadius,
    required this.brightness,
    required this.opaque,
    this.presence = 1,
  });

  final BorderRadius borderRadius;
  final Brightness brightness;
  final bool opaque;
  final double presence;

  @override
  void paint(Canvas canvas, Size size) {
    if (presence == 0) return;
    const width = GlassTokens.rimWidth;
    final rect = (Offset.zero & size).deflate(width / 2);
    Color top;
    Color bottom;
    if (opaque) {
      // Opaque fallback keeps a plain hairline so the shape stays readable.
      top = bottom = (brightness == Brightness.dark
              ? Colors.white
              : Colors.black)
          .withValues(alpha: GlassTokens.hairlineOpacity(brightness));
    } else {
      top = Colors.white
          .withValues(alpha: GlassTokens.rimTopOpacity(brightness));
      bottom = Colors.white
          .withValues(alpha: GlassTokens.rimBottomOpacity(brightness));
    }
    if (presence < 1) {
      top = top.withValues(alpha: top.a * presence);
      bottom = bottom.withValues(alpha: bottom.a * presence);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
    if (borderRadius == BorderRadius.zero) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRSuperellipse(_shape(rect, borderRadius), paint);
    }
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.brightness != brightness ||
      oldDelegate.opaque != opaque ||
      oldDelegate.presence != presence;
}

/// Paints shadows outside the shape only, so they never darken the glass.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({
    required this.borderRadius,
    required this.shadows,
  });

  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    canvas.save();
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(_maxExtent))
      ..addRRect(rrect);
    canvas.clipPath(outside);
    for (final shadow in shadows) {
      final paint = shadow.toPaint();
      final shadowRect = rect.shift(shadow.offset).inflate(shadow.spreadRadius);
      canvas.drawRRect(borderRadius.toRRect(shadowRect), paint);
    }
    canvas.restore();
  }

  double get _maxExtent {
    var extent = 0.0;
    for (final shadow in shadows) {
      final reach = shadow.blurRadius * 2 +
          shadow.spreadRadius +
          shadow.offset.distance;
      if (reach > extent) extent = reach;
    }
    return extent;
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.shadows != shadows;
}
