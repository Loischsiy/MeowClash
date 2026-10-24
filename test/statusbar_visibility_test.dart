import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/statusbar.dart';
import 'package:meowclash/services/ui_lifecycle.dart';

/// macOS runs as a regular window; the menu bar icon
/// (macos/Runner/StatusBarController.swift) asks Dart to show or hide it and
/// reports Cmd+H. A null reply makes the native side toggle the window itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('status_bar_icon');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Simulates a call from the native runner, not a Dart invoke. Returns the
  /// decoded reply, or null when Dart did not handle the method.
  Future<Object?> nativeCall(String method, [Object? arguments]) {
    final done = Completer<Object?>();
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (reply) => done.complete(
        reply == null ? null : codec.decodeEnvelope(reply),
      ),
    );
    return done.future;
  }

  tearDown(() {
    channel.setMethodCallHandler(null);
  });

  test('menu bar show/hide requests run the Dart window actions', () async {
    final controller = UiLifecycleController();
    addTearDown(controller.dispose);
    final calls = <String>[];
    StatusBarManager.listen(
      controller,
      onShowWindow: () async => calls.add('show'),
      onHideWindow: () async => calls.add('hide'),
    );

    expect(await nativeCall('showWindow'), isTrue);
    expect(await nativeCall('hideWindow'), isTrue);
    expect(calls, ['show', 'hide']);
  });

  test('native visibility changes (Cmd+H, native fallback) are forwarded',
      () async {
    final controller = UiLifecycleController();
    addTearDown(controller.dispose);
    StatusBarManager.listen(
      controller,
      onShowWindow: () async {},
      onHideWindow: () async {},
    );

    await nativeCall('visibilityChanged', false);
    expect(controller.hasWindowVisibility, isTrue);
    expect(controller.isForeground, isFalse);
    await nativeCall('visibilityChanged', true);
    expect(controller.isForeground, isTrue);
  });

  test('unknown methods are left to the native fallback', () async {
    final controller = UiLifecycleController();
    addTearDown(controller.dispose);
    StatusBarManager.listen(
      controller,
      onShowWindow: () async {},
      onHideWindow: () async {},
    );

    expect(await nativeCall('togglePopover'), isNull);
    expect(controller.hasWindowVisibility, isFalse);
  });
}
