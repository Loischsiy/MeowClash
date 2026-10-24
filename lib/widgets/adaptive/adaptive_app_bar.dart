import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';
import 'glass_toolbar_group.dart';

/// Background of a page's top bar.
///
/// * Darwin (macOS 26 / iOS 26 toolbar): [child] is the toolbar row, usually
///   a [GlassToolbar]. The bar itself has no fill and no blur of its own —
///   only its capsules are glass, so there is never blur over blur. It sits
///   under the transparent title bar / status bar (the `MediaQuery` top
///   inset) and, on macOS, moves the window when dragged, like a native
///   toolbar. With [scrollEdge] content scrolls under it and fades out into
///   the window color instead of meeting a hairline.
/// * Everything else: returns [child] (the Material `AppBar`) untouched.
class AdaptiveAppBar extends StatelessWidget {
  const AdaptiveAppBar({
    super.key,
    required this.child,
    this.onWindowDrag,
    this.transparent = false,
    this.scrollEdge = false,
  });

  final Widget child;

  /// macOS: starts a native window drag (`windowManager.startDragging`).
  final VoidCallback? onWindowDrag;

  /// Keep the bar see-through (e.g. over a custom page background image).
  final bool transparent;

  /// The page scrolls under the bar: paint the scroll-edge fade.
  final bool scrollEdge;

  /// Height of the toolbar row without the top inset: the Darwin toolbar
  /// height, [kToolbarHeight] for Material.
  static double get toolbarHeight {
    if (!AdaptivePlatform.useGlass) return kToolbarHeight;
    return defaultTargetPlatform == TargetPlatform.macOS
        ? GlassTokens.toolbarHeightMac
        : GlassTokens.toolbarHeightIos;
  }

  /// Top space the bar covers (title bar / status bar + toolbar) inside a
  /// page that scrolls under it (`CommonScaffold` with `scrollUnderToolbar`);
  /// add it to the scroll view's top padding. 0 off Darwin and in pages that
  /// keep their content below the bar.
  static double topInset(BuildContext context) {
    if (!AdaptivePlatform.useGlass) return 0;
    return MediaQuery.paddingOf(context).top;
  }

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) return child;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final opaque = GlassAccessibility.of(context).opaque;
    final window = theme.scaffoldBackgroundColor;

    Widget bar = SafeArea(
      bottom: false,
      child: SizedBox(height: toolbarHeight, child: child),
    );
    if (transparent) {
      // Over a page background image: no fill, no edge.
    } else if (opaque) {
      // Reduce Transparency / Increase Contrast / kill switch: a solid bar
      // with a hairline, as before the glass toolbar.
      final hairline = BorderSide(
        color: (brightness == Brightness.dark ? Colors.white : Colors.black)
            .withValues(alpha: GlassTokens.hairlineOpacity(brightness)),
        width: GlassTokens.hairlineWidth,
      );
      bar = DecoratedBox(
        decoration: BoxDecoration(
          color: window,
          border: Border(bottom: hairline),
        ),
        child: bar,
      );
    } else if (scrollEdge) {
      final fade = window.withValues(
        alpha: GlassTokens.toolbarFadeOpacity(brightness),
      );
      bar = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: -GlassTokens.toolbarFadeExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [GlassTokens.toolbarFadeSolidStop, 1],
                    colors: [fade, fade.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          bar,
        ],
      );
    }

    final drag = onWindowDrag;
    if (defaultTargetPlatform != TargetPlatform.macOS || drag == null) {
      return bar;
    }
    // Translucent detector on top: taps still reach the bar's buttons and
    // win the arena; only a real drag moves the window.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        bar,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => drag(),
          ),
        ),
      ],
    );
  }
}

/// The Darwin toolbar row: an optional round [leading] capsule, the title
/// (macOS: compact at the leading edge; iOS: centered), the page [actions]
/// in one [GlassToolbarGroup] and the [search] button in its own round
/// capsule at the trailing edge. While searching, [searchField] (usually a
/// [GlassToolbarSearchField]) takes the title's place and the actions hide.
///
/// Pages keep passing plain Material `IconButton`s; the capsules restyle
/// them. Nothing here animates, so Reduce Motion needs no extra branch (and
/// no `Opacity` ever sits above the capsules' blur).
///
/// Darwin only; Material pages keep their `AppBar`.
class GlassToolbar extends StatelessWidget {
  const GlassToolbar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.search,
    this.searchField,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? search;
  final Widget? searchField;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset =
        _mac ? GlassTokens.toolbarInsetMac : GlassTokens.toolbarInsetIos;
    final searching = searchField != null;
    final leading = this.leading;
    final search = this.search;
    final trailing = <Widget>[
      if (!searching && actions.isNotEmpty)
        GlassToolbarGroup(children: actions),
      if (!searching && search != null) ...[
        if (actions.isNotEmpty)
          const SizedBox(width: GlassTokens.toolbarItemGap),
        GlassToolbarGroup(children: [search]),
      ],
    ];
    return NavigationToolbar(
      leading: leading == null
          ? null
          : Padding(
              padding: EdgeInsetsDirectional.only(start: inset),
              child: Center(
                widthFactor: 1,
                child: GlassToolbarGroup(children: [leading]),
              ),
            ),
      middle: searchField ??
          DefaultTextStyle(
            style: GlassTextStyles.toolbarTitle(theme.textTheme).copyWith(
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            child: title,
          ),
      trailing: trailing.isEmpty
          ? null
          : Padding(
              padding: EdgeInsetsDirectional.only(end: inset),
              child: Row(mainAxisSize: MainAxisSize.min, children: trailing),
            ),
      centerMiddle: !_mac && !searching,
      middleSpacing: leading == null && !_mac
          ? inset
          : GlassTokens.toolbarTitleGap,
    );
  }
}
