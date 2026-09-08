// Lifecycle steps are deliberately explicit for ordering/race assertions.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/ui_lifecycle.dart';

void main() {
  test(
      'hide stops activity immediately and unloads once after the grace period',
      () {
    fakeAsync((clock) {
      final controller = UiLifecycleController();
      var changes = 0;
      controller.addListener(() => changes++);
      controller.updateWindowVisibility(visible: false);
      expect(controller.isVisible, isFalse);
      expect(controller.isForeground, isFalse);
      expect(controller.isSuspended, isFalse);
      clock.elapse(const Duration(seconds: 2));
      controller.updateWindowVisibility(visible: false);
      controller.updateLifecycle(AppLifecycleState.hidden);
      clock.elapse(const Duration(seconds: 1));
      expect(controller.isSuspended, isTrue);
      expect(changes, 2, reason: 'duplicate events must not delay unloading');
      expect(clock.nonPeriodicTimerCount, 0);
      clock.elapse(const Duration(hours: 1));
      expect(changes, 2, reason: 'there is no recurring background timer');
      controller.updateWindowVisibility(visible: true);
      expect(controller.isVisible, isTrue);
      expect(controller.isForeground, isTrue);
      expect(controller.isSuspended, isFalse);
      controller.dispose();
    });
  });

  test('quick hide/show cancels unloading and invalidates old UI responses',
      () {
    fakeAsync((clock) {
      final controller = UiLifecycleController();
      final generation = controller.generation;
      controller.updateWindowVisibility(visible: false);
      clock.elapse(const Duration(seconds: 2));
      controller.updateWindowVisibility(visible: true);
      expect(controller.generation, greaterThan(generation));
      clock.elapse(const Duration(hours: 1));
      expect(controller.isSuspended, isFalse);
      expect(clock.nonPeriodicTimerCount, 0);
      controller.updateWindowVisibility(visible: false);
      clock.elapse(const Duration(seconds: 3));
      expect(controller.isSuspended, isTrue);
      controller.dispose();
    });
  });

  test('focus loss never unloads a visible window; native popover wins', () {
    fakeAsync((clock) {
      final controller = UiLifecycleController();
      controller.updateLifecycle(AppLifecycleState.inactive);
      expect(controller.isForeground, isFalse);
      expect(controller.isVisible, isTrue);
      clock.elapse(const Duration(minutes: 10));
      expect(controller.isSuspended, isFalse);
      controller.updateWindowVisibility(visible: true);
      controller.updateLifecycle(AppLifecycleState.hidden);
      clock.elapse(const Duration(minutes: 10));
      expect(controller.isVisible, isTrue);
      expect(controller.isForeground, isTrue);
      expect(controller.isSuspended, isFalse);
      controller.updateWindowVisibility(visible: false);
      controller.updateLifecycle(AppLifecycleState.resumed);
      clock.elapse(const Duration(seconds: 3));
      expect(controller.isSuspended, isTrue);
      expect(controller.isForeground, isFalse);
      controller.dispose();
    });
  });

  test('mobile lifecycle unloads and restores without native window events',
      () {
    fakeAsync((clock) {
      final controller = UiLifecycleController();
      controller.updateLifecycle(AppLifecycleState.resumed);
      controller.updateLifecycle(AppLifecycleState.inactive);
      controller.updateLifecycle(AppLifecycleState.hidden);
      controller.updateLifecycle(AppLifecycleState.paused);
      clock.elapse(const Duration(seconds: 3));
      expect(controller.isSuspended, isTrue);
      controller.updateLifecycle(AppLifecycleState.hidden);
      controller.updateLifecycle(AppLifecycleState.inactive);
      expect(controller.isSuspended, isFalse);
      expect(controller.isForeground, isFalse);
      controller.updateLifecycle(AppLifecycleState.resumed);
      expect(controller.isForeground, isTrue);
      expect(clock.nonPeriodicTimerCount, 0);
      controller.dispose();
    });
  });

  test('late startup snapshot cannot overwrite a newer hide/show event',
      () async {
    final controller = UiLifecycleController();
    final snapshot = Completer<bool>();
    final sync = controller.synchronizeWindowVisibility(() => snapshot.future);
    controller.updateWindowVisibility(visible: false);
    controller.updateWindowVisibility(visible: true);
    snapshot.complete(false);
    await sync;
    expect(controller.isVisible, isTrue);
    controller.dispose();
  });

  test('disposal cancels pending unloading and ignores a late snapshot', () {
    fakeAsync((clock) {
      final controller = UiLifecycleController();
      var changes = 0;
      controller.addListener(() => changes++);
      controller.updateWindowVisibility(visible: false);
      final snapshot = Completer<bool>();
      unawaited(controller.synchronizeWindowVisibility(() => snapshot.future));
      controller.dispose();
      snapshot.complete(true);
      clock.flushMicrotasks();
      clock.elapse(const Duration(hours: 1));
      expect(changes, 1);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });
}
