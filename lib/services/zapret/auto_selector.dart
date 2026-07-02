import 'dart:async';
import 'dart:math' as math;

import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/strategy_tester.dart';

/// Live progress of an auto-selection run, surfaced to the UI so a (possibly
/// long) search is transparent: which strategy is being tested and how many
/// remain.
class Zapret2SelectionProgress {
  const Zapret2SelectionProgress({
    required this.round,
    required this.totalStrategies,
    required this.exploredStrategies,
    required this.currentStrategy,
    required this.currentReward,
    required this.bestStrategyId,
    required this.bestMean,
    required this.done,
    required this.accepted,
  });

  final int round;
  final int totalStrategies;
  final int exploredStrategies;
  final Zapret2Strategy? currentStrategy;

  /// Reward of the just-finished probe (null while a probe is in flight).
  final double? currentReward;
  final String? bestStrategyId;
  final double bestMean;
  final bool done;
  final bool accepted;
}

/// Final result of a selection run.
class Zapret2SelectionResult {
  const Zapret2SelectionResult({
    required this.selectedStrategy,
    required this.accepted,
    required this.stats,
  });

  /// Best strategy found. Present even when [accepted] is false (the highest
  /// mean seen), so the caller can decide whether to use it or report failure.
  final Zapret2Strategy? selectedStrategy;

  /// Whether [selectedStrategy] cleared the acceptance threshold.
  final bool accepted;

  /// Per-strategy statistics accumulated across the run (persisted to cache).
  final List<Zapret2Stat> stats;
}

/// Multi-armed bandit (UCB1) strategy selector.
///
/// UCB1 balances exploitation (strategies that worked before) with exploration
/// (strategies tried few times). Each round it computes, per strategy:
///
///   score = mean + sqrt(2 * ln(N) / n_i)
///
/// where `mean` is the average past reward of that strategy, `N` is the total
/// number of probes so far, and `n_i` is the number of probes of that strategy.
/// An unexplored strategy (n_i = 0) has infinite score and is always tried
/// first. The highest-scoring strategy is probed, its stats updated, and — per
/// requirement #2 — the search **stops as soon as a probe's reward clears the
/// acceptance threshold**, without exhausting the candidate list.
///
/// Warm start: prior [Zapret2Stat]s from the cache seed the bandit so a device
/// that has selected before converges immediately on its known-good strategy.
class Zapret2AutoSelector {
  Zapret2AutoSelector({
    required this.tester,
    this.explorationConstant = 2.0,
  });

  final Zapret2StrategyTester tester;

  /// The `c` in `mean + sqrt(c * ln(N) / n_i)`. Classic UCB1 uses 2.
  final double explorationConstant;

