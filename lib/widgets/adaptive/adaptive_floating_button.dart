import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// The floating action of a page.
///
/// * Darwin: a round Liquid Glass button (one blurred surface) that shrinks
///   slightly while pressed and shows a spinner while [busy]. Reduce Motion
///   drops the press animation; Reduce Transparency makes it opaque.
/// * Everything else: `FloatingActionButton`, unchanged.
class AdaptiveFloatingButton extends StatefulWidget {
  const AdaptiveFloatingButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.glassIcon,
    this.busy = false,
    this.tooltip,
  });

  final VoidCallback? onPressed;

  /// Material icon.
  final Widget icon;

  /// Darwin symbol (usually a `CupertinoIcons` icon).
  final Widget glassIcon;

  /// Darwin only: replaces the symbol with a spinner and ignores taps.
  final bool busy;

  final String? tooltip;

  @override
  State<AdaptiveFloatingButton> createState() =>
      _AdaptiveFloatingButtonState();
}

class _AdaptiveFloatingButtonState extends State<AdaptiveFloatingButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return FloatingActionButton(
        heroTag: null,
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        child: widget.icon,
      );
    }
    final theme = Theme.of(context);
    final accessibility = GlassAccessibility.of(context);
    final radius =
        BorderRadius.circular(GlassTokens.floatingButtonSize / 2);
    Widget button = GlassSurface(
      sigma: GlassTokens.barSigma,
      borderRadius: radius,
      shadow: true,
      child: SizedBox.square(
        dimension: GlassTokens.floatingButtonSize,
        child: Center(
          child: widget.busy
              ? const CupertinoActivityIndicator(
                  radius: GlassTokens.activityIndicatorRadius,
                )
              : IconTheme.merge(
                  data: IconThemeData(
                    size: GlassTokens.floatingButtonIconSize,
                    color: theme.colorScheme.primary,
                  ),
                  child: widget.glassIcon,
                ),
        ),
      ),
    );
    button = AnimatedScale(
      scale: _pressed ? GlassTokens.floatingButtonPressedScale : 1,
      duration: GlassTokens.motion(
        GlassTokens.hoverDuration,
        reduceMotion: accessibility.reduceMotion,
      ),
      curve: GlassTokens.morphCurve,
      child: button,
    );
    button = Semantics(
      button: true,
      enabled: _enabled,
      label: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _enabled ? widget.onPressed : null,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        child: button,
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}
