import 'package:flutter/material.dart';
import 'package:meowclash/common/color.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// One entry of [AdaptiveTabBar] / `AdaptiveSidebar`.
@immutable
class AdaptiveDestination {
  const AdaptiveDestination({required this.icon, required this.label});

  final Widget icon;
  final String label;
}

/// Bottom navigation of the mobile layout.
///
/// * Darwin: a floating Liquid Glass capsule above the home indicator. The
///   hosting scaffold uses `Scaffold.extendBody` (see
///   [AdaptiveTabBar.extendsBody]) so the capsule floats over the page
///   background, while `CommonScaffold` keeps the page content above it:
///   nothing (e.g. the dashboard start button) may end up under the bar.
/// * Everything else: the Material 3 `NavigationBar` exactly as before.
class AdaptiveTabBar extends StatelessWidget {
  const AdaptiveTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Whether the scaffold hosting the bar should lay its body out behind it.
  static bool get extendsBody => AdaptivePlatform.useGlass;

  /// Bottom space the floating bar occupies (capsule + gap or home
  /// indicator) when [extendsBody] is on; 0 otherwise.
  static double bottomInset(BuildContext context) {
    if (!extendsBody) return 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return GlassTokens.tabBarHeight +
        (safeBottom > 0 ? safeBottom : GlassTokens.tabBarBottomGap);
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) {
      return _GlassTabBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      );
    }
    return NavigationBarTheme(
      data: _NavigationBarDefaultsM3(context),
      child: NavigationBar(
        destinations: destinations
            .map(
              (e) => NavigationDestination(
                icon: e.icon,
                label: e.label,
              ),
            )
            .toList(),
        onDestinationSelected: onSelected,
        selectedIndex: selectedIndex,
      ),
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final radius = BorderRadius.circular(GlassTokens.tabBarRadius);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        GlassTokens.tabBarHorizontalMargin,
        0,
        GlassTokens.tabBarHorizontalMargin,
        bottomInset > 0 ? bottomInset : GlassTokens.tabBarBottomGap,
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: GlassSurface(
          sigma: GlassTokens.barSigma,
          borderRadius: radius,
          shadow: true,
          child: SizedBox(
            height: GlassTokens.tabBarHeight,
            child: Padding(
              padding: const EdgeInsets.all(GlassTokens.tabBarInnerPadding),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _GlassTabItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTabItem extends StatelessWidget {
  const _GlassTabItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AdaptiveDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final duration = GlassTokens.motion(
      GlassTokens.morphDuration,
      reduceMotion: accessibility.reduceMotion,
    );
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final capsule = selected
        ? scheme.primary.withValues(
            alpha: accessibility.opaque
                ? GlassTokens.selectionOpacityOpaque
                : GlassTokens.selectionOpacity(brightness),
          )
        : scheme.primary.withValues(alpha: 0);
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: GlassTokens.morphCurve,
          decoration: ShapeDecoration(
            color: capsule,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(
                GlassTokens.tabBarRadius - GlassTokens.tabBarInnerPadding,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  size: GlassTokens.tabBarIconSize,
                  color: foreground,
                ),
                child: destination.icon,
              ),
              const SizedBox(height: GlassTokens.tabBarLabelGap),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Moved verbatim from lib/pages/home.dart: the Material bar must stay
// pixel-identical (test/adaptive_chrome_golden_test.dart).
class _NavigationBarDefaultsM3 extends NavigationBarThemeData {
  _NavigationBarDefaultsM3(this.context)
      : super(
          height: 80.0,
          elevation: 3.0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor => _colors.surfaceContainer;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) => IconThemeData(
            size: 24.0,
            color: states.contains(WidgetState.disabled)
                ? _colors.onSurfaceVariant.opacity38
                : states.contains(WidgetState.selected)
                    ? _colors.onSecondaryContainer
                    : _colors.onSurfaceVariant,
          ));

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  ShapeBorder? get indicatorShape => const StadiumBorder();

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle =>
      WidgetStateProperty.resolveWith((Set<WidgetState> states) =>
          _textTheme.labelMedium!.apply(
              overflow: TextOverflow.ellipsis,
              color: states.contains(WidgetState.disabled)
                  ? _colors.onSurfaceVariant.opacity38
                  : states.contains(WidgetState.selected)
                      ? _colors.onSurface
                      : _colors.onSurfaceVariant));
}
