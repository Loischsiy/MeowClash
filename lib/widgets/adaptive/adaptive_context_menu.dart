import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// One row of an [AdaptiveContextMenu]: a platform-neutral description that
/// each platform draws in its own way.
@immutable
class AdaptiveMenuEntry {
  const AdaptiveMenuEntry({
    required this.label,
    this.icon,
    this.onPressed,
    this.destructive = false,
    this.checked = false,
  });

  final String label;
  final IconData? icon;

  /// `null` disables the row.
  final VoidCallback? onPressed;

  /// Destroys data (delete). Drawn in the system red on Darwin and kept in its
  /// own group at the end of the menu, as the Apple HIG asks.
  final bool destructive;

  /// The current choice (pop-up buttons, single-choice menus): a checkmark
  /// on Darwin.
  final bool checked;

  bool get enabled => onPressed != null;
}

/// Context menus of the adaptive chrome.
///
/// * macOS: a real `NSMenu` via [showNative] — system look, vibrancy,
///   keyboard navigation and type-select for free; no Flutter blur at all.
/// * iOS (and macOS when the native channel is missing): a Flutter menu on a
///   single [GlassSurface].
/// * Android, Linux, Windows: [materialBuilder], i.e. the existing
///   `CommonPopupMenu`, untouched.
class AdaptiveContextMenu extends StatelessWidget {
  const AdaptiveContextMenu({
    super.key,
    required this.entries,
    required this.materialBuilder,
    this.minWidth = GlassTokens.menuMinWidth,
  });

  final List<AdaptiveMenuEntry> entries;
  final WidgetBuilder materialBuilder;
  final double minWidth;

  static const channel = MethodChannel('meowclash/context_menu');

  /// Whether menus are shown by the OS rather than drawn by Flutter.
  static bool get prefersNative => AdaptivePlatform.isMacOSGlass;

  /// Pops up a native menu just below [anchor] (global logical coordinates,
  /// which are points on macOS) and runs the chosen entry.
  ///
  /// With [popUp] (the menu of a pop-up button) the checked entry is laid
  /// over [anchor] instead, as `NSPopUpButton` does.
  ///
  /// Completes with `false` when no native menu could be shown (wrong
  /// platform, channel missing or failing) so the caller can fall back to the
  /// Flutter menu; `true` once the menu was shown, whether or not an entry
  /// was picked.
  static Future<bool> showNative({
    required Rect anchor,
    required List<AdaptiveMenuEntry> entries,
    bool popUp = false,
  }) async {
    if (!prefersNative || entries.isEmpty) return false;
    final checkedIndex = entries.indexWhere((entry) => entry.checked);
    final positioned = popUp && checkedIndex >= 0;
    final Object? index;
    try {
      index = await channel.invokeMethod<Object?>('show', {
        'x': anchor.left,
        'y': positioned
            ? anchor.top
            : anchor.bottom + GlassTokens.menuAnchorGap,
        if (positioned) 'positioning': checkedIndex,
        'items': [
          for (final entry in entries)
            {
              'title': entry.label,
              'symbol': sfSymbolFor(entry.icon),
              'enabled': entry.enabled,
              'destructive': entry.destructive,
              'checked': entry.checked,
            },
        ],
      });
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
    if (index is int && index >= 0 && index < entries.length) {
      entries[index].onPressed?.call();
    }
    return true;
  }

  /// SF Symbol shown next to a native menu item for a Material icon used in
  /// the app's menus; `null` (no image) for icons without a counterpart.
  static String? sfSymbolFor(IconData? icon) =>
      icon == null ? null : _sfSymbols[icon];

  // Not `const`: IconData overrides `==`.
  static final Map<IconData, String> _sfSymbols = {
    Icons.check_circle_outline: 'checkmark.circle',
    Icons.edit: 'pencil',
    Icons.edit_outlined: 'pencil',
    Icons.sync_alt_sharp: 'arrow.triangle.2.circlepath',
    Icons.tv_outlined: 'tv',
    Icons.telegram: 'paperplane',
    Icons.insert_link: 'link',
    Icons.extension_outlined: 'puzzlepiece.extension',
    Icons.file_copy_outlined: 'square.and.arrow.up',
    Icons.delete: 'trash',
    Icons.delete_outlined: 'trash',
    Icons.tune: 'slider.horizontal.3',
    Icons.poll_outlined: 'chart.bar',
    Icons.style_outlined: 'paintpalette',
    Icons.rule: 'list.bullet.rectangle',
    Icons.public: 'globe',
    Icons.flash_on: 'bolt',
    Icons.search: 'magnifyingglass',
    Icons.undo: 'arrow.uturn.backward',
    Icons.redo: 'arrow.uturn.forward',
    Icons.content_copy_outlined: 'doc.on.doc',
    Icons.filter_alt_outlined: 'line.3.horizontal.decrease.circle',
    Icons.close_rounded: 'xmark',
  };

  /// Opens the Flutter glass menu next to [anchor] (global coordinates):
  /// below it, or above when there is more room there; it scrolls when the
  /// entries do not fit and starts at the checked entry. For pop-up buttons
  /// on iOS, and on macOS when [showNative] is unavailable.
  static Future<void> showGlass({
    required BuildContext context,
    required Rect anchor,
    required List<AdaptiveMenuEntry> entries,
    double minWidth = GlassTokens.menuMinWidth,
  }) =>
      Navigator.of(context).push(
        _GlassMenuRoute(
          anchor: anchor,
          entries: entries,
          minWidth: minWidth,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) return materialBuilder(context);
    return _GlassMenu(entries: entries, minWidth: minWidth);
  }
}

class _GlassMenuRoute extends PopupRoute<void> {
  _GlassMenuRoute({
    required this.anchor,
    required this.entries,
    required this.minWidth,
    required this.barrierLabel,
  });

