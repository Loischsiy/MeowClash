// ignore_for_file: invalid_annotation_target

import 'package:meowclash/enum/enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/zapret.freezed.dart';
part 'generated/zapret.g.dart';

/// A single DPI-bypass strategy candidate. `args` are the raw engine flags
/// passed to the platform backend (winws / nfqws). They are intentionally
/// opaque here so the same model carries any future zapret2 desync profile
/// without a schema change; the backend is what interprets them.
@freezed
class Zapret2Strategy with _$Zapret2Strategy {
  const factory Zapret2Strategy({
    /// Stable identifier used as the cache/statistics key. Must be unique
    /// within a [Zapret2StrategyProvider] list.
    required String id,
    /// Human-readable label shown in the progress UI.
    required String label,
    /// Engine arguments realizing this strategy (e.g. --dpi-desync=fake,split2).
    @Default([]) List<String> args,
    /// Platforms this strategy is known to run on. Empty = all platforms.
    @Default([]) List<SupportPlatform> platforms,
  }) = _Zapret2Strategy;

  factory Zapret2Strategy.fromJson(Map<String, Object?> json) =>
      _$Zapret2StrategyFromJson(json);
}

extension Zapret2StrategyExt on Zapret2Strategy {
  bool supports(SupportPlatform platform) =>
      platforms.isEmpty || platforms.contains(platform);
}

/// A blockcheck target: a host to probe, optionally pinned to an IP and port.
@freezed
class Zapret2Target with _$Zapret2Target {
  const factory Zapret2Target({
    required String host,
    String? ip,
    @Default(443) int port,
  }) = _Zapret2Target;

  factory Zapret2Target.fromJson(Map<String, Object?> json) =>
      _$Zapret2TargetFromJson(json);
}

/// Running UCB1 statistics for one strategy. Persisted in the cache so past
/// tests inform future selection (the "arm memory" of the bandit).
@freezed
class Zapret2Stat with _$Zapret2Stat {
  const factory Zapret2Stat({
    required String strategyId,
    /// Number of times this strategy has been probed.
    @Default(0) int trials,
    /// Sum of per-probe reward in [0,1] (success ratio across targets). Mean
    /// reward is [rewardSum] / [trials].
    @Default(0) double rewardSum,
    /// Average latency in ms of the last successful probe, for tie-breaking.
    @Default(0) int lastLatencyMs,
  }) = _Zapret2Stat;

  factory Zapret2Stat.fromJson(Map<String, Object?> json) =>
      _$Zapret2StatFromJson(json);
}

extension Zapret2StatExt on Zapret2Stat {
  double get mean => trials == 0 ? 0 : rewardSum / trials;

  Zapret2Stat record({required double reward, int? latencyMs}) => copyWith(
        trials: trials + 1,
        rewardSum: rewardSum + reward,
        lastLatencyMs: latencyMs ?? lastLatencyMs,
      );
}

/// Result of probing a single strategy against the target list.
@freezed
class Zapret2ProbeResult with _$Zapret2ProbeResult {
  const factory Zapret2ProbeResult({
    required String strategyId,
    /// Fraction of targets that passed, in [0,1]. Used as the UCB1 reward.
    required double successRatio,
    /// Median latency in ms across the successful targets (0 if none).
    @Default(0) int latencyMs,
    /// Non-fatal diagnostic (e.g. "engine failed to start"), for the log file.
    String? error,
  }) = _Zapret2ProbeResult;

  factory Zapret2ProbeResult.fromJson(Map<String, Object?> json) =>
      _$Zapret2ProbeResultFromJson(json);
}

/// On-disk cache of the selected strategy plus the bandit's accumulated stats.
///
/// Format (per the task spec):
/// `{ engineVersion, platform, selectedStrategy, targets, testedAt, stats }`.
/// The cache is invalidated when [engineVersion], [platform] or the [targets]
/// set no longer match the current run (see [Zapret2CacheExt.isValidFor]).
@freezed
class Zapret2Cache with _$Zapret2Cache {
  const factory Zapret2Cache({
    /// zapret2 engine version this result was produced with (single source of
    /// truth: lib/zapret_version.dart -> zapret/version.go).
    required String engineVersion,
    /// Platform the selection was made on. A cache is not portable across
    /// platforms because backends and strategies differ.
    required SupportPlatform platform,
    /// The winning strategy, or null if selection has not succeeded yet.
    Zapret2Strategy? selectedStrategy,
    /// Targets the selection was validated against.
    @Default([]) List<Zapret2Target> targets,
    /// When the selection completed.
    required DateTime testedAt,
    /// Per-strategy UCB1 statistics accumulated so far.
    @Default([]) List<Zapret2Stat> stats,
  }) = _Zapret2Cache;

  factory Zapret2Cache.fromJson(Map<String, Object?> json) =>
      _$Zapret2CacheFromJson(json);
}

extension Zapret2CacheExt on Zapret2Cache {
  /// A cache is reusable only if it was produced by the same engine version,
  /// on the same platform, and validated against the same set of targets
  /// (order-insensitive). Any mismatch forces a fresh auto-selection.
  bool isValidFor({
    required String engineVersion,
    required SupportPlatform platform,
    required List<Zapret2Target> targets,
  }) {
    if (this.engineVersion != engineVersion) return false;
    if (this.platform != platform) return false;
    if (selectedStrategy == null) return false;
    final a = this.targets.map((t) => "${t.host}:${t.port}").toSet();
    final b = targets.map((t) => "${t.host}:${t.port}").toSet();
    return a.length == b.length && a.containsAll(b);
  }

  Zapret2Stat? statFor(String strategyId) {
    for (final s in stats) {
      if (s.strategyId == strategyId) return s;
    }
    return null;
  }
}
