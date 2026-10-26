import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';

/// Tells AppKit which appearance the app uses, so the native layers under
/// the transparent Flutter view match the Flutter theme.
///
/// On macOS the sidebar shows an `NSVisualEffectView` (and on macOS 26 an
/// `NSGlassEffectView`) through the window, and context / pop-up menus are
/// `NSMenu`s. They follow the system appearance unless told otherwise, so a
/// light app on a dark system got a dark sidebar under light text. This sets
/// `NSApp.appearance` from [themeMode]: `system` → follow macOS, `light` →
/// Aqua, `dark` → Dark Aqua.
///
/// A plain pass-through everywhere but macOS glass; with an older native
/// runner the call is ignored.
class GlassWindowAppearance extends StatefulWidget {
  const GlassWindowAppearance({
    super.key,
    required this.themeMode,
    required this.child,
  });

  final ThemeMode themeMode;
  final Widget child;

  /// Name sent as `mode` to `setAppearance`.
  static String modeName(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  @override
  State<GlassWindowAppearance> createState() => _GlassWindowAppearanceState();
}

class _GlassWindowAppearanceState extends State<GlassWindowAppearance> {
  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void didUpdateWidget(GlassWindowAppearance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.themeMode != widget.themeMode) _send();
  }

  void _send() {
    if (!AdaptivePlatform.isMacOSGlass) return;
    unawaited(_invoke(GlassWindowAppearance.modeName(widget.themeMode)));
  }

  static Future<void> _invoke(String mode) async {
    try {
      await GlassAccessibilityController.channel.invokeMethod<void>(
        'setAppearance',
        {'mode': mode},
      );
    } on MissingPluginException {
      // Hot reload onto an older runner: the native layers keep following
      // the system appearance.
    } on PlatformException {
      // Same: nothing to fall back to.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
