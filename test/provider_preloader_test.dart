// Test fixtures deliberately spell out each step.
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/provider_cache_updater.dart';
import 'package:meowclash/services/provider_payload.dart';
import 'package:meowclash/services/provider_preloader.dart';

// Deterministic test-only AES-CBC fixture (see provider_payload_test.dart).
const encrypted =
    'AAECAwQFBgcICQoLDA0ODyAhIiMkJSYnKCkqKywtLi8Qi5G3a2urh6ddaL54ZQv/29Zag5fkpUgNG0oZk8wfVP1UMDXagQ/Rvsa/kaLOpxU=';
const plaintext = 'payload:\n  - DOMAIN,example.org\n';
const password = 'background-test-only';
const iterations = 1000;
const agent = 'MeowClash-test/1.0';

/// A loopback provider endpoint that counts every request it serves. The core
/// is never pointed at anything else, so any request not made by the app's
/// loader would show up here too (tracked per User-Agent).
class Stub {
  Stub._(this.server);

  final HttpServer server;
  final requests = <HttpRequest>[];
  final userAgents = <String>[];
  Uint8List body = Uint8List(0);
  int status = 200;
  Map<String, String> headers = {};

  static Future<Stub> start() async {
    final stub = Stub._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    stub.server.listen((request) async {
      stub.userAgents.add(request.headers.value('user-agent') ?? '');
      stub.requests.add(request);
      request.response.statusCode = stub.status;
      stub.headers.forEach(request.response.headers.set);
      request.response.add(stub.body);
      await request.response.close();
    });
    return stub;
  }

  int get hits => requests.length;
  String url([String path = '/sub']) =>
      'http://${server.address.host}:${server.port}$path';
  Future<void> close() => server.close(force: true);
}

