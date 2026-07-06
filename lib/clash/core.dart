import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/clash/interface.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/services/subscription_crypto.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';

class ClashCore {

  factory ClashCore() {
    _instance ??= ClashCore._internal();
    return _instance!;
  }

  ClashCore._internal() {
    if (Platform.isAndroid) {
      clashInterface = clashLib!;
    } else {
      clashInterface = clashService!;
    }
  }
  static ClashCore? _instance;
  late ClashHandlerInterface clashInterface;

  Future<bool> preload() => clashInterface.preload();

  static Future<void> initGeo() async {
    commonPrint.log("ClashCore: Starting initGeo...");
    final homePath = await appPath.homeDirPath;
    final homeDir = Directory(homePath);
    final isExists = await homeDir.exists();
    if (!isExists) {
      commonPrint.log("ClashCore: Creating home directory $homePath");
      await homeDir.create(recursive: true);
    }
    const geoFileNameList = [
      mmdbFileName,
      geoIpFileName,
      geoSiteFileName,
      asnFileName,
    ];
    try {
      for (final geoFileName in geoFileNameList) {
        final geoFile = File(
          join(homePath, geoFileName),
        );
        final isExists = await geoFile.exists();
        if (isExists) {
          commonPrint.log("ClashCore: Geo file $geoFileName already exists, skipping");
          continue;
        }
        commonPrint.log("ClashCore: Loading $geoFileName from assets...");
        try {
          final data = await rootBundle.load('assets/data/$geoFileName');
          final List<int> bytes = data.buffer.asUint8List();
          commonPrint.log("ClashCore: Writing $geoFileName to $homePath (${bytes.length} bytes)");
          await geoFile.writeAsBytes(bytes, flush: true);
        } catch (e) {
          commonPrint.log("ClashCore: Failed to load $geoFileName from assets: $e");
        }
      }
      commonPrint.log("ClashCore: initGeo finished (errors may have been logged)");
    } catch (e, stackTrace) {
      commonPrint.log("=== ClashCore: initGeo NON-FATAL ERROR ===");
      commonPrint.log("Error: $e");
      commonPrint.log("StackTrace: $stackTrace");
    }
  }

  Future<bool> init() async {
    commonPrint.log("ClashCore: Starting init...");
    await initGeo();
    if (globalState.config.appSetting.openLogs) {
      commonPrint.log("ClashCore: Starting log...");
      clashCore.startLog();
    } else {
      clashCore.stopLog();
    }
    final homeDirPath = await appPath.homeDirPath;
    commonPrint.log("ClashCore: Calling clashInterface.init(homeDir=$homeDirPath)...");
    final result = await clashInterface.init(
      InitParams(
        homeDir: homeDirPath,
        version: globalState.appState.version,
      ),
    );
    commonPrint.log("ClashCore: clashInterface.init returned $result");
    return result;
  }

  Future<bool> setState(CoreState state) => clashInterface.setState(state);

  Future<void> shutdown() async {
    await clashInterface.shutdown();
  }

  FutureOr<bool> get isInit => clashInterface.isInit;

  FutureOr<String> validateConfig(String data) {
    ensureCoreInputSize(utf8.encode(data).length, name: 'Config');
    return clashInterface.validateConfig(data);
  }

  FutureOr<String> convertSubscription(String data) {
    ensureCoreInputSize(utf8.encode(data).length, name: 'Subscription');
    return clashInterface.convertSubscription(data);
  }

  Future<String> updateConfig(UpdateParams updateParams) => clashInterface.updateConfig(updateParams);

  Future<String> setupConfig(SetupParams setupParams) {
    ensureCoreInputSize(
      utf8.encode(json.encode(setupParams)).length,
      name: 'Setup config',
    );
    return clashInterface.setupConfig(setupParams);
  }

