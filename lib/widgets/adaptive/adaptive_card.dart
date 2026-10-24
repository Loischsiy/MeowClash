import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meowclash/widgets/card.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_tokens.dart';

/// A tappable content card inside scrolling lists and grids (proxy nodes).
///
/// * Darwin: a translucent rounded card with a hairline edge, **no blur** —
///   it scrolls, and a grid can hold hundreds of them. The selected card is
///   tinted with the accent and outlined; [checked] adds a check badge in the
///   top-end corner. macOS gets a hover wash, keyboard focus gets an accent
///   outline, and Reduce Transparency makes the fill opaque.
/// * Everything else: `CommonCard`, unchanged.
class AdaptiveCard extends StatelessWidget {
  const AdaptiveCard({
    super.key,
    required this.child,
    this.isSelected = false,
    bool? checked,
    this.checkAlignment = AlignmentDirectional.topEnd,
    this.onPressed,
    this.onLongPress,
  }) : checked = checked ?? isSelected;

  final Widget child;
  final bool isSelected;

  /// Shows the check badge (Darwin only). Defaults to [isSelected].
  final bool checked;

  /// Where the check badge sits; `centerEnd` suits one-line cards.
  final AlignmentDirectional checkAlignment;

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return CommonCard(
        onPressed: onPressed,
        onLongPress: onLongPress,
        isSelected: isSelected,
        child: child,
      );
    }
    return _GlassCard(
      isSelected: isSelected,
      checked: checked,
      checkAlignment: checkAlignment,
      onPressed: onPressed,
      onLongPress: onLongPress,
      child: child,
    );
  }
}

class _GlassCard extends StatefulWidget {
  const _GlassCard({
    required this.child,
    required this.isSelected,
    required this.checked,
    required this.checkAlignment,
    required this.onPressed,
    required this.onLongPress,
  });

  final Widget child;
  final bool isSelected;
  final bool checked;
  final AlignmentDirectional checkAlignment;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final dark = brightness == Brightness.dark;
    final accessibility = GlassAccessibility.of(context);
    final opaque = accessibility.opaque;
    final accent = scheme.primary;

    final base = dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
    var fill = opaque
        ? base
        : base.withValues(alpha: GlassTokens.cardFillOpacity(brightness));
    if (widget.isSelected) {
      fill = Color.alphaBlend(
        accent.withValues(
          alpha: opaque
              ? GlassTokens.selectionOpacityOpaque
              : GlassTokens.cardSelectedOpacity(brightness),
        ),
        fill,
      );
    }
    if (_pressed || _hovered) {
      fill = Color.alphaBlend(
        scheme.onSurface.withValues(
          alpha: _pressed
              ? GlassTokens.menuPressedOpacity(brightness)
              : GlassTokens.hoverOpacity(brightness),
        ),
        fill,
      );
    }
    final side = widget.isSelected || _focused
        ? BorderSide(
            color: accent,
            width: GlassTokens.cardSelectedBorderWidth,
          )
        : BorderSide(
            color: (dark ? Colors.white : Colors.black)
                .withValues(alpha: GlassTokens.hairlineOpacity(brightness)),
            width: GlassTokens.hairlineWidth,
          );

    var content = widget.child;
    if (widget.checked) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(GlassTokens.cardCheckInset),
              child: Align(
                alignment: widget.checkAlignment,
                child: _CheckBadge(color: accent, onColor: scheme.onPrimary),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: _enabled,
      selected: widget.isSelected,
      child: FocusableActionDetector(
        enabled: _enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        onShowHoverHighlight: (value) {
          if (_hovered != value) setState(() => _hovered = value);
        },
        onShowFocusHighlight: (value) {
          if (_focused != value) setState(() => _focused = value);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          child: AnimatedContainer(
            duration: GlassTokens.motion(
              GlassTokens.hoverDuration,
              reduceMotion: accessibility.reduceMotion,
            ),
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(GlassTokens.cardRadius),
                side: side,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.color, required this.onColor});

  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: GlassTokens.cardCheckSize,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(
            CupertinoIcons.checkmark_alt,
            size: GlassTokens.cardCheckIconSize,
            color: onColor,
          ),
        ),
      );
}
