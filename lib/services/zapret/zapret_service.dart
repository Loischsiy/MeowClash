import 'dart:async';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/auto_selector.dart';
import 'package:meowclash/services/zapret/backend.dart';
import 'package:meowclash/services/zapret/backend_factory.dart';
import 'package:meowclash/services/zapret/strategy_cache.dart';
import 'package:meowclash/services/zapret/strategy_provider.dart';
import 'package:meowclash/services/zapret/strategy_tester.dart';
import 'package:meowclash/services/zapret/zapret_logger.dart';
import 'package:meowclash/zapret_version.dart';
import 'package:path/path.dart';

/// High-level lifecycle state of the zapret2 mode, surfaced to the UI.
enum Zapret2RunState { off, selecting, running, unavailable, failed }

class Zapret2Status {
  const Zapret2Status({
    required this.runState,
    this.activeStrategy,
    this.progress,
    this.unavailableReason,
    this.message,
  });

  const Zapret2Status.off() : this(runState: Zapret2RunState.off);

  final Zapret2RunState runState;
  final Zapret2Strategy? activeStrategy;
  final Zapret2SelectionProgress? progress;
  final Zapret2UnavailableReason? unavailableReason;
  final String? message;
}

/// Orchestrates the additive, independent zapret2 mode: availability probing,
/// cache reuse, UCB1 auto-selection, engine start/stop and a dedicated log.
///
/// "Independent mode" (per the answered design question): this service owns its
/// own start/stop and is NOT coupled to clash's handleStart/handleStop. The app
/// only asks it to tear down on exit and to restore on launch if it was on.
class Zapret2Service {
  Zapret2Service({
    Zapret2Backend? backend,
    Zapret2StrategyProvider? strategyProvider,
    Zapret2StrategyCache? cache,
    Zapret2StrategyTester? tester,
    Zapret2AutoSelector? selector,
    String engineVersion = kZapret2VersionFromSource,
  })  : _backend = backend ?? createZapret2Backend(),
        _strategyProvider =
            strategyProvider ?? const DefaultZapret2StrategyProvider(),
        _engineVersion = engineVersion {
    _cache = cache ??
        Zapret2StrategyCache(FileZapret2CacheStore(() async {
          final home = await appPath.homeDirPath;
          return join(home, "zapret2");
        }));
    _tester = tester ?? Zapret2StrategyTester(backend: _backend);
    _selector = selector ?? Zapret2AutoSelector(tester: _tester);
  }

  final Zapret2Backend _backend;
  final Zapret2StrategyProvider _strategyProvider;
  final String _engineVersion;
  late final Zapret2StrategyCache _cache;
  late final Zapret2StrategyTester _tester;
  late final Zapret2AutoSelector _selector;

  Zapret2Session? _session;
  var _status = const Zapret2Status.off();

  /// Broadcasts status changes so a Riverpod provider can mirror them into UI.
  final _statusController = StreamController<Zapret2Status>.broadcast();
  Stream<Zapret2Status> get statusStream => _statusController.stream;
  Zapret2Status get status => _status;

  bool get isRunning => _status.runState == Zapret2RunState.running;

  SupportPlatform get platform => _backend.platform;

  void _emit(Zapret2Status status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<Zapret2Availability> checkAvailability() =>
      _backend.checkAvailability();

  /// Enables the mode: reuse a valid cache if present, otherwise run the UCB1
  /// auto-selection, then start the engine with the chosen strategy. All error
  /// paths set an explicit [Zapret2RunState] with a reason — never silent.
  Future<Zapret2Status> enable({
    required Zapret2Props props,
    bool forceRescan = false,
    void Function(Zapret2SelectionProgress)? onProgress,
  }) async {
    await zapretLogger.log(
      "enable (platform=${platform.name}, engine=$_engineVersion, "
      "forceRescan=$forceRescan)",
    );

    final availability = await _backend.checkAvailability();
    if (!availability.isAvailable) {
      await zapretLogger.log(
        "unavailable: ${availability.reason} ${availability.detail ?? ''}",
      );
      final status = Zapret2Status(
        runState: Zapret2RunState.unavailable,
        unavailableReason: availability.reason,
        message: availability.detail,
      );
      _emit(status);
      return status;
    }

    final targets = props.targets;
    final strategies = _strategyProvider.forPlatform(platform);

    // 1) Cache fast-path (unless the user forced a rescan).
    if (!forceRescan) {
      final cached = await _cache.loadValid(
        engineVersion: _engineVersion,
        platform: platform,
        targets: targets,
      );
      final cachedStrategy = cached?.selectedStrategy;
      if (cachedStrategy != null) {
        await zapretLogger.log("using cached strategy ${cachedStrategy.id}");
        return _startWith(cachedStrategy, targets, props.customEnginePath);
      }
    }

    // 2) Auto-select via UCB1.
    _emit(const Zapret2Status(runState: Zapret2RunState.selecting));
    final result = await _selector.select(
      strategies: strategies,
      targets: targets,
      acceptThreshold: props.acceptThreshold,
      priorStats: (await _cache.load())?.stats ?? const [],
      customEnginePath:
          props.customEnginePath.isEmpty ? null : props.customEnginePath,
      onProgress: (p) {
        _emit(Zapret2Status(
          runState: Zapret2RunState.selecting,
          progress: p,
          activeStrategy: p.currentStrategy,
        ));
        onProgress?.call(p);
      },
    );

    // Persist accumulated stats regardless of acceptance so future runs learn.
    await _cache.save(Zapret2Cache(
      engineVersion: _engineVersion,
      platform: platform,
      selectedStrategy: result.accepted ? result.selectedStrategy : null,
      targets: targets,
      testedAt: DateTime.now(),
      stats: result.stats,
    ));

    final selected = result.selectedStrategy;
    if (!result.accepted || selected == null) {
      await zapretLogger.log("no strategy cleared threshold");
      const status = Zapret2Status(
        runState: Zapret2RunState.failed,
        message: "no working strategy found",
      );
      _emit(status);
      return status;
    }

    return _startWith(selected, targets, props.customEnginePath);
  }

  Future<Zapret2Status> _startWith(
    Zapret2Strategy strategy,
    List<Zapret2Target> targets,
    String customEnginePath,
  ) async {
    try {
      await _session?.stop();
      _session = await _backend.start(
        strategy: strategy,
        targets: targets,
        customEnginePath: customEnginePath.isEmpty ? null : customEnginePath,
      );
      await zapretLogger.log("engine running with ${strategy.id}");
      final status = Zapret2Status(
        runState: Zapret2RunState.running,
        activeStrategy: strategy,
      );
      _emit(status);
      return status;
    } on Zapret2BackendException catch (e) {
      await zapretLogger.log("start failed: ${e.message}");
      final status = Zapret2Status(
        runState: Zapret2RunState.failed,
        unavailableReason: e.reason,
        message: e.message,
      );
      _emit(status);
      return status;
    }
  }

  /// Disables the mode and tears the engine down. Idempotent.
  Future<void> disable() async {
    await zapretLogger.log("disable");
    await _session?.stop();
    _session = null;
    _emit(const Zapret2Status.off());
  }

  /// "Перепроверить/сбросить": drop the cache and re-run selection from scratch.
  Future<Zapret2Status> rescan({
    required Zapret2Props props,
    void Function(Zapret2SelectionProgress)? onProgress,
  }) async {
    await _cache.invalidate();
    return enable(props: props, forceRescan: true, onProgress: onProgress);
  }

  Future<void> dispose() async {
    await disable();
    await _statusController.close();
    await zapretLogger.dispose();
  }
}
