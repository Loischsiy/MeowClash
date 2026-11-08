import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meowclash/common/core_input_guard.dart';

import 'async_polling_loop.dart';
import 'provider_refresh_plan.dart';

typedef ProviderPayloadFetcher = Future<Uint8List> Function(
  ProviderRefreshPlan plan,
  ProviderRefreshTarget target,
  CancelToken cancellation,
);

Future<Uint8List> _readCacheFile(String path) => File(path).readAsBytes();

/// Owns every background and manual provider refresh of one isolate (the
/// Android service engine, or the desktop main isolate). The core only rereads
/// cache files, so a refresh works with the core stopped: it downloads,
/// decrypts and writes the cache, and additionally side-loads the bytes into a
/// running core. Automatic and manual refreshes share this single owner.
class ProviderRefreshService {
  ProviderRefreshService({
    required this.invokeCore,
    required this.isRunning,
    required this.fetch,
    required this.modifiedAt,
    required this.persist,
    required this.log,
    Future<Uint8List> Function(String path)? read,
    DateTime Function()? now,
  })  : read = read ?? _readCacheFile,
        _now = now ?? DateTime.now {
    _loop = AsyncPollingLoop(
      interval: const Duration(minutes: 1),
      onTick: (_) => _tick(),
      onError: (error, _) =>
          log('Provider refresh check failed (${error.runtimeType})'),
    );
  }

  final Future<String> Function(String action) invokeCore;
  final bool Function() isRunning;
  final ProviderPayloadFetcher fetch;
  final Future<DateTime> Function(String path) modifiedAt;
  final Future<void> Function(String path, Uint8List bytes) persist;
  final void Function(String message) log;
  final Future<Uint8List> Function(String path) read;
  final DateTime Function() _now;
  late final AsyncPollingLoop _loop;
  ProviderRefreshPlan? _plan;
  int _generation = 0;
  int _configuration = 0;
  int _requestId = 0;
  bool _disposed = false;
  Future<void> _mutations = Future<void>.value();
  final _inFlight = <String, Future<String>>{};
  final _cancellations = <CancelToken>{};
  final _updatedAt = <String, DateTime>{};

