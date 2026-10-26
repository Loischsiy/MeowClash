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
    this.leading,
    this.trailing,
  });

  final Widget child;

  /// Header: symbol and title. Without it the child fills the tile.
  final Info? info;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Passed through to `CommonCard` on Material.
  final EdgeInsets? padding;

  /// Darwin only: replaces the header symbol (e.g. a country flag).
  final Widget? leading;

  /// Darwin only: a small control at the trailing edge of the header.
  final Widget? trailing;

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
          GlassWidgetTileHeader(
            info: header,
            leading: leading,
            trailing: trailing,
          ),
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
  const GlassWidgetTileHeader({
    super.key,
    required this.info,
    this.leading,
    this.trailing,
  });

  final Info info;

  /// Replaces the symbol of [info].
  final Widget? leading;

  /// Pinned to the trailing edge; the title takes the space in between.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mac = AdaptivePlatform.isMacOSGlass;
    final padding = AdaptiveWidgetTile.glassPadding();
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
      child: Row(
        children: [
          if (leading case final leading?) ...[
            leading,
            const SizedBox(width: GlassTokens.widgetTileSymbolGap),
          ] else if (info.iconData != null) ...[
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
            fit: trailing == null ? FlexFit.loose : FlexFit.tight,
            child: Text(
              info.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GlassTextStyles.widgetTitle(theme.textTheme).copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing case final trailing?) trailing,
        ],
      ),
    );
  }
}

/// Content area of a glass tile under its header: inset like the header and
/// placed at the bottom-start, where widgets keep their figure. Darwin only.
class GlassWidgetTileBody extends StatelessWidget {
  const GlassWidgetTileBody({
    super.key,
    required this.child,
    this.alignment = AlignmentDirectional.bottomStart,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final padding = AdaptiveWidgetTile.glassPadding();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        padding,
        GlassTokens.widgetRowGap,
        padding,
        padding,
      ),
      child: Align(alignment: alignment, child: child),
    );
  }
}

/// The large tabular figure of a glass tile with an optional caption under
/// it (unit, date). The block scales down rather than overflow — in width
/// on a narrow tile, in height on a one-row tile or with large text. Darwin
/// only.
class GlassWidgetValue extends StatelessWidget {
  const GlassWidgetValue({
    super.key,
    required this.value,
    this.unit,
    this.caption,
    this.color,
  });

  final String value;

  /// Shown after the value in the caption style, on the same baseline.
  final String? unit;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final secondary = theme.colorScheme.onSurfaceVariant;
    final captionStyle =
        GlassTextStyles.widgetCaption(textTheme).copyWith(color: secondary);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.bottomStart,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' ${unit!}',
                    style: GlassTextStyles.widgetTitle(textTheme)
                        .copyWith(color: secondary),
                  ),
              ],
            ),
            maxLines: 1,
            style: GlassTextStyles.widgetValue(textTheme).copyWith(
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
        if (caption != null) ...[
          const SizedBox(height: GlassTokens.widgetLineGap),
          Text(
            caption!,
            maxLines: 1,
            style: captionStyle,
          ),
        ],
      ],
      ),
    );
  }
}
