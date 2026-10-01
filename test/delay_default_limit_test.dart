import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/models/core.dart';
import 'package:meowclash/services/delay_test_runner.dart';

void main() {
  test('default permits ten simultaneous probes and queues the eleventh',
      () async {
    final pending = <({String name, String url}), Completer<Delay>>{};
    final runner = DelayTestRunner(
      onDelay: (_) {},
      probe: (target) => (pending[target] = Completer<Delay>()).future,
    );
    expect(runner.concurrency, 10);
    final jobs = [
      for (var i = 0; i < 25; i++)
        runner.test((name: '$i', url: 'https://example.com/204'))
    ];
    expect(pending, hasLength(10));
    final first = pending.entries.first;
    first.value
        .complete(Delay(name: first.key.name, url: first.key.url, value: 42));
    await Future<void>.delayed(Duration.zero);
    expect(pending, hasLength(11));
    while (pending.values.any((v) => !v.isCompleted)) {
      final batch = pending.entries.where((e) => !e.value.isCompleted).toList();
      expect(batch.length, lessThanOrEqualTo(10));
      for (final entry in batch) {
        entry.value.complete(
            Delay(name: entry.key.name, url: entry.key.url, value: 42));
      }
      await Future<void>.delayed(Duration.zero);
    }
    await Future.wait(jobs);
    expect(pending, hasLength(25));
  });

  test('platform defaults: 32 on desktop, 10 on mobile; 0 means unlimited', () {
    expect(DelayTestRunner.resolve(null, isDesktop: true), 32);
    expect(DelayTestRunner.resolve(null, isDesktop: false), 10);
    expect(DelayTestRunner.resolve(0, isDesktop: false), 0);
    expect(DelayTestRunner.resolve(64, isDesktop: false), 64);
    expect(DelayTestRunner.resolve(-3, isDesktop: true), 32);
    expect(DelayTestRunner.resolve(5000, isDesktop: true),
        DelayTestRunner.maxConcurrency);
  });

  test('unlimited starts every bulk target at once', () async {
    final pending = <({String name, String url}), Completer<Delay>>{};
    final runner = DelayTestRunner(
      concurrency: DelayTestRunner.unlimited,
      onDelay: (_) {},
      probe: (target) => (pending[target] = Completer<Delay>()).future,
    );
    final done = runner.testAll(Iterable.generate(
        150, (i) => (name: '$i', url: 'https://example.com/204')));
    for (var i = 0; i < 20 && pending.length < 150; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(pending, hasLength(150));
    for (final entry in pending.entries) {
      entry.value
          .complete(Delay(name: entry.key.name, url: entry.key.url, value: 1));
    }
    await done;
  });

  test('raising the limit starts queued probes immediately', () async {
    final pending = <({String name, String url}), Completer<Delay>>{};
    final runner = DelayTestRunner(
      concurrency: 2,
      onDelay: (_) {},
      probe: (target) => (pending[target] = Completer<Delay>()).future,
    );
    final jobs = [
      for (var i = 0; i < 6; i++)
        runner.test((name: '$i', url: 'https://example.com/204'))
    ];
    expect(pending, hasLength(2));
    runner.concurrency = 5;
    expect(pending, hasLength(5));
    runner.concurrency = DelayTestRunner.unlimited;
    expect(pending, hasLength(6));
    for (final entry in pending.entries) {
      entry.value
          .complete(Delay(name: entry.key.name, url: entry.key.url, value: 1));
    }
    await Future.wait(jobs);
  });
}
