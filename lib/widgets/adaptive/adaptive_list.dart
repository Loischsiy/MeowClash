import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_text_styles.dart';
import 'glass_theme.dart';
import 'glass_tokens.dart';

// Content-level primitives of Darwin forms and grouped lists (profile
// editors; later Settings). Everything here scrolls, so nothing blurs: the
// sections are flat translucent cards like `AdaptiveCard`.

bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

double get _rowPadding =>
    _mac ? GlassTokens.listRowPaddingMac : GlassTokens.listRowPaddingIos;

double get _leadingSize => _mac
    ? GlassTokens.listRowLeadingSizeMac
    : GlassTokens.listRowLeadingSizeIos;

double get _leadingGap =>
    _mac ? GlassTokens.listRowLeadingGapMac : GlassTokens.listRowLeadingGapIos;

Color _systemRed(Brightness brightness) => brightness == Brightness.dark
    ? CupertinoColors.systemRed.darkColor
    : CupertinoColors.systemRed.color;

/// On/off switch.
///
/// * Darwin: `CupertinoSwitch` in the accent; on macOS scaled down to the
///   AppKit switch size.
/// * Everything else: Material `Switch`, unchanged.
class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;

  /// `null` disables the switch.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return Switch(value: value, onChanged: onChanged);
    }
    final Widget control = CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: Theme.of(context).colorScheme.primary,
    );
    if (!_mac) return control;
    return SizedBox(
      height: GlassTokens.switchBoxHeightIos *
          GlassTokens.switchTrackHeightMac /
          GlassTokens.switchTrackHeightIos,
      child: FittedBox(child: control),
    );
  }
}

/// Header line above a [GlassListSection], lined up with the row text; an
/// optional [trailing] control (e.g. a [GlassButton]) sits at its end.
///
/// Darwin only.
class GlassSectionHeader extends StatelessWidget {
  const GlassSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = GlassTextStyles.listSectionHeader(theme.textTheme).copyWith(
      color: _mac ? scheme.onSurface : scheme.onSurfaceVariant,
    );
    final trailing = this.trailing;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: _rowPadding,
        end: trailing == null ? _rowPadding : 0,
        bottom: GlassTokens.listSectionHeaderGap,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: style),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: GlassTokens.listRowTrailingGap),
            trailing,
          ],
        ],
      ),
    );
  }
}

/// A group of rows in one rounded inset card, as the grouped lists of iOS
/// Settings and macOS System Settings: optional [header] above, [footer]
/// below, hairlines between the rows starting at the row text.
///
/// Flat translucent fill, no blur; opaque with Reduce Transparency or the
/// blur kill switch. Darwin only.
class GlassListSection extends StatelessWidget {
  const GlassListSection({
    super.key,
    required this.children,
    this.header,
    this.headerTrailing,
    this.footer,
    this.dividerInset,
  });

  /// Usually [GlassListRow]s.
  final List<Widget> children;
  final String? header;

  /// Control at the end of the header line.
  final Widget? headerTrailing;
  final String? footer;

  /// Start of the hairlines between rows; defaults to the row text (after
  /// the leading symbol when a [GlassListRow] has one).
  final double? dividerInset;

  /// Space to leave between two sections.
  static double get gap =>
      _mac ? GlassTokens.listSectionGapMac : GlassTokens.listSectionGapIos;

  /// Horizontal inset of row content (for content laid out like a row).
  static double get rowPadding => _rowPadding;

  /// Padding of a scroll view that lays out sections.
  static EdgeInsets get listPadding => _mac
      ? const EdgeInsets.symmetric(
          horizontal: GlassTokens.listInsetMac,
          vertical: GlassTokens.listInsetVerticalMac,
        )
      : const EdgeInsets.symmetric(
          horizontal: GlassTokens.listInsetIos,
          vertical: GlassTokens.listInsetVerticalIos,
        );

