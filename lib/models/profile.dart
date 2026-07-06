// ignore_for_file: invalid_annotation_target
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meowclash/clash/core.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/services/subscription_crypto.dart';
import 'package:meowclash/utils/device_info_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'clash_config.dart';

part 'generated/profile.freezed.dart';
part 'generated/profile.g.dart';

typedef SelectedMap = Map<String, String>;

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int total,
    @Default(0) int expire,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.formHString(String? info) {
    if (info == null) return const SubscriptionInfo();
    final list = info.split(";");
    final map = <String, int?>{};
    for (final i in list) {
      final keyValue = i.trim().split("=");
      map[keyValue[0]] = int.tryParse(keyValue[1]);
    }
    return SubscriptionInfo(
      upload: map["upload"] ?? 0,
      download: map["download"] ?? 0,
      total: map["total"] ?? 0,
      expire: map["expire"] ?? 0,
    );
  }
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? label,
    String? currentGroupName,
    @Default("") String url,
    DateTime? lastUpdateDate,
    required Duration autoUpdateDuration,
    SubscriptionInfo? subscriptionInfo,
    @Default(true) bool autoUpdate,
    @Default({}) SelectedMap selectedMap,
    @Default({}) Set<String> unfoldSet,
    @Default(OverrideData()) OverrideData overrideData,
    @JsonKey(includeToJson: false, includeFromJson: false)
    @Default(false)
    bool isUpdating,
    @Default({}) Map<String, String> providerHeaders,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  factory Profile.normal({
    String? label,
    String url = '',
  }) =>
      Profile(
        label: label,
        url: url,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        autoUpdateDuration: defaultUpdateDuration,
      );
}

@freezed
class OverrideData with _$OverrideData {
  const factory OverrideData({
    @Default(false) bool enable,
    @Default(OverrideRule()) OverrideRule rule,
    @Default([]) List<ProxyChain> chains,
  }) = _OverrideData;

  factory OverrideData.fromJson(Map<String, Object?> json) =>
      _$OverrideDataFromJson(json);
}

extension OverrideDataExt on OverrideData {
  List<String> get runningRule {
    if (!enable) {
      return [];
    }
    return rule.rules.map((item) => item.value).toList();
  }

  /// Enabled chains that have enough hops to form a chain (>= 2).
  List<ProxyChain> get enabledChains => chains
      .where((chain) => chain.enable && chain.hops.length >= 2)
      .toList();

