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
    this.largeTitle = false,
  });

  final Widget child;

  /// macOS: starts a native window drag (`windowManager.startDragging`).
  final VoidCallback? onWindowDrag;

  /// Keep the bar see-through (e.g. over a custom page background image).
  final bool transparent;

  /// The page scrolls under the bar: paint the scroll-edge fade.
  final bool scrollEdge;

  /// [child] is a [GlassToolbar] with its large title row (iOS root page):
  /// the bar is [GlassTokens.toolbarLargeTitleHeightIos] tall, the buttons
  /// share that row with the title.
  final bool largeTitle;

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  /// Height of the toolbar row without the top inset: the Darwin toolbar
  /// height, [kToolbarHeight] for Material.
  static double get toolbarHeight {
    if (!AdaptivePlatform.useGlass) return kToolbarHeight;
    return defaultTargetPlatform == TargetPlatform.macOS
        ? GlassTokens.toolbarHeightMac
        : GlassTokens.toolbarHeightIos;
  }

  /// Whether root pages (no back button) put their title in a large title
  /// row next to the buttons: the iOS glass toolbar only.
  static bool get largeTitles => AdaptivePlatform.useGlass && _ios;

  static double _barHeight({required bool largeTitle}) =>
      largeTitle && largeTitles
          ? GlassTokens.toolbarLargeTitleHeightIos
          : toolbarHeight;

  /// The `PreferredSize` height of a page's bar, without the top inset the
  /// `Scaffold` adds on its own: the toolbar row, the large title row when
  /// [largeTitle], and on iOS whatever [GlassTokens.toolbarMinTopInsetIos]
  /// adds where there is no status bar.
  static double preferredHeight(
    BuildContext context, {
    bool largeTitle = false,
  }) {
    if (!AdaptivePlatform.useGlass) return kToolbarHeight;
    final shortfall = _ios
        ? GlassTokens.toolbarMinTopInsetIos - MediaQuery.paddingOf(context).top
        : 0.0;
    return _barHeight(largeTitle: largeTitle) +
        (shortfall > 0 ? shortfall : 0);
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
      minimum: _ios
          ? const EdgeInsets.only(top: GlassTokens.toolbarMinTopInsetIos)
          : EdgeInsets.zero,
      child: SizedBox(
        height: _barHeight(largeTitle: largeTitle),
        child: child,
      ),
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
      // iOS large title: nothing may show through the title row, so the
      // backdrop is solid down to the bar's bottom edge and only fades below.
      final large = largeTitle && largeTitles;
      final fade = window.withValues(
        alpha: large
            ? GlassTokens.toolbarLargeTitleBackdropOpacity
            : GlassTokens.toolbarFadeOpacity(brightness),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final solidStop = large && height > 0
                      ? (height - GlassTokens.toolbarFadeExtent) / height
                      : GlassTokens.toolbarFadeSolidStop;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [solidStop, 1],
                        colors: [fade, fade.withValues(alpha: 0)],
                      ),
                    ),
                  );
                },
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

/// First sliver of a scroll view that scrolls under the glass toolbar and
/// has pinned headers of its own: an empty pinned spacer as tall as
/// [AdaptiveAppBar.topInset]. It paints nothing and takes no taps, so the
/// content still scrolls visibly under the bar, but later pinned headers
/// stick right below the bar instead of under it (never glass under glass).
/// Add it only when the inset is above 0, so Material keeps its old slivers.
class SliverToolbarInset extends StatelessWidget {
  const SliverToolbarInset({super.key});

  @override
  Widget build(BuildContext context) => SliverPersistentHeader(
        pinned: true,
        delegate: _ToolbarInsetDelegate(AdaptiveAppBar.topInset(context)),
      );
}

class _ToolbarInsetDelegate extends SliverPersistentHeaderDelegate {
  const _ToolbarInsetDelegate(this.extent);

  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  // Full height, so the following pinned slivers see it as overlap.
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      const SizedBox.expand();

  @override
  bool shouldRebuild(_ToolbarInsetDelegate oldDelegate) =>
      oldDelegate.extent != extent;
}

/// The Darwin toolbar row: an optional round [leading] capsule, the title
/// (macOS: compact at the leading edge; iOS: centered), the page [actions]
/// in one [GlassToolbarGroup] and the [search] button in its own round
/// capsule at the trailing edge. While searching, [searchField] (usually a
/// [GlassToolbarSearchField]) takes the title's place and the actions hide.
///
/// With [largeTitle] (iOS root pages) the title is large at the leading
/// edge, like the iOS 26 large title, and the capsules share its row at the
/// trailing edge, centered on the title's line. While searching the back
/// capsule ([leading]) and the field take that row, so the bar never changes
/// height. It stays put while the page scrolls. Wrap it in an
/// [AdaptiveAppBar] with the same `largeTitle`.
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
    this.largeTitle = false,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? search;
  final Widget? searchField;
  final bool largeTitle;

  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  Widget _title(TextStyle style, Color color) => DefaultTextStyle(
        style: style.copyWith(color: color),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        child: title,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    final large = largeTitle && !_mac;
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
    final row = NavigationToolbar(
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
          (large
              ? null
              : _title(GlassTextStyles.toolbarTitle(theme.textTheme), color)),
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
    if (!large) return row;
    final field = searchField;
    return SizedBox(
      height: GlassTokens.toolbarLargeTitleHeightIos,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: inset),
        child: field != null
            ? Padding(
                padding: const EdgeInsets.only(
                  bottom: GlassTokens.toolbarLargeTitleActionsBottomIos,
                ),
                // Search mode: the back capsule that leaves it, then the field.
                child: Row(
                  children: [
                    if (leading != null) ...[
                      GlassToolbarGroup(children: [leading]),
                      const SizedBox(width: GlassTokens.toolbarTitleGap),
                    ],
                    Expanded(child: field),
                  ],
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: GlassTokens.toolbarLargeTitleBottomIos,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: Semantics(
                          header: true,
                          child: _title(
                            GlassTextStyles.toolbarLargeTitle(
                              theme.textTheme,
                            ),
                            color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (trailing.isNotEmpty) ...[
                    const SizedBox(width: GlassTokens.toolbarTitleGap),
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: GlassTokens.toolbarLargeTitleActionsBottomIos,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: trailing,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
