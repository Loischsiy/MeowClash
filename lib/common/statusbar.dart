import 'dart:io';
import 'package:flutter/services.dart';
import 'package:meowclash/services/ui_lifecycle.dart';

class StatusBarManager {
  static const MethodChannel _channel = MethodChannel('status_bar_icon');

  /// Called only by the macOS window bootstrap. Listen before requesting the
  /// snapshot so an opening/closing popover cannot be lost during startup.
  static Future<void> initVisibility(UiLifecycleController controller) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'visibilityChanged' && call.arguments is bool) {
        controller.updateWindowVisibility(visible: call.arguments as bool);
      }
    });
    try {
      await controller.synchronizeWindowVisibility(() async =>
          await _channel.invokeMethod<bool>('isVisible') ?? true);
    } on MissingPluginException {
      // A hot-reloaded Dart app can be using an older native runner. Fall back
      // to Flutter lifecycle rather than leaving its UI permanently hidden.
      controller.updateWindowVisibility(visible: null);
    }
  }

  static Future<void> updateIcon({required bool isConnected}) async {
    if (!Platform.isMacOS) return;

    try {
      await _channel.invokeMethod('updateIcon', {
        'isConnected': isConnected,
      });
    } catch (e) {
      // silent
    }
  }
}
