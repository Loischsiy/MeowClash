import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_accessibility.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// A small capsule label inside long lists (proxy chain, log level) and the
/// removable keyword filter above them.
///
/// Never blurred: a faint neutral wash, or a wash of [color] (accent or a
/// system color) with the label in that color. With Reduce Transparency the
/// wash is mixed into the window color, so it stays the same shade but opaque.
///
/// Darwin only; Material screens keep `CommonChip`.
class GlassTag extends StatefulWidget {
  const GlassTag({
    super.key,
    required this.label,
    this.color,
    this.onPressed,
    this.onRemove,
    this.large = false,
  });

  final String label;

  /// `null` = neutral (secondary label on a gray wash).
  final Color? color;

  final VoidCallback? onPressed;

  /// Shows a trailing ✕; tapping the capsule then removes it.
  final VoidCallback? onRemove;

  /// The keyword filter size.
  final bool large;

  /// Height of the capsule on the current platform.
  static double heightOf({bool large = false}) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    if (large) {
      return mac
          ? GlassTokens.tagLargeHeightMac
          : GlassTokens.tagLargeHeightIos;
    }
    return mac ? GlassTokens.tagHeightMac : GlassTokens.tagHeightIos;
  }

  @override
  State<GlassTag> createState() => _GlassTagState();
}

class _GlassTagState extends State<GlassTag> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  VoidCallback? get _action => widget.onRemove ?? widget.onPressed;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final large = widget.large;
    final tint = widget.color;
    final base = tint ?? scheme.onSurface;
    var opacity = tint == null
        ? GlassTokens.tagFillOpacity(brightness)
        : GlassTokens.tagTintOpacity(brightness);
    if (_action != null && _pressed) {
      opacity += GlassTokens.menuPressedOpacity(brightness);
    } else if (_action != null && _hovered) {
      opacity += GlassTokens.hoverOpacity(brightness);
    }
    final wash = base.withValues(alpha: opacity);
    final fill =
        accessibility.opaque ? Color.alphaBlend(wash, scheme.surface) : wash;
    final foreground = tint ?? scheme.onSurfaceVariant;
    final height = GlassTag.heightOf(large: large);
    final padding = large
        ? _mac
            ? GlassTokens.tagLargePaddingMac
            : GlassTokens.tagLargePaddingIos
        : _mac
            ? GlassTokens.tagPaddingMac
            : GlassTokens.tagPaddingIos;
    final style = GlassTextStyles.tag(theme.textTheme, large: large)
        .copyWith(color: foreground);
    final remove = widget.onRemove != null;

    Widget tag = AnimatedContainer(
      duration: GlassTokens.motion(
        GlassTokens.hoverDuration,
        reduceMotion: accessibility.reduceMotion,
      ),
      height: height,
      padding: EdgeInsetsDirectional.only(
        start: padding,
        end: remove ? padding - GlassTokens.tagRemoveGap : padding,
      ),
      decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          ),
          if (remove) ...[
            const SizedBox(width: GlassTokens.tagRemoveGap),
            Icon(
              Icons.close_rounded,
              size: _mac
                  ? GlassTokens.tagRemoveIconSizeMac
                  : GlassTokens.tagRemoveIconSizeIos,
              color: foreground,
            ),
          ],
        ],
      ),
    );
    final action = _action;
    if (action == null) return tag;
    tag = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: tag,
      ),
    );
    return Semantics(
      button: true,
      label: remove
          ? '${widget.label}, ${MaterialLocalizations.of(context).deleteButtonTooltip}'
          : null,
      excludeSemantics: remove,
      child: tag,
    );
  }
}
