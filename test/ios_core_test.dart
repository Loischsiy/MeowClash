import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/clash/ios.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/plugins/ios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.meowclash/ios');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late IOSVpn bridge;
  late ClashIOSHandler handler;

  setUp(() {
    bridge = IOSVpn(channel: channel);
    handler = ClashIOSHandler(bridge: bridge);
  });
  tearDown(() async {
    await handler.destroy();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('preserves the MeowClash id/method/data protocol', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'action');
      final action =
          json.decode(call.arguments as String) as Map<String, dynamic>;
      expect(action['method'], 'validateConfig');
      expect(action['data'], 'proxies: []');
      expect(action['id'], startsWith('validateConfig#'));
      return json.encode({...action, 'data': '', 'code': 0});
    });
    expect(await handler.validateConfig('proxies: []'), '');
  });

  test('core errors do not turn into empty success values', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final action =
          json.decode(call.arguments as String) as Map<String, dynamic>;
      return json.encode({...action, 'data': 'invalid config', 'code': -1});
    });
    await expectLater(handler.invoke<bool>(method: ActionMethod.getIsInit),
        throwsA(isA<PlatformException>()));
  });

  test('getConfig preserves the existing Result error contract', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final action =
          json.decode(call.arguments as String) as Map<String, dynamic>;
      return json.encode({...action, 'data': 'file not found', 'code': -1});
    });
    final result = await handler.getConfig('/missing.yaml');
    expect(result.type, ResultType.error);
    expect(result.message, 'file not found');
  });

  test('mismatched replies are rejected', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final action =
          json.decode(call.arguments as String) as Map<String, dynamic>;
      return json
          .encode({...action, 'id': 'old-request', 'data': true, 'code': 0});
    });
    await expectLater(handler.isInit, throwsFormatException);
  });

  test('native signing and VPN failures propagate', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
          code: 'app_group', message: 'Missing entitlement');
    });
    await expectLater(bridge.start(), throwsA(isA<PlatformException>()));
  });

  test('status reflects the extension, not a requested start', () async {
    messenger.setMockMethodCallHandler(
        channel, (_) async => {'status': 'connecting'});
    expect((await bridge.start()).isConnected, isFalse);
    messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
              'status': 'connected',
              'startedAt': 1700000000000,
            });
    final status = await bridge.refreshStatus();
    expect(status.isConnected, isTrue);
    expect(status.startedAt!.millisecondsSinceEpoch, 1700000000000);
  });

  test('disposing the Flutter handler never stops the VPN', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {'status': 'connected', 'startedAt': 1700000000000};
    });
    await handler.preload();
    await handler.destroy();
    expect(calls, ['initialize']);
  });
}
