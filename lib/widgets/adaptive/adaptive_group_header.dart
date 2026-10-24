import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_icon_button.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

/// Header of a collapsible group in a scrolling list (proxy groups).
///
/// * Darwin: a fixed-height row — optional leading icon, title, subtitle, a
///   test button and a chevron. While its group scrolls under it the list
///   pins it and passes [pinned]: it then becomes the one blurred
///   [GlassSurface] of the list; at rest it is a translucent card without
///   blur. Use [extent] for the pinned sliver.
/// * Everything else: [materialBuilder], i.e. the old Material header
///   unchanged.
class AdaptiveGroupHeader extends StatelessWidget {
  const AdaptiveGroupHeader({
    super.key,
    required this.materialBuilder,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.onTest,
    this.leading,
    this.subtitle,
    this.testing = false,
    this.pinned = false,
  });

  final WidgetBuilder materialBuilder;
  final String title;
  final Widget? leading;

  /// Second line, e.g. the selected proxy. Its line is reserved even when
  /// `null`, so the header keeps one height.
  final Widget? subtitle;

  final bool expanded;
  final VoidCallback onToggle;

  /// `null` disables the test button.
  final VoidCallback? onTest;

  /// Shows a spinner in the test button.
  final bool testing;

  /// The header is stuck to the top with content scrolling under it.
  final bool pinned;

  /// Height of the Darwin header for [titleHeight] / [subtitleHeight] (the
  /// measured `titleMedium` / `labelMedium` lines).
  static double extent({
    required double titleHeight,
    required double subtitleHeight,
  }) {
    final content = math.max(
      math.max(
        GlassTokens.groupHeaderIconSize,
        GlassTokens.groupHeaderButtonSize,
      ),
      titleHeight + GlassTokens.groupHeaderTitleGap + subtitleHeight,
    );
    return content +
        GlassTokens.groupHeaderVerticalPadding * 2 +
        GlassTokens.groupHeaderMargin * 2;
  }

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) return materialBuilder(context);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final dark = brightness == Brightness.dark;
    final accessibility = GlassAccessibility.of(context);
    final radius = BorderRadius.circular(GlassTokens.groupHeaderRadius);

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GlassTokens.groupHeaderHorizontalPadding,
        vertical: GlassTokens.groupHeaderVerticalPadding,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox.square(
              dimension: GlassTokens.groupHeaderIconSize,
              child: leading,
            ),
            const SizedBox(width: GlassTokens.groupHeaderIconGap),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: GlassTokens.groupHeaderTitleGap),
                DefaultTextStyle.merge(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  child: subtitle ?? const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(width: GlassTokens.groupHeaderButtonGap),
          GlassIconButton(
            icon: const Icon(CupertinoIcons.speedometer),
            onPressed: onTest,
            busy: testing,
          ),
          const SizedBox(width: GlassTokens.groupHeaderButtonGap),
          GlassIconButton(
            icon: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: GlassTokens.motion(
                GlassTokens.morphDuration,
                reduceMotion: accessibility.reduceMotion,
              ),
              curve: GlassTokens.morphCurve,
              child: const Icon(CupertinoIcons.chevron_down),
            ),
            onPressed: onToggle,
          ),
        ],
      ),
    );

    final Widget surface;
    if (pinned) {
      surface = GlassSurface(
        sigma: GlassTokens.barSigma,
        borderRadius: radius,
        shadow: true,
        child: row,
      );
    } else {
      final base =
          dark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;
      surface = DecoratedBox(
        decoration: ShapeDecoration(
          color: accessibility.opaque
              ? base
              : base.withValues(
                  alpha: GlassTokens.cardFillOpacity(brightness),
                ),
          shape: RoundedSuperellipseBorder(
            borderRadius: radius,
            side: BorderSide(
              color: (dark ? Colors.white : Colors.black)
                  .withValues(alpha: GlassTokens.hairlineOpacity(brightness)),
              width: GlassTokens.hairlineWidth,
            ),
          ),
        ),
        child: row,
      );
    }

    return Semantics(
      container: true,
      header: true,
      expanded: expanded,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: GlassTokens.groupHeaderMargin,
          ),
          child: surface,
        ),
      ),
    );
  }
}
