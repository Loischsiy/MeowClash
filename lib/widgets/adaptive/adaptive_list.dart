import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'adaptive_app_bar.dart';
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

/// Marks a subtree laid out as an Apple grouped list ([GlassListView] or a
/// [GlassListSection]). The app-wide `ListItem` / `ListHeader` render their
/// Darwin rows only inside it, so lists that are not migrated (connections,
/// logs, the dashboard mode radios) keep the Material tiles.
class GlassListScope extends InheritedWidget {
  const GlassListScope({
    super.key,
    this.inSection = false,
    required super.child,
  });

  /// `true` inside the card of a [GlassListSection]; `false` directly in a
  /// [GlassListView], where a lone row wraps itself in a section.
  final bool inSection;

  static GlassListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassListScope>();

  @override
  bool updateShouldNotify(GlassListScope oldWidget) =>
      inSection != oldWidget.inSection;
}

/// A child of a [GlassListSection] that is not a [GlassListRow] but knows
/// whether its row has a leading symbol (so the hairline above it starts at
/// the text without waiting for the row to report it).
abstract interface class GlassLeadingHint {
  bool get hasGlassLeading;
}

/// Scroll view of an Apple grouped list: the [GlassListSection.listPadding]
/// insets (plus the toolbar inset of pages that scroll under the bar) and
/// [GlassListSection.gap] between the children, none right after a
/// [GlassSectionHeader]. Never blurred. Darwin only.
class GlassListView extends StatelessWidget {
  const GlassListView({super.key, required this.children});

