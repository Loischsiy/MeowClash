import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_tokens.dart';

/// The round badge on a tile in edit mode, as on the iOS home screen and in
/// the macOS widget gallery: [GlassEditBadge.remove] is a neutral "−",
/// [GlassEditBadge.add] a green "+". No blur, a small toolbar shadow to lift
/// it off the tile.
///
/// Darwin only; Material keeps its filled `IconButton`s.
class GlassEditBadge extends StatelessWidget {
  const GlassEditBadge.remove({
    super.key,
    required this.onPressed,
    this.tooltip,
  }) : add = false;

  const GlassEditBadge.add({
    super.key,
    required this.onPressed,
    this.tooltip,
  }) : add = true;

  final bool add;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final mac = AdaptivePlatform.isMacOSGlass;
    final size = GlassTokens.editBadgeSize(mac: mac);
    final badge = Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: add
                ? GlassTokens.systemGreen(brightness)
                : GlassTokens.editBadgeRemoveFill(brightness),
            boxShadow: GlassTokens.toolbarItemShadow(brightness),
          ),
          child: Icon(
            add ? Icons.add_rounded : Icons.remove_rounded,
            size: GlassTokens.editBadgeIconSize(mac: mac),
            color: add
                ? GlassTokens.editBadgeAddGlyph
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
    if (tooltip == null) return badge;
    return Tooltip(message: tooltip, child: badge);
  }
}
