import 'dart:convert';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/backend.dart';
import 'package:meowclash/services/zapret/zapret_logger.dart';
import 'package:flutter/services.dart';

/// Android backend: because a non-root device cannot run nfqws (there is no
/// userspace NFQUEUE), DPI bypass is applied as **userspace packet mutation
/// inside the Go core**, on the sing-tun read path (see AGENTS.md / core
/// changes and README "Android: packet mutation in the Go core"). This Dart
/// side just drives that native seam over a dedicated method channel; the
/// strategy args are forwarded to the core, which interprets a supported subset
/// (TTL, split, fake) on outbound TLS/QUIC flows.
///
/// The channel is optional: on an app build where the native seam is not
/// compiled in, [checkAvailability] reports [missingNativeSupport] and the UI
/// shows an explicit message instead of failing silently.
class AndroidZapret2Backend extends Zapret2Backend {
  AndroidZapret2Backend({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel("zapret2");

  final MethodChannel _channel;

  @override
  SupportPlatform get platform => SupportPlatform.Android;

  @override
  Future<Zapret2Availability> checkAvailability() async {
    try {
      final ok = await _channel.invokeMethod<bool>("isSupported");
      if (ok == true) {
        return const Zapret2Availability.available();
      }
      return const Zapret2Availability.unavailable(
        Zapret2UnavailableReason.missingNativeSupport,
        detail: "core packet-mutation seam not enabled",
      );
    } on MissingPluginException {
      return const Zapret2Availability.unavailable(
        Zapret2UnavailableReason.missingNativeSupport,
        detail: "zapret2 channel not registered",
      );
    } on PlatformException catch (e) {
      return Zapret2Availability.unavailable(
        Zapret2UnavailableReason.missingNativeSupport,
        detail: e.message,
      );
    }
  }

  @override
  Future<Zapret2Session> start({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  }) async {
    await zapretLogger.log("android: applying ${strategy.id} via core seam");
    try {
      final ok = await _channel.invokeMethod<bool>("apply", {
        "strategyId": strategy.id,
        "args": strategy.args,
        "targets": jsonEncode(targets.map((t) => t.toJson()).toList()),
      });
      if (ok != true) {
        throw const Zapret2BackendException(
          Zapret2UnavailableReason.missingNativeSupport,
          "core rejected strategy",
        );
      }
      return _AndroidZapret2Session(_channel, strategy);
    } on MissingPluginException {
      throw const Zapret2BackendException(
        Zapret2UnavailableReason.missingNativeSupport,
        "zapret2 channel not registered",
      );
    } on PlatformException catch (e) {
      throw Zapret2BackendException(
        Zapret2UnavailableReason.missingNativeSupport,
        e.message ?? "apply failed",
      );
    }
  }
}

class _AndroidZapret2Session implements Zapret2Session {
  _AndroidZapret2Session(this._channel, this.strategy);

  final MethodChannel _channel;

  @override
  final Zapret2Strategy strategy;

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>("clear");
    } on PlatformException catch (e) {
      await zapretLogger.log("android: clear failed: ${e.message}");
    } on MissingPluginException {
      // Channel vanished (engine torn down) — nothing to clear.
    }
  }
}
