import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meowclash/widgets/null_status.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_tokens.dart';

/// Indeterminate progress.
///
/// * Darwin: `CupertinoActivityIndicator`.
/// * Everything else: `CircularProgressIndicator`, unchanged.
class AdaptiveActivityIndicator extends StatelessWidget {
  const AdaptiveActivityIndicator({
    super.key,
    this.radius = GlassTokens.activityIndicatorRadius,
    this.strokeWidth = 4,
  });

  /// Darwin spinner radius.
  final double radius;

  /// Material stroke width.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return CircularProgressIndicator(strokeWidth: strokeWidth);
    }
    return CupertinoActivityIndicator(radius: radius);
  }
}

/// Determinate progress (e.g. used subscription traffic).
///
/// * Darwin: a thin static capsule filled with [glassColor] (the accent by
///   default) on a faint track; the track turns opaque with Reduce
///   Transparency. Nothing animates, so Reduce Motion needs no extra case.
/// * Everything else: the rounded 6 px `LinearProgressIndicator` filled with
///   [color], unchanged.
class AdaptiveProgressBar extends StatelessWidget {
  const AdaptiveProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.glassColor,
  });

  /// 0..1.
  final double value;

  /// Material fill.
  final Color color;

  /// Darwin fill; defaults to the accent.
  final Color? glassColor;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final opaque = GlassAccessibility.of(context).opaque;
    final track = opaque
        ? scheme.surfaceContainerHighest
        : scheme.onSurface.withValues(
            alpha: GlassTokens.progressTrackOpacity(theme.brightness),
          );
    final radius = BorderRadius.circular(GlassTokens.progressBarRadius);
    return Semantics(
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: SizedBox(
        height: GlassTokens.progressBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(color: track, borderRadius: radius),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: glassColor ?? scheme.primary,
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder of an empty screen or list.
///
/// * Darwin: a muted symbol over a secondary-colored label, like the empty
///   states of Apple's own apps.
/// * Everything else: `NullStatus`, unchanged.
class AdaptiveEmptyState extends StatelessWidget {
  const AdaptiveEmptyState({
    super.key,
    required this.label,
    this.icon = Icons.inbox_outlined,
  });

  final String label;

  /// Darwin only; the Material placeholder is text-only.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) return NullStatus(label: label);
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GlassTokens.emptyStatePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: GlassTokens.emptyStateIconSize, color: color),
            const SizedBox(height: GlassTokens.emptyStateGap),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