  final Rect anchor;
  final List<AdaptiveMenuEntry> entries;
  final double minWidth;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => GlassTokens.morphDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      CustomSingleChildLayout(
        delegate: _GlassMenuLayout(
          anchor: anchor,
          padding: MediaQuery.paddingOf(context),
        ),
        child: GlassMenuTransition(
          animation: animation,
          alignment: Alignment.topCenter,
          child: _GlassMenu(
            entries: entries,
            minWidth: minWidth < anchor.width ? anchor.width : minWidth,
          ),
        ),
      );
}

/// Places a glass menu below its anchor, or above when there is more room,
/// inside the safe area.
class _GlassMenuLayout extends SingleChildLayoutDelegate {
  const _GlassMenuLayout({required this.anchor, required this.padding});

  final Rect anchor;
  final EdgeInsets padding;

  static const _gap = GlassTokens.menuAnchorGap;
  static const _margin = GlassTokens.menuScreenMargin;

  double _below(Size size) =>
      size.height - padding.bottom - _margin - (anchor.bottom + _gap);

  double _above() => anchor.top - _gap - padding.top - _margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final below = _below(size);
    final above = _above();
    final height = below > above ? below : above;
    final width = size.width - padding.horizontal - 2 * _margin;
    return BoxConstraints(
      maxWidth: width < 0 ? 0 : width,
      maxHeight: height < 0 ? 0 : height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsBelow = childSize.height <= _below(size) || _below(size) >= _above();
    final y = fitsBelow
        ? anchor.bottom + _gap
        : anchor.top - _gap - childSize.height;
    final minX = padding.left + _margin;
    final maxX = size.width - padding.right - _margin - childSize.width;
    final x = maxX < minX ? minX : anchor.left.clamp(minX, maxX);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_GlassMenuLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.padding != padding;
}

/// Opening animation of a glass popup: it grows out of the corner nearest to
/// the control that opened it.
///
/// Scale only: an `Opacity` above the menu's `BackdropFilter` would force an
/// extra offscreen layer every frame. Closing is immediate, like system menus,
/// and Reduce Motion shows the menu at once.
class GlassMenuTransition extends StatelessWidget {
  const GlassMenuTransition({
    super.key,
    required this.animation,
    required this.alignment,
    required this.child,
  });