  Future<List<Group>> getProxiesGroups() async {
    final proxies = await clashInterface.getProxies();
    if (proxies.isEmpty) return [];
    final visibleGroupNames = [
      UsedProxy.GLOBAL.name,
      ...(proxies[UsedProxy.GLOBAL.name]["all"] as List).where((e) {
        final proxy = proxies[e] ?? {};
        // Hide groups flagged `hidden: true` (e.g. proxy-chain groups injected
        // by the override editor). mihomo forwards the flag through its API;
        // such groups stay usable via rules but must not appear on the
        // proxies page.
        if (proxy['hidden'] == true) {
          return false;
        }
        return GroupTypeExtension.valueList.contains(proxy['type']);
      })
    ];
    final visibleGroupNameSet = visibleGroupNames.toSet();
    final groupNames = [
      ...visibleGroupNames,
      ...proxies.entries
          .where((entry) =>
              !visibleGroupNameSet.contains(entry.key) &&
              GroupTypeExtension.valueList.contains(entry.value['type']))
          .map((entry) => entry.key)
    ];
    final groupsRaw = groupNames.map((groupName) {
      final group = Map<String, dynamic>.from(proxies[groupName]);
      group["hidden"] =
          group["hidden"] == true || !visibleGroupNameSet.contains(groupName);
      group["all"] = ((group["all"] ?? []) as List)
          .map(
            (name) => proxies[name],
          )
          .where((proxy) => proxy != null)
          .toList();
      return group;
    }).toList();
    return groupsRaw
        .map(
          Group.fromJson,
        )
        .toList();
  }

  FutureOr<String> changeProxy(ChangeProxyParams changeProxyParams) async => await clashInterface.changeProxy(changeProxyParams);

  Future<List<Connection>> getConnections() async {
    final res = await clashInterface.getConnections();
    final connectionsData = json.decode(res) as Map;
    final connectionsRaw = connectionsData['connections'] as List? ?? [];
    return connectionsRaw.map((e) => Connection.fromJson(e)).toList();
  }

  void closeConnection(String id) {
    clashInterface.closeConnection(id);
  }

  void closeConnections() {
    clashInterface.closeConnections();
  }

  void resetConnections() {
    clashInterface.resetConnections();
  }

  Future<List<ExternalProvider>> getExternalProviders() async {
    final externalProvidersRawString =
        await clashInterface.getExternalProviders();
    if (externalProvidersRawString.isEmpty) {
      return [];
    }
    final externalProviders =
        (json.decode(externalProvidersRawString) as List<dynamic>)
            .map(
              (item) => ExternalProvider.fromJson(item),
            )
            .toList();
    return externalProviders;
  }

  Future<ExternalProvider?> getExternalProvider(
      String externalProviderName) async {
    final externalProvidersRawString =
        await clashInterface.getExternalProvider(externalProviderName);
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    if (externalProvidersRawString.isEmpty) {
      return null;
    }
    return ExternalProvider.fromJson(json.decode(externalProvidersRawString));
  }

  Future<String> updateGeoData(UpdateGeoDataParams params) => clashInterface.updateGeoData(params);

  Future<String> sideLoadExternalProvider({
    required String providerName,
    required String data,
  }) {
    ensureCoreInputSize(
      utf8.encode(data).length,
      name: 'Provider $providerName',
    );
    return clashInterface.sideLoadExternalProvider(
        providerName: providerName, data: data);
  }

  static Future<Uint8List> maybeDecryptProvider(
    Uint8List data, {
    required String? password,
    required int iterations,
  }) async {
    final String text;
    try {
      text = utf8.decode(data, allowMalformed: false);
    } on FormatException {
      return data;
    }
    if (!SubscriptionCrypto.looksLikeEncryptedPayload(text)) {
      return data;
    }
    if (password == null || password.isEmpty) {
      throw SubscriptionPasswordRequiredException(
        AppLocalizations.current.profileEncryptedPasswordRequired,
      );
    }
    return SubscriptionCrypto.decryptBase64(
      text,
      password: password,
      iterations: iterations,
    );
  }

