import 'dart:async';
import 'dart:io';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/models/models.dart';
import 'package:meow_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'common.dart';

class Tray {
  Timer? _debounceTimer;
  TrayState? _pendingState;
  bool _isUpdating = false;

  static const _debounceDelay = Duration(milliseconds: 300);
  Future _updateSystemTray({
    required Brightness? brightness,
    required bool isStart,
    bool force = false,
  }) async {
    if (system.isAndroid) {
      return;
    }
    if (force) {
      await trayManager.destroy();
    }
    await trayManager.setIcon(
      utils.getTrayIconPath(
        brightness:
            brightness ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
        isStart: isStart,
      ),
      isTemplate: system.isMacOS,
    );
    if (!Platform.isLinux) {
      await trayManager.setToolTip(appName);
    }
  }

  Future<void> update({
    required TrayState trayState,
    bool focus = false,
  }) async {
    if (system.isAndroid) {
      return;
    }

    _debounceTimer?.cancel();

    if (_isUpdating) {
      _pendingState = trayState;
      return;
    }

    if (focus) {
      await _doUpdate(trayState: trayState, focus: focus);
    } else {
      _debounceTimer = Timer(_debounceDelay, () async {
        await _doUpdate(trayState: trayState, focus: focus);
      });
    }
  }

  Future<void> _doUpdate({
    required TrayState trayState,
    bool focus = false,
  }) async {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      if (!Platform.isLinux) {
        await _updateSystemTray(
          brightness: trayState.brightness,
          isStart: trayState.isStart,
          force: focus,
        );
      }
    List<MenuItem> menuItems = [];
    final showMenuItem = MenuItem(
      label: appLocalizations.show,
      onClick: (_) {
        window?.show();
      },
    );
    menuItems.add(showMenuItem);
    final startMenuItem = MenuItem.checkbox(
      label: trayState.isStart ? appLocalizations.stop : appLocalizations.start,
      onClick: (_) async {
        globalState.appController.updateStart();
      },
      checked: false,
    );
    menuItems.add(startMenuItem);
    menuItems.add(MenuItem.separator());
    for (final mode in Mode.values) {
      menuItems.add(
        MenuItem.checkbox(
          label: Intl.message(mode.name),
          onClick: (_) {
            globalState.appController.changeMode(mode);
          },
          checked: mode == trayState.mode,
        ),
      );
    }
    menuItems.add(MenuItem.separator());
    for (final group in trayState.groups) {
      List<MenuItem> subMenuItems = [];
      for (final proxy in group.all) {
        subMenuItems.add(
          MenuItem.checkbox(
            label: proxy.name,
            checked: trayState.selectedMap[group.name] == proxy.name,
            onClick: (_) {
              final appController = globalState.appController;
              appController.updateCurrentSelectedMap(group.name, proxy.name);
              appController.changeProxy(
                groupName: group.name,
                proxyName: proxy.name,
              );
            },
          ),
        );
      }
      menuItems.add(
        MenuItem.submenu(
          label: group.name,
          submenu: Menu(items: subMenuItems),
        ),
      );
    }
    if (trayState.groups.isNotEmpty) {
      menuItems.add(MenuItem.separator());
    }
    if (trayState.isStart) {
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.tun,
          onClick: (_) {
            globalState.appController.updateTun();
          },
          checked: trayState.tunEnable,
        ),
      );
      menuItems.add(
        MenuItem.checkbox(
          label: appLocalizations.systemProxy,
          onClick: (_) {
            globalState.appController.updateSystemProxy();
          },
          checked: trayState.systemProxy,
        ),
      );
      menuItems.add(MenuItem.separator());
    }
    final autoStartMenuItem = MenuItem.checkbox(
      label: appLocalizations.autoLaunch,
      onClick: (_) async {
        globalState.appController.updateAutoLaunch();
      },
      checked: trayState.autoLaunch,
    );
    final copyEnvVarMenuItem = MenuItem(
      label: appLocalizations.copyEnvVar,
      onClick: (_) async {
        await _copyEnv(trayState.port);
      },
    );
    menuItems.add(autoStartMenuItem);
    menuItems.add(copyEnvVarMenuItem);

    if (!system.isAndroid) {
      final wakelockMenuItem = MenuItem.checkbox(
        label: appLocalizations.wakelock,
        onClick: (_) async {
          await _toggleWakelock();
        },
        checked: trayState.wakelockEnabled,
      );
      menuItems.add(wakelockMenuItem);
    }

    menuItems.add(MenuItem.separator());
    final exitMenuItem = MenuItem(
      label: appLocalizations.exit,
      onClick: (_) async {
        await globalState.appController.handleExit();
      },
    );
    menuItems.add(exitMenuItem);
    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
    if (Platform.isLinux) {
      await _updateSystemTray(
        brightness: trayState.brightness,
        isStart: trayState.isStart,
        force: focus,
      );
    }
    } finally {
      _isUpdating = false;

      if (_pendingState != null) {
        final pending = _pendingState;
        _pendingState = null;
        await _doUpdate(trayState: pending!, focus: false);
      }
    }
  }

  Future<void> _copyEnv(int port) async {
    final url = 'http://127.0.0.1:$port';

    final cmdline = system.isWindows
        ? 'set \$env:all_proxy=$url'
        : 'export all_proxy=$url';

    await Clipboard.setData(ClipboardData(text: cmdline));
  }

  Future<void> _toggleWakelock() async {
    try {
      final enabled = await WakelockPlus.enabled;
      if (enabled) {
        await WakelockPlus.disable();
        globalState.appController.stopWakelockAutoRecovery();
      } else {
        await WakelockPlus.enable();
        globalState.appController.startWakelockAutoRecovery();
      }
      globalState.updateWakelockState(!enabled);
      await globalState.appController.updateTray();
    } catch (e) {
      commonPrint.log('WakeLock toggle error: $e');
    }
  }
}

final tray = Tray();
