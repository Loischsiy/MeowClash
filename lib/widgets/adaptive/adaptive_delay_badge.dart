import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// Latency of one proxy: `null` = not tested yet, `0` = test running,
/// `< 0` = timeout, otherwise milliseconds. Tapping it starts a new test.
///
/// * Darwin: a capsule tinted with [color]; a `CupertinoActivityIndicator`
///   while testing; a bolt symbol before the first test.
/// * Everything else: the colored text, spinner and bolt button the proxy
///   card always had.
class AdaptiveDelayBadge extends StatelessWidget {
  const AdaptiveDelayBadge({
    super.key,
    required this.delay,
    required this.color,
    required this.height,
    required this.onTest,
  });

  final int? delay;

  /// Color of the measured delay (`utils.getDelayColor`).
  final Color? color;

  /// Line height the badge must fit in (`labelSmall` on Material, the
  /// [GlassTextStyles.delayBadge] line on Darwin).
  final double height;

  final VoidCallback onTest;

  String _label(int delay) => delay > 0 ? '$delay ms' : 'Timeout';

  @override
  Widget build(BuildContext context) {
    final delay = this.delay;
    if (!AdaptivePlatform.useGlass) {
      // Moved verbatim from ProxyCard._buildDelayText.
      return delay == 0 || delay == null
          ? SizedBox(
              height: height,
              width: height,
              child: delay == 0
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                    )
                  : IconButton(
                      icon: const Icon(Icons.bolt),
                      iconSize: height,
                      padding: EdgeInsets.zero,
                      onPressed: onTest,
                    ),
            )
          : GestureDetector(
              onTap: onTest,
              child: Text(
                _label(delay),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      overflow: TextOverflow.ellipsis,
                      color: color,
                    ),
              ),
            );
    }

    final theme = Theme.of(context);
    if (delay == 0) {
      return SizedBox.square(
        dimension: height,
        child: CupertinoActivityIndicator(
          radius: height * GlassTokens.delayIndicatorRadiusFactor,
        ),
      );
    }
    if (delay == null) {
      return Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTest,
          child: SizedBox.square(
            dimension: height,
            child: Icon(
              Icons.bolt_rounded,
              size: height * GlassTokens.delayBoltSizeFactor,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    final opaque = GlassAccessibility.of(context).opaque;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTest,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(
            horizontal: GlassTokens.delayPillHorizontalPadding,
          ),
          decoration: ShapeDecoration(
            color: tint.withValues(
              alpha: opaque
                  ? GlassTokens.selectionOpacityOpaque
                  : GlassTokens.delayPillOpacity(theme.brightness),
            ),
            shape: const StadiumBorder(),
          ),
          // Shrink-wraps the label horizontally (the badge also sits in
          // start-aligned columns) and centers it vertically.
          child: Align(
            widthFactor: 1,
            child: Text(
              _label(delay),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GlassTextStyles.delayBadge(theme.textTheme).copyWith(
                color: tint,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