  Future<void> downloadAndDecryptProvider({
    required Profile profile,
    required String providerName,
    required String url,
    required String type,
    required String providerPath,
  }) async {
    final response = await request.getFileResponseForUrl(url);
    final responseData = response.data;
    if (responseData == null) {
      throw Exception("Failed to download provider data");
    }
    ensureCoreInputHeaderFits(
      response.headers.value(HttpHeaders.contentLengthHeader),
      name: 'Provider $providerName',
    );

    final password = profile.providerHeaders['meowclash-password'];
    final iterations = int.tryParse(profile.providerHeaders['meowclash-password-iterations'] ?? '') ?? kDefaultPbkdf2Iterations;

    final decryptedData = await maybeDecryptProvider(
      responseData,
      password: password,
      iterations: iterations,
    );
    ensureCoreInputBytes(decryptedData, name: 'Provider $providerName');

    final file = File(providerPath);
    await file.create(recursive: true);
    await file.writeAsBytes(decryptedData);
  }

  Future<String> updateExternalProvider({
    required String providerName,
  }) async {
    final currentProfile = globalState.config.currentProfile;
    if (currentProfile != null) {
      final profileId = currentProfile.id;
      try {
        final configMap = await globalState.getProfileConfig(profileId);
        String? url;
        String? type;

        if (configMap['proxy-providers'] != null) {
          final provider = configMap['proxy-providers'][providerName];
          if (provider is Map && provider['url'] != null) {
            url = provider['url'].toString();
            type = 'proxies';
          }
        }
        if (url == null && configMap['rule-providers'] != null) {
          final provider = configMap['rule-providers'][providerName];
          if (provider is Map && provider['url'] != null) {
            url = provider['url'].toString();
            type = 'rules';
          }
        }

        if (url != null && type != null) {
          final providerPath = await appPath.getProvidersFilePath(profileId, type, url);
          await downloadAndDecryptProvider(
            profile: currentProfile,
            providerName: providerName,
            url: url,
            type: type,
            providerPath: providerPath,
          );

          final text = await File(providerPath).readAsString();
          return sideLoadExternalProvider(
            providerName: providerName,
            data: text,
          );
        }
      } on CoreInputTooLargeException catch (e) {
        commonPrint.log("updateExternalProvider blocked: $e");
        return e.toString();
      } catch (e) {
        commonPrint.log("Custom updateExternalProvider failed: $e");
        // Fallback to default Clash update if anything fails
      }
    }
    return clashInterface.updateExternalProvider(providerName);
  }

  Future<void> startListener() async {
    await clashInterface.startListener();
  }

  Future<void> stopListener() async {
    await clashInterface.stopListener();
  }

  Future<Delay> getDelay(String url, String proxyName) async {
    final data = await clashInterface.asyncTestDelay(url, proxyName);
    return Delay.fromJson(json.decode(data));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final profilePath = await appPath.getProfilePath(id);
    ensureCoreInputFileFits(File(profilePath), name: 'Profile $id');
    final res = await clashInterface.getConfig(profilePath);
    if (res.isSuccess) {
      return res.data as Map<String, dynamic>;
    } else {
      throw res.message;
    }
  }

  Future<Traffic> getTraffic() async {
    final trafficString = await clashInterface.getTraffic();
    if (trafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(trafficString));
  }

  Future<IpInfo?> getCountryCode(String ip) async {
    final countryCode = await clashInterface.getCountryCode(ip);
    if (countryCode.isEmpty) {
      return null;
    }
    return IpInfo(
      ip: ip,
      countryCode: countryCode,
    );
  }

  Future<Traffic> getTotalTraffic() async {
    final totalTrafficString = await clashInterface.getTotalTraffic();
    if (totalTrafficString.isEmpty) {
      return Traffic();
    }
    return Traffic.fromMap(json.decode(totalTrafficString));
  }

  Future<int> getMemory() async {
    final value = await clashInterface.getMemory();
    if (value.isEmpty) {
      return 0;
    }
    return int.parse(value);
  }

  void resetTraffic() {
    clashInterface.resetTraffic();
  }

  void startLog() {
    clashInterface.startLog();
  }

  void stopLog() {
    clashInterface.stopLog();
  }

  void requestGc() {
    clashInterface.forceGc();
  }

  Future<void> destroy() async {
    await clashInterface.destroy();
  }
}

final clashCore = ClashCore();
