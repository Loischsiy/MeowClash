import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/models/core.dart';
import 'package:meowclash/services/delay_test_runner.dart';

DelayTestTarget target(String name, [String url = 'https://example.com/204']) =>
    (name: name, url: url);
Delay success(DelayTestTarget target, [int value = 42]) =>
    Delay(name: target.name, url: target.url, value: value);

void main() {
  test('single and bulk callers share a concurrency limit', () async {
    var active = 0;
    var maximum = 0;
    final runner = DelayTestRunner(
      concurrency: 4,
      onDelay: (_) {},
      probe: (t) async {
        active++;
        if (active > maximum) maximum = active;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        active--;
        return success(t);
      },
    );
    await Future.wait([
      runner.testAll(Iterable.generate(100, (i) => target('a$i'))),
      runner.testAll(Iterable.generate(100, (i) => target('b$i'))),
      runner.test(target('single')),
    ]);
    expect(maximum, inInclusiveRange(1, 4));
    expect(active, 0);
  });

  test('deduplicates in-flight identities but preserves different URLs',
      () async {
    final pending = <DelayTestTarget, Completer<Delay>>{};
    final runner = DelayTestRunner(
        onDelay: (_) {},
        probe: (t) => (pending[t] = Completer<Delay>()).future);
    final a = runner.test(target('same'));
    final b = runner.test(target('same'));
    final c = runner.test(target('same', 'https://other.example/204'));
    expect(identical(a, b), isTrue);
    expect(pending, hasLength(2));
    for (final entry in pending.entries) {
      entry.value.complete(success(entry.key));
    }
    await Future.wait([a, b, c]);
  });

  test('bulk input is consumed lazily, with one request per effective target',
      () async {
    var visited = 0;
    final pending = <DelayTestTarget, Completer<Delay>>{};
    final runner = DelayTestRunner(
        concurrency: 2,
        onDelay: (_) {},
        probe: (t) => (pending[t] = Completer<Delay>()).future);
    final done = runner.testAll(Iterable.generate(20, (i) {
      visited++;
      return target('node${i % 5}');
    }));
    expect(visited, 0);
    await Future<void>.delayed(Duration.zero);
    expect(visited, 2);
    expect(pending, hasLength(2));
    for (var tick = 0; tick < 20 && visited < 20; tick++) {
      for (final entry in pending.entries.toList()) {
        if (!entry.value.isCompleted) entry.value.complete(success(entry.key));
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await done;
    expect(pending, hasLength(5));
  });

  test('cancel drops queued work, settles loading and ignores stale results',
      () async {
    final updates = <Delay>[];
    final pending = <DelayTestTarget, Completer<Delay>>{};
    final runner = DelayTestRunner(
        concurrency: 1,
        onDelay: updates.add,
        probe: (t) => (pending[t] = Completer<Delay>()).future);
    final old = runner.test(target('old'));
    final queued = runner.test(target('queued'));
    runner.cancel();
    await Future.wait([old, queued]);
    final current = runner.test(target('current'));
    expect(pending.keys, [target('old')]);
    pending[target('old')]!.complete(success(target('old'), 999));
    await Future<void>.delayed(Duration.zero);
    pending[target('current')]!.complete(success(target('current')));
    await current;
    expect(updates.where((d) => d.value == 999), isEmpty);
    expect(updates.where((d) => d.name == 'queued'), isEmpty);
    expect(updates.last, success(target('current')));
    expect(updates.where((d) => d.name == 'old').last.value, -1);
  });

  test('failure, null values and timeout always release the slot', () async {
    final updates = <Delay>[];
    final runner = DelayTestRunner(
      concurrency: 1,
      timeout: const Duration(milliseconds: 5),
      onDelay: updates.add,
      probe: (t) {
        if (t.name == 'throws') throw StateError('probe failed');
        if (t.name == 'timeout') return Completer<Delay>().future;
        if (t.name == 'null') {
          return Future.value(const Delay(name: '', url: ''));
        }
        return Future.value(success(t));
      },
    );
    await runner.testAll(['throws', 'timeout', 'null', 'ok'].map(target));
    final finals = updates.where((d) => d.value != 0).toList();
    expect(finals.map((d) => d.value), [-1, -1, -1, 42]);
    expect(finals.map((d) => d.name), ['throws', 'timeout', 'null', 'ok']);
    expect(finals.every((d) => d.url == target('').url), isTrue);
  });

  test('thousands of immediately completed probes yield to the event loop',
      () async {
    var count = 0;
    var observedAtTimer = -1;
    final runner = DelayTestRunner(
        onDelay: (_) {},
        probe: (t) async {
          count++;
          return success(t);
        });
    final done = runner.testAll(Iterable.generate(2500, (i) => target('$i')));
    Timer.run(() => observedAtTimer = count);
    await done;
    expect(count, 2500);
    expect(observedAtTimer, inInclusiveRange(0, 2499));
  });
}
