import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate' show Isolate, IsolateNameServer, ReceivePort, SendPort;
import 'dart:ui';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/plugins/app.dart';
import 'package:meowclash/plugins/tile.dart';
import 'package:meowclash/plugins/vpn.dart';
import 'package:meowclash/services/image_memory.dart';
import 'package:meowclash/services/provider_payload.dart';
import 'package:meowclash/services/provider_refresh_plan.dart';
import 'package:meowclash/services/provider_refresh_service.dart';
import 'package:meowclash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'models/core.dart' as core_models show Action;
import 'models/models.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    globalState.isService = false;
    WidgetsFlutterBinding.ensureInitialized();
    configureUiImageCache(PaintingBinding.instance.imageCache);
    commonPrint.log("=== [DART] main entrypoint started ===");

    // Enable Skia graphics for better performance on desktop
    if (Platform.isWindows || Platform.isLinux) {
      DartPluginRegistrant.ensureInitialized();
    }

    final version = await system.version;
    await globalState.initApp(version);
    commonPrint.log("[DART] globalState.initApp() completed");

    if (system.isDesktop) {
      await proxy?.stopProxy();
    }
    globalState.startupTunRecovery = await request.recoverTunAtStartup();
    globalState.tunRecoveryBlocked =
        globalState.startupTunRecovery?['status'] != null &&
            globalState.startupTunRecovery?['status'] != 'restored';

    commonPrint.log("[DART] Calling clashCore.preload()...");
    await clashCore.preload();
    commonPrint.log("[DART] clashCore.preload() completed");

    await android?.init();
    await window?.init(version);

    // Initialize VPN plugin on Android to handle method channel calls from VPN service
    if (Platform.isAndroid) {
      vpn; // Accessing the getter initializes the singleton
    }
    await initWindowsTrustedRoots();
    HttpOverrides.global = MeowClashHttpOverrides();
    commonPrint.log("[DART] Running application...");
    runApp(const ProviderScope(
      child: Application(),
    ));
  }, (error, stack) {
    commonPrint.log("=== [DART] main UNHANDLED ERROR ===");
    commonPrint.log("Error: $error");
    commonPrint.log("StackTrace: $stack");
  });
}

