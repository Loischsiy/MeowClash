import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/zapret.dart';

import 'zapret_mocks.dart';

/// Unit tests for the strategy cache: JSON round-trip, the version/platform/
/// target invalidation rules ([Zapret2CacheExt.isValidFor]) exercised for every
/// SupportPlatform, and the [Zapret2StrategyCache] load/save/invalidate flow on
/// an in-memory store (including corrupt-input resilience).
void main() {
  // The service logs through the global ZapretLogger, which by default resolves
  // its directory via appPath (path_provider) — unavailable under flutter_test.
  // Point it at a temp dir so logging never touches the plugin.
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('zapret2_test_log');
    zapretLogger.directoryResolver = () async => dir.path;
  });

  Zapret2Cache sampleCache({
    String engineVersion = 'v1.0.2',
    SupportPlatform platform = SupportPlatform.Linux,
    List<Zapret2Target> targets = testTargets,
  }) =>
      Zapret2Cache(
        engineVersion: engineVersion,
        platform: platform,
        selectedStrategy: const Zapret2Strategy(
          id: 'fake_split2',
          label: 'Fake + split2',
          args: ['--dpi-desync=fake,split2'],
        ),
        targets: targets,
        testedAt: DateTime.utc(2026, 1, 1),
        stats: const [
          Zapret2Stat(strategyId: 'fake_split2', trials: 2, rewardSum: 2.0),
          Zapret2Stat(strategyId: 's2', trials: 1, rewardSum: 0.0),
        ],
      );

  group('Zapret2Cache JSON', () {
    test('round-trip preserves all fields (spec format)', () {
      final cache = sampleCache();
      final json = cache.toJson();
      // The persisted shape matches the required
      // { engineVersion, platform, selectedStrategy, targets, testedAt, stats }.
      expect(json.keys, containsAll(<String>[
        'engineVersion',
        'platform',
        'selectedStrategy',
        'targets',
        'testedAt',
        'stats',
      ]));
      final restored = Zapret2Cache.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(restored.engineVersion, cache.engineVersion);
      expect(restored.platform, cache.platform);
      expect(restored.selectedStrategy?.id, 'fake_split2');
      expect(restored.selectedStrategy?.args, ['--dpi-desync=fake,split2']);
      expect(restored.targets.length, 2);
      expect(restored.testedAt, cache.testedAt);
      expect(restored.stats.first.trials, 2);
    });

    test('statFor finds a strategy stat', () {
      final cache = sampleCache();
      expect(cache.statFor('fake_split2')?.mean, 1.0);
      expect(cache.statFor('unknown'), isNull);
    });
  });

  group('isValidFor invalidation', () {
    test('valid when version, platform and targets all match', () {
      for (final platform in SupportPlatform.values) {
        final cache = sampleCache(platform: platform);
        expect(
          cache.isValidFor(
            engineVersion: 'v1.0.2',
            platform: platform,
            targets: testTargets,
          ),
          isTrue,
          reason: 'should be valid on ${platform.name}',
        );
      }
    });

    test('stale when engine version differs', () {
      final cache = sampleCache(engineVersion: 'v1.0.1');
      expect(
        cache.isValidFor(
          engineVersion: 'v1.0.2',
          platform: SupportPlatform.Linux,
          targets: testTargets,
        ),
        isFalse,
      );
    });

    test('stale when platform differs (not portable across platforms)', () {
      final cache = sampleCache(platform: SupportPlatform.Windows);
      expect(
        cache.isValidFor(
          engineVersion: 'v1.0.2',
          platform: SupportPlatform.Linux,
          targets: testTargets,
        ),
        isFalse,
      );
    });

    test('stale when the target set differs', () {
      final cache = sampleCache();
      expect(
        cache.isValidFor(
          engineVersion: 'v1.0.2',
          platform: SupportPlatform.Linux,
          targets: const [Zapret2Target(host: 'example.com')],
        ),
        isFalse,
      );
    });

    test('target comparison is order-insensitive', () {
      final cache = sampleCache();
      expect(
        cache.isValidFor(
          engineVersion: 'v1.0.2',
          platform: SupportPlatform.Linux,
          targets: const [
            Zapret2Target(host: 'www.youtube.com'),
            Zapret2Target(host: 'discord.com'),
          ],
        ),
        isTrue,
      );
    });

    test('invalid when no strategy was selected', () {
      final cache = sampleCache().copyWith(selectedStrategy: null);
      expect(
        cache.isValidFor(
          engineVersion: 'v1.0.2',
          platform: SupportPlatform.Linux,
          targets: testTargets,
        ),
        isFalse,
      );
    });
  });

  group('Zapret2StrategyCache store', () {
    test('save then load round-trips', () async {
      final store = MemoryCacheStore();
      final cache = Zapret2StrategyCache(store);
      await cache.save(sampleCache());
      final loaded = await cache.load();
      expect(loaded, isNotNull);
      expect(loaded!.selectedStrategy?.id, 'fake_split2');
    });

    test('load returns null when absent', () async {
      final cache = Zapret2StrategyCache(MemoryCacheStore());
      expect(await cache.load(), isNull);
    });

    test('load returns null on corrupt JSON (never throws)', () async {
      final store = MemoryCacheStore()..contents = '{not valid json';
      final cache = Zapret2StrategyCache(store);
      expect(await cache.load(), isNull);
    });

    test('loadValid gates on version/platform/targets', () async {
      final store = MemoryCacheStore();
      final cache = Zapret2StrategyCache(store);
      await cache.save(sampleCache(platform: SupportPlatform.MacOS));

      // Wrong platform -> treated as no cache.
      expect(
        await cache.loadValid(
          engineVersion: 'v1.0.2',
          platform: SupportPlatform.Linux,
          targets: testTargets,
        ),
        isNull,
      );
      // Correct everything -> returned.
      final valid = await cache.loadValid(
        engineVersion: 'v1.0.2',
        platform: SupportPlatform.MacOS,
        targets: testTargets,
      );
      expect(valid, isNotNull);
    });

    test('invalidate clears the stored cache', () async {
      final store = MemoryCacheStore();
      final cache = Zapret2StrategyCache(store);
      await cache.save(sampleCache());
      await cache.invalidate();
      expect(store.contents, isNull);
      expect(await cache.load(), isNull);
    });
  });

  group('Zapret2Service with mock backend (per platform)', () {
    test('reports unavailable with the backend reason', () async {
      for (final platform in SupportPlatform.values) {
        final backend = MockZapret2Backend(
          platform: platform,
          availability: const Zapret2Availability.unavailable(
            Zapret2UnavailableReason.missingBinary,
          ),
        );
        final service = Zapret2Service(
          backend: backend,
          cache: Zapret2StrategyCache(MemoryCacheStore()),
          tester: ScriptedTester(backend: backend, rewards: const {}),
        );
        final status = await service.enable(props: const Zapret2Props());
        expect(status.runState, Zapret2RunState.unavailable);
        expect(status.unavailableReason, Zapret2UnavailableReason.missingBinary);
        expect(backend.startCount, 0, reason: 'must not start when unavailable');
        await service.dispose();
      }
    });

    test('auto-selects, caches, and starts the winning strategy', () async {
      final backend = MockZapret2Backend(platform: SupportPlatform.Linux);
      final store = MemoryCacheStore();
      final service = Zapret2Service(
        backend: backend,
        strategyProvider: const _FixedStrategyProvider(),
        cache: Zapret2StrategyCache(store),
        tester: ScriptedTester(
          backend: backend,
          rewards: const {'s1': 0.0, 's2': 1.0},
        ),
      );
      final status = await service.enable(props: const Zapret2Props());
      expect(status.runState, Zapret2RunState.running);
      expect(status.activeStrategy?.id, 's2');
      expect(backend.startCount, 1);
      // Cache now holds the accepted strategy for reuse.
      final cached = await Zapret2StrategyCache(store).load();
      expect(cached?.selectedStrategy?.id, 's2');
      await service.dispose();
    });

    test('reuses a valid cache without re-running selection', () async {
      final backend = MockZapret2Backend(platform: SupportPlatform.Windows);
      final store = MemoryCacheStore();
      // Pre-seed a valid cache for the default targets.
      await Zapret2StrategyCache(store).save(Zapret2Cache(
        engineVersion: 'v1.0.2',
        platform: SupportPlatform.Windows,
        selectedStrategy: const Zapret2Strategy(id: 's2', label: 'S2'),
        targets: defaultZapret2Targets,
        testedAt: DateTime.utc(2026, 1, 1),
      ));
      final tester = ScriptedTester(backend: backend, rewards: const {});
      final service = Zapret2Service(
        backend: backend,
        cache: Zapret2StrategyCache(store),
        tester: tester,
        engineVersion: 'v1.0.2',
      );
      final status = await service.enable(props: const Zapret2Props());
      expect(status.runState, Zapret2RunState.running);
      expect(status.activeStrategy?.id, 's2');
      // Selection was skipped entirely — no probing happened.
      expect(tester.probeOrder, isEmpty);
      await service.dispose();
    });
  });
}

/// Strategy provider returning a fixed two-strategy list for the service test.
class _FixedStrategyProvider extends Zapret2StrategyProvider {
  const _FixedStrategyProvider();

  @override
  List<Zapret2Strategy> all() => const [
        Zapret2Strategy(id: 's1', label: 'S1'),
        Zapret2Strategy(id: 's2', label: 'S2'),
      ];
}