  /// Targets whose cache was rewritten while the core was stopped. A core that
  /// keeps its loaded config across a stop/start must reread them on start.
  final _pendingReload = <String, ProviderRefreshTarget>{};

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final preceding = _mutations;
    final completed = Completer<void>();
    _mutations = completed.future;
    return () async {
      await preceding;
      try {
        return await operation();
      } finally {
        completed.complete();
      }
    }();
  }

  void suspend() {
    _generation++;
    _loop.stop();
    for (final cancellation in _cancellations.toList()) {
      cancellation.cancel('Provider context changed');
    }
    _inFlight.clear();
  }

  void resume() {
    if (!_disposed && _plan?.hasAutomaticUpdates == true) {
      unawaited(_loop.start());
    }
  }

  void dispose() {
    suspend();
    _disposed = true;
    _plan = null;
    _updatedAt.clear();
    _pendingReload.clear();
    _loop.dispose();
  }

  /// Also used by cold starts from the Android quick-settings tile.
  Future<T> configure<T>(
    ProviderRefreshPlan? plan,
    Future<T> Function() apply, {
    required bool Function(T result) succeeded,
  }) {
    suspend();
    _plan = null;
    _updatedAt.clear();
    _pendingReload.clear();
    final generation = _generation;
    final configuration = ++_configuration;
    return _exclusive(() async {
      final result = await apply();
      if (_disposed || configuration != _configuration || !succeeded(result)) {
        return result;
      }
      // Snapshot all initial cache times before accepting manual/automatic
      // refreshes. Providers may share a path but have different deadlines;
      // another provider's later cache write must never postpone this one.
      final loadedAt = <String, DateTime>{};
      if (plan != null && plan.managed) {
        for (final target in plan.targets) {
          try {
            loadedAt[target.key] = (await modifiedAt(target.path)).toUtc();
          } catch (error) {
            loadedAt[target.key] =
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
            log('Provider ${target.type}/${target.name} cache check failed (${error.runtimeType})');
          }
          if (_disposed || configuration != _configuration) return result;
        }
      }
      if (!_disposed && configuration == _configuration) {
        _plan = plan;
        _updatedAt.addAll(loadedAt);
        // A newer setup, shutdown or disposal invalidates the plan; a plain
        // stop does not, because refreshes also run while the core is stopped.
        if (generation == _generation) resume();
      }
      return result;
    });
  }

  Future<String> handleAction(String message) async {
    final action = Map<String, dynamic>.from(json.decode(message) as Map);
    final method = action['method'];
    if (method == 'setupConfig') {
      final params = Map<String, dynamic>.from(
          json.decode(action['data'] as String) as Map);
      final metadata = params.remove(providerRefreshMetadataKey);
      final plan = metadata is Map
          ? ProviderRefreshPlan.fromJson(Map<String, dynamic>.from(metadata))
          : null;
      final config = Map<String, dynamic>.from(params['config'] as Map);
      params['config'] = config;
      action['data'] = json.encode(params);
      return configure(
        plan,
        () => invokeCore(json.encode(action)),
        succeeded: _setupSucceeded,
      );
    }
    if (method == 'stopListener') {
      // Providers keep refreshing with the core stopped; the commit step
      // checks isRunning() again, so an in-flight refresh just writes the cache.
      return _exclusive(() => invokeCore(message));
    }
    if (method == 'shutdown') {
      suspend();
      _configuration++;
      _plan = null;
      _updatedAt.clear();
      _pendingReload.clear();
      return _exclusive(() => invokeCore(message));
    }
    if (method == 'startListener') {
      final generation = _generation;
      final response = await _exclusive(() => invokeCore(message));
      final result = json.decode(response) as Map;
      if (generation == _generation &&
          result['code'] == 0 &&
          result['data'] == true) {
        resume();
        final plan = _plan;
        if (plan != null) unawaited(_reloadPending(plan, generation));
      }
      return response;
    }
    if (method == 'updateExternalProvider') {
      final name = action['data'];
      final result = name is String ? await refreshByName(name) : null;
      if (result != null) {
        return json.encode({
          'id': action['id'],
          'method': method,
          'code': 0,
          'data': result
        });
      }
      return _exclusive(() => invokeCore(message));
    }
    if (method == 'sideLoadExternalProvider') {
      return _exclusive(() => invokeCore(message));
    }
    return invokeCore(message);
  }

  /// Manual refresh by provider name; null when no managed target has it (the
  /// caller then falls back to the core). Waits for a pending setup first.
  Future<String?> refreshByName(String name) async {
    await _mutations;
    final plan = _plan;
    if (plan == null || !plan.managed) return null;
    final matches = plan.targets.where((target) => target.name == name).toList();
    if (matches.isEmpty) return null;
    if (matches.length > 1) {
      return 'Provider name is ambiguous between proxy and rule providers';
    }
    return refresh(matches.single);
  }

  /// For owners that start the core without routing through [handleAction]
  /// (desktop): resumes ticking and reloads caches written while it was stopped.
  Future<void> coreStarted() async {
    final plan = _plan;
    if (plan == null || _disposed) return;
    resume();
    await _reloadPending(plan, _generation);
  }

  static bool _setupSucceeded(String response) {
    final result = json.decode(response) as Map;
    return result['code'] == 0 && result['data'] == '';
  }

  bool _current(ProviderRefreshPlan plan, int generation) =>
      !_disposed && identical(_plan, plan) && generation == _generation;

  Future<void> _tick() async {
    final plan = _plan;
    if (plan == null || !plan.managed) return;
    final generation = _generation;
    for (final target in plan.targets) {
      if (!_current(plan, generation)) return;
      if (target.interval <= Duration.zero) continue;
      try {
        final lastUpdate = _updatedAt[target.key] ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        if (_now().toUtc().difference(lastUpdate.toUtc()) >= target.interval) {
          await refresh(target);
        }
      } catch (error) {
        log('Provider ${target.type}/${target.name} check failed (${error.runtimeType})');
      }
    }
  }

  /// Sends [bytes] to the running core. Empty string means the core accepted
  /// them. `expectedPath` makes the core reject a late payload of an old profile.
  Future<String> _sideLoad(ProviderRefreshTarget target, Uint8List bytes) async {
    final response = await invokeCore(json.encode({
      'id': 'provider-refresh#${++_requestId}',
      'method': 'sideLoadExternalProvider',
      'data': json.encode({
        'providerName': target.name,
        'providerType': target.type,
        'expectedPath': target.path,
        'dataBase64': base64.encode(bytes),
      }),
    }));
    final result = json.decode(response) as Map;
    return result['code'] != 0 || result['data'] != ''
        ? 'Provider data was rejected by the core'
        : '';
  }

  /// After a start: caches written while the core was stopped are side-loaded
  /// into it, so the loaded providers never lag behind the files on disk.
  Future<void> _reloadPending(ProviderRefreshPlan plan, int generation) async {
    for (final target in _pendingReload.values.toList()) {
      if (!_current(plan, generation)) return;
      try {
        await _exclusive(() async {
          if (!_current(plan, generation) || !isRunning()) return;
          if (!_pendingReload.containsKey(target.key)) return;
          final error = await _sideLoad(target, await read(target.path));
          if (error.isEmpty) {
            _pendingReload.remove(target.key);
          } else {
            log('Provider ${target.type}/${target.name}: $error');
          }
        });
      } catch (error) {
        log('Provider ${target.type}/${target.name} reload failed (${error.runtimeType})');
      }
    }
  }

  /// Network work is single-flight per typed provider. Native application and
  /// cache commit are serialized with setup/start/stop, with a generation check
  /// immediately before committing. A stopped/old profile cannot publish late.
  /// With the core running the bytes are side-loaded first and the cache is
  /// written only if the core accepts them; with the core stopped the cache is
  /// written directly and reloaded on the next start.
  Future<String> refresh(ProviderRefreshTarget target) {
    final existing = _inFlight[target.key];
    if (existing != null) return existing;
    final plan = _plan;
    if (plan == null ||
        !plan.managed ||
        _disposed ||
        !plan.targets.contains(target)) {
      return Future<String>.value('Provider profile is no longer active');
    }
    final generation = _generation;
    final cancellation = CancelToken();
    final completed = Completer<String>();
    _inFlight[target.key] = completed.future;
    _cancellations.add(cancellation);
    unawaited(() async {
      var outcome = 'Provider update cancelled';
      try {
        final bytes = await fetch(plan, target, cancellation);
        ensureCoreInputBytes(bytes, name: 'Provider');
        if (_current(plan, generation) && !cancellation.isCancelled) {
          outcome = await _exclusive(() async {
            if (!_current(plan, generation) || cancellation.isCancelled) {
              return 'Provider update cancelled';
            }
            final coreRunning = isRunning();
            if (coreRunning) {
              final error = await _sideLoad(target, bytes);
              if (error.isNotEmpty) return error;
              // The native call may finish after a stop/profile-change request.
              // It is serialized before the next setup, but cannot be cancelled.
              if (!_current(plan, generation) || cancellation.isCancelled) {
                return 'Provider update cancelled';
              }
              _pendingReload.remove(target.key);
            }
            await persist(target.path, bytes);
            if (!coreRunning) _pendingReload[target.key] = target;
            if (_current(plan, generation)) {
              _updatedAt[target.key] = _now().toUtc();
              log('Provider ${target.type}/${target.name} updated automatically or manually');
            }
            return '';
          });
        }
      } catch (error) {
        if (_current(plan, generation)) {
          outcome = 'Provider update failed (${error.runtimeType})';
        }
      } finally {
        if (identical(_inFlight[target.key], completed.future)) {
          unawaited(_inFlight.remove(target.key));
        }
        _cancellations.remove(cancellation);
        if (outcome.isNotEmpty && _current(plan, generation)) {
          log('Provider ${target.type}/${target.name}: $outcome');
        }
        completed.complete(outcome);
      }
    }());
    return completed.future;
  }
}
