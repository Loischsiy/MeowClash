import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/clash/ios.dart';
import 'package:meowclash/plugins/ios.dart';

/// `test/fixtures/provider_cache_paths.json` is written by the Go core test
/// (`UPDATE_GOLDEN=1 go -C core test -run TestProviderCachePathGolden`) from
/// mihomo's own `GetPathByHash`. The channel below answers like the core does:
/// `home + golden path` for the golden url/kind, so the Dart side proves it
/// sends the right request and takes the answer verbatim, with no hashing of
/// its own. The Go test `TestExternalProviderReadsFFIPathWithoutNetwork` proves
/// the core reads exactly that file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.meowclash/provider-path');
  const home = '/core/home';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final golden = (json.decode(
    File('test/fixtures/provider_cache_paths.json').readAsStringSync(),
  ) as List)
      .cast<Map<String, dynamic>>();
  late ClashIOSHandler handler;

  setUp(() => handler = ClashIOSHandler(bridge: IOSVpn(channel: channel)));
  tearDown(() async {
    await handler.destroy();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('the golden fixture covers both kinds and several urls', () {
    expect(golden.map((e) => e['kind']).toSet(), {'proxies', 'rules'});
    expect(golden.length, greaterThanOrEqualTo(6));
    expect(golden.map((e) => e['path']).toSet().length, golden.length);
  });

  test('FFI answers equal the golden paths for every kind and url', () async {
    final seen = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final action =
          json.decode(call.arguments as String) as Map<String, dynamic>;
      expect(action['method'], 'getProviderCachePath');
      final request = json.decode(action['data'] as String) as Map;
      seen.add('${request['kind']}|${request['url']}');
      final entry = golden.firstWhere(
          (e) => e['kind'] == request['kind'] && e['url'] == request['url']);
      return json.encode({...action, 'data': '$home/${entry['path']}', 'code': 0});
    });

    for (final entry in golden) {
      expect(
        await handler.getProviderCachePath(
            kind: entry['kind'] as String, url: entry['url'] as String),
        '$home/${entry['path']}',
      );
    }
    expect(seen.length, golden.length);
  });

  test('a core that cannot answer yields an empty path, never an error text',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      final action =
          json.decode(call.arguments as String) as Map<String, dynamic>;
      return json.encode({...action, 'data': '', 'code': 0});
    });
    expect(
        await handler.getProviderCachePath(
            kind: 'proxies', url: 'https://example.com/sub'),
        isEmpty);
  });
}
