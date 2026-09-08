// Native messages intentionally arrive between asynchronous snapshot steps.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/statusbar.dart';
import 'package:meowclash/services/ui_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('status_bar_icon');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> nativeVisibility({required bool visible}) {
    final done = Completer<void>();
    // Simulate a native macOS NSPopover delegate callback, not a Dart invoke.
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall('visibilityChanged', visible)),
      (_) => done.complete(),
    );
    return done.future;
  }

  tearDown(() {
    channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('initially hidden popover and native reopen/auto-close are forwarded',
      () async {
    final controller = UiLifecycleController();
    addTearDown(controller.dispose);
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isVisible');
      return false;
    });
    await StatusBarManager.initVisibility(controller);
    expect(controller.hasWindowVisibility, isTrue);
    expect(controller.isVisible, isFalse);
    await nativeVisibility(visible: true);
    expect(controller.isForeground, isTrue);
    await nativeVisibility(visible: false);
    expect(controller.isForeground, isFalse);
  });

  test('a late native snapshot cannot re-hide an opened popover', () async {
    final controller = UiLifecycleController();
    addTearDown(controller.dispose);
    final snapshot = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (_) => snapshot.future);
    final init = StatusBarManager.initVisibility(controller);
    await nativeVisibility(visible: true);
    snapshot.complete(false);
    await init;
    expect(controller.isVisible, isTrue);
  });

  test('older native runners fall back to Flutter lifecycle', () async {
    final controller = UiLifecycleController();
    addTearDown(controller.dispose);
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw MissingPluginException();
    });
    await StatusBarManager.initVisibility(controller);
    expect(controller.hasWindowVisibility, isFalse);
    expect(controller.isVisible, isTrue);
  });
}