@pragma('vm:entry-point')
Future<void> _service(List<String> flags) async {
  runZonedGuarded(() async {
    commonPrint.log("=== [DART] _service entrypoint started, flags: $flags");

    globalState.isService = true;
    commonPrint.log("[DART] Setting isService = true");

    WidgetsFlutterBinding.ensureInitialized();
    // Flush any logs that were queued before bindings were initialized
    fileLogger.flushPendingLogs();
    commonPrint.log("[DART] WidgetsFlutterBinding initialized");

    final quickStart = flags.contains("quick");
    commonPrint.log("[DART] quickStart = $quickStart");

    commonPrint.log("[DART] Creating ClashLibHandler...");
    final clashLibHandler = ClashLibHandler();
    commonPrint.log("[DART] ClashLibHandler created");

    bool initSuccess = false;
    commonPrint.log("[DART] BEFORE try-catch block");
    try {
      commonPrint.log("[DART] Calling globalState.init()...");
      await globalState.init();
      initSuccess = true;
      commonPrint.log("[DART] globalState.init() completed");
    } catch (e, stackTrace) {
      commonPrint
          .log("=== [DART] _service ERROR during globalState.init() ===");
      commonPrint.log("[DART] Error: $e");
      commonPrint.log("[DART] StackTrace: $stackTrace");
      commonPrint.log("[DART] Continuing execution anyway...");
    }
    commonPrint.log("[DART] AFTER try-catch block (initSuccess=$initSuccess)");

    if (!initSuccess) {
      commonPrint.log(
          "[DART] init failed, signaling service ready but skipping listeners");
      try {
        await tile?.signalServiceReady();
      } catch (_) {}
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }

    // This owner survives Activity/UI disposal. It does not read UI state or
    // stale SharedPreferences caches; setup IPC supplies the applied snapshot.
    final providerDownloader = ProviderPayloadDownloader();
    final providerUpdates = ProviderRefreshService(
      invokeCore: clashLibHandler.invokeAction,
      isRunning: () => clashLibHandler.getRunTime() != null,
      fetch: providerDownloader.fetch,
      modifiedAt: providerCacheModifiedAt,
      persist: writeProviderCache,
      log: commonPrint.log,
    );
    final mainIpc = _MainIpc(clashLibHandler, providerUpdates);

    commonPrint.log("[DART] Adding tile listener...");
    tile?.addListener(
      _TileListenerWithService(
        onUiDetached: mainIpc.detach,
        onChangeMode: (mode) async {
          commonPrint.log("[DART] TileService onChangeMode: $mode");
          try {
            final modeEnum = Mode.values.byName(mode);
            final patched = globalState.config.patchClashConfig.copyWith(
              mode: modeEnum,
            );
            globalState.config = globalState.config.copyWith(
              patchClashConfig: patched,
            );
            await preferences.saveConfig(globalState.config);

            // Try to apply to running core so the switch is immediate.
            try {
              final updateParams = UpdateParams(
                tun: patched.tun
                    .getRealTun(globalState.config.networkProps.routeMode),
                allowLan: patched.allowLan,
                findProcessMode: patched.findProcessMode,
                mode: modeEnum,
                logLevel: patched.logLevel,
                ipv6: patched.ipv6,
                tcpConcurrent: patched.tcpConcurrent,
                externalController: patched.externalController,
                unifiedDelay: patched.unifiedDelay,
                mixedPort: patched.mixedPort,
              );
              final actionJson = json.encode(
                core_models.Action(
                  id: "${ActionMethod.updateConfig.name}#${utils.id}",
                  method: ActionMethod.updateConfig,
                  data: json.encode(updateParams),
                ),
              );
              final handler = clashLibHandler;
              if (handler != null) {
                unawaited(handler.invokeAction(actionJson));
              }
            } catch (e) {
              debugPrint("onChangeMode: live updateConfig error: $e");
            }

            unawaited(tile?.updateMode(mode));
          } catch (e) {
            debugPrint("onChangeMode error: $e");
          }
        },
        onStart: () async {
          commonPrint.log("=== [DART] TileService onStart called ===");
          debugPrint("=== TileService onStart called ===");
          try {
            commonPrint.log("TileService: Showing start notification");
            unawaited(app?.tip(appLocalizations.startVpn));

            // Initialize GeoIP/GeoSite only if profile enables it (geodata-mode == true)
            try {
              final currentProfileId = globalState.config.currentProfileId;
              if (currentProfileId != null) {
                final profileConfig =
                    await globalState.getProfileConfig(currentProfileId);
                final geodataMode = profileConfig["geodata-mode"];
                if (geodataMode == true) {
                  commonPrint.log(
                      "TileService: Initializing GeoIP/GeoSite (geodata-mode=true)...");
                  await ClashCore.initGeo();
                  commonPrint.log("TileService: GeoIP/GeoSite initialized");
                } else {
                  commonPrint.log(
                      "TileService: Skipping Geo init (geodata-mode != true)");
                }
              } else {
                commonPrint
                    .log("TileService: Skipping Geo init (no current profile)");
              }
            } catch (e) {
              commonPrint
                  .log("TileService: Skipping Geo init due to error: $e");
            }

            commonPrint.log("TileService: Getting paths...");
            final homeDirPath = await appPath.homeDirPath;
            final version = await system.version;
            commonPrint
                .log("TileService: homeDirPath=$homeDirPath, version=$version");

            commonPrint.log("TileService: Creating config...");
            final clashConfig =
                globalState.config.patchClashConfig.copyWith.tun(
              enable: false,
            );

            final profileId = globalState.config.currentProfileId;
            commonPrint.log("TileService: currentProfileId=$profileId");
            if (profileId == null) {
              commonPrint.log("TileService: No profile selected, aborting");
              unawaited(app?.tip("No profile selected"));
              return;
            }
            commonPrint.log("TileService: Getting setup params");
            final initParams = InitParams(homeDir: homeDirPath, version: version);
            // The service isolate has no ClashCore. The core needs its home
            // directory before it can name provider cache files, so initialise
            // it first (idempotent; quickStart repeats it) and ask it directly.
            Future<Map> invokeCore(ActionMethod method, Object data) async =>
                json.decode(await clashLibHandler.invokeAction(json.encode(
                  core_models.Action(
                    id: "${method.name}#${utils.id}",
                    method: method,
                    data: data,
                  ),
                ))) as Map;
            await invokeCore(ActionMethod.initClash, json.encode(initParams));
            Future<String> resolveProviderPath(String kind, String url) async {
              final result = await invokeCore(
                ActionMethod.getProviderCachePath,
                json.encode({'kind': kind, 'url': url}),
              );
              final path = result['data'];
              return path is String ? path : '';
            }

            final params = await globalState.getSetupParams(
              pathConfig: clashConfig,
              resolveProviderPath: resolveProviderPath,
            );
            commonPrint.log("TileService: Setup params ready");

            commonPrint.log("TileService: Starting ClashCore with quickStart");
            final refreshPlan = ProviderRefreshPlan.forProfile(
              profileId: profileId,
              userAgent: globalState.ua,
              config: params.config,
              credentials: globalState.config.currentProfile?.providerHeaders ??
                  const {},
              cachePaths: await ProviderRefreshPlan.resolveCachePaths(
                params.config,
                resolveProviderPath,
              ),
            );
            final res = await providerUpdates.configure(
              refreshPlan,
              () => clashLibHandler.quickStart(
                initParams,
                params,
                globalState.getCoreState(),
              ),
              succeeded: (result) => result.isEmpty,
            );
            commonPrint.log("TileService: quickStart result: $res");

            if (res.isNotEmpty) {
              providerUpdates.dispose();
              providerDownloader.close();
              commonPrint.log("TileService: Start failed with error: $res");
              unawaited(app?.tip("Start failed: $res"));
              try {
                await vpn?.stop();
              } catch (e) {
                debugPrint("Tile vpn.stop() error (ignored): $e");
              }
              _exitServiceIsolate();
              return;
            }

            commonPrint.log("TileService: Starting VPN service");
            try {
              await vpn?.start(
                clashLibHandler.getAndroidVpnOptions(),
              );
              commonPrint.log("TileService: VPN service started");
            } catch (e) {
              // MissingPluginException may occur if VpnPlugin not yet attached
              // VPN is started by native side via VpnPlugin.handleStart()
              commonPrint.log(
                  "TileService: vpn.start() error (may be handled by native): $e");
            }

            commonPrint.log("TileService: Starting listener");
            clashLibHandler.startListener();
            providerUpdates.resume();
            commonPrint
                .log("=== TileService onStart completed successfully ===");
          } catch (e, stackTrace) {
            providerUpdates.dispose();
            providerDownloader.close();
            commonPrint.log("=== TileService onStart ERROR ===");
            commonPrint.log("Error: $e");
            commonPrint.log("StackTrace: $stackTrace");
            unawaited(app?.tip("Start error: $e"));
            try {
              await vpn?.stop();
            } catch (stopError) {
              debugPrint("Tile vpn.stop() error (ignored): $stopError");
            }
            _exitServiceIsolate();
            return;
          }
        },
        onStop: () async {
          providerUpdates.dispose();
          providerDownloader.close();
          try {
            unawaited(app?.tip(appLocalizations.stopVpn));
            clashLibHandler.stopListener();
          } catch (e) {
            debugPrint("Tile stop listener error: $e");
          }
          try {
            await vpn?.stop();
          } catch (e) {
            debugPrint("Tile vpn.stop() error (ignored): $e");
          }
          _exitServiceIsolate();
        },
      ),
    );

    // This runs in the service isolate, where only the profile label and traffic
    // are needed for the foreground notification.
    vpn?.handleGetStartForegroundParams = () {
      try {
        final traffic = clashLibHandler.getTraffic();
        final profile = globalState.config.currentProfile;
        final profileName = profile?.label ?? profile?.id ?? "MeowClash";

        return json.encode(
            {"title": profileName, "server": "", "content": "$traffic"});
      } catch (_) {
        // Fallback minimal
        return json.encode({"title": "MeowClash", "server": "", "content": ""});
      }
    };

    commonPrint.log("[DART] Adding VPN listener");
    vpn?.addListener(
      _VpnListenerWithService(
        onDnsChanged: (dns) {
          commonPrint.log("handle dns $dns");
          clashLibHandler.updateDns(dns);
        },
      ),
    );

    // Signal to native side that Dart service is ready to receive commands
    // This must be called AFTER adding tile listener so pending actions can be handled
    commonPrint.log("[DART] Signaling service ready to native side");
    await tile?.signalServiceReady();
    commonPrint.log("[DART] Service ready signal sent");

    // Push initial mode to widget so the active button is highlighted correctly.
    try {
      final currentMode = globalState.config.patchClashConfig.mode.name;
      unawaited(tile?.updateMode(currentMode));
      unawaited(tile?.updateGlobalModeEnabled(true));
    } catch (e) {
      debugPrint("Initial updateMode error (ignored): $e");
    }

    commonPrint.log("[DART] quickStart=$quickStart");
    // The service engine outlives the Activity. A reopened UI attaches through
    // this port instead of recreating the engine and the core configuration.
    final attachPort = ReceivePort();
    IsolateNameServer.removePortNameMapping(serviceIsolate);
    IsolateNameServer.registerPortWithName(attachPort.sendPort, serviceIsolate);
    attachPort.listen((message) {
      if (message == serviceAttachRequest) {
        unawaited(mainIpc.attach(waitForMain: false));
      }
    });
    if (!quickStart) {
      // App is in memory - set up IPC for communication with main isolate
      commonPrint.log("[DART] Not quickStart, attaching to the main isolate");
      unawaited(mainIpc.attach(waitForMain: true));
    } else {
      // App was not in memory - VPN will be started via pending action triggered by signalServiceReady()
      // The onStart callback in tile listener will handle the actual VPN startup
      commonPrint.log(
          "[DART] QuickStart mode - VPN will be started via pending action from tile service");
    }
  }, (error, stack) {
    commonPrint.log("=== [DART] _service UNHANDLED ERROR ===");
    commonPrint.log("Error: $error");
    commonPrint.log("StackTrace: $stack");
  });
}