  /// Builds the proxy nodes and proxy-groups needed to realize the enabled
  /// chains for mihomo 1.19+, where the `relay` group type was removed and
  /// `dialer-proxy` is only honored on concrete proxy *nodes* (not on groups).
  ///
  /// For a chain `entry -> ... -> exit`, traffic must flow
  /// `client -> entry -> ... -> exit -> internet`. We achieve this by cloning
  /// each hop after the entry into a new proxy node that carries
  /// `dialer-proxy: <previous hop>`, so every later hop dials out through the
  /// previous one. The entry hop is used as a dialer only and is never cloned,
  /// so it may be a concrete node OR an existing group (a selector or an
  /// auto/url-test group) — a `dialer-proxy` value is allowed to be a group.
  ///
  /// The final (exit) clone is wrapped in a hidden `select` group named after
  /// the chain, so the chain can be used as a rule target like any other group
  /// while staying hidden from the proxies page (mihomo's `hidden` flag).
  ///
  /// [resolveProxyNode] returns the raw definition of a concrete proxy node by
  /// name, or null when the name is not an inline node (e.g. a provider-backed
  /// node that cannot be cloned). [resolveProxyName] may map a non-entry group
  /// hop to its selected concrete node. [resolveProxyGroup] returns an inline
  /// group definition by name so group hops can be cloned as hidden groups.
  ///
  /// The result is injected on top of the parsed profile config right before
  /// it is handed to the core (see GlobalState.patchRawConfig), so chains live
  /// outside the subscription YAML and survive subscription auto-updates.
  ({
    List<Map<String, dynamic>> proxies,
    List<Map<String, dynamic>> proxyGroups,
  }) buildRunningChainConfig(
    Map<String, dynamic>? Function(String name) resolveProxyNode, {
    String Function(String name)? resolveProxyName,
    Map<String, dynamic>? Function(String name)? resolveProxyGroup,
  }) {
    final proxies = <Map<String, dynamic>>[];
    final groups = <Map<String, dynamic>>[];
    for (final chain in enabledChains) {
      final hops = chain.hops;
      // The entry hop is the first dialer and is never cloned (it may be a
      // group). Every later hop is cloned into a node carrying `dialer-proxy`.
      var dialerProxy = hops.first;
      final clonedNodes = <Map<String, dynamic>>[];
      final clonedGroups = <Map<String, dynamic>>[];
      String? exitName;
      var isValid = true;
      for (var i = 1; i < hops.length; i++) {
        final hopName = resolveProxyName?.call(hops[i]) ?? hops[i];
        final def = resolveProxyNode(hopName);
        if (def == null) {
          final group = resolveProxyGroup?.call(hops[i]);
          final groupProxies =
              (group?["proxies"] as List?)?.whereType<String>().toList() ??
                  const <String>[];
          if (group == null || groupProxies.isEmpty) {
            isValid = false;
            break;
          }
          final groupName = "${chain.name} \u00b7 ${i + 1}";
          final groupCloneNames = <String>[];
          for (var j = 0; j < groupProxies.length; j++) {
            final memberName =
                resolveProxyName?.call(groupProxies[j]) ?? groupProxies[j];
            final memberDef = resolveProxyNode(memberName);
            if (memberDef == null) {
              isValid = false;
              break;
            }
            final cloneName = "$groupName.${j + 1}";
            final clone = Map<String, dynamic>.from(memberDef);
            clone["name"] = cloneName;
            clone["dialer-proxy"] = dialerProxy;
            clonedNodes.add(clone);
            groupCloneNames.add(cloneName);
          }
          if (!isValid) {
            break;
          }
          final groupClone = Map<String, dynamic>.from(group);
          groupClone["name"] = groupName;
          groupClone["hidden"] = true;
          groupClone["proxies"] = groupCloneNames;
          groupClone.remove("use");
          clonedGroups.add(groupClone);
          dialerProxy = groupName;
          exitName = groupName;
          continue;
        }
        final cloneName = "${chain.name} \u00b7 ${i + 1}";
        final clone = Map<String, dynamic>.from(def);
        clone["name"] = cloneName;
        clone["dialer-proxy"] = dialerProxy;
        clonedNodes.add(clone);
        dialerProxy = cloneName;
        exitName = cloneName;
      }
      if (!isValid || exitName == null) {
        continue;
      }
      proxies.addAll(clonedNodes);
      groups.addAll(clonedGroups);
      // Expose the chain only as a hidden `select` group: it stays a valid rule
      // target (rules reference it by name) but is filtered out of the proxies
      // page, so traffic is routed to it via rules instead of being picked
      // manually. mihomo forwards the `hidden` flag through its API and
      // ClashCore.getProxiesGroups drops hidden groups from the UI.
      groups.add(<String, dynamic>{
        "name": chain.name,
        "type": "select",
        "hidden": true,
        "proxies": [exitName],
      });
    }
    return (proxies: proxies, proxyGroups: groups);
  }
}

/// Returns [rules] with the final `MATCH` rule repointed to [selector]
/// (appending one if there is none). Chain mode uses this so all
/// otherwise-unmatched traffic egresses through the selected chain while the
/// subscription's specific rules stay intact.
List<String> withChainSelectorMatch(List<String> rules, String selector) {
  final result = List<String>.from(rules);
  final match = "MATCH,$selector";
  final index = result.lastIndexWhere(
    (rule) => rule.trimLeft().toUpperCase().startsWith("MATCH,"),
  );
  if (index == -1) {
    result.add(match);
  } else {
    result[index] = match;
  }
  return result;
}