void main() {
  late Directory tmp;
  late Stub stub;
  late ProviderPayloadDownloader downloader;
  late ProviderCacheUpdater updater;
  final asked = <String>[];

  Future<String> resolve(String kind, String url) async {
    asked.add('$kind|$url');
    return '${tmp.path}/$kind/${url.hashCode}';
  }

  ProviderPreloader preloader({DateTime Function()? now}) => ProviderPreloader(
        resolvePath: resolve,
        updater: updater,
        now: now,
      );

  Map<String, dynamic> config({int interval = 0, String path = '/sub'}) => {
        'proxy-providers': {
          'main': {
            'type': 'http',
            'url': stub.url(path),
            'path': '/user/chosen/path',
            'interval': interval,
          },
          'inline': {'type': 'inline', 'payload': <dynamic>[]},
        },
        'rule-providers': <String, dynamic>{},
      };

  Future<ProviderPreloadResult> prepare(
    Map<String, dynamic> config, {
    String? pass = password,
    DateTime Function()? now,
  }) =>
      preloader(now: now).prepare(
        config,
        userAgent: agent,
        password: pass,
        iterations: iterations,
      );

  String cachePath([String path = '/sub']) =>
      '${tmp.path}/proxies/${stub.url(path).hashCode}';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('provider_preload');
    stub = await Stub.start();
    stub.body = Uint8List.fromList(utf8.encode(encrypted));
    downloader = ProviderPayloadDownloader();
    updater = ProviderCacheUpdater(
      download: (request, cancellation) => downloader.download(
        url: request.url,
        headers: request.headers,
        userAgent: request.userAgent,
        cancellation: cancellation,
      ),
    );
    asked.clear();
  });

  tearDown(() async {
    downloader.close();
    await stub.close();
    await tmp.delete(recursive: true);
  });

  group('preload', () {
    test('writes the decrypted provider to the path the core reported',
        () async {
      final map = config();
      final result = await prepare(map);

      expect(result.warnings, isEmpty);
      expect(asked, ['proxies|${stub.url()}']);
      expect(File(cachePath()).readAsStringSync(), plaintext);
      final provider = (map['proxy-providers'] as Map)['main'] as Map;
      expect(provider['meowclash-external'], isTrue);
      // The core derives the very same path from the url when none is set.
      expect(provider.containsKey('path'), isFalse);
      expect((map['proxy-providers'] as Map)['inline'],
          isNot(contains('meowclash-external')));
    });

    test('exactly one loader request per download, identified by User-Agent',
        () async {
      await prepare(config());
      expect(stub.hits, 1);
      expect(stub.userAgents, [agent]);
    });

    test('a restart with a live cache makes no request at all', () async {
      await prepare(config());
      await prepare(config());
      await prepare(config(interval: 3600));
      expect(stub.hits, 1);
    });

    test('a cache older than the interval is refreshed exactly once',
        () async {
      await prepare(config(interval: 60));
      expect(stub.hits, 1);
      await prepare(config(interval: 60),
          now: () => DateTime.now().add(const Duration(minutes: 5)));
      expect(stub.hits, 2);
    });

    test('profile credentials win, response headers are the fallback',
        () async {
      stub.headers = {
        'meowclash-password': password,
        'meowclash-password-iterations': '$iterations',
      };
      await prepare(config(), pass: null);
      expect(File(cachePath()).readAsStringSync(), plaintext);
    });

    test('plaintext and V2Ray base64 providers pass through untouched',
        () async {
      for (final text in [
        'proxies:\n  - {name: a, type: direct}\n',
        base64.encode(utf8.encode(
            'vless://u@example.com:443?security=tls#a\nvmess://abc#b\n')),
      ]) {
        stub.body = Uint8List.fromList(utf8.encode(text));
        if (File(cachePath()).existsSync()) File(cachePath()).deleteSync();
        await prepare(config(), pass: null);
        expect(File(cachePath()).readAsStringSync(), text);
      }
    });
  });

  group('error UX', () {
    test('wrong password: clear reason, never a schema or YAML error',
        () async {
      await expectLater(
        prepare(config(), pass: 'definitely-wrong'),
        throwsA(isA<ProviderFetchException>()
            .having((e) => e.reason, 'reason',
                ProviderFailureReason.wrongPassword)
            .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('password'),
                  contains('main'),
                  isNot(contains('ProxySchema')),
                  isNot(contains('yaml')),
                ))),
      );
      expect(File(cachePath()).existsSync(), isFalse);
    });

    test('no password and no cache: start is cancelled with a clear reason',
        () async {
      await expectLater(
        prepare(config(), pass: null),
        throwsA(isA<ProviderFetchException>()
            .having((e) => e.reason, 'reason',
                ProviderFailureReason.passwordRequired)
            .having((e) => e.message, 'message', contains('password'))),
      );
      expect(File(cachePath()).existsSync(), isFalse);
    });

    test('download failure without a cache cancels the start', () async {
      stub.status = 500;
      await expectLater(
        prepare(config()),
        throwsA(isA<ProviderFetchException>().having(
            (e) => e.reason, 'reason', ProviderFailureReason.download)),
      );
    });

    test('an old cache turns a failure into a warning and stays untouched',
        () async {
      await prepare(config(interval: 60));
      final before = File(cachePath()).readAsBytesSync();
      final later = DateTime.now().add(const Duration(hours: 1));

      // Server error, then a wrong password: both keep the saved copy.
      stub.status = 500;
      var result = await prepare(config(interval: 60), now: () => later);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.providerName, 'main');
      expect(File(cachePath()).readAsBytesSync(), before);

      stub.status = 200;
      result = await prepare(config(interval: 60),
          pass: 'definitely-wrong', now: () => later);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.reason,
          ProviderFailureReason.wrongPassword);
      expect(File(cachePath()).readAsBytesSync(), before);
    });

    test('an unknown cache path is reported, not guessed', () async {
      final bad = ProviderPreloader(
        resolvePath: (_, __) async => '',
        updater: updater,
      );
      await expectLater(
        bad.prepare(config(), userAgent: agent, password: password),
        throwsA(isA<ProviderFetchException>().having((e) => e.reason,
            'reason', ProviderFailureReason.pathUnavailable)),
      );
      expect(stub.hits, 0);
    });
  });
}
