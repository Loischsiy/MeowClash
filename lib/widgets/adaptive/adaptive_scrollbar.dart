import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meowclash/widgets/scroll.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_tokens.dart';

/// Scrollbar of long lists (requests, connections, logs).
///
/// * macOS: the thin AppKit overlay scroller — no track, a rounded thumb
///   that shows while scrolling and fades out when the list rests (at once
///   with Reduce Motion); it can still be dragged.
/// * iOS: `CupertinoScrollbar`.
/// * Everything else: `CommonScrollBar` (always visible 8 px track),
///   unchanged.
class AdaptiveScrollbar extends StatelessWidget {
  const AdaptiveScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return CommonScrollBar(controller: controller, child: child);
    }
    if (!AdaptivePlatform.isMacOSGlass) {
      return CupertinoScrollbar(controller: controller, child: child);
    }
    final theme = Theme.of(context);
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    return RawScrollbar(
      controller: controller,
      thickness: GlassTokens.scrollbarThicknessMac,
      radius: const Radius.circular(GlassTokens.scrollbarThicknessMac / 2),
      crossAxisMargin: GlassTokens.scrollbarMarginMac,
      mainAxisMargin: GlassTokens.scrollbarMarginMac,
      thumbColor: theme.colorScheme.onSurface.withValues(
        alpha: GlassTokens.scrollbarOpacity(theme.brightness),
      ),
      fadeDuration: GlassTokens.motion(
        GlassTokens.scrollbarFadeDuration,
        reduceMotion: reduceMotion,
      ),
      timeToFade: GlassTokens.scrollbarTimeToFade,
      interactive: true,
      child: child,
    );
  }
}
