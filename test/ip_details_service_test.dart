import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/ip_country_names.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/ip_details.dart';
import 'package:meowclash/services/ip_details_service.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> payload(String ip) => {
      'success': true,
      'ip': ip,
      'country_code': 'ru',
      'country': '俄罗斯', // Deliberately wrong API language; not used by the UI.
      'region': 'Moscow',
      'city': 'Moscow',
      'connection': {'domain': 'example.net', 'isp': 'Example ISP'},
    };

ResponseBody response(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );

void main() {
  test('localizes countries for every app language independently of API', () {
    const expected = {
      'en': 'Russia',
      'fi': 'Venäjä',
      'ja': 'ロシア',
      'ru': 'Россия',
      'uk': 'Росія',
      'zh': '俄罗斯',
    };
    for (final locale in AppLocalizations.delegate.supportedLocales) {
      expect(localizedIpCountryName(' ru ', locale.toString()),
          expected[locale.languageCode]);
      for (final country in ['US', 'DE', 'FI', 'JP', 'UA', 'CN', 'AX', 'XK']) {
        expect(localizedIpCountryName(country, locale.toString()), isNotNull);
      }
    }
    expect(localizedIpCountryName('RU', 'zz'), 'Russia');
    expect(localizedIpCountryName('XX', 'ru'), isNull);
    expect(localizedIpCountryName('', 'ru'), isNull);
  });

  test('optional fields are safe; a provider name is not a domain', () {
    final data = payload('8.8.8.8')..['connection'] = {'isp': 'Example ISP'};
    final details = IpDetails.fromJson(data, geographyLanguage: 'en');
    expect(details.countryCode, 'RU');
    expect(details.regionAndCity, 'Moscow');
    expect(details.domain, isNull);
    data['region'] = 10;
    data['city'] = '  ';
    data['connection'] = 'invalid';
    final empty = IpDetails.fromJson(data, geographyLanguage: 'en');
    expect(empty.regionAndCity, isNull);
    expect(empty.domain, isNull);
    expect(
        () => IpDetails.fromJson({'success': false}, geographyLanguage: 'en'),
        throwsFormatException);
  });

  test('requests exact IPv4/IPv6 over HTTPS with an explicit API language',
      () async {
    final adapter =
        _Adapter((o) async => response(payload(o.uri.path.substring(1))));
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final service = IpDetailsService(dio);
    const languages = {
      'en': 'en',
      'ru': 'ru',
      'ja': 'ja',
      'zh_CN': 'zh-CN',
      'fi': 'en',
      'uk': 'en'
    };
    for (final entry in languages.entries) {
      final details =
          await service.lookup(ip: '8.8.8.8', languageCode: entry.key);
      expect(details, isNotNull);
      expect(details!.ip, '8.8.8.8');
      expect(details.geographyLanguage,
          entry.value == 'zh-CN' ? 'zh' : entry.value);
    }
    // en/fi/uk intentionally share the English geographic cache, NOT country UI.
    expect(adapter.requests, hasLength(4));
    expect(adapter.requests.map((o) => o.uri.queryParameters['lang']),
        ['en', 'ru', 'ja', 'zh-CN']);
    final ipv6 =
        await service.lookup(ip: '2001:4860:4860::8888', languageCode: 'ru');
    expect(ipv6?.ip, '2001:4860:4860::8888');
    expect(adapter.requests.last.uri.scheme, 'https');
    expect(adapter.requests.last.uri.host, 'ipwho.is');
    expect(adapter.requests.last.uri.path, '/2001:4860:4860::8888');
    expect(adapter.requests.last.receiveTimeout, const Duration(seconds: 5));
  });

  test('caches success by IP/language with expiry and LRU bounds', () async {
    final adapter =
        _Adapter((o) async => response(payload(o.uri.path.substring(1))));
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    var now = DateTime.utc(2026);
    final service = IpDetailsService(dio, maxCacheEntries: 2, now: () => now);
    Future<IpDetails?> get(String ip, [String lang = 'en']) =>
        service.lookup(ip: ip, languageCode: lang);
    await get('8.8.8.8');
    await get('1.1.1.1');
    await get('8.8.8.8');
    expect(adapter.requests, hasLength(2));
    await get('9.9.9.9'); // Evicts 1.1.1.1, not the recently used 8.8.8.8.
    await get('8.8.8.8');
    expect(adapter.requests, hasLength(3));
    await get('1.1.1.1');
    expect(adapter.requests, hasLength(4));
    now = now.add(const Duration(minutes: 6));
    await get('1.1.1.1');
    expect(adapter.requests, hasLength(5));
    await get('1.1.1.1', 'ru');
    expect(adapter.requests, hasLength(6));
  });

  test(
      'invalid, mismatched, rate-limited and malformed responses are not cached',
      () async {
    for (final makeResponse in <ResponseBody Function()>[
      () => response(payload('9.9.9.9')),
      () => response({'success': false}),
      () => response({}, 429),
      () => ResponseBody.fromString('bad json', 200, headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          }),
    ]) {
      var fail = true;
      final adapter = _Adapter(
          (o) async => fail ? makeResponse() : response(payload('8.8.8.8')));
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final service = IpDetailsService(dio);
      expect(await service.lookup(ip: '8.8.8.8', languageCode: 'ru'), isNull);
      fail = false;
      expect(
          await service.lookup(ip: '8.8.8.8', languageCode: 'ru'), isNotNull);
      expect(adapter.requests, hasLength(2));
      expect(await service.lookup(ip: 'not-an-ip/?lang=zh', languageCode: 'ru'),
          isNull);
      expect(adapter.requests, hasLength(2));
    }
  });

  test('cancelled lookups do not publish or cache a late response', () async {
    final pending = Completer<ResponseBody>();
    final started = Completer<void>();
    final adapter = _Adapter((_) {
      if (!started.isCompleted) started.complete();
      return pending.future;
    });
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final service = IpDetailsService(dio);
    final cancel = CancelToken();
    final lookup =
        service.lookup(ip: '8.8.8.8', languageCode: 'en', cancelToken: cancel);
    await started.future;
    cancel.cancel();
    expect(await lookup, isNull);
    pending.complete(response(payload('8.8.8.8')));
    await Future<void>.delayed(Duration.zero);
    expect(await service.lookup(ip: '8.8.8.8', languageCode: 'en'), isNotNull);
    expect(adapter.requests, hasLength(2));
    expect(
        await service.lookup(
            ip: '8.8.8.8', languageCode: 'en', cancelToken: cancel),
        isNull);
  });

  test('transport timeouts keep basic information available and allow retry',
      () async {
    final adapter = _Adapter((o) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        ));
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final service = IpDetailsService(dio);
    for (var i = 0; i < 2; i++) {
      expect(await service.lookup(ip: '8.8.8.8', languageCode: 'ru'), isNull);
    }
    expect(adapter.requests, hasLength(2));
  });
}
