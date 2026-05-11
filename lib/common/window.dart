import 'dart:io';

import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  Future<void> init(int version) async {
    final props = globalState.config.windowProps;
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      exit(0);
    }
    if (system.isWindows) {
      protocol.register('clash');
      protocol.register('clashmeta');
      protocol.register('bettbox');
    }
    if ((version > 10 && system.isMacOS)) {
      await acrylic.Window.initialize();
    }
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: Size(props.width, props.height),
      minimumSize: const Size(380, 400),
    );
    if (!system.isMacOS || version > 10) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    if (!system.isMacOS) {
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      final right = left + props.width;
      final bottom = top + props.height;
      if (left == 0 && top == 0) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        final displays = await screenRetriever.getAllDisplays();
        final isPositionValid = displays.any((display) {
          final displayBounds = Rect.fromLTWH(
            display.visiblePosition!.dx,
            display.visiblePosition!.dy,
            display.size.width,
            display.size.height,
          );
          return displayBounds.contains(Offset(left, top)) ||
              displayBounds.contains(Offset(right, bottom));
        });
        if (isPositionValid) {
          await windowManager.setPosition(Offset(left, top));
        }
      }
    }
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
    });

    if (props.isLocked) {
      try {
        await windowManager.setResizable(false);
      } catch (e) {
        commonPrint.log('Failed to apply the locked state: $e');
      }
    }
  }

  void updateMacOSBrightness(Brightness brightness) {
    if (!system.isMacOS) {
      return;
    }
    acrylic.Window.overrideMacOSBrightness(dark: brightness == Brightness.dark);
  }

  Future<void> show() async {
    globalState.handleForeground();
    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
    await globalState.resumeForegroundUpdates();
    await globalState.appController.syncWakelockIfNeeded();
  }

  Future<bool> get isVisible async {
    return await windowManager.isVisible();
  }

  Future<bool> get isMinimized async {
    return await windowManager.isMinimized();
  }

  Future<void> close() async {
    try {
      await trayManager.destroy();
      commonPrint.log('The tray icon has been destroyed.');
    } catch (e) {
      commonPrint.log('Failed to destroy the tray icon: $e');
    }

    exit(0);
  }

  Future<void> hide() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
    await globalState.handleBackground();
  }
}

final window = system.isDesktop ? Window() : null;
