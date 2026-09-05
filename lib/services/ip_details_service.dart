import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meowclash/models/ip_details.dart';

/// On-demand only: opening details never adds work to dashboard polling.
/// The injected client must use the same proxy routing as IP detection.
class IpDetailsService {
  IpDetailsService(
    this._dio, {
    this.cacheLifetime = const Duration(minutes: 5),
    this.maxCacheEntries = 16,
    DateTime Function()? now,
  })  : assert(maxCacheEntries > 0, 'Cache size must be positive'),
        _now = now ?? DateTime.now;

  final Dio _dio;
  final Duration cacheLifetime;
  final int maxCacheEntries;
  final DateTime Function() _now;
  final _cache = <(String, String), ({IpDetails details, DateTime expires})>{};

  /// ipwho.is supports these app languages. Finnish and Ukrainian geographic
  /// names explicitly fall back to English, not the service/browser default.
  /// Country names are localized offline for ALL app languages separately.
  static String geographyLanguage(String languageCode) =>
      switch (languageCode.toLowerCase().split(RegExp('[-_]')).first) {
        'ru' => 'ru',
        'ja' => 'ja',
        'zh' => 'zh',
        _ => 'en',
      };

  Future<IpDetails?> lookup({
    required String ip,
    required String languageCode,
    CancelToken? cancelToken,
  }) async {
    final address = InternetAddress.tryParse(ip);
    if (address == null || cancelToken?.isCancelled == true) return null;
    final language = geographyLanguage(languageCode);
    final key = (address.address, language);
    final cached = _cache.remove(key);
    if (cached != null && _now().isBefore(cached.expires)) {
      _cache[key] = cached;
      return cached.details;
    }

    final uri = Uri.https('ipwho.is', '/${address.address}', {
      'lang': language == 'zh' ? 'zh-CN' : language,
    });
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        uri.toString(),
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      if (cancelToken?.isCancelled == true ||
          response.statusCode != HttpStatus.ok ||
          response.data == null) {
        return null;
      }
      final details = IpDetails.fromJson(
        response.data!,
        geographyLanguage: language,
      );
      // A VPN/profile switch must not mix the old IP with the new exit's data.
      if (InternetAddress.tryParse(details.ip) != address) return null;
      _cache[key] = (
        details: details,
        expires: _now().add(cacheLifetime),
      );
      while (_cache.length > maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      return details;
    } on Exception {
      // Keep the already detected IP/country usable on timeout, rate limiting,
      // invalid JSON, offline operation or cancellation. Failures aren't cached.
      return null;
    }
  }
}
