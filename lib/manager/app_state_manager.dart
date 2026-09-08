import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/plugins/tile.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/services/image_memory.dart';
import 'package:meowclash/services/ui_lifecycle.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/visibility_polling.dart';

class AppStateManager extends ConsumerStatefulWidget {
  const AppStateManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  Future<void> _dnsOp = Future.value();
  int _lifecycleGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    uiLifecycle
      ..updateLifecycle(WidgetsBinding.instance.lifecycleState)
      ..addListener(_syncUiActivity);
    _syncUiActivity();
    ref.listenManual(layoutChangeProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev != next) {
          globalState.cacheHeightMap = {};
        }
      });
    });
    ref.listenManual(
      checkIpProvider,
      (prev, next) {
        if (prev != next && next.b) {
          detectionState.startCheck();
        }
      },
      fireImmediately: true,
    );
    ref.listenManual(configStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.savePreferencesDebounce();
      }
    });
    ref.listenManual(
      autoSetSystemDnsStateProvider,
      (prev, next) {
        if (prev == next) {
          return;
        }
        final restore = !(next.a == true && next.b == true);
        _dnsOp =
            _dnsOp.then((_) => system.setMacOSDns(restore)).catchError((_) {});
      },
    );
    ref.listenManual(
      patchClashConfigProvider.select((state) => state.mode),
      (prev, next) {
        if (prev != next) {
          tile?.updateMode(next.name);
        }
      },
      fireImmediately: true,
    );
    ref.listenManual(
      globalModeEnabledProvider,
      (prev, next) {
        if (prev != next) {
          tile?.updateGlobalModeEnabled(next);
        }
      },
      fireImmediately: true,
    );
    ref.listenManual(
      globalModeEnabledProvider,
      (prev, next) {
        if (next) {
          return;
        }
        final currentMode = ref.read(
          patchClashConfigProvider.select((state) => state.mode),
        );
        if (currentMode != Mode.global) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          globalState.appController.changeMode(Mode.rule);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void reassemble() {
    super.reassemble();
  }

  @override
  void dispose() {
    _lifecycleGeneration++;
    uiLifecycle.removeListener(_syncUiActivity);
    globalState.stopUpdateTasks();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncUiActivity() {
    if (uiLifecycle.isVisible) {
      render?.resume();
    } else {
      render?.pause();
      releaseUnusedUiImages(PaintingBinding.instance.imageCache);
    }
    if (!uiLifecycle.isForeground) {
      globalState.stopUpdateTasks();
      debouncer.cancel(FunctionTag.updateGroups);
      return;
    }
    // Desktop run status is owned here; Android must first synchronize with
    // its independent VPN service in the guarded resume branch below.
    if (!Platform.isAndroid && globalState.isStart) {
      unawaited(globalState.startUpdateTasks());
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final generation = ++_lifecycleGeneration;
    uiLifecycle.updateLifecycle(state);
    commonPrint.log("$state");
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(globalState.appController.savePreferences());
      case AppLifecycleState.resumed:
        if (Platform.isAndroid) {
          // Tile/notification actions may have changed the VPN while the UI
          // was unloaded. Never let a stale resume callback restart polling.
          await globalState.updateStartTime();
          if (!mounted ||
              generation != _lifecycleGeneration ||
              !isUiForeground) {
            return;
          }
          globalState.appController.updateRunTime();
          if (globalState.isStart) {
            unawaited(globalState.startUpdateTasks());
          }
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerHover: (_) {
          if (uiLifecycle.isVisible) render?.resume();
        },
        child: widget.child,
      );
}

class AppEnvManager extends StatelessWidget {
  const AppEnvManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: 'PRE',
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}
