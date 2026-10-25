import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_field.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// Darwin-only overlay for the app [ThemeData].
///
/// The color scheme still comes from the app's own generator, so MeowClash
/// keeps its identity; only the seed follows the system accent on macOS (when
/// it is not "Multicolor"), and chrome-level components become transparent so
/// the glass surfaces of the adaptive layer show through. Content widgets are
/// not restyled here (phase 2). The bundled NotoSans is not used on Darwin:
/// see [fontFamily].
abstract final class GlassTheme {
  /// The seed to use instead of the user-picked primary color, or `null` to
  /// keep the app's own color (macOS "Multicolor", iOS, non-Darwin).
  static Color? seedOverride(GlassAccessibility accessibility) =>
      AdaptivePlatform.useGlass ? accessibility.accentColor : null;

  /// App font family: `null` on Darwin, so `ThemeData` keeps the Cupertino
  /// typography (the system San Francisco); [materialFamily] elsewhere.
  static String? fontFamily(String materialFamily) =>
      AdaptivePlatform.useGlass ? null : materialFamily;

  /// Font fallbacks: `null` on Darwin, so glyphs San Francisco lacks come
  /// from the system cascade (PingFang, Hiragino, Apple Color Emoji...);
  /// [materialFallback] elsewhere.
  static List<String>? fontFamilyFallback(List<String> materialFallback) =>
      AdaptivePlatform.useGlass ? null : materialFallback;

  static ThemeData apply(ThemeData base) => base.copyWith(
        // Apple controls highlight, they do not ripple.
        splashFactory: NoSplash.splashFactory,
        appBarTheme: base.appBarTheme.copyWith(
          // The bar color comes from AdaptiveAppBar (glass on iOS, the
          // unified window toolbar on macOS), never from Material elevation.
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          // Sheets paint their own GlassSurface (lib/widgets/sheet.dart).
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          modalElevation: 0,
        ),
      );

  /// Darwin overlay for forms (dialog content, later the profile editors):
  /// Apple-sized field text and rounded filled fields without an outline.
  /// macOS rings the focused field in the accent, iOS shows only the caret;
  /// errors get a hairline in the error color.
  ///
  /// The state borders are set on purpose: they win over the
  /// `border: OutlineInputBorder()` that call sites pass for Material, so the
  /// fields need no Darwin branch of their own.
  static ThemeData form(ThemeData base) {
    final scheme = base.colorScheme;
    final brightness = base.brightness;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final text = GlassTextStyles.inputText(base.textTheme);
    const rest = GlassFieldBorder();
    final error = GlassFieldBorder(
      borderSide: BorderSide(
        color: scheme.error,
        width: GlassTokens.inputErrorWidth,
      ),
    );
    final focused = mac
        ? GlassFieldBorder(
            borderSide: BorderSide(
              color: scheme.primary.withValues(
                alpha: GlassTokens.inputFocusOpacityMac,
              ),
              width: GlassTokens.inputFocusWidthMac,
            ),
          )
        : rest;
    return base.copyWith(
      textTheme: base.textTheme.copyWith(bodyLarge: text),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.onSurface.withValues(
          alpha: GlassTokens.inputFillOpacity(brightness),
        ),
        hoverColor: Colors.transparent,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: GlassTokens.inputHorizontalPadding,
          vertical: mac
              ? GlassTokens.inputVerticalPaddingMac
              : GlassTokens.inputVerticalPaddingIos,
        ),
        labelStyle: text.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.copyWith(color: scheme.onSurfaceVariant),
        border: rest,
        enabledBorder: rest,
        disabledBorder: rest,
        focusedBorder: focused,
        errorBorder: error,
        focusedErrorBorder: error,
      ),
    );
  }
}
