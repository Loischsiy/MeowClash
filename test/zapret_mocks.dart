import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/zapret.dart';

/// A scriptable backend used across the zapret2 tests. It never touches the
/// network or a real process: [start] hands back a no-op session, and the
/// tester's probing is driven by an injected prober (see [scriptedTester]).
/// [platform] is configurable so tests can exercise every SupportPlatform.
class MockZapret2Backend extends Zapret2Backend {
  MockZapret2Backend({
    required this.platform,
    this.availability = const Zapret2Availability.available(),
    this.startError,
  });

  @override
  final SupportPlatform platform;

  Zapret2Availability availability;

  /// If set, [start] throws this instead of returning a session.
  Zapret2BackendException? startError;

  int startCount = 0;
  final List<String> startedStrategyIds = [];

  @override
  Future<Zapret2Availability> checkAvailability() async => availability;

  @override
  Future<Zapret2Session> start({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  }) async {
    startCount++;
    startedStrategyIds.add(strategy.id);
    final error = startError;
    if (error != null) throw error;
    return _MockSession(strategy);
  }
}

class _MockSession implements Zapret2Session {
  _MockSession(this.strategy);

  @override
  final Zapret2Strategy strategy;

  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

/// Builds a [Zapret2StrategyTester] whose probing is fully deterministic: the
/// [rewards] map gives the success ratio each strategy returns, and every probe
/// is recorded in [probeOrder] so tests can assert exploration order and count.
class ScriptedTester extends Zapret2StrategyTester {
  ScriptedTester({
    required MockZapret2Backend backend,
    required this.rewards,
    this.latencies = const {},
  }) : super(backend: backend, settleDelay: Duration.zero);

  /// strategyId -> success ratio in [0,1].
  final Map<String, double> rewards;
  final Map<String, int> latencies;
  final List<String> probeOrder = [];

  @override
  Future<Zapret2ProbeResult> test({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  }) async {
    probeOrder.add(strategy.id);
    return Zapret2ProbeResult(
      strategyId: strategy.id,
      successRatio: rewards[strategy.id] ?? 0,
      latencyMs: latencies[strategy.id] ?? 0,
    );
  }
}

/// Simple in-memory cache store for cache tests (no filesystem).
class MemoryCacheStore implements Zapret2CacheStore {
  String? contents;

  @override
  Future<void> delete() async {
    contents = null;
  }

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String data) async {
    contents = data;
  }
}

const testStrategies = [
  Zapret2Strategy(id: "s1", label: "S1"),
  Zapret2Strategy(id: "s2", label: "S2"),
  Zapret2Strategy(id: "s3", label: "S3"),
];

const testTargets = [
  Zapret2Target(host: "discord.com"),
  Zapret2Target(host: "www.youtube.com"),
];
