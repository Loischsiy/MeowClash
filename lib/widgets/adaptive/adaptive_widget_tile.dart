import 'package:flutter/material.dart';
import 'package:meowclash/widgets/card.dart';

import 'adaptive_card.dart';
import 'adaptive_platform.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// A dashboard widget tile.
///
/// * Darwin: a tile after the macOS 26 / iOS 26 widgets — the content card's
///   translucent fill and hairline (no blur: the grid scrolls), a larger
///   corner, and a header of the symbol in the accent next to a small
///   secondary title. Hover, press, keyboard focus and Reduce Transparency
///   come from [AdaptiveCard].
/// * Everything else: `CommonCard(info: …)`, unchanged.
class AdaptiveWidgetTile extends StatelessWidget {
  const AdaptiveWidgetTile({
    super.key,
    required this.child,
    this.info,
    this.onPressed,
    this.onLongPress,
    this.padding,
  });

  final Widget child;

  /// Header: symbol and title. Without it the child fills the tile.
  final Info? info;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Passed through to `CommonCard` on Material.
  final EdgeInsets? padding;

  /// Inner padding of the glass tile; content aligns to the header with it.
  static double glassPadding() => AdaptivePlatform.isMacOSGlass
      ? GlassTokens.widgetTilePaddingMac
      : GlassTokens.widgetTilePaddingIos;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return CommonCard(
        info: info,
        onPressed: onPressed,
        onLongPress: onLongPress,
        padding: padding,
        child: child,
      );
    }
    final radius =
        GlassTokens.widgetTileRadius(mac: AdaptivePlatform.isMacOSGlass);
    var content = child;
    final header = info;
    if (header != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassWidgetTileHeader(info: header),
          Flexible(child: child),
        ],
      );
    }
    return AdaptiveCard(
      radius: radius,
      onPressed: onPressed,
      onLongPress: onLongPress,
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// Header row of a glass dashboard tile: the symbol in the accent and the
/// title in small secondary text. Darwin only.
class GlassWidgetTileHeader extends StatelessWidget {
  const GlassWidgetTileHeader({super.key, required this.info});

  final Info info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mac = AdaptivePlatform.isMacOSGlass;
    final padding = AdaptiveWidgetTile.glassPadding();
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
      child: Row(
        children: [
          if (info.iconData != null) ...[
            Icon(
              info.iconData,
              size: mac
                  ? GlassTokens.widgetTileSymbolSizeMac
                  : GlassTokens.widgetTileSymbolSizeIos,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: GlassTokens.widgetTileSymbolGap),
          ],
          Flexible(
            child: Text(
              info.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GlassTextStyles.widgetTitle(theme.textTheme).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