  double get _dividerInset {
    final inset = dividerInset;
    if (inset != null) return inset;
    final hasLeading =
        children.any((child) => child is GlassListRow && child.leading != null);
    return hasLeading ? _rowPadding + _leadingSize + _leadingGap : _rowPadding;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final dark = brightness == Brightness.dark;
    final opaque = GlassAccessibility.of(context).opaque;
    final base =
        dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
    final fill = opaque
        ? base
        : base.withValues(alpha: GlassTokens.cardFillOpacity(brightness));
    final edge = (dark ? Colors.white : Colors.black)
        .withValues(alpha: GlassTokens.cardHairlineOpacity(brightness));
    final separatorColor = scheme.onSurface
        .withValues(alpha: GlassTokens.hairlineOpacity(brightness));
    final radius = BorderRadius.circular(
      _mac
          ? GlassTokens.listSectionRadiusMac
          : GlassTokens.listSectionRadiusIos,
    );
    final separator = Padding(
      padding: EdgeInsetsDirectional.only(start: _dividerInset),
      child: SizedBox(
        height: GlassTokens.hairlineWidth,
        child: ColoredBox(color: separatorColor),
      ),
    );

    final header = this.header;
    final footer = this.footer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          GlassSectionHeader(title: header, trailing: headerTrailing),
        if (children.isNotEmpty)
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: edge,
                  width: GlassTokens.hairlineWidth,
                ),
              ),
            ),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(borderRadius: radius),
              ),
              child: ClipRSuperellipse(
                borderRadius: radius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) separator,
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.only(
              left: _rowPadding,
              right: _rowPadding,
              top: GlassTokens.listSectionFooterGap,
            ),
            child: Text(
              footer,
              style: GlassTextStyles.listSectionFooter(theme.textTheme)
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// What a [GlassListRow] shows at its trailing edge after [GlassListRow.trailing].
enum GlassRowAccessory {
  none,

  /// Opens a page, sheet or dialog.
  chevron,

  /// The row is the current choice of a single-choice list.
  checkmark,
}

/// One row of a [GlassListSection]: leading symbol, title, optional
/// subtitle, trailing control and accessory. A hover / press wash when
/// tappable; no ripple. Darwin only.
class GlassListRow extends StatefulWidget {
  const GlassListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.accessory = GlassRowAccessory.none,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
  });

  /// Usually a `Text`; styled by the row.
  final Widget title;
  final Widget? subtitle;

  /// Usually an `Icon`; drawn in the accent at the row symbol size.
  final Widget? leading;

  /// A control (switch, button) or a secondary value text.
  final Widget? trailing;
  final GlassRowAccessory accessory;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Reported to accessibility (single-choice lists).
  final bool selected;
  final bool enabled;

  @override
  State<GlassListRow> createState() => _GlassListRowState();
}

class _GlassListRowState extends State<GlassListRow> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final enabled = widget.enabled;
    final disabled =
        scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity);

    final double washOpacity;
    if (!_interactive) {
      washOpacity = 0;
    } else if (_pressed) {
      washOpacity = GlassTokens.menuPressedOpacity(brightness);
    } else if (_hovered) {
      washOpacity = GlassTokens.hoverOpacity(brightness);
    } else {
      washOpacity = 0;
    }
    final wash = _focused && _interactive
        ? scheme.primary
            .withValues(alpha: GlassTokens.selectionOpacity(brightness))
        : scheme.onSurface.withValues(alpha: washOpacity);

    final titleStyle = GlassTextStyles.listRowTitle(theme.textTheme)
        .copyWith(color: enabled ? scheme.onSurface : disabled);
    final secondaryStyle = GlassTextStyles.listRowSubtitle(theme.textTheme)
        .copyWith(color: enabled ? scheme.onSurfaceVariant : disabled);
    final chevronSize = _mac
        ? GlassTokens.listRowChevronSizeMac
        : GlassTokens.listRowChevronSizeIos;

    final leading = widget.leading;
    final subtitle = widget.subtitle;
    final trailing = widget.trailing;
    final row = Row(
      children: [
        if (leading != null) ...[
          IconTheme.merge(
            data: IconThemeData(
              size: _leadingSize,
              color: enabled ? scheme.primary : disabled,
            ),
            child: SizedBox.square(
              dimension: _leadingSize,
              child: Center(child: leading),
            ),
          ),
          SizedBox(width: _leadingGap),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(style: titleStyle, child: widget.title),
              if (subtitle != null) ...[
                const SizedBox(height: GlassTokens.listRowSubtitleGap),
                DefaultTextStyle.merge(style: secondaryStyle, child: subtitle),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: GlassTokens.listRowTrailingGap),
          DefaultTextStyle.merge(
            style: titleStyle.copyWith(color: secondaryStyle.color),
            child: trailing,
          ),
        ],
        if (widget.accessory == GlassRowAccessory.chevron) ...[
          const SizedBox(width: GlassTokens.listRowTrailingGap),
          Icon(
            Icons.chevron_right_rounded,
            size: chevronSize,
            color: scheme.onSurfaceVariant
                .withValues(alpha: GlassTokens.listRowChevronOpacity),
          ),
        ],
        if (widget.accessory == GlassRowAccessory.checkmark) ...[
          const SizedBox(width: GlassTokens.listRowTrailingGap),
          Icon(
            Icons.check_rounded,
            size: GlassTokens.optionCheckSize,
            color: enabled ? scheme.primary : disabled,
          ),
        ],
      ],
    );

    Widget content = AnimatedContainer(
      duration: GlassTokens.motion(
        GlassTokens.hoverDuration,
        reduceMotion: accessibility.reduceMotion,
      ),
      color: wash,
      constraints: BoxConstraints(
        minHeight: _mac
            ? GlassTokens.listRowMinHeightMac
            : GlassTokens.listRowMinHeightIos,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _rowPadding,
        vertical: _mac
            ? GlassTokens.listRowVerticalPaddingMac
            : GlassTokens.listRowVerticalPaddingIos,
      ),
      alignment: AlignmentDirectional.centerStart,
      child: row,
    );
    if (_interactive) {
      content = FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
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
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: content,
        ),
      );
    }
    return Semantics(
      button: _interactive,
      enabled: enabled,
      selected: widget.selected,
      child: content,
    );
  }
}