  /// Runs the bandit over [strategies] against [targets].
  ///
  /// - [acceptThreshold]: reward (success ratio) required to accept and stop.
  /// - [priorStats]: warm-start statistics (e.g. from a previous cached run).
  /// - [maxRounds]: hard cap on probes; defaults to giving every strategy a few
  ///   chances. Guarantees termination even if nothing clears the threshold.
  /// - [onProgress]: called after each probe for UI updates.
  Future<Zapret2SelectionResult> select({
    required List<Zapret2Strategy> strategies,
    required List<Zapret2Target> targets,
    required double acceptThreshold,
    List<Zapret2Stat> priorStats = const [],
    int? maxRounds,
    String? customEnginePath,
    void Function(Zapret2SelectionProgress progress)? onProgress,
  }) async {
    if (strategies.isEmpty) {
      return const Zapret2SelectionResult(
        selectedStrategy: null,
        accepted: false,
        stats: [],
      );
    }

    // Bandit state keyed by strategy id, seeded from prior stats.
    final stats = <String, Zapret2Stat>{
      for (final s in strategies) s.id: Zapret2Stat(strategyId: s.id),
    };
    for (final prior in priorStats) {
      if (stats.containsKey(prior.strategyId)) {
        stats[prior.strategyId] = prior;
      }
    }

    final rounds = maxRounds ?? strategies.length * 3;
    var totalTrials = stats.values.fold<int>(0, (a, s) => a + s.trials);

    Zapret2Strategy? best;
    // Starts at 0: a strategy must have a positive mean reward to be considered
    // "best". If nothing ever succeeds, [best] stays null (no false winner).
    var bestMean = 0.0;
    var accepted = false;

    for (var round = 0; round < rounds; round++) {
      final pick = _pickByUcb1(strategies, stats, totalTrials);

      onProgress?.call(Zapret2SelectionProgress(
        round: round + 1,
        totalStrategies: strategies.length,
        exploredStrategies: stats.values.where((s) => s.trials > 0).length,
        currentStrategy: pick,
        currentReward: null,
        bestStrategyId: best?.id,
        bestMean: bestMean < 0 ? 0 : bestMean,
        done: false,
        accepted: false,
      ));

      final result = await tester.test(
        strategy: pick,
        targets: targets,
        customEnginePath: customEnginePath,
      );

      stats[pick.id] = stats[pick.id]!.record(
        reward: result.successRatio,
        latencyMs: result.latencyMs,
      );
      totalTrials += 1;

      final mean = stats[pick.id]!.mean;
      if (mean > bestMean ||
          (mean == bestMean &&
              best != null &&
              result.latencyMs > 0 &&
              result.latencyMs < (stats[best.id]?.lastLatencyMs ?? 1 << 30))) {
        bestMean = mean;
        best = pick;
      }

      // Early acceptance: a single probe clearing the threshold is enough — no
      // need to keep exploring the rest of the catalogue (requirement #2).
      if (result.successRatio >= acceptThreshold) {
        best = pick;
        bestMean = mean;
        accepted = true;
        onProgress?.call(Zapret2SelectionProgress(
          round: round + 1,
          totalStrategies: strategies.length,
          exploredStrategies: stats.values.where((s) => s.trials > 0).length,
          currentStrategy: pick,
          currentReward: result.successRatio,
          bestStrategyId: best.id,
          bestMean: bestMean,
          done: true,
          accepted: true,
        ));
        break;
      }

      onProgress?.call(Zapret2SelectionProgress(
        round: round + 1,
        totalStrategies: strategies.length,
        exploredStrategies: stats.values.where((s) => s.trials > 0).length,
        currentStrategy: pick,
        currentReward: result.successRatio,
        bestStrategyId: best?.id,
        bestMean: bestMean < 0 ? 0 : bestMean,
        done: false,
        accepted: false,
      ));
    }

    if (!accepted) {
      onProgress?.call(Zapret2SelectionProgress(
        round: rounds,
        totalStrategies: strategies.length,
        exploredStrategies: stats.values.where((s) => s.trials > 0).length,
        currentStrategy: null,
        currentReward: null,
        bestStrategyId: best?.id,
        bestMean: bestMean < 0 ? 0 : bestMean,
        done: true,
        accepted: false,
      ));
    }

    return Zapret2SelectionResult(
      selectedStrategy: best,
      accepted: accepted,
      stats: strategies.map((s) => stats[s.id]!).toList(),
    );
  }

  /// Returns the UCB1 score for [stat] given [totalTrials]. An unexplored
  /// strategy scores [double.infinity] so it is always tried before any
  /// explored one (the standard UCB1 initialization).
  double ucb1Score(Zapret2Stat stat, int totalTrials) {
    if (stat.trials == 0) return double.infinity;
    final bonus = math.sqrt(
      explorationConstant * math.log(math.max(1, totalTrials)) / stat.trials,
    );
    return stat.mean + bonus;
  }

  Zapret2Strategy _pickByUcb1(
    List<Zapret2Strategy> strategies,
    Map<String, Zapret2Stat> stats,
    int totalTrials,
  ) {
    Zapret2Strategy? best;
    var bestScore = double.negativeInfinity;
    for (final s in strategies) {
      final score = ucb1Score(stats[s.id]!, totalTrials);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best ?? strategies.first;
  }
}
