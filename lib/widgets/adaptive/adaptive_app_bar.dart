import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// Background of a page's top bar.
///
/// Wraps an `AppBar` whose own background is transparent on Darwin
/// (`GlassTheme.apply`):
/// * iOS: a glass navigation bar (one `BackdropFilter`) with a hairline.
/// * macOS: the unified window toolbar. It extends under the transparent
///   title bar (the `MediaQuery` top inset added by `WindowHeaderContainer`),
///   paints the content color with a hairline, and moves the window when
///   dragged, like a native toolbar.
/// * Everything else: returns [child] untouched.
class AdaptiveAppBar extends StatelessWidget {
  const AdaptiveAppBar({
    super.key,
    required this.child,
    this.onWindowDrag,
    this.transparent = false,
  });

  final Widget child;

  /// macOS: starts a native window drag (`windowManager.startDragging`).
  final VoidCallback? onWindowDrag;

  /// Keep the bar see-through (e.g. over a custom page background image).
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) return child;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final hairline = BorderSide(
      color: (brightness == Brightness.dark ? Colors.white : Colors.black)
          .withValues(alpha: GlassTokens.hairlineOpacity(brightness)),
      width: GlassTokens.hairlineWidth,
    );
    final bar = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: Border(bottom: hairline)),
      child: child,
    );
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final drag = onWindowDrag;
      final toolbar = transparent
          ? bar
          : ColoredBox(color: theme.scaffoldBackgroundColor, child: bar);
      if (drag == null) return toolbar;
      // Translucent detector on top: taps still reach the bar's buttons and
      // win the arena; only a real drag moves the window.
      return Stack(
        children: [
          toolbar,
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => drag(),
            ),
          ),
        ],
      );
    }
    if (transparent) return bar;
    return GlassSurface(
      sigma: GlassTokens.barSigma,
      rim: false,
      child: bar,
    );
  }
}
