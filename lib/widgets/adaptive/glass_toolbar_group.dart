import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// A glass capsule of toolbar buttons, as in the macOS 26 window toolbar and
/// the iOS 26 navigation bar: one [GlassSurface] (one `BackdropFilter`) with
/// the buttons side by side in it — no circle per button, only a faint wash
/// on hover and press. A single child makes a round button.
///
/// Children are usually the screens' own Material `IconButton`s; an
/// [IconButtonTheme] gives them the toolbar size, symbol size and colors, so
/// pages keep their widgets. Children that lay out to zero width (hidden
/// actions) take no room, and a capsule with nothing visible paints nothing.
///
/// Darwin only; Material app bars keep their plain actions.
class GlassToolbarGroup extends StatelessWidget {
  const GlassToolbarGroup({super.key, required this.children});

  final List<Widget> children;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  /// Height of a capsule and width of each button in it.
  static double get itemSize =>
      _mac ? GlassTokens.toolbarItemSizeMac : GlassTokens.toolbarItemSizeIos;

  static double get iconSize =>
      _mac ? GlassTokens.toolbarIconSizeMac : GlassTokens.toolbarIconSizeIos;

  /// Style of the Material buttons inside a capsule: square, no padding and
  /// no ripple; the label color for the symbol, the accent when selected.
  static ButtonStyle buttonStyle(ThemeData theme, {double? iconSize}) {
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final size = Size.square(itemSize);
    return ButtonStyle(
      fixedSize: WidgetStatePropertyAll(size),
      minimumSize: WidgetStatePropertyAll(size),
      maximumSize: WidgetStatePropertyAll(size),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      iconSize: WidgetStatePropertyAll(iconSize ?? GlassToolbarGroup.iconSize),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      shape: const WidgetStatePropertyAll(CircleBorder()),
      splashFactory: NoSplash.splashFactory,
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(
            alpha: GlassTokens.disabledOpacity,
          );
        }
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.onSurface;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return scheme.onSurface.withValues(
            alpha: GlassTokens.menuPressedOpacity(brightness),
          );
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return scheme.onSurface.withValues(
            alpha: GlassTokens.hoverOpacity(brightness),
          );
        }
        return Colors.transparent;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassToolbarCapsule(
      child: IconButtonTheme(
        data: IconButtonThemeData(style: buttonStyle(theme)),
        child: IconTheme.merge(
          data: IconThemeData(
            size: iconSize,
            color: theme.colorScheme.onSurface,
          ),
          child: SizedBox(
            height: itemSize,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// The toolbar search field: a glass capsule with a magnifier, the text and
/// a clear button, in place of the title while the page is searching.
///
/// Darwin only; the Material app bar keeps its full-width text field.
class GlassToolbarSearchField extends StatelessWidget {
  const GlassToolbarSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hintText,
    this.clearTooltip,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// The clear button (it may also leave search mode once the text is empty).
  final VoidCallback onClear;
  final String? hintText;
  final String? clearTooltip;
  final bool autofocus;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style =
        GlassTextStyles.toolbarSearch(theme.textTheme).copyWith(
      color: scheme.onSurface,
    );
    final iconSize = _mac
        ? GlassTokens.toolbarSearchIconSizeMac
        : GlassTokens.toolbarSearchIconSizeIos;
    const none = InputBorder.none;
    return _GlassToolbarCapsule(
      child: SizedBox(
        height: GlassToolbarGroup.itemSize,
        child: Row(
          children: [
            const SizedBox(width: GlassTokens.toolbarSearchPadding),
            Icon(
              Icons.search_rounded,
              size: iconSize,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: GlassTokens.toolbarSearchIconGap),
            Expanded(
              // Desktop's compact VisualDensity makes a collapsed
              // InputDecorator push its line 4 pt below the field's own
              // box, so the text sat low in the capsule on macOS. The
              // capsule fixes the height; the field keeps standard density.
              child: Theme(
                data: theme.copyWith(visualDensity: VisualDensity.standard),
                child: TextField(
                  autofocus: autofocus,
                  controller: controller,
                  onChanged: onChanged,
                  style: style,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: none,
                    enabledBorder: none,
                    focusedBorder: none,
                    disabledBorder: none,
                    errorBorder: none,
                    focusedErrorBorder: none,
                    hintText: hintText,
                    hintStyle: style.copyWith(color: scheme.onSurfaceVariant),
                    // Reduce Motion: the hint goes away at once, no fade.
                    hintFadeDuration:
                        GlassAccessibility.of(context).reduceMotion
                            ? Duration.zero
                            : null,
                  ),
                ),
              ),
            ),
            IconButton(
              style: GlassToolbarGroup.buttonStyle(theme, iconSize: iconSize)
                  .copyWith(
                foregroundColor:
                    WidgetStatePropertyAll(scheme.onSurfaceVariant),
              ),
              tooltip: clearTooltip,
              onPressed: onClear,
              icon: const Icon(Icons.cancel_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glass shape shared by toolbar capsules.
class _GlassToolbarCapsule extends StatelessWidget {
  const _GlassToolbarCapsule({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    return _HideWhenEmpty(
      child: GlassSurface(
        // Inside a blurring surface (a page in a glass sheet) the capsule
        // keeps its tint, rim and shadow but never blurs a second time.
        backdrop: GlassSurface.isOverBlur(context)
            ? GlassBackdrop.native
            : GlassBackdrop.blur,
        sigma: GlassTokens.toolbarItemSigma,
        borderRadius: BorderRadius.circular(GlassToolbarGroup.itemSize / 2),
        // Light glass reads white over the window; dark glass is a step
        // lighter than the window, as in Apple's toolbars.
        color: brightness == Brightness.dark
            ? scheme.surfaceContainerHighest
            : Colors.white,
        opaqueColor: scheme.surfaceContainerHigh,
        shadow: true,
        shadows: GlassTokens.toolbarItemShadow(brightness),
        child: child,
      ),
    );
  }
}

/// Paints and hit-tests its child only when it has a non-zero width, so a
/// capsule whose buttons are all hidden leaves no empty glass behind.
class _HideWhenEmpty extends SingleChildRenderObjectWidget {
  const _HideWhenEmpty({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHideWhenEmpty();
}

class _RenderHideWhenEmpty extends RenderProxyBox {
  bool get _empty => size.width <= 0 || size.height <= 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_empty) return;
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_empty) return false;
    return super.hitTest(result, position: position);
  }
}
