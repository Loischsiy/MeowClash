import 'dart:io';
import 'package:flutter/services.dart';
import 'package:meowclash/services/ui_lifecycle.dart';

/// Dart side of the macOS menu bar icon (`macos/Runner/StatusBarController.swift`).
///
/// The app is a regular window: window_manager reports focus/minimize/restore
/// and the initial visibility. Native code additionally asks Dart to show or
/// hide the window (menu bar icon, Dock reopen) and reports Cmd+H, which no
/// window event covers.
class StatusBarManager {
  static const MethodChannel _channel = MethodChannel('status_bar_icon');

  /// Called only by the macOS window bootstrap, before the window is shown.
  static void listen(
    UiLifecycleController controller, {
    required Future<void> Function() onShowWindow,
    required Future<void> Function() onHideWindow,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'visibilityChanged':
          if (call.arguments is bool) {
            controller.updateWindowVisibility(visible: call.arguments as bool);
          }
          return null;
        case 'showWindow':
          await onShowWindow();
          return true;
        case 'hideWindow':
          await onHideWindow();
          return true;
      }
      throw MissingPluginException();
    });
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
