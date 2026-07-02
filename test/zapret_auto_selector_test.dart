import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/services/zapret/zapret.dart';

import 'zapret_mocks.dart';

/// Unit tests for the UCB1 multi-armed-bandit strategy selector
/// ([Zapret2AutoSelector]). These exercise the core algorithmic guarantees:
/// unexplored-first ordering, warm-start ordering from cached stats, early
/// acceptance on the first strategy clearing the threshold, threshold rejection,
/// and termination when nothing works.
void main() {
  Zapret2AutoSelector selectorFor(ScriptedTester tester) =>
      Zapret2AutoSelector(tester: tester);

  group('UCB1 score', () {
    test('an unexplored strategy scores infinity (always tried first)', () {
      final selector = Zapret2AutoSelector(
        tester: ScriptedTester(
          backend: MockZapret2Backend(platform: SupportPlatform.Linux),
          rewards: const {},
        ),
      );
      const unexplored = Zapret2Stat(strategyId: 's1');
      expect(selector.ucb1Score(unexplored, 10), double.infinity);
    });

    test('explored score = mean + exploration bonus', () {
      final selector = Zapret2AutoSelector(
        tester: ScriptedTester(
          backend: MockZapret2Backend(platform: SupportPlatform.Linux),
          rewards: const {},
        ),
      );
      // 2 trials, reward sum 1.0 -> mean 0.5; bonus = sqrt(2*ln(10)/2).
      const stat = Zapret2Stat(strategyId: 's1', trials: 2, rewardSum: 1.0);
      final score = selector.ucb1Score(stat, 10);
      expect(score, greaterThan(0.5));
      expect(score, lessThan(2.5));
    });
  });

  group('select()', () {
    test('tries every unexplored strategy before repeating any', () async {
      // Nothing succeeds -> selector must keep exploring; the first N picks
      // must be all N distinct strategies (unexplored -> infinite score).
      final tester = ScriptedTester(
        backend: MockZapret2Backend(platform: SupportPlatform.Linux),
        rewards: const {'s1': 0, 's2': 0, 's3': 0},
      );
      final result = await selectorFor(tester).select(
        strategies: testStrategies,
        targets: testTargets,
        acceptThreshold: 0.6,
      );
      expect(tester.probeOrder.take(3).toSet(), {'s1', 's2', 's3'});
      expect(result.accepted, isFalse);
      expect(result.selectedStrategy, isNull); // best mean is 0 -> no winner
    });

    test('stops early on the first strategy clearing the threshold', () async {
      // s1 fails, s2 passes; selection must accept s2 and stop before s3.
      final tester = ScriptedTester(
        backend: MockZapret2Backend(platform: SupportPlatform.Linux),
        rewards: const {'s1': 0.0, 's2': 1.0, 's3': 1.0},
      );
      final result = await selectorFor(tester).select(
        strategies: testStrategies,
        targets: testTargets,
        acceptThreshold: 0.6,
      );
      expect(result.accepted, isTrue);
      expect(result.selectedStrategy?.id, 's2');
      // s3 must never have been probed (early stop, no full sweep).
      expect(tester.probeOrder, isNot(contains('s3')));
      expect(tester.probeOrder, ['s1', 's2']);
    });

    test('warm start from prior stats tries the known-good strategy first',
        () async {
      // Prior cache says s3 was great and s1/s2 were tried and failed. With all
      // arms already explored, UCB1 exploits the highest mean -> s3 first.
      final tester = ScriptedTester(
        backend: MockZapret2Backend(platform: SupportPlatform.Windows),
        rewards: const {'s1': 0.0, 's2': 0.0, 's3': 1.0},
      );
      final result = await selectorFor(tester).select(
        strategies: testStrategies,
        targets: testTargets,
        acceptThreshold: 0.6,
        priorStats: const [
          Zapret2Stat(strategyId: 's1', trials: 3, rewardSum: 0.0),
          Zapret2Stat(strategyId: 's2', trials: 3, rewardSum: 0.0),
          Zapret2Stat(strategyId: 's3', trials: 3, rewardSum: 3.0),
        ],
      );
      expect(tester.probeOrder.first, 's3');
      expect(result.accepted, isTrue);
      expect(result.selectedStrategy?.id, 's3');
      expect(tester.probeOrder, ['s3']); // one probe, thanks to the warm start
    });

    test('partial success below threshold is not accepted', () async {
      // Every strategy only clears half the targets (0.5) < threshold 0.6.
      final tester = ScriptedTester(
        backend: MockZapret2Backend(platform: SupportPlatform.MacOS),
        rewards: const {'s1': 0.5, 's2': 0.5, 's3': 0.5},
      );
      final result = await selectorFor(tester).select(
        strategies: testStrategies,
        targets: testTargets,
        acceptThreshold: 0.6,
      );
      expect(result.accepted, isFalse);
      // Best-effort strategy is still surfaced (highest mean > 0).
      expect(result.selectedStrategy, isNotNull);
      expect(result.stats.every((s) => s.trials > 0), isTrue);
    });

    test('lower threshold accepts a partial success', () async {
      final tester = ScriptedTester(
        backend: MockZapret2Backend(platform: SupportPlatform.Android),
        rewards: const {'s1': 0.5, 's2': 1.0, 's3': 0.0},
      );
      final result = await selectorFor(tester).select(
        strategies: testStrategies,
        targets: testTargets,
        acceptThreshold: 0.5,
      );
      expect(result.accepted, isTrue);
      // s1 is explored first (unexplored, infinite score) and already clears
      // the 0.5 bar, so it wins immediately.
      expect(result.selectedStrategy?.id, 's1');
    });

    test('emits progress and terminates within maxRounds when nothing works',
        () async {
      final tester = ScriptedTester(
        backend: MockZapret2Backend(platform: SupportPlatform.Linux),
        rewards: const {'s1': 0, 's2': 0, 's3': 0},
      );
      var lastDone = false;
      final progressEvents = <Zapret2SelectionProgress>[];
      final result = await selectorFor(tester).select(
        strategies: testStrategies,
        targets: testTargets,
        acceptThreshold: 0.6,
        maxRounds: 4,
        onProgress: (p) {
          progressEvents.add(p);
          lastDone = p.done;
        },
      );
      // Hard cap honoured: exactly maxRounds probes, then a terminal event.
      expect(tester.probeOrder.length, 4);
      expect(lastDone, isTrue);
      expect(result.accepted, isFalse);
      expect(progressEvents, isNotEmpty);
    });

    test('empty strategy list yields no selection', () async {
      final tester = ScriptedTester(
        backend: MockZapret2Backend(platform: SupportPlatform.Linux),
        rewards: const {},
      );
      final result = await selectorFor(tester).select(
        strategies: const [],
        targets: testTargets,
        acceptThreshold: 0.6,
      );
      expect(result.selectedStrategy, isNull);
      expect(result.accepted, isFalse);
    });
  });
}
