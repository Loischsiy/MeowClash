// Test fixtures deliberately spell out each step.
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/core_input_guard.dart';
import 'package:meowclash/services/provider_payload.dart';
import 'package:meowclash/services/provider_refresh_plan.dart';
import 'package:meowclash/services/subscription_crypto.dart';

// Deterministic test-only AES-CBC fixture; PBKDF2-SHA256, 1000 rounds.
const encrypted =
    'AAECAwQFBgcICQoLDA0ODyAhIiMkJSYnKCkqKywtLi8Qi5G3a2urh6ddaL54ZQv/29Zag5fkpUgNG0oZk8wfVP1UMDXagQ/Rvsa/kaLOpxU=';
const plaintext = 'payload:\n  - DOMAIN,example.org\n';

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

ProviderRefreshTarget get target => const ProviderRefreshTarget(
      name: 'rules',
      type: 'Rule',
      url: 'https://example.invalid/rules',
      path: '/unused',
      interval: Duration(seconds: 1200),
      headers: {
        'Authorization': ['Bearer test-only']
      },
    );
ProviderRefreshPlan get fixturePlan => ProviderRefreshPlan(
      profileId: 'test',
      userAgent: 'MeowClash-test',
      targets: [target],
      password: 'background-test-only',
      iterations: 1000,
    );

void main() {
  test('decrypts a provider without a widget or app-controller instance',
      () async {
    final result = await decryptProviderPayload(
        Uint8List.fromList(utf8.encode(encrypted)),
        password: 'background-test-only',
        iterations: 1000);
    expect(utf8.decode(result), plaintext);
  });
  test('plain YAML and binary MRS bytes pass through unchanged', () async {
    for (final bytes in [
      Uint8List.fromList(utf8.encode(plaintext)),
      Uint8List.fromList([77, 82, 83, 0, 255, 128])
    ]) {
      expect(
          await decryptProviderPayload(bytes, password: null, iterations: 1000),
          same(bytes));
    }
  });
  test('missing and incorrect credentials cannot return an encrypted payload',
      () async {
    final bytes = Uint8List.fromList(utf8.encode(encrypted));
    await expectLater(
        decryptProviderPayload(bytes, password: null, iterations: 1000),
        throwsA(isA<SubscriptionPasswordRequiredException>()));
    await expectLater(
        decryptProviderPayload(bytes, password: 'wrong', iterations: 1000),
        throwsException);
    await expectLater(
        decryptProviderPayload(bytes,
            password: 'background-test-only', iterations: 1001),
        throwsException);
  });
  test('stream downloader sends provider headers, not the decryption password',
      () async {
    RequestOptions? captured;
    final dio = Dio()
      ..httpClientAdapter = Adapter((options) async {
        captured = options;
        return ResponseBody.fromString(encrypted, 200);
      });
    final downloader = ProviderPayloadDownloader(dio: dio);
    try {
      final result = await downloader.fetch(fixturePlan, target, CancelToken());
      expect(utf8.decode(result), plaintext);
      expect(captured?.headers['Authorization'], ['Bearer test-only']);
      expect(captured?.headers['User-Agent'], 'MeowClash-test');
      expect(captured?.headers.toString(),
          isNot(contains('background-test-only')));
    } finally {
      downloader.close();
    }
  });
  test('oversized content-length is rejected before reading its body',
      () async {
    final dio = Dio()
      ..httpClientAdapter =
          Adapter((_) async => ResponseBody.fromString('small', 200, headers: {
                'content-length': ['${maxCoreInputBytes + 1}']
              }));
    final downloader = ProviderPayloadDownloader(dio: dio);
    final cancel = CancelToken();
    try {
      await expectLater(downloader.fetch(fixturePlan, target, cancel),
          throwsA(isA<CoreInputTooLargeException>()));
      expect(cancel.isCancelled, isTrue);
    } finally {
      downloader.close();
    }
  });
  test('chunked responses cannot bypass the byte limit', () async {
    final dio = Dio()
      ..httpClientAdapter = Adapter((_) async => ResponseBody(
            Stream.fromIterable([Uint8List(maxCoreInputBytes), Uint8List(1)]),
            200,
          ));
    final downloader = ProviderPayloadDownloader(dio: dio);
    try {
      await expectLater(downloader.fetch(fixturePlan, target, CancelToken()),
          throwsA(isA<CoreInputTooLargeException>()));
    } finally {
      downloader.close();
    }
  });
  test('cache replacement is atomic and preserves binary bytes', () async {
    final dir = await Directory.systemTemp.createTemp('provider-refresh-test-');
    try {
      final path = '${dir.path}/rules.mrs';
      await writeProviderCache(path, Uint8List.fromList([1]));
      final bytes = Uint8List.fromList([77, 82, 83, 0, 255]);
      await writeProviderCache(path, bytes);
      expect(await File(path).readAsBytes(), bytes);
      expect(dir.listSync().map((file) => file.path), [path]);
      expect((await providerCacheModifiedAt(path)).year, greaterThan(2020));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
