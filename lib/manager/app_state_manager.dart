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
import 'package:meowclash/state.dart';

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
    globalState.stopUpdateTasks();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final generation = ++_lifecycleGeneration;
    commonPrint.log("$state");
    if (Platform.isAndroid && state != AppLifecycleState.resumed) {
      globalState.stopUpdateTasks();
    }
    switch (state) {
      case AppLifecycleState.inactive:
        unawaited(globalState.appController.savePreferences());
      case AppLifecycleState.paused:
        releaseUnusedUiImages(PaintingBinding.instance.imageCache);
        unawaited(globalState.appController.savePreferences());
        if (Platform.isAndroid) {
          // The VPN foreground service keeps this process alive (and unfrozen)
          // while backgrounded, so the 1-second UI polling loop (traffic +
          // runtime via FFI into the core) would otherwise run forever for a
          // UI nobody is looking at — a straight battery drain. The service
          // engine keeps its own notification updates; this only pauses the
          // in-app dashboard polling.
          globalState.stopUpdateTasks();
        }
      case AppLifecycleState.hidden:
        releaseUnusedUiImages(PaintingBinding.instance.imageCache);
        // Desktop window hidden (tray/minimize). Falling through to the
        // generic resume branch cancelled the render pause armed by
        // window.hide(), so the engine kept rasterizing dashboard animations
        // in an invisible window.
        render?.pause();
      case AppLifecycleState.resumed:
        render?.resume();
        if (Platform.isAndroid) {
          // The proxy may have been started/stopped from the tile or the
          // persistent notification while the UI was backgrounded — re-read
          // the native truth before deciding whether to restart the polling
          // loop paused above.
          await globalState.updateStartTime();
          if (!mounted ||
              generation != _lifecycleGeneration ||
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed) {
            return;
          }
          if (globalState.isStart) {
            unawaited(globalState.startUpdateTasks());
          } else {
            // Stopped while backgrounded — reflect it instead of leaving the
            // last polled runtime on screen.
            globalState.appController.updateRunTime();
          }
        }
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
          render?.resume();
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
