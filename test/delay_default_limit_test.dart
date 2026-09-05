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
}
