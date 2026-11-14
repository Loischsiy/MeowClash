import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/plugins/service.dart';
import 'package:meowclash/services/provider_refresh_plan.dart';
import 'package:meowclash/state.dart';

import 'generated/clash_ffi.dart';
import 'interface.dart';
import 'native_config.dart';

class ClashLib extends ClashHandlerInterface with AndroidClashInterface {

  factory ClashLib() {
    _instance ??= ClashLib._internal();
    return _instance!;
  }

  ClashLib._internal() {
    receiverPort.listen(_handleServiceMessage);
    unawaited(_initService(reuseRunningService: true));
  }
  static ClashLib? _instance;
  Completer<bool> _canSendCompleter = Completer();
  SendPort? sendPort;
  final receiverPort = ReceivePort();

  @override
  Future<bool> preload() => _canSendCompleter.future;

  @override
  Future<String> setupConfig(SetupParams setupParams) async {
    final profile = globalState.config.currentProfile;
    // The service isolate cannot compute provider cache paths; the core does.
    final cachePaths = await ProviderRefreshPlan.resolveCachePaths(
      setupParams.config,
      (kind, url) => getProviderCachePath(kind: kind, url: url),
    );
    final plan = ProviderRefreshPlan.forProfile(
      profileId: profile?.id ?? '',
      userAgent: globalState.ua,
      config: setupParams.config,
      credentials: profile?.providerHeaders ?? const {},
      cachePaths: cachePaths,
    );
    return invoke<String>(
      method: ActionMethod.setupConfig,
      data: json.encode({
        ...setupParams.toJson(),
        providerRefreshMetadataKey: plan.toJson(),
      }),
      timeout: const Duration(minutes: 2),
    );
  }

  /// True when this UI isolate attached to a service engine that was already
  /// running (the UI was reopened after being swiped from recents) instead of
  /// starting a new one.
  bool attachedToRunningService = false;

  void _handleServiceMessage(dynamic message) {
    if (message is SendPort) {
      commonPrint.log("[DART] ClashLib: Received service SendPort");
      if (_canSendCompleter.isCompleted) {
        commonPrint.log("[DART] ClashLib: _canSendCompleter already completed, resetting");
        sendPort = null;
        _canSendCompleter = Completer();
      }
      sendPort = message;
      _canSendCompleter.complete(true);
      commonPrint.log("[DART] ClashLib: _canSendCompleter COMPLETED");
    } else if (message is Map) {
      // Ignore IPC responses (Map type) - they don't need processing
      return;
    } else {
      handleResult(
        ActionResult.fromJson(json.decode(
          message,
        )),
      );
    }
  }

  Future<void> _initService({required bool reuseRunningService}) async {
    commonPrint.log("[DART] ClashLib._initService: Starting service initialization...");
    _registerMainPort(receiverPort.sendPort);
    if (reuseRunningService && await _attachToRunningService()) {
      attachedToRunningService = true;
      commonPrint.log("[DART] ClashLib: attached to the running service engine");
      return;
    }
    // Destroying the service engine drops its provider scheduler, and the core
    // configuration then has to be pushed again; only do it when there is no
    // live service to attach to, or for an explicit core restart.
    await service?.destroy();
    commonPrint.log("[DART] ClashLib: Calling service.init()...");
    await service?.init();
    commonPrint.log("[DART] ClashLib: service.init() returned");
  }

  /// The service engine outlives the Activity while the VPN runs. Ask it to
  /// connect to this UI isolate instead of recreating it, which would also
  /// reapply the profile and reset every URL-test group in the core.
  Future<bool> _attachToRunningService() async {
    try {
      if (await service?.isAlive() != true) return false;
      final servicePort = IsolateNameServer.lookupPortByName(serviceIsolate);
      if (servicePort == null) return false;
      servicePort.send(serviceAttachRequest);
      await _canSendCompleter.future.timeout(const Duration(seconds: 2));
      return true;
    } catch (error) {
      commonPrint.log("[DART] ClashLib: service attach failed: $error");
      return false;
    }
  }

  void _registerMainPort(SendPort sendPort) {
    commonPrint.log("[DART] ClashLib: Registering mainIsolate port '$mainIsolate'");
    IsolateNameServer.removePortNameMapping(mainIsolate);
    final success = IsolateNameServer.registerPortWithName(sendPort, mainIsolate);
    commonPrint.log("[DART] ClashLib: Port registration success = $success");
  }

  @override
  Future<bool> destroy() async {
    await service?.destroy();
    return true;
  }

  @override
  void reStart() {
    unawaited(_initService(reuseRunningService: false));
  }

  @override
  Future<bool> shutdown() async {
    await super.shutdown();
    destroy();
    return true;
  }

  @override
  Future<void> sendMessage(String message) async {
    await _canSendCompleter.future;
    sendPort?.send(message);
  }

