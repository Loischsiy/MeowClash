import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/plugins/app.dart';
import 'package:meowclash/plugins/tile.dart';
import 'package:meowclash/plugins/vpn.dart';
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
  globalState.isService = false;
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable Skia graphics for better performance on desktop
  if (Platform.isWindows || Platform.isLinux) {
    DartPluginRegistrant.ensureInitialized();
  }
  
  final version = await system.version;
  await clashCore.preload();
  await globalState.initApp(version);
  await android?.init();
  await window?.init(version);
  
  // Initialize VPN plugin on Android to handle method channel calls from VPN service
  if (Platform.isAndroid) {
    vpn; // Accessing the getter initializes the singleton
  }
  HttpOverrides.global = MeowClashHttpOverrides();
  runApp(const ProviderScope(
    child: Application(),
  ));
}

@pragma('vm:entry-point')
Future<void> _service(List<String> flags) async {
  commonPrint.log("=== [DART] _service entrypoint started, flags: $flags");
  
  globalState.isService = true;
  commonPrint.log("[DART] Setting isService = true");
  
  WidgetsFlutterBinding.ensureInitialized();
  // Flush any logs that were queued before bindings were initialized
  fileLogger.flushPendingLogs();
  commonPrint.log("[DART] WidgetsFlutterBinding initialized");
  
  final quickStart = flags.contains("quick");
  commonPrint.log("[DART] quickStart = $quickStart");
  
  final clashLibHandler = ClashLibHandler();
  commonPrint.log("[DART] ClashLibHandler created");
  
  commonPrint.log("[DART] BEFORE try-catch block");
  try {
    commonPrint.log("[DART] Calling globalState.init()...");
    await globalState.init();
    commonPrint.log("[DART] globalState.init() completed");
  } catch (e, stackTrace) {
    commonPrint.log("=== [DART] _service ERROR during globalState.init() ===");
    commonPrint.log("[DART] Error: $e");
    commonPrint.log("[DART] StackTrace: $stackTrace");
    commonPrint.log("[DART] Continuing execution anyway...");
    // Don't rethrow - continue to add listeners
  }
  commonPrint.log("[DART] AFTER try-catch block");

  commonPrint.log("[DART] Adding tile listener...");
  tile?.addListener(
    _TileListenerWithService(
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
              final profileConfig = await globalState.getProfileConfig(currentProfileId);
              final geodataMode = profileConfig["geodata-mode"];
              if (geodataMode == true) {
                commonPrint.log("TileService: Initializing GeoIP/GeoSite (geodata-mode=true)...");
                await ClashCore.initGeo();
                commonPrint.log("TileService: GeoIP/GeoSite initialized");
              } else {
                commonPrint.log("TileService: Skipping Geo init (geodata-mode != true)");
              }
            } else {
              commonPrint.log("TileService: Skipping Geo init (no current profile)");
            }
          } catch (e) {
            commonPrint.log("TileService: Skipping Geo init due to error: $e");
          }
          
          commonPrint.log("TileService: Getting paths...");
          final homeDirPath = await appPath.homeDirPath;
          final version = await system.version;
          commonPrint.log("TileService: homeDirPath=$homeDirPath, version=$version");
          
          commonPrint.log("TileService: Creating config...");
          final clashConfig = globalState.config.patchClashConfig.copyWith.tun(
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
          final params = await globalState.getSetupParams(
            pathConfig: clashConfig,
          );
          commonPrint.log("TileService: Setup params ready");
          
          commonPrint.log("TileService: Starting ClashCore with quickStart");
          final res = await clashLibHandler.quickStart(
            InitParams(
              homeDir: homeDirPath,
              version: version,
            ),
            params,
            globalState.getCoreState(),
          );
          commonPrint.log("TileService: quickStart result: $res");
          
          if (res.isNotEmpty) {
            commonPrint.log("TileService: Start failed with error: $res");
            unawaited(app?.tip("Start failed: $res"));
            try {
              await vpn?.stop();
            } catch (e) {
              debugPrint("Tile vpn.stop() error (ignored): $e");
            }
            exit(0);
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
            commonPrint.log("TileService: vpn.start() error (may be handled by native): $e");
          }
          
          commonPrint.log("TileService: Starting listener");
          clashLibHandler.startListener();
          commonPrint.log("=== TileService onStart completed successfully ===");
        } catch (e, stackTrace) {
          commonPrint.log("=== TileService onStart ERROR ===");
          commonPrint.log("Error: $e");
          commonPrint.log("StackTrace: $stackTrace");
          unawaited(app?.tip("Start error: $e"));
          try {
            await vpn?.stop();
          } catch (stopError) {
            debugPrint("Tile vpn.stop() error (ignored): $stopError");
          }
          exit(0);
        }
      },
      onStop: () async {
        try {
          unawaited(app?.tip(appLocalizations.stopVpn));
          clashLibHandler.stopListener();
        } catch (e) {
          debugPrint("Tile stop listener error: $e");
        }
        try {
          await vpn?.stop();
        } catch (e) {
          // MissingPluginException may occur if VpnPlugin not yet attached
          // VPN will be stopped by native side via VpnPlugin.handleStop()
          debugPrint("Tile vpn.stop() error (ignored): $e");
        }
        exit(0);
      },
    ),
  );

  // Provide foreground notification params using data from globalState.config
  // This runs in service isolate, so we read from the in-memory config (loaded at service start)
  vpn?.handleGetStartForegroundParams = () {
    try {
      final traffic = clashLibHandler.getTraffic();
      final profile = globalState.config.currentProfile;
      final profileName = profile?.label ?? profile?.id ?? "MeowClash";

      // Get server group name from header (may be base64-encoded)
      String? groupName = profile?.providerHeaders['meowclash-serverinfo'];
      if (groupName != null && groupName.isNotEmpty) {
        try {
          final normalized = base64.normalize(groupName);
          groupName = utf8.decode(base64.decode(normalized));
        } catch (_) {
          // not base64, keep as is
        }
        groupName = groupName?.trim();
      }

      // Get selected proxy name from selectedMap
      String serverName = "";
      if (groupName != null && groupName.isNotEmpty) {
        final selectedMap = profile?.selectedMap ?? const <String, String>{};
        serverName = selectedMap[groupName] ?? "";
      }

      // Build title using active server (keep flags/emojis)
      final serverDisplay = serverName.trim();
      final title = serverDisplay.isNotEmpty ? "$profileName / $serverDisplay" : profileName;

      // Service name (subtext) from header meowclash-servicename (constant per profile)
      String serviceName = "";
      try {
        String? svc = profile?.providerHeaders['meowclash-servicename'];
        if (svc != null && svc.isNotEmpty) {
          try {
            final normalized = base64.normalize(svc);
            svc = utf8.decode(base64.decode(normalized));
          } catch (_) {}
          serviceName = svc?.trim() ?? "";
        }
      } catch (_) {}

      return json.encode({
        "title": title,
        "server": serviceName,
        "content": "$traffic"
      });
    } catch (_) {
      // Fallback minimal
      return json.encode({
        "title": "MeowClash",
        "server": "",
        "content": ""
      });
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
    final globalHeader =
        globalState.config.currentProfile?.providerHeaders['meowclash-globalmode'];
    final globalEnabled = globalHeader?.toLowerCase() != 'false';
    unawaited(tile?.updateGlobalModeEnabled(globalEnabled));
  } catch (e) {
    debugPrint("Initial updateMode error (ignored): $e");
  }
  
  commonPrint.log("[DART] quickStart=$quickStart");
  if (!quickStart) {
    // App is in memory - set up IPC for communication with main isolate
    commonPrint.log("[DART] Not quickStart, calling _handleMainIpc");
    _handleMainIpc(clashLibHandler);
  } else {
    // App was not in memory - VPN will be started via pending action triggered by signalServiceReady()
    // The onStart callback in tile listener will handle the actual VPN startup
    commonPrint.log("[DART] QuickStart mode - VPN will be started via pending action from tile service");
  }
}

