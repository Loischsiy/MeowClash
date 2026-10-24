import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meowclash/common/scroll.dart';

import 'adaptive_platform.dart';
import 'adaptive_tab_bar.dart';
import 'glass_accessibility.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// Side navigation of the tablet/desktop layout.
///
/// * macOS: a source-list sidebar. Flutter paints only a faint wash; the
///   translucency is the native `NSVisualEffectView` behind the transparent
///   Flutter view (macos/Runner/MainFlutterWindow.swift), so the sidebar costs
///   no `BackdropFilter`. It starts under the traffic lights (full-size content
///   view) and pads itself by the title-bar inset from `MediaQuery`.
/// * iOS (iPad): the same layout on a solid grouped background.
/// * Everything else: the Material 3 `NavigationRail` exactly as before.
class AdaptiveSidebar extends StatelessWidget {
  const AdaptiveSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.showLabel,
    required this.onToggleLabel,
    required this.title,
    required this.logo,
    this.showMaterialLogo = true,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Material: rail labels. Glass: extended (icon + title rows) sidebar.
  final bool showLabel;
  final VoidCallback onToggleLabel;

  final String title;
  final ImageProvider logo;

  /// The Material rail shows the logo block (hidden on macOS before glass).
  final bool showMaterialLogo;

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _GlassSidebar(sidebar: this);
    return _buildMaterial(context);
  }

  // Moved verbatim from lib/pages/home.dart: the Material rail must stay
  // pixel-identical (test/adaptive_chrome_golden_test.dart).
  Widget _buildMaterial(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colorScheme.surfaceContainer,
      child: Column(
        children: [
          // App logo at the top of sidebar
          if (showMaterialLogo) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircleAvatar(
                      foregroundImage: logo,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
          Expanded(
            child: ScrollConfiguration(
              behavior: HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: colorScheme.surfaceContainer,
                    selectedIconTheme: IconThemeData(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    selectedLabelTextStyle: textTheme.labelLarge!.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    unselectedLabelTextStyle: textTheme.labelLarge!.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    destinations: destinations
                        .map(
                          (e) => NavigationRailDestination(
                            icon: e.icon,
                            label: Text(e.label),
                          ),
                        )
                        .toList(),
                    onDestinationSelected: onSelected,
                    extended: false,
                    selectedIndex: selectedIndex,
                    labelType: showLabel
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          IconButton(
            onPressed: onToggleLabel,
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    );
  }
}

class _GlassSidebar extends StatelessWidget {
  const _GlassSidebar({required this.sidebar});

  final AdaptiveSidebar sidebar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final extended = sidebar.showLabel;
    final topInset = MediaQuery.paddingOf(context).top;
    final width =
        extended ? GlassTokens.sidebarExtendedWidth : GlassTokens.sidebarWidth;
    final hairline = (brightness == Brightness.dark ? Colors.white : Colors.black)
        .withValues(alpha: GlassTokens.hairlineOpacity(brightness));
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        GlassTokens.sidebarPadding,
        topInset + GlassTokens.sidebarPadding,
        GlassTokens.sidebarPadding,
        GlassTokens.sidebarPadding,
      ),
      child: Column(
        crossAxisAlignment:
            extended ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          _SidebarHeader(
            title: sidebar.title,
            logo: sidebar.logo,
            extended: extended,
          ),
          const SizedBox(height: GlassTokens.sidebarPadding),
          Expanded(
            child: ScrollConfiguration(
              behavior: HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sidebar.destinations.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: GlassTokens.sidebarRowGap,
                        ),
                        child: _SidebarRow(
                          destination: sidebar.destinations[i],
                          selected: i == sidebar.selectedIndex,
                          extended: extended,
                          onTap: () => sidebar.onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment:
                extended ? AlignmentDirectional.centerStart : Alignment.center,
            child: IconButton(
              onPressed: sidebar.onToggleLabel,
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              iconSize: GlassTokens.sidebarIconSize,
              color: scheme.onSurfaceVariant,
              icon: const Icon(Icons.view_sidebar_outlined),
            ),
          ),
        ],
      ),
    );

    final background = isMacOS
        ? GlassSurface(
            backdrop: GlassBackdrop.native,
            rim: false,
            color: scheme.surfaceContainer,
            opaqueColor: scheme.surfaceContainer,
            child: content,
          )
        : ColoredBox(color: scheme.surfaceContainerLow, child: content);

    return AnimatedContainer(
      duration: GlassTokens.motion(
        GlassTokens.morphDuration,
        reduceMotion: accessibility.reduceMotion,
      ),
      curve: GlassTokens.morphCurve,
      width: width,
      decoration: BoxDecoration(
        border: BorderDirectional(
          end: BorderSide(color: hairline, width: GlassTokens.hairlineWidth),
        ),
      ),
      // The row labels must not wrap while the width animates.
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.topStart,
          minWidth: 0,
          maxWidth: width,
          child: background,
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.title,
    required this.logo,
    required this.extended,
  });

  final String title;
  final ImageProvider logo;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = SizedBox.square(
      dimension: GlassTokens.sidebarLogoSize,
      child: CircleAvatar(
        foregroundImage: logo,
        backgroundColor: Colors.transparent,
      ),
    );
    if (!extended) return image;
    return Row(
      children: [
        image,
        const SizedBox(width: GlassTokens.sidebarPadding),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final AdaptiveDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final accessibility = GlassAccessibility.of(context);
    final selected = widget.selected;
    final Color fill;
    if (selected) {
      fill = scheme.primary.withValues(
        alpha: accessibility.opaque
            ? GlassTokens.selectionOpacityOpaque
            : GlassTokens.selectionOpacity(brightness),
      );
    } else if (_hovered) {
      fill = scheme.onSurface
          .withValues(alpha: GlassTokens.hoverOpacity(brightness));
    } else {
      fill = scheme.onSurface.withValues(alpha: 0);
    }
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final icon = IconTheme.merge(
      data: IconThemeData(
        color: foreground,
        size: widget.extended
            ? GlassTokens.sidebarIconSize
            : GlassTokens.sidebarCompactIconSize,
      ),
      child: widget.destination.icon,
    );
    final Widget body = widget.extended
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GlassTokens.sidebarPadding,
            ),
            child: Row(
              children: [
                icon,
                const SizedBox(width: GlassTokens.sidebarPadding),
                Expanded(
                  child: Text(
                    widget.destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Center(child: icon);

    Widget row = Semantics(
      button: true,
      selected: selected,
      label: widget.destination.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: GlassTokens.motion(
              GlassTokens.hoverDuration,
              reduceMotion: accessibility.reduceMotion,
            ),
            height: widget.extended
                ? GlassTokens.sidebarRowHeight
                : GlassTokens.sidebarCompactRowHeight,
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedSuperellipseBorder(
                borderRadius:
                    BorderRadius.circular(GlassTokens.sidebarRowRadius),
              ),
            ),
            child: body,
          ),
        ),
      ),
    );
    if (!widget.extended) {
      row = Tooltip(message: widget.destination.label, child: row);
    }
    return row;
  }
}
