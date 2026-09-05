// Explicit lifecycle steps keep ordering and timer assertions readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/async_polling_loop.dart';

void main() {
  test('concurrent starts share one in-flight task', () {
    fakeAsync((clock) {
      var calls = 0;
      final blocked = Completer<void>();
      final loop = AsyncPollingLoop(
        interval: const Duration(seconds: 1),
        onTick: (_) {
          calls++;
          return blocked.future;
        },
      );
      loop
        ..start()
        ..start()
        ..start();
      clock.elapse(const Duration(hours: 1));
      expect(calls, 1);
      expect(clock.nonPeriodicTimerCount, 0);
      blocked.complete();
      clock.flushMicrotasks();
      expect(clock.nonPeriodicTimerCount, 1);
      loop.stop();
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('stop during await cannot re-arm polling or publish stale data', () {
    fakeAsync((clock) {
      var published = 0;
      final blocked = Completer<void>();
      final loop = AsyncPollingLoop(
        interval: const Duration(seconds: 1),
        onTick: (token) async {
          await blocked.future;
          if (token.isCurrent) published++;
        },
      );
      loop
        ..start()
        ..stop();
      blocked.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(hours: 1));
      expect(published, 0);
      expect(clock.nonPeriodicTimerCount, 0);
      expect(loop.isActive, isFalse);
    });
  });

  test('rapid stop/start waits for old task and invalidates its token', () {
    fakeAsync((clock) {
      final requests = <Completer<void>>[];
      final tokens = <PollingToken>[];
      final loop = AsyncPollingLoop(
        interval: const Duration(seconds: 1),
        onTick: (token) {
          tokens.add(token);
          final request = Completer<void>();
          requests.add(request);
          return request.future;
        },
      );
      loop.start();
      for (var i = 0; i < 50; i++) {
        loop
          ..stop()
          ..start();
      }
      expect(requests, hasLength(1));
      expect(tokens.first.isCurrent, isFalse);
      requests.first.complete();
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      expect(requests, hasLength(2));
      expect(tokens.last.isCurrent, isTrue);
      loop.dispose();
      requests.last.complete();
      clock.flushMicrotasks();
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('many manual refreshes coalesce into one follow-up', () {
    fakeAsync((clock) {
      final requests = <Completer<void>>[];
      final loop = AsyncPollingLoop(
        interval: const Duration(seconds: 1),
        onTick: (_) {
          final request = Completer<void>();
          requests.add(request);
          return request.future;
        },
      );
      loop.start();
      for (var i = 0; i < 100; i++) {
        loop.refresh();
      }
      expect(requests, hasLength(1));
      requests.first.complete();
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      expect(requests, hasLength(2));
      requests.last.complete();
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      expect(requests, hasLength(2));
      loop.dispose();
    });
  });

  test('errors do not kill subsequent polling', () {
    fakeAsync((clock) {
      var calls = 0;
      var errors = 0;
      final loop = AsyncPollingLoop(
        interval: const Duration(seconds: 1),
        onTick: (_) {
          calls++;
          throw StateError('temporary failure');
        },
        onError: (_, __) {
          errors++;
        },
      );
      loop.start();
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      expect(calls, 4);
      expect(errors, 4);
      loop.dispose();
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('dispose is terminal and invalidates pending refreshes', () {
    fakeAsync((clock) {
      var calls = 0;
      final blocked = Completer<void>();
      final loop = AsyncPollingLoop(
        interval: const Duration(seconds: 1),
        onTick: (_) {
          calls++;
          return blocked.future;
        },
      );
      loop
        ..start()
        ..refresh()
        ..dispose()
        ..start()
        ..refresh();
      blocked.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(hours: 1));
      expect(calls, 1);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('refresh while stopped never starts work', () {
    fakeAsync((clock) {
      var calls = 0;
      final loop = AsyncPollingLoop(
        interval: const Duration(seconds: 1),
        onTick: (_) {
          calls++;
        },
      );
      loop.refresh();
      clock.flushMicrotasks();
      expect(calls, 0);
      loop.dispose();
    });
  });
}
