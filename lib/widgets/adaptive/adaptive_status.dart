import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meowclash/widgets/null_status.dart';

import 'adaptive_platform.dart';
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

/// Placeholder of an empty screen or list.
///
/// * Darwin: a muted symbol over a secondary-colored label, like the empty
///   states of Apple's own apps.
/// * Everything else: `NullStatus`, unchanged.
class AdaptiveEmptyState extends StatelessWidget {
  const AdaptiveEmptyState({
    super.key,
    required this.label,
    this.icon = CupertinoIcons.tray,
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