  // @override
  // Future<bool> stopTun() {
  //   return invoke<bool>(
  //     method: ActionMethod.stopTun,
  //   );
  // }

  @override
  Future<String> getAndroidVpnOptions() => invoke<String>(
        method: ActionMethod.getAndroidVpnOptions,
      );

  @override
  Future<bool> updateDns(String value) => invoke<bool>(
      method: ActionMethod.updateDns,
      data: value,
    );

  @override
  Future<DateTime?> getRunTime() async {
    final runTimeString = await invoke<String>(
      method: ActionMethod.getRunTime,
    );
    if (runTimeString.isEmpty) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(int.parse(runTimeString));
  }

  @override
  Future<String> getCurrentProfileName() => invoke<String>(
      method: ActionMethod.getCurrentProfileName,
    );
}

class ClashLibHandler {

  factory ClashLibHandler() {
    _instance ??= ClashLibHandler._internal();
    return _instance!;
  }

  ClashLibHandler._internal() {
    lib = DynamicLibrary.open("libclash.so");
    clashFFI = ClashFFI(lib);
    clashFFI.initNativeApiBridge(
      NativeApi.initializeApiDLData,
    );
  }
  static ClashLibHandler? _instance;

  late final ClashFFI clashFFI;

  late final DynamicLibrary lib;

  Future<String> invokeAction(String actionParams) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message);
        receiver.close();
      }
    });
    final actionParamsChar = actionParams.toNativeUtf8().cast<Char>();
    clashFFI.invokeAction(
      actionParamsChar,
      receiver.sendPort.nativePort,
    );
    malloc.free(actionParamsChar);
    return completer.future;
  }

  void attachMessagePort(int messagePort) {
    clashFFI.attachMessagePort(
      messagePort,
    );
  }

  void updateDns(String dns) {
    final dnsChar = dns.toNativeUtf8().cast<Char>();
    clashFFI.updateDns(dnsChar);
    malloc.free(dnsChar);
  }

  void setState(CoreState state) {
    final stateChar = json.encode(state).toNativeUtf8().cast<Char>();
    clashFFI.setState(stateChar);
    malloc.free(stateChar);
  }

  String getCurrentProfileName() {
    final currentProfileRaw = clashFFI.getCurrentProfileName();
    if (currentProfileRaw == nullptr) return "";
    final currentProfile = currentProfileRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(currentProfileRaw);
    return currentProfile;
  }

  String getAndroidVpnOptions() {
    final vpnOptionsRaw = clashFFI.getAndroidVpnOptions();
    if (vpnOptionsRaw == nullptr) return "";
    final vpnOptions = vpnOptionsRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(vpnOptionsRaw);
    return vpnOptions;
  }

  Traffic getTraffic() {
    final trafficRaw = clashFFI.getTraffic();
    if (trafficRaw == nullptr) return Traffic();
    final trafficString = trafficRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(trafficRaw);
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Traffic getTotalTraffic(bool value) {
    final trafficRaw = clashFFI.getTotalTraffic();
    if (trafficRaw == nullptr) return Traffic();
    final trafficString = trafficRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(trafficRaw);
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Future<bool> startListener() async {
    clashFFI.startListener();
    return true;
  }

  Future<bool> stopListener() async {
    clashFFI.stopListener();
    return true;
  }

  DateTime? getRunTime() {
    final runTimeRaw = clashFFI.getRunTime();
    if (runTimeRaw == nullptr) return null;
    final runTimeString = runTimeRaw.cast<Utf8>().toDartString();
    clashFFI.freeCString(runTimeRaw);
    if (runTimeString.isEmpty) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(int.parse(runTimeString));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final path = await appPath.getProfilePath(id);
    return readNativeConfig(
      path,
      getConfig: clashFFI.getConfig,
      freeCString: clashFFI.freeCString,
    );
  }

  Future<String> quickStart(
    InitParams initParams,
    SetupParams setupParams,
    CoreState state,
  ) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message);
        receiver.close();
      }
    });
    final params = json.encode(setupParams);
    final initValue = json.encode(initParams);
    final stateParams = json.encode(state);
    final initParamsChar = initValue.toNativeUtf8().cast<Char>();
    final paramsChar = params.toNativeUtf8().cast<Char>();
    final stateParamsChar = stateParams.toNativeUtf8().cast<Char>();
    clashFFI.quickStart(
      initParamsChar,
      paramsChar,
      stateParamsChar,
      receiver.sendPort.nativePort,
    );
    malloc.free(initParamsChar);
    malloc.free(paramsChar);
    malloc.free(stateParamsChar);
    return completer.future;
  }
}

ClashLib? get clashLib =>
    Platform.isAndroid && !globalState.isService ? ClashLib() : null;

ClashLibHandler? get clashLibHandler =>
    Platform.isAndroid && globalState.isService ? ClashLibHandler() : null;