  final Animation<double> animation;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final closing = animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed;
        if (closing) return const SizedBox.shrink();
        if (reduceMotion) return child!;
        final t = GlassTokens.morphCurve.transform(animation.value);
        final scale = GlassTokens.menuOpenScale +
            (1 - GlassTokens.menuOpenScale) * t;
        return Transform.scale(
          alignment: alignment,
          scale: scale,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _GlassMenu extends StatefulWidget {
  const _GlassMenu({required this.entries, required this.minWidth});

  final List<AdaptiveMenuEntry> entries;
  final double minWidth;

  @override
  State<_GlassMenu> createState() => _GlassMenuState();
}

class _GlassMenuState extends State<_GlassMenu> {
  final _checkedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // A long choice list (hundreds of nodes) opens at the current value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checked = _checkedKey.currentContext;
      if (checked != null && checked.mounted) {
        Scrollable.ensureVisible(checked, alignment: 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final minWidth = widget.minWidth;
    final hasChecks = entries.any((entry) => entry.checked);
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final separatorColor = theme.colorScheme.onSurface
        .withValues(alpha: GlassTokens.hairlineOpacity(brightness));
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth,
          // A pop-up button's menu is at least as wide as the button.
          maxWidth: minWidth > GlassTokens.menuMaxWidth
              ? minWidth
              : GlassTokens.menuMaxWidth,
        ),
        child: GlassSurface(
          sigma: GlassTokens.menuSigma,
          borderRadius: BorderRadius.circular(GlassTokens.menuRadius),
          shadow: true,
          opaqueColor: theme.colorScheme.surfaceContainer,
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: GlassTokens.menuVerticalPadding,
              ),
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    // Destructive actions form their own trailing group.
                    if (i > 0 &&
                        entries[i].destructive &&
                        !entries[i - 1].destructive)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GlassTokens.menuRowInset +
                              GlassTokens.menuRowPadding,
                          vertical: GlassTokens.menuGroupGap,
                        ),
                        child: SizedBox(
                          height: GlassTokens.hairlineWidth,
                          child: ColoredBox(color: separatorColor),
                        ),
                      ),
                    _GlassMenuRow(
                      key: entries[i].checked ? _checkedKey : null,
                      entry: entries[i],
                      reserveCheck: hasChecks,
                    ),
                  ],
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMenuRow extends StatefulWidget {
  const _GlassMenuRow({
    super.key,
    required this.entry,
    required this.reserveCheck,
  });

  final AdaptiveMenuEntry entry;

  /// Leaves the leading checkmark column of a choice menu (iOS puts the
  /// checkmark before the label).
  final bool reserveCheck;

  @override
  State<_GlassMenuRow> createState() => _GlassMenuRowState();
}

class _GlassMenuRowState extends State<_GlassMenuRow> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _activate() {
    final onPressed = widget.entry.onPressed;
    if (onPressed == null) return;
    Navigator.of(context).pop();
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final onSurface = theme.colorScheme.onSurface;
    final Color foreground;
    if (!entry.enabled) {
      foreground = onSurface.withValues(alpha: GlassTokens.disabledOpacity);
    } else if (entry.destructive) {
      foreground = brightness == Brightness.dark
          ? CupertinoColors.systemRed.darkColor
          : CupertinoColors.systemRed.color;
    } else {
      foreground = onSurface;
    }
    final double washOpacity;
    if (!entry.enabled) {
      washOpacity = 0;
    } else if (_pressed) {
      washOpacity = GlassTokens.menuPressedOpacity(brightness);
    } else if (_hovered) {
      washOpacity = GlassTokens.hoverOpacity(brightness);
    } else {
      washOpacity = 0;
    }

    return Semantics(
      button: true,
      enabled: entry.enabled,
      child: MouseRegion(
        cursor: entry.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: entry.enabled ? (_) => _setPressed(true) : null,
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: entry.enabled ? _activate : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GlassTokens.menuRowInset,
            ),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: onSurface.withValues(alpha: washOpacity),
                shape: RoundedSuperellipseBorder(
                  borderRadius:
                      BorderRadius.circular(GlassTokens.menuRowRadius),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: GlassTokens.menuRowHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GlassTokens.menuRowPadding,
                  ),
                  child: Row(
                    children: [
                      if (widget.reserveCheck) ...[
                        SizedBox.square(
                          dimension: GlassTokens.optionCheckSize,
                          child: entry.checked
                              ? Icon(
                                  Icons.check_rounded,
                                  size: GlassTokens.optionCheckSize,
                                  color: foreground,
                                )
                              : null,
                        ),
                        const SizedBox(width: GlassTokens.menuCheckGap),
                      ],
                      Expanded(
                        child: Text(
                          entry.label,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: foreground),
                        ),
                      ),
                      // iOS menus put the symbol on the trailing edge.
                      if (entry.icon != null) ...[
                        const SizedBox(width: GlassTokens.menuIconGap),
                        Icon(
                          entry.icon,
                          size: GlassTokens.menuIconSize,
                          color: foreground,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
