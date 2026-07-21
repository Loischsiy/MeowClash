import 'dart:async';
import 'dart:convert';

import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class VpnListener {
  void onDnsChanged(String dns) {}
}

class Vpn {
  factory Vpn() {
    _instance ??= Vpn._internal();
    return _instance!;
  }

  Vpn._internal() {
    methodChannel = const MethodChannel("vpn");
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "gc":
          clashCore.requestGc();
        case "getStartForegroundParams":
          if (handleGetStartForegroundParams != null) {
            return await handleGetStartForegroundParams!();
          }
          // Default handler for UI mode - get current proxy name from core
          return _getDefaultForegroundParams();
        case "status":
          return clashLibHandler?.getRunTime() != null;
        default:
          for (final listener in _listeners) {
            switch (call.method) {
              case "dnsChanged":
                final dns = call.arguments as String;
                listener.onDnsChanged(dns);
            }
          }
      }
    });
  }
  static Vpn? _instance;
  late MethodChannel methodChannel;
  FutureOr<String> Function()? handleGetStartForegroundParams;

  /// Default foreground params when running in UI mode
  String _getDefaultForegroundParams() {
    try {
      final traffic = clashCore.getTraffic();
      final profile = globalState.config.currentProfile;
      final profileName = profile?.label ?? profile?.id ?? "MeowClash";

      return json
          .encode({"title": profileName, "server": "", "content": "$traffic"});
    } catch (e) {
      return json.encode({"title": "MeowClash", "server": "", "content": ""});
    }
  }

  final ObserverList<VpnListener> _listeners = ObserverList<VpnListener>();

  /// Accepts the raw JSON string produced by the Go core so that fields the
  /// Dart [AndroidVpnOptions] model doesn't know about (e.g. includePackage /
  /// excludePackage injected from profile `tun` config) still make it through
  /// to the Kotlin VpnService unchanged.
  Future<bool?> start(String optionsJson) async =>
      methodChannel.invokeMethod<bool>("start", {
        'data': optionsJson,
      });

  Future<bool?> stop() async => methodChannel.invokeMethod<bool>("stop");

  /// Show subscription expiration notification
  Future<bool?> showSubscriptionNotification({
    required String title,
    required String message,
    required String actionLabel,
    required String actionUrl,
  }) async =>
      methodChannel.invokeMethod<bool>("showSubscriptionNotification", {
        'title': title,
        'message': message,
        'actionLabel': actionLabel,
        'actionUrl': actionUrl,
      });

  void addListener(VpnListener listener) {
    _listeners.add(listener);
  }

  void removeListener(VpnListener listener) {
    _listeners.remove(listener);
  }
}

Vpn? get vpn {
  // On Android, we always need Vpn instance to handle method channel calls
  // from the VPN service (e.g., getStartForegroundParams)
  if (defaultTargetPlatform == TargetPlatform.android) {
    return Vpn();
  }
  // On other platforms, only create in service mode
  return globalState.isService ? Vpn() : null;
}