void _handleMainIpc(ClashLibHandler clashLibHandler) {
  final sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
  if (sendPort == null) {
    return;
  }
  final serviceReceiverPort = ReceivePort();
  serviceReceiverPort.listen((message) async {
    // Handle special IPC messages for foreground notification updates
    if (message is Map<String, dynamic>) {
      final action = message['action'];
      if (action == 'updateForegroundServer') {
        final serverName = message['serverName'] as String? ?? '';
        final groupName = message['groupName'] as String? ?? '';
        // Update selectedMap in globalState.config
        final profile = globalState.config.currentProfile;
        if (profile != null && groupName.isNotEmpty) {
          final newSelectedMap = Map<String, String>.from(profile.selectedMap);
          newSelectedMap[groupName] = serverName;
          final updatedProfile = profile.copyWith(selectedMap: newSelectedMap);
          globalState.config = globalState.config.copyWith(
            profiles: globalState.config.profiles.map((p) => 
              p.id == profile.id ? updatedProfile : p
            ).toList(),
          );
        }
        sendPort.send({'success': true});
        return;
      }
    }
    final res = await clashLibHandler.invokeAction(message);
    sendPort.send(res);
  });
  sendPort.send(serviceReceiverPort.sendPort);
  final messageReceiverPort = ReceivePort();
  clashLibHandler.attachMessagePort(
    messageReceiverPort.sendPort.nativePort,
  );
  messageReceiverPort.listen(sendPort.send);
}

@immutable
class _TileListenerWithService with TileListener {

  const _TileListenerWithService({
    required Function() onStart,
    required Function() onStop,
    required Function(String mode) onChangeMode,
  }) : _onStart = onStart,
       _onStop = onStop,
       _onChangeMode = onChangeMode;

  final Function() _onStart;
  final Function() _onStop;
  final Function(String mode) _onChangeMode;

  @override
  void onStart() {
    _onStart();
  }

  @override
  void onStop() {
    _onStop();
  }

  @override
  void onChangeMode(String mode) {
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
