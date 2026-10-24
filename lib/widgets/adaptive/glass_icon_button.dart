import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'glass_accessibility.dart';
import 'glass_tokens.dart';

/// A round, borderless symbol button for Darwin glass chrome and cards: no
/// ripple, a faint wash on hover / press, the accent for the symbol.
///
/// Darwin only; callers keep their Material `IconButton` on other platforms.
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = GlassTokens.groupHeaderButtonSize,
    this.iconSize = GlassTokens.groupHeaderButtonIconSize,
    this.busy = false,
    this.tooltip,
  });

  /// Usually an `Icon` with a `CupertinoIcons` symbol; its size and color come
  /// from this button.
  final Widget icon;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  /// Replaces the symbol with a spinner (and disables the button).
  final bool busy;

  final String? tooltip;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final wash = _enabled && (_pressed || _hovered)
        ? scheme.onSurface.withValues(
            alpha: _pressed
                ? GlassTokens.menuPressedOpacity(brightness)
                : GlassTokens.hoverOpacity(brightness),
          )
        : scheme.onSurface.withValues(alpha: 0);
    final foreground = _enabled
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(
            alpha: widget.busy ? 1 : GlassTokens.disabledOpacity,
          );
    Widget button = Semantics(
      button: true,
      enabled: _enabled,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? widget.onPressed : null,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          child: AnimatedContainer(
            duration: GlassTokens.motion(
              GlassTokens.hoverDuration,
              reduceMotion: accessibility.reduceMotion,
            ),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
            child: Center(
              child: widget.busy
                  ? CupertinoActivityIndicator(radius: widget.iconSize / 2)
                  : IconTheme.merge(
                      data: IconThemeData(
                        size: widget.iconSize,
                        color: foreground,
                      ),
                      child: widget.icon,
                    ),
            ),
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return button;
  }
}
