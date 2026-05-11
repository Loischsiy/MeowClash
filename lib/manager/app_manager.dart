import 'dart:async';

import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/manager/window_manager.dart';
import 'package:meow_clash/plugins/app.dart';
import 'package:meow_clash/providers/providers.dart';
import 'package:meow_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/widgets/transparent_macos_sidebar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  bool _isRefreshActive = false;
  Timer? _dashboardRefreshDebounceTimer;
  Timer? _missedUpdateCheckTimer;
  DateTime? _lastMissedUpdateCheck;
  late final VoidCallback _dashboardTickListener;

  static const _missedUpdateCheckDelay = Duration(seconds: 5);
  static const _missedUpdateCheckThrottle = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardTickListener = () {
      if (!globalState.isStart) {
        return;
      }
      unawaited(globalState.appController.updateRunTime());
    };
    dashboardRefreshManager.tick1s.addListener(_dashboardTickListener);
    ref.listenManual(layoutChangeProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev != next) {
          globalState.computeHeightMapCache = {};
        }
      });
    });
    ref.listenManual(checkIpProvider, (prev, next) {
      if (next.b && (prev?.a != next.a)) {
        detectionState.startCheck();
      }
    });
    ref.listenManual(configStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.savePreferencesDebounce();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDashboardRefreshState();
      detectionState.tryStartCheck();
    });
    if (window == null) {
      return;
    }
    ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
      if (prev == next) {
        return;
      }
      if (next.a == true && next.b == true) {
        macOS?.updateDns(false);
      } else {
        macOS?.updateDns(true);
      }
    });
    ref.listenManual(currentBrightnessProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      window?.updateMacOSBrightness(next);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _dashboardRefreshDebounceTimer?.cancel();
    _missedUpdateCheckTimer?.cancel();
    dashboardRefreshManager.tick1s.removeListener(_dashboardTickListener);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _updateDashboardRefreshState() async {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    var isVisible = true;
    var isMinimized = false;
    if (system.isDesktop) {
      final visible = await window?.isVisible;
      if (visible == false) {
        isVisible = false;
      }
      isMinimized = await window?.isMinimized ?? false;
    }
    final shouldRun = isForeground && isVisible && !isMinimized;

    if (!shouldRun) {
      _dashboardRefreshDebounceTimer?.cancel();
      _dashboardRefreshDebounceTimer = null;
      if (_isRefreshActive) {
        dashboardRefreshManager.stop();
        _isRefreshActive = false;
      }
      return;
    }

    if (_isRefreshActive) {
      return;
    }

    _dashboardRefreshDebounceTimer?.cancel();
    _dashboardRefreshDebounceTimer = Timer(
      const Duration(milliseconds: 1000),
      () {
        if (!mounted) return;
        if (_isRefreshActive) return;
        dashboardRefreshManager.start();
        _isRefreshActive = true;
      },
    );
  }

  bool get _shouldCheckMissedUpdates {
    if (_lastMissedUpdateCheck == null) return true;
    return DateTime.now().difference(_lastMissedUpdateCheck!) > _missedUpdateCheckThrottle;
  }

  void _scheduleMissedUpdateCheck() {
    if (!_shouldCheckMissedUpdates) return;
    _missedUpdateCheckTimer?.cancel();
    _missedUpdateCheckTimer = Timer(_missedUpdateCheckDelay, () {
      _lastMissedUpdateCheck = DateTime.now();
      globalState.appController.checkAndUpdateMissedProfiles();
    });
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final isBackgroundState = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive && !system.isDesktop);

    if (isBackgroundState) {
      _missedUpdateCheckTimer?.cancel();
      globalState.appController.savePreferences();
      await globalState.handleBackground();
    } else if (state == AppLifecycleState.resumed) {
      globalState.handleForeground();
      render?.resume();
      await globalState.resumeForegroundUpdates();
      await globalState.appController.syncWakelockIfNeeded();
      _scheduleMissedUpdateCheck();

      final hasDetection = ref
          .read(dashboardStateProvider)
          .dashboardWidgets
          .contains(DashboardWidget.networkDetection);
      if (hasDetection) {
        detectionState.startCheck(immediate: true);
      }
    }
    if (state == AppLifecycleState.resumed && system.isAndroid) {
      final hidden = ref.read(appSettingProvider.select((s) => s.hidden));
      app.updateExcludeFromRecents(hidden);
      SystemChrome.setSystemUIOverlayStyle(globalState.appState.systemUiOverlayStyle);
    }
    if (state == AppLifecycleState.inactive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        detectionState.tryStartCheck();
      });
    }
    _updateDashboardRefreshState();
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateBrightness();
    globalState.appController.updateTray();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

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

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  Widget _buildLoading() {
    return Consumer(
      builder: (_, ref, _) {
        final loading = ref.watch(loadingProvider);
        final isMobileView = ref.watch(isMobileViewProvider);
        return loading && !isMobileView
            ? RotatedBox(
                quarterTurns: 1,
                child: const LinearProgressIndicator(),
              )
            : Container();
      },
    );
  }

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    if (!system.isMacOS) {
      return Material(
        color: context.colorScheme.surfaceContainer,
        child: child,
      );
    }
    return TransparentMacOSSidebar(
      child: Material(color: Colors.transparent, child: child),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(appSettingProvider).showLabel;
    return Row(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            _buildBackground(
              context: context,
              child: SafeArea(
                left: !system.isAndroid,
                top: true,
                right: false,
                bottom: false,
                child: Column(
                  children: [
                    if (system.isMacOS) const SizedBox(height: 22),
                    const SizedBox(height: 16),
                    if (!system.isMacOS) ...[const AppIcon(), const SizedBox(height: 12)],
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: HiddenBarScrollBehavior(),
                        child: CallbackShortcuts(
                          bindings: <ShortcutActivator, VoidCallback>{
                            const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                              if (currentIndex > 0) {
                                globalState.appController.toPage(
                                  navigationItems[currentIndex - 1].label,
                                );
                              }
                            },
                            const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                              if (currentIndex < navigationItems.length - 1) {
                                globalState.appController.toPage(
                                  navigationItems[currentIndex + 1].label,
                                );
                              }
                            },
                            const SingleActivator(LogicalKeyboardKey.select): () {},
                            const SingleActivator(LogicalKeyboardKey.enter): () {},
                          },
                          child: Focus(
                            autofocus: true,
                            child: NavigationRail(
                              backgroundColor: Colors.transparent,
                              selectedLabelTextStyle: context
                                  .textTheme
                                  .labelLarge!
                                  .copyWith(
                                    color: context.colorScheme.onSurface,
                                  ),
                              unselectedLabelTextStyle: context
                                  .textTheme
                                  .labelLarge!
                                  .copyWith(
                                    color: context.colorScheme.onSurface,
                                  ),
                              destinations: navigationItems
                                  .map(
                                    (e) => NavigationRailDestination(
                                      icon: e.icon,
                                      label: Text(Intl.message(e.label.name)),
                                    ),
                                  )
                                  .toList(),
                              onDestinationSelected: (index) {
                                globalState.appController.toPage(
                                  navigationItems[index].label,
                                );
                              },
                              extended: showLabel,
                              selectedIndex: currentIndex,
                              labelType: showLabel
                                  ? NavigationRailLabelType.none
                                  : NavigationRailLabelType.all,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (window != null) const WindowLockButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildLoading(),
          ],
        ),
        Expanded(flex: 1, child: ClipRect(child: child)),
      ],
    );
  }
}

class WindowLockButton extends ConsumerWidget {
  const WindowLockButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(
      windowSettingProvider.select((state) => state.isLocked),
    );

    return IconButton(
      onPressed: () async {
        try {
          final currentLocked = ref.read(
            windowSettingProvider.select((state) => state.isLocked),
          );
          final newLocked = !currentLocked;

          await windowManager.setResizable(!newLocked);

          ref
              .read(windowSettingProvider.notifier)
              .updateState((state) => state.copyWith(isLocked: newLocked));
        } catch (e) {
          commonPrint.log('Window Lock Failed: $e');
        }
      },
      icon: Icon(
        isLocked ? Icons.lock : Icons.lock_open,
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}