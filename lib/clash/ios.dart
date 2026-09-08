import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Action;
import 'package:meowclash/clash/interface.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/plugins/ios.dart';

class ClashIOSHandler extends ClashHandlerInterface
    with WidgetsBindingObserver {
  ClashIOSHandler({required this.bridge});

  final IOSVpn bridge;
  Timer? _eventsTimer;
  bool _draining = false;
  bool _attached = false;
  int _generation = 0;

  @override
  Future<bool> preload() async {
    await bridge.initialize();
    if (!_attached) {
      _attached = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _syncPolling(WidgetsBinding.instance.lifecycleState);
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPolling(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(bridge.refreshStatus().catchError((Object error) {
        commonPrint.log('iOS VPN status: $error');
        return bridge.status.value;
      }));
    }
  }

  void _syncPolling(AppLifecycleState? state) {
    _generation++;
    _eventsTimer?.cancel();
    _eventsTimer = null;
    if (!_attached || (state != null && state != AppLifecycleState.resumed)) {
      return;
    }
    _eventsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      unawaited(_drainEvents());
    });
  }

  Future<void> _drainEvents() async {
    if (_draining) return;
    _draining = true;
    final generation = _generation;
    try {
      final events = json.decode(await bridge.drainEvents()) as List;
      if (generation != _generation || !_attached) return;
      for (final event in events) {
        await handleResult(
            ActionResult.fromJson(Map<String, dynamic>.from(event as Map)));
      }
    } catch (error) {
      commonPrint.log('iOS core events: $error');
    } finally {
      _draining = false;
    }
  }

  @override
  Future<T> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
    FutureOr<T> Function()? onTimeout,
    T? defaultValue,
  }) async {
    final action =
        Action(id: '${method.name}#${utils.id}', method: method, data: data);
    Future<T> request() async {
      final reply = ActionResult.fromJson(
        json.decode(await bridge.invokeAction(json.encode(action)))
            as Map<String, dynamic>,
      );
      if (reply.id != action.id || reply.method != method) {
        throw const FormatException('Mismatched iOS core response');
      }
      if (method == ActionMethod.getConfig) return reply.toResult as T;
      if (reply.code != ResultType.success) {
        throw PlatformException(code: 'ios_core', message: '${reply.data}');
      }
      return reply.data as T;
    }

    // Never turn platform errors/timeouts into successful empty config data.
    // A caller's explicit timeout result (latency=-1) is still supported.
    return request()
        .timeout(timeout ?? const Duration(seconds: 130), onTimeout: onTimeout);
  }

  @override
  Future<void> sendMessage(String message) async {
    final reply = await bridge.invokeAction(message);
    await handleResult(
        ActionResult.fromJson(json.decode(reply) as Map<String, dynamic>));
  }

  void _fire(ActionMethod method) {
    unawaited(invoke<Object?>(method: method).catchError((Object error) {
      commonPrint.log('iOS ${method.name}: $error');
      return null;
    }));
  }

  @override
  void startLog() => _fire(ActionMethod.startLog);
  @override
  void stopLog() => _fire(ActionMethod.stopLog);
  @override
  void resetTraffic() => _fire(ActionMethod.resetTraffic);

  // NE start/stop owns listeners and TUN together. GlobalState uses bridge.start
  // and bridge.stop, so these calls must not start a second TUN in Runner.
  @override
  Future<bool> startListener() async => true;
  @override
  Future<bool> stopListener() async => true;

  @override
  Future<void> reStart() => bridge.restartLocal();

  @override
  Future<bool> destroy() async {
    _attached = false;
    _generation++;
    _eventsTimer?.cancel();
    _eventsTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    // Detaching Flutter/backgrounding must leave PacketTunnel alive.
    return true;
  }
}
