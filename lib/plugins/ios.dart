import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class IOSVpnStatus {
  const IOSVpnStatus({this.state = 'disconnected', this.startedAt});

  factory IOSVpnStatus.fromMap(Map<dynamic, dynamic> value) {
    final milliseconds = value['startedAt'] as num?;
    return IOSVpnStatus(
      state: value['status'] as String? ?? 'disconnected',
      startedAt: milliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt()),
    );
  }

  final String state;
  final DateTime? startedAt;
  bool get isConnected => state == 'connected' || state == 'reasserting';
}

/// iOS uses an independent NetworkExtension, not Android's service isolate.
/// The channel is injectable for tests; no global pub/plugin cache is modified.
class IOSVpn {
  IOSVpn({this.channel = const MethodChannel('com.meowclash/ios')}) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'statusChanged') {
        status.value = IOSVpnStatus.fromMap(call.arguments as Map);
      }
    });
  }

  final MethodChannel channel;
  final status = ValueNotifier(const IOSVpnStatus());

  Future<IOSVpnStatus> _statusCall(String method) async {
    final result = await channel.invokeMapMethod<String, dynamic>(method);
    if (result == null) {
      throw PlatformException(code: 'ios_vpn', message: 'Missing VPN status');
    }
    return status.value = IOSVpnStatus.fromMap(result);
  }

  Future<IOSVpnStatus> initialize() => _statusCall('initialize');
  Future<IOSVpnStatus> refreshStatus() => _statusCall('status');
  Future<IOSVpnStatus> start() => _statusCall('start');
  Future<IOSVpnStatus> stop() => _statusCall('stop');

  Future<String> get homeDirectory async {
    final path = await channel.invokeMethod<String>('homeDirectory');
    if (path == null || path.isEmpty) {
      throw PlatformException(
          code: 'app_group', message: 'App Group storage unavailable');
    }
    return path;
  }

  Future<String> invokeAction(String action) async {
    final reply = await channel.invokeMethod<String>('action', action);
    if (reply == null) {
      throw PlatformException(
          code: 'ios_core', message: 'Core returned no response');
    }
    return reply;
  }

  Future<String> drainEvents() async =>
      await channel.invokeMethod<String>('events') ?? '[]';

  Future<void> restartLocal() => channel.invokeMethod<void>('restartLocal');
}

final IOSVpn? iosVpn = Platform.isIOS ? IOSVpn() : null;
