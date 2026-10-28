import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';

import 'connections_logs_test_support.dart';
import 'performance_test_support.dart';

/// Host workload of the log / request buffers and of the row height cache:
/// core events pushed through the notifiers while a listener selects the
/// buffer version the way an open Logs / Requests page does (plus the one
/// snapshot of its throttled update), and height cache lookups on a full
/// [FixedMap]. Times, snapshots and copied list slots are printed for the
/// RAM work; they are not asserted (host VM, not a device).

const _events = 10000;
const _warmUp = 1000;

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(2);

/// Slot bytes at 8 B per reference (64-bit VM, no compressed pointers).
String _kib(int slots) => (slots * 8 / 1024).toStringAsFixed(1);

class _BufferRun {
  _BufferRun(this.elapsed, this.snapshots, this.slots, this.updates);

  final Duration elapsed;
  final int snapshots;
  final int slots;
  final int updates;

  @override
  String toString() => '${_ms(elapsed)} ms, '
      'snapshots $snapshots, copied slots $slots '
      '(~${_kib(slots)} KiB), page updates $updates';
}

/// Mirrors `LogsView` (lib/views/logs.dart): the select reads the version,
/// and the throttled update after the burst takes one snapshot.
_BufferRun _runLogs(List<Log> logs) {
  initializePerformanceState();
  globalState.appState = globalState.appState.copyWith(
    logs: FixedList<Log>(maxLength),
  );
  final container = ProviderContainer();
  var updates = 0;
  final sub = container.listen(
    logsProvider.select((state) => state.version),
    (prev, next) {
      if (prev != next) updates++;
    },
  );
  final notifier = container.read(logsProvider.notifier);
  final watch = Stopwatch()..start();
  for (final log in logs) {
    notifier.addLog(log);
  }
  final snapshot = container.read(logsProvider).list;
  watch.stop();
  const snapshots = 1;
  final slots = snapshot.length;
  final state = container.read(logsProvider);
  expect(state.length, maxLength);
  expect(state[state.length - 1], same(logs.last));
  expect(globalState.appState.logs.length, maxLength);
  sub.close();
  container.dispose();
  return _BufferRun(watch.elapsed, snapshots, slots, updates);
}

/// Mirrors `RequestsView` (lib/views/connection/requests.dart), as above.
_BufferRun _runRequests(List<Connection> requests) {
  initializePerformanceState();
  globalState.appState = globalState.appState.copyWith(
    requests: FixedList<Connection>(maxLength),
  );
  final container = ProviderContainer();
  var updates = 0;
  final sub = container.listen(
    requestsProvider.select((state) => state.version),
    (prev, next) {
      if (prev != next) updates++;
    },
  );
  final notifier = container.read(requestsProvider.notifier);
  final watch = Stopwatch()..start();
  for (final request in requests) {
    notifier.addRequest(request);
  }
  final snapshot = container.read(requestsProvider).list;
  watch.stop();
  const snapshots = 1;
  final slots = snapshot.length;
  final state = container.read(requestsProvider);
  expect(state.length, maxLength);
  expect(state[state.length - 1], same(requests.last));
  expect(globalState.appState.requests.length, maxLength);
  sub.close();
  container.dispose();
  return _BufferRun(watch.elapsed, snapshots, slots, updates);
}

typedef _MapRun = ({Duration misses, Duration hits, Duration resize});

/// A full height cache: [keys] are new rows (each one evicts the oldest),
/// then the same number of lookups of cached rows, then the per-build
/// `updateMaxLength` call of `CacheItemExtentListView` with an unchanged size.
_MapRun _runFixedMap(List<String> keys) {
  final map = FixedMap<String, double>(maxLength);
  for (var i = 0; i < maxLength; i++) {
    map.updateCacheValue('seed$i', () => i.toDouble());
  }
  final watch = Stopwatch()..start();
  for (final key in keys) {
    map.updateCacheValue(key, () => 1);
  }
  final misses = watch.elapsed;
  expect(map.length, maxLength);
  expect(map.containsKey(keys.last), isTrue);
  expect(map.containsKey(keys[keys.length - maxLength - 1]), isFalse);

  final cached = keys.sublist(keys.length - maxLength);
  watch
    ..reset()
    ..start();
  for (var i = 0; i < keys.length; i++) {
    map.updateCacheValue(cached[i % cached.length], () => 2);
  }
  final hits = watch.elapsed;
  expect(map.get(keys.last), 1);

  watch
    ..reset()
    ..start();
  for (var i = 0; i < keys.length; i++) {
    map.updateMaxLength(maxLength);
  }
  final resize = watch.elapsed;
  expect(map.length, maxLength);
  return (misses: misses, hits: hits, resize: resize);
}

void main() {
  test('$_events addLog with the Logs page select listening', () {
    _runLogs(sampleLogs(_warmUp));
    final run = _runLogs(sampleLogs(_events));
    expect(run.updates, _events);
    // ignore: avoid_print
    print('buffers perf [logs] $_events addLog, capacity $maxLength: $run');
  });

  test('$_events addRequest with the Requests page select listening', () {
    _runRequests(sampleConnections(_warmUp));
    final run = _runRequests(sampleConnections(_events));
    expect(run.updates, _events);
    // ignore: avoid_print
    print(
      'buffers perf [requests] $_events addRequest, capacity $maxLength: $run',
    );
  });

  test('$_events FixedMap.updateCacheValue on a full height cache', () {
    _runFixedMap(List.generate(_warmUp, (i) => 'warm$i'));
    final run = _runFixedMap(List.generate(_events, (i) => 'row$i'));
    // ignore: avoid_print
    print(
      'buffers perf [height cache] capacity $maxLength, $_events calls: '
      'misses ${_ms(run.misses)} ms, hits ${_ms(run.hits)} ms, '
      'updateMaxLength (same size) ${_ms(run.resize)} ms',
    );
  });
}
