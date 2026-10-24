import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';

/// Darwin-only overlay for the app [ThemeData].
///
/// The color scheme still comes from the app's own generator, so MeowClash
/// keeps its identity; only the seed follows the system accent on macOS (when
/// it is not "Multicolor"), and chrome-level components become transparent so
/// the glass surfaces of the adaptive layer show through. Content widgets are
/// not restyled here (phase 2).
abstract final class GlassTheme {
  /// The seed to use instead of the user-picked primary color, or `null` to
  /// keep the app's own color (macOS "Multicolor", iOS, non-Darwin).
  static Color? seedOverride(GlassAccessibility accessibility) =>
      AdaptivePlatform.useGlass ? accessibility.accentColor : null;

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
}
