import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_tokens.dart';

/// Text styles of glass content (proxy cards, group headers) on the Apple
/// type scale: macOS and iOS sizes from [GlassTokens], derived from the
/// app's [TextTheme] so font family and colors still follow the theme.
///
/// Darwin only; Material screens keep their `TextTheme` styles. Line heights
/// are exact, so fixed-height rows can be measured from the same style.
abstract final class GlassTextStyles {
  static bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  static TextStyle _style(
    TextStyle? base, {
    required double size,
    required double line,
    required FontWeight weight,
  }) =>
      (base ?? const TextStyle()).copyWith(
        fontSize: size,
        height: line / size,
        fontWeight: weight,
        letterSpacing: 0,
      );

  /// Proxy name.
  static TextStyle cardTitle(TextTheme textTheme) => _style(
        textTheme.bodyMedium,
        size: _mac ? GlassTokens.cardTitleSizeMac : GlassTokens.cardTitleSizeIos,
        line: _mac ? GlassTokens.cardTitleLineMac : GlassTokens.cardTitleLineIos,
        weight: FontWeight.w500,
      );

  /// Proxy type / description line.
  static TextStyle cardSubtitle(TextTheme textTheme) => _style(
        textTheme.bodySmall,
        size: _mac
            ? GlassTokens.cardSubtitleSizeMac
            : GlassTokens.cardSubtitleSizeIos,
        line: _mac
            ? GlassTokens.cardSubtitleLineMac
            : GlassTokens.cardSubtitleLineIos,
        weight: FontWeight.w400,
      );

  /// Label of the delay badge; its line height is the capsule height.
  static TextStyle delayBadge(TextTheme textTheme) => _style(
        textTheme.labelSmall,
        size: _mac ? GlassTokens.delayBadgeSizeMac : GlassTokens.delayBadgeSizeIos,
        line: _mac ? GlassTokens.delayBadgeLineMac : GlassTokens.delayBadgeLineIos,
        weight: FontWeight.w600,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Group name in a group header.
  static TextStyle groupTitle(TextTheme textTheme) => _style(
        textTheme.titleMedium,
        size: _mac ? GlassTokens.groupTitleSizeMac : GlassTokens.groupTitleSizeIos,
        line: _mac ? GlassTokens.groupTitleLineMac : GlassTokens.groupTitleLineIos,
        weight: FontWeight.w600,
      );

  /// Page title in the toolbar.
  static TextStyle toolbarTitle(TextTheme textTheme) => _style(
        textTheme.titleLarge,
        size: _mac
            ? GlassTokens.toolbarTitleSizeMac
            : GlassTokens.toolbarTitleSizeIos,
        line: _mac
            ? GlassTokens.toolbarTitleLineMac
            : GlassTokens.toolbarTitleLineIos,
        weight: FontWeight.w600,
      );

  /// Text of the toolbar search field.
  static TextStyle toolbarSearch(TextTheme textTheme) => _style(
        textTheme.bodyLarge,
        size: _mac
            ? GlassTokens.toolbarSearchSizeMac
            : GlassTokens.toolbarSearchSizeIos,
        line: _mac
            ? GlassTokens.toolbarSearchLineMac
            : GlassTokens.toolbarSearchLineIos,
        weight: FontWeight.w400,
      );

  /// Selected proxy under the group name.
  static TextStyle groupSubtitle(TextTheme textTheme) => _style(
        textTheme.labelMedium,
        size: _mac
            ? GlassTokens.groupSubtitleSizeMac
            : GlassTokens.groupSubtitleSizeIos,
        line: _mac
            ? GlassTokens.groupSubtitleLineMac
            : GlassTokens.groupSubtitleLineIos,
        weight: FontWeight.w400,
      );
}
