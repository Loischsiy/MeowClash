import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_context_menu.dart';
import 'glass_accessibility.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// A single-choice control in the style of an Apple pop-up button: a filled
/// rounded field showing [label] and the current value with the
/// `chevron.up.chevron.down` symbol. Tapping it opens the choices with a
/// checkmark at the current one:
///
/// * macOS: a native `NSMenu` with the current item laid over the control,
///   as `NSPopUpButton` does (the Flutter glass menu when the channel is
///   missing);
/// * iOS: the glass menu next to the control, scrolling for long lists.
///
/// [errorText] (e.g. from a `FormField`) shows below in the error color.
/// Darwin only; Material screens keep their `DropdownMenu`.
class GlassPopUpButton<T> extends StatefulWidget {
  const GlassPopUpButton({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.textBuilder,
    required this.onChanged,
    this.errorText,
  });

  final String label;

  /// `null` shows no value (nothing chosen yet).
  final T? value;
  final List<T> options;
  final String Function(T option) textBuilder;

  /// `null` disables the control.
  final ValueChanged<T>? onChanged;
  final String? errorText;

  @override
  State<GlassPopUpButton<T>> createState() => _GlassPopUpButtonState<T>();
}

class _GlassPopUpButtonState<T> extends State<GlassPopUpButton<T>> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onChanged != null && widget.options.isNotEmpty;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  List<AdaptiveMenuEntry> get _entries {
    final onChanged = widget.onChanged;
    return [
      for (final option in widget.options)
        AdaptiveMenuEntry(
          label: widget.textBuilder(option),
          checked: option == widget.value,
          onPressed: onChanged == null ? null : () => onChanged(option),
        ),
    ];
  }

  Future<void> _open() async {
    final box = context.findRenderObject() as RenderBox?;
    if (!_enabled || box == null || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final entries = _entries;
    final shown = await AdaptiveContextMenu.showNative(
      anchor: anchor,
      entries: entries,
      popUp: true,
    );
    if (shown || !mounted) return;
    await AdaptiveContextMenu.showGlass(
      context: context,
      anchor: anchor,
      entries: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final accessibility = GlassAccessibility.of(context);
    final enabled = _enabled;
    final disabled =
        scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity);
    final text = GlassTextStyles.inputText(theme.textTheme);
    final value = widget.value;
    final errorText = widget.errorText;

    var fill = scheme.onSurface
        .withValues(alpha: GlassTokens.inputFillOpacity(brightness));
    if (enabled && (_pressed || _hovered)) {
      fill = Color.alphaBlend(
        scheme.onSurface.withValues(
          alpha: _pressed
              ? GlassTokens.menuPressedOpacity(brightness)
              : GlassTokens.hoverOpacity(brightness),
        ),
        fill,
      );
    }
    final BorderSide side;
    if (errorText != null) {
      side = BorderSide(
        color: scheme.error,
        width: GlassTokens.inputErrorWidth,
      );
    } else if (_focused) {
      side = BorderSide(
        color:
            scheme.primary.withValues(alpha: GlassTokens.inputFocusOpacityMac),
        width: GlassTokens.inputFocusWidthMac,
      );
    } else {
      side = BorderSide.none;
    }

    final valueText = value == null ? '' : widget.textBuilder(value);
    final field = AnimatedContainer(
      duration: GlassTokens.motion(
        GlassTokens.hoverDuration,
        reduceMotion: accessibility.reduceMotion,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: GlassTokens.inputHorizontalPadding,
        vertical: mac
            ? GlassTokens.inputVerticalPaddingMac
            : GlassTokens.inputVerticalPaddingIos,
      ),
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(GlassTokens.inputRadius),
          side: side,
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.copyWith(
                color: enabled ? scheme.onSurfaceVariant : disabled,
              ),
            ),
          ),
          const SizedBox(width: GlassTokens.listRowTrailingGap),
          Expanded(
            flex: 2,
            child: Text(
              valueText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: text.copyWith(
                // iOS menu pickers show the value in the accent.
                color: !enabled
                    ? disabled
                    : mac
                        ? scheme.onSurface
                        : scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: GlassTokens.buttonIconGap),
          Icon(
            Icons.unfold_more_rounded,
            size: mac
                ? GlassTokens.listRowChevronSizeMac
                : GlassTokens.listRowChevronSizeIos,
            color: !enabled
                ? disabled
                : mac
                    ? scheme.onSurfaceVariant
                    : scheme.primary,
          ),
        ],
      ),
    );

    Widget control = FocusableActionDetector(
      enabled: enabled,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _open();
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
        onTap: enabled ? _open : null,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: field,
      ),
    );
    control = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      value: valueText,
      child: control,
    );
    if (errorText == null) return control;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        control,
        Padding(
          padding: const EdgeInsets.only(
            left: GlassTokens.inputHorizontalPadding,
            right: GlassTokens.inputHorizontalPadding,
            top: GlassTokens.listSectionFooterGap,
          ),
          child: Text(
            errorText,
            style: GlassTextStyles.listSectionFooter(theme.textTheme)
                .copyWith(color: scheme.error),
          ),
        ),
      ],
    );
  }
}