/// A row of a [GlassListSection] that holds a form control (a text field, a
/// [GlassButton]) instead of a title: padded like a [GlassListRow], with the
/// [GlassTheme.form] overlay so Material `TextFormField`s become Apple fields
/// without a Darwin branch of their own. Darwin only.
class GlassListField extends StatelessWidget {
  const GlassListField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
        data: GlassTheme.form(Theme.of(context)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _rowPadding,
            vertical: _mac
                ? GlassTokens.listRowVerticalPaddingMac
                : GlassTokens.listRowVerticalPaddingIos,
          ),
          child: child,
        ),
      );
}

/// How strongly a [GlassButton] is drawn.
enum GlassButtonKind {
  /// Accent-tinted capsule: secondary actions.
  tinted,

  /// Accent-filled capsule: the main action of a form.
  filled,

  /// Accent text only: inline actions.
  plain,
}

/// A push button inside content (editor forms, section headers): a capsule
/// with an optional leading symbol, a spinner in place of the symbol while
/// [busy]. Never blurred. Darwin only; callers keep their Material buttons on
/// other platforms.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = GlassButtonKind.tinted,
    this.busy = false,
    this.destructive = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonKind kind;

  /// Shows a spinner in place of [icon] and ignores taps.
  final bool busy;

  /// Removes something: drawn in the system red instead of the accent.
  final bool destructive;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _hovered = false;
  bool _focused = false;
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
    final accent = widget.destructive ? _systemRed(brightness) : scheme.primary;
    final onAccent = widget.destructive ? Colors.white : scheme.onPrimary;

    Color fill;
    Color foreground;
    if (widget.onPressed == null) {
      fill = widget.kind == GlassButtonKind.plain
          ? scheme.onSurface.withValues(alpha: 0)
          : scheme.onSurface
              .withValues(alpha: GlassTokens.buttonTintOpacity(brightness));
      foreground =
          scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity);
    } else {
      switch (widget.kind) {
        case GlassButtonKind.filled:
          fill = accent;
          foreground = onAccent;
        case GlassButtonKind.tinted:
          fill = accent.withValues(
            alpha: GlassTokens.buttonTintOpacity(brightness),
          );
          foreground = accent;
        case GlassButtonKind.plain:
          fill = accent.withValues(alpha: 0);
          foreground = accent;
      }
    }
    if (_enabled && (_pressed || _hovered)) {
      fill = Color.alphaBlend(
        scheme.onSurface.withValues(
          alpha: _pressed
              ? GlassTokens.menuPressedOpacity(brightness)
              : GlassTokens.hoverOpacity(brightness),
        ),
        fill,
      );
    }

    final iconSize =
        _mac ? GlassTokens.buttonIconSizeMac : GlassTokens.buttonIconSizeIos;
    final icon = widget.icon;
    final symbol = widget.busy
        ? CupertinoActivityIndicator(radius: iconSize / 2, color: foreground)
        : icon == null
            ? null
            : Icon(icon, size: iconSize, color: foreground);

    Widget button = AnimatedContainer(
      duration: GlassTokens.motion(
        GlassTokens.hoverDuration,
        reduceMotion: accessibility.reduceMotion,
      ),
      height: _mac ? GlassTokens.buttonHeightMac : GlassTokens.buttonHeightIos,
      padding: EdgeInsets.symmetric(
        horizontal:
            _mac ? GlassTokens.buttonPaddingMac : GlassTokens.buttonPaddingIos,
      ),
      decoration: ShapeDecoration(
        color: fill,
        shape: StadiumBorder(
          side: _focused
              ? BorderSide(
                  color: scheme.primary,
                  width: GlassTokens.cardFocusBorderWidth,
                )
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (symbol != null) ...[
            symbol,
            const SizedBox(width: GlassTokens.buttonIconGap),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GlassTextStyles.button(theme.textTheme)
                  .copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
    button = FocusableActionDetector(
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
        onTap: _enabled ? widget.onPressed : null,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        child: button,
      ),
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      child: button,
    );
  }
}
