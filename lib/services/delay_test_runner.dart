import 'dart:async';
import 'dart:collection';

import 'package:meowclash/models/core.dart';

typedef DelayTestTarget = ({String name, String url});

/// One shared, bounded queue for single, group and all-group URL tests.
/// The transport already runs outside the UI isolate; do not eagerly create a
/// Future (and a native request) for every proxy before applying the limit.
class DelayTestRunner {
  DelayTestRunner({
    required this.probe,
    required this.onDelay,
    this.concurrency = 4,
    this.timeout = const Duration(seconds: 7),
  }) : assert(concurrency > 0, 'concurrency must be positive');

  final Future<Delay> Function(DelayTestTarget target) probe;
  final void Function(Delay delay) onDelay;
  final int concurrency;
  final Duration timeout;
  final _queue = Queue<_DelayTestTask>();
  final _requests = <DelayTestTarget, _DelayTestTask>{};
  int _active = 0;
  int _generation = 0;

  int get generation => _generation;

  Future<void> test(DelayTestTarget target) {
    if (target.name.isEmpty) return Future<void>.value();
    final existing = _requests[target];
    if (existing != null) return existing.done.future;
    final task = _DelayTestTask(target, _generation);
    _requests[target] = task;
    _queue.add(task);
    _pump();
    return task.done.future;
  }

  Future<void> testAll(Iterable<DelayTestTarget> targets) async {
    final generation = _generation;
    final iterator = targets.iterator;
    final seen = <DelayTestTarget>{};
    var scanned = 0;

    Future<void> worker() async {
      // Yield to the event loop, not just the microtask queue, so a large input
      // or immediately completed probes cannot starve input and animation.
      await Future<void>.delayed(Duration.zero);
      while (generation == _generation && iterator.moveNext()) {
        final target = iterator.current;
        final isNew = seen.add(target);
        if (++scanned % 32 == 0) {
          await Future<void>.delayed(Duration.zero);
          if (generation != _generation) return;
        }
        if (!isNew || target.name.isEmpty) continue;
        await test(target);
        await Future<void>.delayed(Duration.zero);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
  }

  /// Discard queued work and ignore late results after a profile/core change.
  /// In-flight probes retain their slots until completion/transport timeout.
  void cancel() {
    _generation++;
    for (final task in _requests.values) {
      if (task.started) {
        onDelay(Delay(name: task.target.name, url: task.target.url, value: -1));
      }
      if (!task.done.isCompleted) task.done.complete();
    }
    _requests.clear();
    _queue.clear();
  }

  void _pump() {
    while (_active < concurrency && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      _active++;
      task.started = true;
      unawaited(_execute(task));
    }
  }

  Future<void> _execute(_DelayTestTask task) async {
    final target = task.target;
    try {
      onDelay(Delay(name: target.name, url: target.url, value: 0));
      Delay result;
      try {
        result = await probe(target).timeout(timeout);
      } catch (_) {
        result = Delay(name: target.name, url: target.url, value: -1);
      }
      if (task.generation == _generation) {
        // Keep the requested identity even when the core returns an empty URL
        // for a missing proxy. Every started spinner must reach a final state.
        onDelay(Delay(
          name: target.name,
          url: target.url,
          value: (result.value ?? -1) > 0 ? result.value : -1,
        ));
      }
    } finally {
      _active--;
      if (identical(_requests[target], task)) _requests.remove(target);
      if (!task.done.isCompleted) task.done.complete();
      _pump();
    }
  }
}

class _DelayTestTask {
  _DelayTestTask(this.target, this.generation);

  final DelayTestTarget target;
  final int generation;
  final done = Completer<void>();
  bool started = false;
}
