import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:meow_clash/plugins/app.dart';
import 'package:meow_clash/plugins/tile.dart';
import 'package:meow_clash/plugins/vpn.dart';
import 'package:meow_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'models/models.dart';

ReceivePort? _serviceReceiverPort;
ReceivePort? _messageReceiverPort;

Future<void> main() async {
  globalState.isService = false;
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('=== MAIN START ===');
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  final version = await system.version;
  debugPrint('=== Version: $version ===');
  debugPrint('=== Calling preload... ===');
  await clashCore.preload();
  debugPrint('=== preload done ===');

  // Set defaults so _runApp doesn't crash on late fields
  globalState.config = Config(themeProps: defaultThemeProps);
  globalState.accentColor = const Color(defaultPrimaryColor);
  globalState.appState = AppState(
    brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
    version: version,
    viewSize: Size.zero,
    requests: FixedList(maxLength),
    logs: FixedList(maxLength),
    traffics: FixedList(30),
    totalTraffic: Traffic(),
    systemUiOverlayStyle: const SystemUiOverlayStyle(),
  );

  // Init in background, don't block UI
  unawaited(Future(() async {
    await globalState.initApp(version);
    unawaited(uiManager.initializeUI().catchError((e) => debugPrint('UI init error: $e')));
  }));

  await _runApp(version);
}

Future<void> _runApp(int version) async {
  debugPrint('=== _runApp: start ===');
  if (system.isAndroid && globalState.config.appSetting.enableHighRefreshRate) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      commonPrint.log('Failed to set high refresh rate: $e');
    }
  }
  debugPrint('=== _runApp: android?.init ===');
  await android?.init();
  debugPrint('=== _runApp: window?.init ===');
  await window?.init(version);
  debugPrint('=== _runApp: runApp ===');
  HttpOverrides.global = MeowClashHttpOverrides();
  runApp(ProviderScope(child: const Application()));
  debugPrint('=== _runApp: done ===');
}

@pragma('vm:entry-point')
Future<void> _service(List<String> flags) async {
  debugPrint('=== _service: start, flags=$flags ===');
  globalState.isService = true;
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('=== _service: calling globalState.init() ===');
  await globalState.init();
  debugPrint('=== _service: globalState.init() done ===');

  {
    final quickStart = flags.contains('quick');
    final bootStart = flags.contains('boot');
    final clashLibHandler = ClashLibHandler();

    tile?.addListener(
      _TileListenerWithService(
        onStart: () async {
          await app.tip(appLocalizations.startVpn);
          await globalState.handleStart();
        },
        onStop: () async {
          await app.tip(appLocalizations.stopVpn);
          clashLibHandler.stopListener();
          await vpn?.stop();
        },
        onReconnectIpc: () {
          commonPrint.log(
            'Service: reconnectIpc requested, re-establishing IPC',
          );
          _handleMainIpc(clashLibHandler);
        },
      ),
    );

    vpn?.addListener(
      _VpnListenerWithService(
        onDnsChanged: (String dns) {
          clashLibHandler.updateDns(dns);
        },
      ),
    );

    if (!quickStart && !bootStart) {
      _handleMainIpc(clashLibHandler);
      return;
    }

    _handleMainIpc(clashLibHandler);

    if (bootStart && !globalState.config.appSetting.autoRun) {
      commonPrint.log('Silent boot detected, but autoRun is disabled. Staying idle.');
      _handleMainIpc(clashLibHandler);
      return;
    }

    commonPrint.log('Executing ${bootStart ? "boot" : "quick"} start sequence');
    await ClashCore.initGeo();
    app.tip(appLocalizations.startVpn);
    final homeDirPath = await appPath.homeDirPath;
    final version = await system.version;
    final clashConfig = globalState.config.patchClashConfig.copyWith.tun(
      enable: false,
    );

    final params = await globalState.getSetupParams(pathConfig: clashConfig);
    Future(() async {
      try {
        final profileId = globalState.config.currentProfileId;
        if (profileId == null) {
          return;
        }
        final res = await clashLibHandler.quickStart(
          InitParams(homeDir: homeDirPath, version: version),
          params,
          globalState.getCoreState(),
        );
        debugPrint(res);
        if (res.isNotEmpty) {
          commonPrint.log('QuickStart failed with error: $res');
          await vpn?.stop();
          return;
        }
        await vpn?.start(clashLibHandler.getAndroidVpnOptions());

        if (globalState.config.appSetting.openLogs) {
          await clashLibHandler.invokeAction('{"id": "quickStartLog", "method": "startLog"}');
        } else {
          await clashLibHandler.invokeAction('{"id": "quickStopLog", "method": "stopLog"}');
        }

        clashLibHandler.startListener();
      } catch (e) {
        commonPrint.log('Fatal error during service background start: $e');
        await vpn?.stop();
      }
    });
  }
}

void _handleMainIpc(ClashLibHandler clashLibHandler) {
  debugPrint('=== _handleMainIpc: start ===');
  final sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
  debugPrint('=== _handleMainIpc: mainIsolate port = $sendPort ===');
  if (sendPort == null) {
    commonPrint.log('Service: mainIsolate sendPort not found, IPC unavailable');
    return;
  }

  _serviceReceiverPort?.close();
  _messageReceiverPort?.close();

  _serviceReceiverPort = ReceivePort();
  _serviceReceiverPort!.listen((message) async {
    final res = await clashLibHandler.invokeAction(message);
    _safeSend(sendPort, res);
  });
  _safeSend(sendPort, _serviceReceiverPort!.sendPort);

  _messageReceiverPort = ReceivePort();
  clashLibHandler.attachMessagePort(_messageReceiverPort!.sendPort.nativePort);
  _messageReceiverPort!.listen((message) {
    _safeSend(sendPort, message);
  });

  clashLibHandler.startListener();
}

void _safeSend(SendPort sendPort, dynamic message) {
  try {
    sendPort.send(message);
  } catch (e) {
    commonPrint.log('Service: IPC send failed: $e');
    final retryPort = IsolateNameServer.lookupPortByName(mainIsolate);
    if (retryPort != null) {
      try {
        retryPort.send(message);
      } catch (_) {}
    }
  }
}

@immutable
class _TileListenerWithService with TileListener {
  final Function() _onStart;
  final Function() _onStop;
  final Function() _onReconnectIpc;

  const _TileListenerWithService({
    required Function() onStart,
    required Function() onStop,
    required Function() onReconnectIpc,
  }) : _onStart = onStart,
       _onStop = onStop,
       _onReconnectIpc = onReconnectIpc;

  @override
  void onStart() => _onStart();

  @override
  void onStop() => _onStop();

  @override
  void onReconnectIpc() => _onReconnectIpc();
}

@immutable
class _VpnListenerWithService with VpnListener {
  final Function(String dns) _onDnsChanged;

  const _VpnListenerWithService({required Function(String dns) onDnsChanged})
    : _onDnsChanged = onDnsChanged;

  @override
  void onDnsChanged(String dns) {
    super.onDnsChanged(dns);
    _onDnsChanged(dns);
  }
}
