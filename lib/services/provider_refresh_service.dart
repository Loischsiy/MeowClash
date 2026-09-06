import 'dart:async';
import 'dart:convert';
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

/// Owned by the Android service engine, never by an Application widget.
/// Both automatic and manual encrypted refreshes use this single owner.
class ProviderRefreshService {
  ProviderRefreshService({
    required this.invokeCore,
    required this.isRunning,
    required this.fetch,
    required this.modifiedAt,
    required this.persist,
    required this.log,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
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
      if (plan?.managed == true) {
        for (final target in plan!.targets) {
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
        // Stop keeps the applied plan for the next start. A newer setup,
        // shutdown or disposal invalidates it altogether.
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
      params['config'] = plan?.prepareCoreConfig(config) ?? config;
      action['data'] = json.encode(params);
      return configure(
        plan,
        () => invokeCore(json.encode(action)),
        succeeded: _setupSucceeded,
      );
    }
    if (method == 'stopListener' || method == 'shutdown') {
      suspend();
      if (method == 'shutdown') {
        _configuration++;
        _plan = null;
        _updatedAt.clear();
      }
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
      }
      return response;
    }
    if (method == 'updateExternalProvider') {
      await _mutations;
      final plan = _plan;
      if (plan?.managed == true) {
        final matches = plan!.targets
            .where((target) => target.name == action['data'])
            .toList();
        if (matches.isNotEmpty) {
          final result = matches.length == 1
              ? await refresh(matches.single)
              : 'Provider name is ambiguous between proxy and rule providers';
          return json.encode({
            'id': action['id'],
            'method': method,
            'code': 0,
            'data': result
          });
        }
      }
      return _exclusive(() => invokeCore(message));
    }
    if (method == 'sideLoadExternalProvider') {
      return _exclusive(() => invokeCore(message));
    }
    return invokeCore(message);
  }

  static bool _setupSucceeded(String response) {
    final result = json.decode(response) as Map;
    return result['code'] == 0 && result['data'] == '';
  }

  bool _current(ProviderRefreshPlan plan, int generation) =>
      !_disposed && identical(_plan, plan) && generation == _generation;

  Future<void> _tick() async {
    final plan = _plan;
    if (plan == null || !plan.managed || !isRunning()) return;
    final generation = _generation;
    for (final target in plan.targets) {
      if (!_current(plan, generation) || !isRunning()) return;
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

  /// Network work is single-flight per typed provider. Native application and
  /// cache commit are serialized with setup/start/stop, with a generation check
  /// immediately before committing. A stopped/old profile cannot publish late.
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
            if (result['code'] != 0 || result['data'] != '') {
              return 'Provider data was rejected by the core';
            }
            // The native call may finish after a stop/profile-change request.
            // It is serialized before the next setup, but cannot be cancelled.
            if (!_current(plan, generation) || cancellation.isCancelled) {
              return 'Provider update cancelled';
            }
            await persist(target.path, bytes);
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
