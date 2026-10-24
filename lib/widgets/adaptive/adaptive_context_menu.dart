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
  });

  final String label;
  final IconData? icon;

  /// `null` disables the row.
  final VoidCallback? onPressed;

  /// Destroys data (delete). Drawn in the system red on Darwin and kept in its
  /// own group at the end of the menu, as the Apple HIG asks.
  final bool destructive;

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
  /// Completes with `false` when no native menu could be shown (wrong
  /// platform, channel missing or failing) so the caller can fall back to the
  /// Flutter menu; `true` once the menu was shown, whether or not an entry
  /// was picked.
  static Future<bool> showNative({
    required Rect anchor,
    required List<AdaptiveMenuEntry> entries,
  }) async {
    if (!prefersNative || entries.isEmpty) return false;
    final Object? index;
    try {
      index = await channel.invokeMethod<Object?>('show', {
        'x': anchor.left,
        'y': anchor.bottom + GlassTokens.menuAnchorGap,
        'items': [
          for (final entry in entries)
            {
              'title': entry.label,
              'symbol': sfSymbolFor(entry.icon),
              'enabled': entry.enabled,
              'destructive': entry.destructive,
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
  };

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) return materialBuilder(context);
    return _GlassMenu(entries: entries, minWidth: minWidth);
  }
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

class _GlassMenu extends StatelessWidget {
  const _GlassMenu({required this.entries, required this.minWidth});

  final List<AdaptiveMenuEntry> entries;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final separatorColor = theme.colorScheme.onSurface
        .withValues(alpha: GlassTokens.hairlineOpacity(brightness));
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth,
          maxWidth: GlassTokens.menuMaxWidth,
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
                    _GlassMenuRow(entry: entries[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMenuRow extends StatefulWidget {
  const _GlassMenuRow({required this.entry});

  final AdaptiveMenuEntry entry;

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
