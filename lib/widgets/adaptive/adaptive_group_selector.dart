import 'package:flutter/material.dart';
import 'package:meowclash/common/color.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_icon_button.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// Horizontal selector of the proxy groups in the tab mode, driven by a
/// [TabController].
///
/// * Darwin: one floating Liquid Glass bar; the selected group is an accent
///   capsule and [onMore] opens the full list. The host stacks the bar over
///   its pages and pads them with [contentInset] so they scroll under it —
///   the bar is the only blurred layer, whatever the number of proxies.
/// * Everything else: the old Material `TabBar` with its fading "more"
///   button ([moreButton]), unchanged.
class AdaptiveGroupSelector extends StatefulWidget {
  const AdaptiveGroupSelector({
    super.key,
    required this.controller,
    required this.labels,
    required this.moreButton,
    required this.onMore,
    this.moreTooltip,
  });

  final TabController? controller;
  final List<String> labels;

  /// Material "more" button, shown once the tabs overflow.
  final Widget moreButton;

  /// Darwin "more" action.
  final VoidCallback onMore;
  final String? moreTooltip;

  /// Whether the host must overlay the selector on its pages.
  static bool get floats => AdaptivePlatform.useGlass;

  /// Extra top padding the pages need below a floating selector; 0 when the
  /// selector does not float.
  static double get contentInset => floats
      ? GlassTokens.groupBarTopMargin + GlassTokens.groupBarHeight
      : 0;

  @override
  State<AdaptiveGroupSelector> createState() => _AdaptiveGroupSelectorState();
}

class _AdaptiveGroupSelectorState extends State<AdaptiveGroupSelector> {
  final _hasMoreButtonNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hasMoreButtonNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _buildGlass(context);
    // Moved verbatim from ProxiesTabViewState.build.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (scrollNotification) {
        _hasMoreButtonNotifier.value =
            scrollNotification.metrics.maxScrollExtent > 0;
        return true;
      },
      child: ValueListenableBuilder(
        valueListenable: _hasMoreButtonNotifier,
        builder: (_, value, child) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            TabBar(
              controller: widget.controller,
              padding: EdgeInsets.only(
                left: 16,
                right: 16 + (value ? 16 : 0),
              ),
              dividerColor: Colors.transparent,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              tabs: [
                for (final groupName in widget.labels)
                  Tab(
                    text: groupName,
                  ),
              ],
            ),
            if (value)
              Positioned(
                right: 0,
                child: child!,
              ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Theme.of(context).colorScheme.surface.opacity10,
                  Theme.of(context).colorScheme.surface,
                ],
                stops: const [
                  0.0,
                  0.1
                ]),
          ),
          child: widget.moreButton,
        ),
      ),
    );
  }

  Widget _buildGlass(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accessibility = GlassAccessibility.of(context);
    const inner = GlassTokens.groupBarInnerPadding;
    final capsule = scheme.primary.withValues(
      alpha: accessibility.opaque
          ? GlassTokens.selectionOpacityOpaque
          : GlassTokens.selectionOpacity(theme.brightness),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GlassTokens.groupBarHorizontalMargin,
        GlassTokens.groupBarTopMargin,
        GlassTokens.groupBarHorizontalMargin,
        0,
      ),
      child: GlassSurface(
        sigma: GlassTokens.barSigma,
        borderRadius: BorderRadius.circular(GlassTokens.groupBarRadius),
        shadow: true,
        child: SizedBox(
          height: GlassTokens.groupBarHeight,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: widget.controller,
                  padding: const EdgeInsets.all(inner),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: ShapeDecoration(
                    color: capsule,
                    shape: const StadiumBorder(),
                  ),
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: GlassTokens.groupBarItemPadding,
                  ),
                  labelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    for (final label in widget.labels)
                      Tab(
                        height: GlassTokens.groupBarHeight - inner * 2,
                        text: label,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: inner),
                child: GlassIconButton(
                  icon: const Icon(Icons.grid_view_rounded),
                  onPressed: widget.onMore,
                  size: GlassTokens.groupBarButtonSize,
                  iconSize: GlassTokens.groupBarIconSize,
                  tooltip: widget.moreTooltip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