  /// Usually [GlassListSection]s.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = GlassListSection.listPadding;
    return GlassListScope(
      child: ListView.builder(
        padding: padding.copyWith(
          top: padding.top + AdaptiveAppBar.topInset(context),
        ),
        itemCount: children.length,
        itemBuilder: (_, index) {
          final child = children[index];
          if (index == 0 || children[index - 1] is GlassSectionHeader) {
            return child;
          }
          return Padding(
            padding: EdgeInsets.only(top: GlassListSection.gap),
            child: child,
          );
        },
      ),
    );
  }
}

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
/// optional [subtitle] in the footer style below the title and an optional
/// [trailing] control (e.g. a [GlassButton]) at its end.
///
/// Darwin only.
class GlassSectionHeader extends StatelessWidget {
  const GlassSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = GlassTextStyles.listSectionHeader(theme.textTheme).copyWith(
      color: _mac ? scheme.onSurface : scheme.onSurfaceVariant,
    );
    final trailing = this.trailing;
    final subtitle = this.subtitle;
    final Widget heading = Semantics(
      header: true,
      child: Text(title, style: style),
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: _rowPadding,
        end: trailing == null ? _rowPadding : 0,
        bottom: GlassTokens.listSectionHeaderGap,
      ),
      child: Row(
        children: [
          Expanded(
            child: subtitle == null
                ? heading
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      const SizedBox(height: GlassTokens.listRowSubtitleGap),
                      Text(
                        subtitle,
                        style: GlassTextStyles.listSectionFooter(
                          theme.textTheme,
                        ).copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
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
class GlassListSection extends StatefulWidget {
  const GlassListSection({
    super.key,
    required this.children,
    this.header,
    this.headerSubtitle,
    this.headerTrailing,
    this.footer,
    this.dividerInset,
  });

  /// Usually [GlassListRow]s.
  final List<Widget> children;
  final String? header;

  /// Second header line in the footer style.
  final String? headerSubtitle;

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

  @override
  State<GlassListSection> createState() => _GlassListSectionState();
}

class _GlassListSectionState extends State<GlassListSection> {
  /// Leading symbols reported by rows the section cannot see directly (a
  /// `ListItem` inside a wrapper widget), by child index.
  final Map<int, bool> _reportedLeading = {};
  bool _rebuildScheduled = false;

  bool get _sectionHasLeading => widget.children.any(
        (child) => switch (child) {
          GlassListRow(leading: != null) => true,
          GlassLeadingHint(hasGlassLeading: true) => true,
          _ => false,
        },
      );

  bool _leadingAt(int index) =>
      _sectionHasLeading || (_reportedLeading[index] ?? false);

  /// Called by a [GlassListRow] while it builds. A changed inset is applied
  /// one frame later (the hairline above the row is already built).
  void _report(int index, bool hasLeading) {
    if (_reportedLeading[index] == hasLeading) return;
    final before = _leadingAt(index);
    _reportedLeading[index] = hasLeading;
    if (before == _leadingAt(index) || _rebuildScheduled) return;
    _rebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  double _dividerInset(int index) {
    final inset = widget.dividerInset;
    if (inset != null) return inset;
    return _leadingAt(index)
        ? _rowPadding + _leadingSize + _leadingGap
        : _rowPadding;
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
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
    Widget separator(int index) => Padding(
          padding: EdgeInsetsDirectional.only(start: _dividerInset(index)),
          child: SizedBox(
            height: GlassTokens.hairlineWidth,
            child: ColoredBox(color: separatorColor),
          ),
        );

    final header = widget.header;
    final footer = widget.footer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          GlassSectionHeader(
            title: header,
            subtitle: widget.headerSubtitle,
            trailing: widget.headerTrailing,
          ),
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
                child: GlassListScope(
                  inSection: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) separator(i),
                        _GlassSectionSlot(
                          section: this,
                          index: i,
                          child: children[i],
                        ),
                      ],
                    ],
                  ),
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

/// Lets a row inside child [index] of a section report its leading symbol.
class _GlassSectionSlot extends InheritedWidget {
  const _GlassSectionSlot({
    required this.section,
    required this.index,
    required super.child,
  });

  final _GlassListSectionState section;
  final int index;

  @override
  bool updateShouldNotify(_GlassSectionSlot oldWidget) => false;
}

/// What a [GlassListRow] shows at its trailing edge after [GlassListRow.trailing].
enum GlassRowAccessory {
  none,

  /// Opens a page, sheet or dialog.
  chevron,

  /// The row is the current choice of a single-choice list.
  checkmark,

  /// Opens a menu of choices (`chevron.up.chevron.down`).
  popUp,

  /// Opens a web page outside the app (`arrow.up.forward`).
  link,
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
    this.value,
    this.trailing,
    this.accessory = GlassRowAccessory.none,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.destructive = false,
  });

  /// Usually a `Text`; styled by the row.
  final Widget title;
  final Widget? subtitle;

  /// Usually an `Icon`; drawn in the accent at the row symbol size.
  final Widget? leading;

  /// The current value (usually a `Text`) in the secondary color before
  /// [trailing]: one line, at most [GlassTokens.listRowValueMaxFraction] of
  /// the row, ellipsized.
  final Widget? value;

  /// A control (switch, button) or a secondary value text.
  final Widget? trailing;
  final GlassRowAccessory accessory;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Reported to accessibility (single-choice lists).
  final bool selected;
  final bool enabled;

  /// Removes or resets something: title and symbol in the system red.
  final bool destructive;

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
    final slot = context.getInheritedWidgetOfExactType<_GlassSectionSlot>();
    slot?.section._report(slot.index, widget.leading != null);
    final red = _systemRed(brightness);

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

    final titleStyle = GlassTextStyles.listRowTitle(theme.textTheme).copyWith(
      color: !enabled
          ? disabled
          : widget.destructive
              ? red
              : scheme.onSurface,
    );
    final secondaryStyle = GlassTextStyles.listRowSubtitle(theme.textTheme)
        .copyWith(color: enabled ? scheme.onSurfaceVariant : disabled);
    final chevronSize = _mac
        ? GlassTokens.listRowChevronSizeMac
        : GlassTokens.listRowChevronSizeIos;

    final leading = widget.leading;
    final subtitle = widget.subtitle;
    final value = widget.value;
    final trailing = widget.trailing;
    Widget buildRow(double maxValueWidth) => Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: _leadingSize,
                  color: !enabled
                      ? disabled
                      : widget.destructive
                          ? red
                          : scheme.primary,
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
                  DefaultTextStyle.merge(
                      style: titleStyle, child: widget.title),
                  if (subtitle != null) ...[
                    const SizedBox(height: GlassTokens.listRowSubtitleGap),
                    DefaultTextStyle.merge(
                        style: secondaryStyle, child: subtitle),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: GlassTokens.listRowTrailingGap),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxValueWidth),
                child: DefaultTextStyle.merge(
                  style: titleStyle.copyWith(color: secondaryStyle.color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  child: value,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: GlassTokens.listRowTrailingGap),
              DefaultTextStyle.merge(
                style: titleStyle.copyWith(color: secondaryStyle.color),
                child: trailing,
              ),
            ],
            if (widget.accessory == GlassRowAccessory.popUp) ...[
              const SizedBox(width: GlassTokens.buttonIconGap),
              Icon(
                Icons.unfold_more_rounded,
                size: chevronSize,
                color: scheme.onSurfaceVariant
                    .withValues(alpha: GlassTokens.listRowChevronOpacity),
              ),
            ],
            if (widget.accessory == GlassRowAccessory.link) ...[
              const SizedBox(width: GlassTokens.listRowTrailingGap),
              Icon(
                Icons.north_east_rounded,
                size: chevronSize,
                color: scheme.onSurfaceVariant
                    .withValues(alpha: GlassTokens.listRowChevronOpacity),
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
    final row = value == null
        ? buildRow(double.infinity)
        : LayoutBuilder(
            builder: (_, constraints) => buildRow(
              constraints.maxWidth * GlassTokens.listRowValueMaxFraction,
            ),
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
