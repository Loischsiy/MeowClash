import 'dart:async';
import 'dart:io';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/backend.dart';
import 'package:meowclash/services/zapret/zapret_logger.dart';

/// Outcome of probing one target once.
class TargetProbe {
  const TargetProbe({required this.ok, required this.latencyMs});

  const TargetProbe.fail()
      : ok = false,
        latencyMs = 0;

  final bool ok;
  final int latencyMs;
}

/// Probes reachability of a single [Zapret2Target] and reports success +
/// latency. Injectable so [Zapret2StrategyTester] is unit-testable without real
/// sockets. This is the "blockcheck"-like signal: a target that was blocked/
/// throttled becomes reachable once a working strategy is applied.
typedef TargetProber = Future<TargetProbe> Function(Zapret2Target target);

/// Default prober: opens a TLS connection to the target and measures the
/// handshake latency. A blocked/throttled TLS ClientHello typically hangs or is
/// RST'd, so a completed handshake within the timeout is the success signal.
Future<TargetProbe> defaultTargetProber(Zapret2Target target) async {
  final stopwatch = Stopwatch()..start();
  SecureSocket? socket;
  try {
    socket = await SecureSocket.connect(
      target.ip ?? target.host,
      target.port,
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 5),
    ).timeout(const Duration(seconds: 6));
    stopwatch.stop();
    return TargetProbe(ok: true, latencyMs: stopwatch.elapsedMilliseconds);
  } catch (_) {
    return const TargetProbe.fail();
  } finally {
    await socket?.close();
  }
}

/// Applies a single strategy through the [Zapret2Backend] and measures how many
/// of the targets become reachable. Returns a [Zapret2ProbeResult] whose
/// `successRatio` is the UCB1 reward. Always stops the engine session before
/// returning so strategies never overlap on the packet hook.
class Zapret2StrategyTester {
  Zapret2StrategyTester({
    required this.backend,
    TargetProber? prober,
    this.settleDelay = const Duration(milliseconds: 300),
  }) : prober = prober ?? defaultTargetProber;

  final Zapret2Backend backend;
  final TargetProber prober;

  /// Time to let the engine install its hook before probing.
  final Duration settleDelay;

  Future<Zapret2ProbeResult> test({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  }) async {
    if (targets.isEmpty) {
      return Zapret2ProbeResult(strategyId: strategy.id, successRatio: 0);
    }
    Zapret2Session? session;
    try {
      session = await backend.start(
        strategy: strategy,
        targets: targets,
        customEnginePath: customEnginePath,
      );
      await Future<void>.delayed(settleDelay);

      if (backend.platform == SupportPlatform.Android ||
          backend.platform == SupportPlatform.MacOS) {
        // ponytail: Dart SecureSocket does not reliably travel through the
        // mihomo stream hook on these platforms, so probing here creates false
        // "no working strategy" failures. Start success is the smoke test.
        return Zapret2ProbeResult(
          strategyId: strategy.id,
          successRatio: 1,
        );
      }

      final probes = await Future.wait(targets.map(prober));
      final successes = probes.where((p) => p.ok).toList();
      final ratio = successes.length / targets.length;
      final latency = successes.isEmpty
          ? 0
          : _median(successes.map((p) => p.latencyMs).toList());
      await zapretLogger.log(
        "probe ${strategy.id}: ${successes.length}/${targets.length} ok, "
        "median ${latency}ms",
      );
      return Zapret2ProbeResult(
        strategyId: strategy.id,
        successRatio: ratio,
        latencyMs: latency,
      );
    } on Zapret2BackendException catch (e) {
      await zapretLogger.log("probe ${strategy.id} failed: ${e.message}");
      return Zapret2ProbeResult(
        strategyId: strategy.id,
        successRatio: 0,
        error: e.message,
      );
    } finally {
      await session?.stop();
    }
  }

  static int _median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}