/// Removes the attach mapping before the service isolate exits, so a reopened
/// UI does not wait for a port that nobody listens to.
void _exitServiceIsolate() {
  IsolateNameServer.removePortNameMapping(serviceIsolate);
  Isolate.current.kill(priority: Isolate.immediate);
}

/// IPC between the service isolate and the current UI isolate. The UI can be
/// destroyed and recreated many times while the service keeps the core.
class _MainIpc {
  _MainIpc(this.clashLibHandler, this.providerUpdates);

  final ClashLibHandler clashLibHandler;
  final ProviderRefreshService providerUpdates;
  ReceivePort? _requests;
  ReceivePort? _messages;
  int _generation = 0;

  Future<void> attach({required bool waitForMain}) async {
    final generation = ++_generation;
    commonPrint.log("[DART] _MainIpc: Looking up mainIsolate port...");
    SendPort? sendPort;
    final attempts = waitForMain ? 10 : 1;
    for (int i = 0; i < attempts; i++) {
      sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
      if (sendPort != null || i == attempts - 1) break;
      commonPrint.log("[DART] _MainIpc: mainIsolate port not found, retry $i...");
      await Future.delayed(Duration(milliseconds: 200 * (i + 1)));
    }
    if (generation != _generation) return;
    if (sendPort == null) {
      commonPrint.log(
          "[DART] _MainIpc: mainIsolate port NOT FOUND, aborting IPC setup");
      return;
    }
    _close();
    final target = sendPort;

    void safeSend(dynamic message) {
      try {
        target.send(message);
      } catch (_) {}
    }

    final requests = ReceivePort()
      ..listen((message) async {
        final res = await providerUpdates.handleAction(message as String);
        safeSend(res);
      });
    final messages = ReceivePort()..listen(safeSend);
    _requests = requests;
    _messages = messages;
    clashLibHandler.attachMessagePort(messages.sendPort.nativePort);
    commonPrint.log("[DART] _MainIpc: Sending service port to mainIsolate");
    safeSend(requests.sendPort);
    commonPrint.log("[DART] _MainIpc: IPC setup completed");
  }

