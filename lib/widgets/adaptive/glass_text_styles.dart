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

  /// Large title of an iOS root page, in its own row below the toolbar.
  static TextStyle toolbarLargeTitle(TextTheme textTheme) => _style(
        textTheme.headlineLarge,
        size: GlassTokens.toolbarLargeTitleSizeIos,
        line: GlassTokens.toolbarLargeTitleLineIos,
        weight: FontWeight.w700,
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

  /// Dialog title.
  static TextStyle dialogTitle(TextTheme textTheme) => _style(
        textTheme.titleLarge,
        size: _mac ? GlassTokens.dialogTitleSizeMac : GlassTokens.dialogTitleSizeIos,
        line: _mac ? GlassTokens.dialogTitleLineMac : GlassTokens.dialogTitleLineIos,
        weight: FontWeight.w600,
      );

  /// Dialog text (messages, default text of the dialog content).
  static TextStyle dialogMessage(TextTheme textTheme) => _style(
        textTheme.bodyMedium,
        size: _mac
            ? GlassTokens.dialogMessageSizeMac
            : GlassTokens.dialogMessageSizeIos,
        line: _mac
            ? GlassTokens.dialogMessageLineMac
            : GlassTokens.dialogMessageLineIos,
        weight: FontWeight.w400,
      );

  /// Dialog button label; [preferred] is the confirming (last) action.
  static TextStyle dialogButton(TextTheme textTheme, {bool preferred = false}) =>
      _style(
        textTheme.labelLarge,
        size: _mac
            ? GlassTokens.dialogButtonSizeMac
            : GlassTokens.dialogButtonSizeIos,
        line: _mac
            ? GlassTokens.dialogButtonLineMac
            : GlassTokens.dialogButtonLineIos,
        weight: preferred && !_mac ? FontWeight.w600 : FontWeight.w400,
      );

  /// Text typed into a field.
  static TextStyle inputText(TextTheme textTheme) => _style(
        textTheme.bodyLarge,
        size: _mac ? GlassTokens.inputTextSizeMac : GlassTokens.inputTextSizeIos,
        line: _mac ? GlassTokens.inputTextLineMac : GlassTokens.inputTextLineIos,
        weight: FontWeight.w400,
      );

  /// Title of a grouped list row.
  static TextStyle listRowTitle(TextTheme textTheme) => _style(
        textTheme.bodyLarge,
        size: _mac
            ? GlassTokens.listRowTitleSizeMac
            : GlassTokens.listRowTitleSizeIos,
        line: _mac
            ? GlassTokens.listRowTitleLineMac
            : GlassTokens.listRowTitleLineIos,
        weight: FontWeight.w400,
      );

  /// Second line of a grouped list row.
  static TextStyle listRowSubtitle(TextTheme textTheme) => _style(
        textTheme.bodyMedium,
        size: _mac
            ? GlassTokens.listRowSubtitleSizeMac
            : GlassTokens.listRowSubtitleSizeIos,
        line: _mac
            ? GlassTokens.listRowSubtitleLineMac
            : GlassTokens.listRowSubtitleLineIos,
        weight: FontWeight.w400,
      );

  /// Header above a grouped list section: bold on macOS (System Settings),
  /// secondary footnote on iOS.
  static TextStyle listSectionHeader(TextTheme textTheme) => _style(
        textTheme.titleSmall,
        size: _mac
            ? GlassTokens.listSectionHeaderSizeMac
            : GlassTokens.listSectionHeaderSizeIos,
        line: _mac
            ? GlassTokens.listSectionHeaderLineMac
            : GlassTokens.listSectionHeaderLineIos,
        weight: _mac ? FontWeight.w600 : FontWeight.w400,
      );

  /// Explanation below a grouped list section.
  static TextStyle listSectionFooter(TextTheme textTheme) => _style(
        textTheme.bodySmall,
        size: _mac
            ? GlassTokens.listSectionFooterSizeMac
            : GlassTokens.listSectionFooterSizeIos,
        line: _mac
            ? GlassTokens.listSectionFooterLineMac
            : GlassTokens.listSectionFooterLineIos,
        weight: FontWeight.w400,
      );

  /// Symbol on a key cap; [large] in the shortcut recorder.
  static TextStyle keyCap(TextTheme textTheme, {bool large = false}) => _style(
        textTheme.labelLarge,
        size: large
            ? GlassTokens.keyCapLargeTextSize
            : _mac
                ? GlassTokens.keyCapTextSizeMac
                : GlassTokens.keyCapTextSizeIos,
        line: large
            ? GlassTokens.keyCapLargeTextLine
            : _mac
                ? GlassTokens.keyCapTextLineMac
                : GlassTokens.keyCapTextLineIos,
        weight: FontWeight.w500,
      );

  /// The small or [large] "A" at the ends of the text size slider.
  static TextStyle scaleGlyph(TextTheme textTheme, {required bool large}) =>
      _style(
        textTheme.bodyMedium,
        size: large
            ? _mac
                ? GlassTokens.scaleGlyphLargeSizeMac
                : GlassTokens.scaleGlyphLargeSizeIos
            : _mac
                ? GlassTokens.scaleGlyphSmallSizeMac
                : GlassTokens.scaleGlyphSmallSizeIos,
        line: large
            ? _mac
                ? GlassTokens.scaleGlyphLargeLineMac
                : GlassTokens.scaleGlyphLargeLineIos
            : _mac
                ? GlassTokens.scaleGlyphSmallLineMac
                : GlassTokens.scaleGlyphSmallLineIos,
        weight: FontWeight.w400,
      );

  /// App name in the About header.
  static TextStyle aboutTitle(TextTheme textTheme) => _style(
        textTheme.titleLarge,
        size: _mac
            ? GlassTokens.aboutTitleSizeMac
            : GlassTokens.aboutTitleSizeIos,
        line: _mac
            ? GlassTokens.aboutTitleLineMac
            : GlassTokens.aboutTitleLineIos,
        weight: FontWeight.w700,
      );

  /// A line of code (override rules); callers apply the monospaced family.
  static TextStyle codeLine(TextTheme textTheme) => _style(
        textTheme.bodyMedium,
        size: _mac ? GlassTokens.ruleTextSizeMac : GlassTokens.ruleTextSizeIos,
        line: _mac ? GlassTokens.ruleTextLineMac : GlassTokens.ruleTextLineIos,
        weight: FontWeight.w400,
      );

  /// Label of a content push button.
  static TextStyle button(TextTheme textTheme) => _style(
        textTheme.labelLarge,
        size: _mac ? GlassTokens.buttonTextSizeMac : GlassTokens.buttonTextSizeIos,
        line: _mac ? GlassTokens.buttonTextLineMac : GlassTokens.buttonTextLineIos,
        weight: _mac ? FontWeight.w500 : FontWeight.w600,
      );

  /// Label of a capsule floating button ("Save").
  static TextStyle floatingButtonLabel(TextTheme textTheme) => _style(
        textTheme.labelLarge,
        size: GlassTokens.floatingButtonLabelSize,
        line: GlassTokens.floatingButtonLabelLine,
        weight: FontWeight.w600,
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