/// A user-defined proxy chain: entry hop -> ... -> exit hop.
///
/// Each entry in [hops] is the name of an existing proxy or proxy-group from
/// the active profile (a specific node, a selector, or an auto/url-test
/// group). The chain is realized by cloning each hop after the entry into a
/// proxy node carrying `dialer-proxy`; the exit clone is wrapped in a `select`
/// group named [name] so it can be selected on the proxies page and used as a
/// rule target like any other group. The entry hop may be a node or a group.
/// Later group hops are resolved to their selected concrete node before cloning.
@freezed
class ProxyChain with _$ProxyChain {
  const factory ProxyChain({
    required String id,
    @Default("") String name,
    @Default([]) List<String> hops,
    @Default(true) bool enable,
  }) = _ProxyChain;

  factory ProxyChain.fromJson(Map<String, Object?> json) =>
      _$ProxyChainFromJson(json);

  factory ProxyChain.create({String name = ""}) => ProxyChain(
        id: utils.uuidV4,
        name: name,
      );
}

@freezed
class OverrideRule with _$OverrideRule {
  const factory OverrideRule({
    @Default(OverrideRuleType.added) OverrideRuleType type,
    @Default([]) List<Rule> overrideRules,
    @Default([]) List<Rule> addedRules,
  }) = _OverrideRule;

  factory OverrideRule.fromJson(Map<String, Object?> json) =>
      _$OverrideRuleFromJson(json);
}

extension OverrideRuleExt on OverrideRule {
  List<Rule> get rules => switch (type == OverrideRuleType.override) {
        true => overrideRules,
        false => addedRules,
      };

  OverrideRule updateRules(List<Rule> Function(List<Rule> rules) builder) {
    if (type == OverrideRuleType.added) {
      return copyWith(addedRules: builder(addedRules));
    }
    return copyWith(overrideRules: builder(overrideRules));
  }
}

extension ProfilesExt on List<Profile> {
  Profile? getProfile(String? profileId) {
    final index = indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : this[index];
  }
}

extension ProfileExtension on Profile {
  ProfileType get type =>
      url.isEmpty == true ? ProfileType.file : ProfileType.url;

  bool get realAutoUpdate => url.isEmpty == true ? false : autoUpdate;

  Future<void> checkAndUpdate() async {
    final isExists = await check();
    if (!isExists) {
      if (url.isNotEmpty && realAutoUpdate) {
        await update();
      }
    }
  }

  Future<bool> check() async {
    final profilePath = await appPath.getProfilePath(id);
    return File(profilePath).exists();
  }

