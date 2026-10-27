import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// The floating action of a page.
///
/// * Darwin: a round Liquid Glass button (one blurred surface) that shrinks
///   slightly while pressed and shows a spinner while [busy]; a capsule with
///   the symbol and [label] when there is one. Reduce Motion drops the press
///   animation; Reduce Transparency makes it opaque. [prominent] tints the
///   glass with the accent and draws the symbol in `onPrimary` (the primary
///   action of a page, like `.glassProminent`): plain glass all but vanishes
///   over a dark, empty page.
/// * Everything else: `FloatingActionButton` (`.extended` with a [label]),
///   unchanged.
class AdaptiveFloatingButton extends StatefulWidget {
  const AdaptiveFloatingButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.glassIcon,
    this.busy = false,
    this.tooltip,
    this.label,
    this.prominent = false,
  });

  /// Darwin only: accent-tinted glass with an `onPrimary` symbol.
  final bool prominent;

  /// Text next to the icon (extended button / capsule).
  final String? label;

  final VoidCallback? onPressed;

  /// Material icon.
  final Widget icon;

  /// Darwin symbol (a rounded Material icon; `cupertino_icons` is not bundled).
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
    final label = widget.label;
    if (!AdaptivePlatform.useGlass) {
      if (label != null) {
        return FloatingActionButton.extended(
          heroTag: null,
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
          label: Text(label),
          icon: widget.icon,
        );
      }
      return FloatingActionButton(
        heroTag: null,
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        child: widget.icon,
      );
    }
    final theme = Theme.of(context);
    final accessibility = GlassAccessibility.of(context);
    final scheme = theme.colorScheme;
    final prominent = widget.prominent;
    final foreground = prominent ? scheme.onPrimary : scheme.primary;
    final radius =
        BorderRadius.circular(GlassTokens.floatingButtonSize / 2);
    final symbol = widget.busy
        ? CupertinoActivityIndicator(
            radius: GlassTokens.activityIndicatorRadius,
            color: prominent ? foreground : null,
          )
        : IconTheme.merge(
            data: IconThemeData(
              size: GlassTokens.floatingButtonIconSize,
              color: foreground,
            ),
            child: widget.glassIcon,
          );
    Widget button = GlassSurface(
      sigma: GlassTokens.barSigma,
      borderRadius: radius,
      shadow: true,
      color: prominent ? scheme.primary : null,
      opaqueColor: prominent ? scheme.primary : null,
      tintOpacity:
          prominent ? GlassTokens.floatingButtonProminentTintOpacity : null,
      child: label == null
          ? SizedBox.square(
              dimension: GlassTokens.floatingButtonSize,
              child: Center(child: symbol),
            )
          : SizedBox(
              height: GlassTokens.floatingButtonSize,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GlassTokens.floatingButtonLabelPadding,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    symbol,
                    const SizedBox(width: GlassTokens.floatingButtonLabelGap),
                    Text(
                      label,
                      maxLines: 1,
                      style: GlassTextStyles.floatingButtonLabel(
                        theme.textTheme,
                      ).copyWith(color: foreground),
                    ),
                  ],
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
      label: widget.tooltip ?? label,
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