  /// The UI engine is gone: stop the core from serializing logs, requests and
  /// delays for a port that nobody reads.
  void detach() {
    _generation++;
    _close();
    commonPrint.log("[DART] _MainIpc: UI detached");
  }

  void _close() {
    if (_messages != null) clashLibHandler.attachMessagePort(-1);
    _requests?.close();
    _messages?.close();
    _requests = null;
    _messages = null;
  }
}

@immutable
class _TileListenerWithService with TileListener {
  const _TileListenerWithService({
    required Function() onStart,
    required Function() onStop,
    required Function(String mode) onChangeMode,
    required Function() onUiDetached,
  })  : _onStart = onStart,
        _onStop = onStop,
        _onChangeMode = onChangeMode,
        _onUiDetached = onUiDetached;

  final Function() _onStart;
  final Function() _onStop;
  final Function(String mode) _onChangeMode;
  final Function() _onUiDetached;

  @override
  void onUiDetached() => _onUiDetached();

  @override
  void onStart() {
    if (globalState.isAppControllerReady) return;
    _onStart();
  }

  @override
  void onStop() {
    if (globalState.isAppControllerReady) return;
    _onStop();
  }

  @override
  void onChangeMode(String mode) {
    if (globalState.isAppControllerReady) return;
    _onChangeMode(mode);
  }
}

@immutable
class _VpnListenerWithService with VpnListener {
  const _VpnListenerWithService({
    required Function(String dns) onDnsChanged,
  }) : _onDnsChanged = onDnsChanged;
  final Function(String dns) _onDnsChanged;

  @override
  void onDnsChanged(String dns) {
    super.onDnsChanged(dns);
    _onDnsChanged(dns);
  }
}