  Future<File> getFile() async {
    final path = await appPath.getProfilePath(id);
    final file = File(path);
    final isExists = await file.exists();
    if (!isExists) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<int> get profileLastModified async {
    final file = await getFile();
    return (await file.lastModified()).microsecondsSinceEpoch;
  }

  Future<Profile> update({
    bool shouldSendHeaders = true,
    String? decryptionPassword,
    int? decryptionIterations,
  }) async {
    final headers = <String, dynamic>{};

    if (shouldSendHeaders) {
      final deviceInfoService = DeviceInfoService();
      final details = await deviceInfoService.getDeviceDetails();

      if (details.hwid != null) headers['x-hwid'] = details.hwid;
      if (details.os != null) headers['x-device-os'] = details.os;
      if (details.osVersion != null) headers['x-ver-os'] = details.osVersion;
      if (details.model != null) headers['x-device-model'] = details.model;
    }

    final response = await request.getFileResponseForUrl(
      url,
      headers: headers.isNotEmpty ? headers : null,
    );

    final disposition = response.headers.value("content-disposition");
    final userinfo = response.headers.value('subscription-userinfo');

    final responseData = response.data;
    if (responseData == null) {
      throw Exception("Failed to get profile data from response.");
    }
    ensureCoreInputHeaderFits(
      response.headers.value(HttpHeaders.contentLengthHeader),
      name: 'Profile ${label ?? url}',
    );

    final profileData = await _maybeDecrypt(
      responseData,
      password: decryptionPassword ?? providerHeaders['meowclash-password'],
      iterations: decryptionIterations ??
          int.tryParse(
              providerHeaders['meowclash-password-iterations'] ?? '') ??
          kDefaultPbkdf2Iterations,
    );
    ensureCoreInputBytes(profileData, name: 'Profile ${label ?? url}');

    final newProviderHeaders = <String, String>{};

    final headersToCollect = [
      'announce',
      'support-url',
      'profile-update-interval',
      'x-hwid-limit',
    ];

    for (final headerName in headersToCollect) {
      final value = response.headers.value(headerName);
      if (value != null && value.isNotEmpty) {
        newProviderHeaders[headerName] = value;
      }
    }

    // Only the subscription-decryption credentials are still read from
    // meowclash-* response headers. The rest of the meowclash-* customization
    // system has been removed.
    const passwordHeaderNames = [
      'meowclash-password',
      'meowclash-password-iterations',
    ];
    for (final headerName in passwordHeaderNames) {
      final value = response.headers.value(headerName);
      if (value != null && value.isNotEmpty) {
        newProviderHeaders[headerName] = value;
      }
    }

    // Preserve saved credentials if not provided by server
    if (decryptionPassword != null) {
      newProviderHeaders['meowclash-password'] = decryptionPassword;
    } else if (providerHeaders.containsKey('meowclash-password')) {
      newProviderHeaders['meowclash-password'] =
          providerHeaders['meowclash-password']!;
    }

    if (decryptionIterations != null) {
      newProviderHeaders['meowclash-password-iterations'] =
          decryptionIterations.toString();
    } else if (providerHeaders.containsKey('meowclash-password-iterations')) {
      newProviderHeaders['meowclash-password-iterations'] =
          providerHeaders['meowclash-password-iterations']!;
    }

    Duration? durationFromHeader;
    final updateIntervalHeader = newProviderHeaders['profile-update-interval'];
    if (updateIntervalHeader != null) {
      final hours = int.tryParse(updateIntervalHeader);
      if (hours != null && hours > 0) {
        durationFromHeader = Duration(hours: hours);
      }
    }

    return copyWith(
      label: label ?? utils.getFileNameForDisposition(disposition) ?? id,
      subscriptionInfo: SubscriptionInfo.formHString(userinfo),
      autoUpdateDuration: durationFromHeader ?? autoUpdateDuration,
      providerHeaders: newProviderHeaders,
    ).saveFile(profileData);
  }

  /// If [data] looks like an AES-256-CBC payload produced by the
  /// companion `crypto.py` script, decrypt it with [password] and
  /// return the plaintext bytes. Otherwise return [data] unchanged.
  ///
  /// Throws a [SubscriptionPasswordRequiredException] when the payload
  /// is encrypted but no [password] was supplied.
  static Future<Uint8List> _maybeDecrypt(
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

  Future<Profile> saveFile(Uint8List bytes) async {
    return saveFileWithString(utf8.decode(bytes));
  }

  /// Persists a clash profile to disk.
  ///
  /// Accepts either a clash YAML profile or a V2Ray-style subscription
  /// (a base64 or plain text list of `vless://`, `vmess://`, `trojan://`,
  /// `ss://`, `hysteria://` ... URIs). Subscription content is normalized
  /// to a minimal clash YAML by the core before validation, so the file
  /// on disk is always something the core can load.
  Future<Profile> saveFileWithString(String value) async {
    final normalized = await clashCore.convertSubscription(value);
    final yaml = normalized.isNotEmpty ? normalized : value;
    final message = await clashCore.validateConfig(yaml);
    if (message.isNotEmpty) {
      throw message;
    }
    final file = await getFile();
    await _writeProfileFileAtomically(file, utf8.encode(yaml));
    return copyWith(lastUpdateDate: DateTime.now());
  }

  Future<void> _writeProfileFileAtomically(File file, List<int> bytes) async {
    final tempFile = File(
      '${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      await tempFile.rename(file.path);
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }
}
