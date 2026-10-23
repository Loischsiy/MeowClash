import 'package:flutter/foundation.dart';

/// Decides which chrome family a widget renders: Darwin glass or Material 3.
///
/// Resolution uses [defaultTargetPlatform], which follows the real OS in
/// release builds and honours `debugDefaultTargetPlatformOverride` in tests,
/// so every branch can be exercised from `flutter test` on any host.
abstract final class AdaptivePlatform {
  /// Forces the glass decision in tests or for debugging; `null` follows the
  /// platform.
  static bool? debugUseGlassOverride;

  /// Glass chrome is used on macOS and iOS only. Android, Linux and Windows
  /// always get the unchanged Material widgets.
  static bool get useGlass {
    final override = debugUseGlassOverride;
    if (override != null) return override;
    if (kIsWeb) return false;
    return isDarwin;
  }

  static bool get isDarwin =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMacOSGlass =>
      useGlass && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isIOSGlass =>
      useGlass && defaultTargetPlatform == TargetPlatform.iOS;
}

/// Graceful-degradation switches for the glass layer.
abstract final class GlassFlags {
  /// Global kill switch for `BackdropFilter`. When false every glass surface
  /// renders its opaque fallback (same look as Reduce Transparency), which
  /// keeps older or GPU-limited Macs smooth.
  ///
  /// Defaults from `--dart-define=MEOWCLASH_GLASS_BLUR=false`; it can also be
  /// flipped at runtime before the first frame.
  static bool backdropBlurEnabled =
      const bool.fromEnvironment('MEOWCLASH_GLASS_BLUR', defaultValue: true);
}
