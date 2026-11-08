import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meowclash/common/core_input_guard.dart';

import 'provider_refresh_plan.dart';
import 'subscription_crypto.dart';

/// No widget, AppController, global app state or UI isolate is required.
Future<Uint8List> decryptProviderPayload(
  Uint8List bytes, {
  required String? password,
  required int iterations,
}) async {
  ensureCoreInputBytes(bytes, name: 'Provider');
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return bytes; // Binary MRS data must not be converted to UTF-8.
  }
  if (!SubscriptionCrypto.looksLikeEncryptedPayload(text)) return bytes;
  if (password == null || password.isEmpty) {
    throw const SubscriptionPasswordRequiredException(
        'Provider password required');
  }
  final result = await SubscriptionCrypto.decryptBase64(
    text,
    password: password,
    iterations: iterations,
  );
  ensureCoreInputBytes(result, name: 'Provider');
  return result;
}

/// Raw provider bytes plus the (lower-cased) response headers, which may carry
/// the `meowclash-password` credentials when the profile has none stored.
class ProviderDownload {
  const ProviderDownload(this.bytes, this.headers);
  final Uint8List bytes;
  final Map<String, String> headers;
}

class ProviderPayloadDownloader {
  ProviderPayloadDownloader({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ));

  final Dio _dio;

  Future<Uint8List> fetch(
    ProviderRefreshPlan plan,
    ProviderRefreshTarget target,
    CancelToken cancellation,
  ) async {
    final fetched = await download(
      url: target.url,
      headers: target.headers,
      userAgent: plan.userAgent,
      cancellation: cancellation,
    );
    if (cancellation.isCancelled) throw StateError('Provider update cancelled');
    // Profile credentials win; the response headers are the fallback.
    var password = plan.password;
    var iterations = plan.iterations;
    if (password == null || password.isEmpty) {
      password = fetched.headers['meowclash-password'];
      iterations = int.tryParse(
              fetched.headers['meowclash-password-iterations'] ?? '') ??
          iterations;
    }
    final result = await decryptProviderPayload(
      fetched.bytes,
      password: password,
      iterations: iterations,
    );
    if (cancellation.isCancelled) throw StateError('Provider update cancelled');
    return result;
  }

  /// One network request, bounded by a one-minute deadline. Every provider
  /// download of the app goes through here (preload, scheduler, manual).
  Future<ProviderDownload> download({
    required String url,
    required Map<String, dynamic> headers,
    required String userAgent,
    required CancelToken cancellation,
  }) =>
      _download(url, headers, userAgent, cancellation).timeout(
        const Duration(minutes: 1),
        onTimeout: () {
          cancellation.cancel('Provider download timed out');
          throw TimeoutException('Provider download timed out');
        },
      );

  Future<ProviderDownload> _download(
    String url,
    Map<String, dynamic> targetHeaders,
    String userAgent,
    CancelToken cancellation,
  ) async {
    final headers = Map<String, dynamic>.from(targetHeaders);
    if (!headers.keys.any((key) => key.toLowerCase() == 'user-agent')) {
      headers['User-Agent'] = userAgent;
    }
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancellation,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final body = response.data;
    if (body == null) throw const FormatException('Empty provider response');
    try {
      ensureCoreInputHeaderFits(
        response.headers.value(HttpHeaders.contentLengthHeader),
        name: 'Provider',
      );
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in body.stream) {
        ensureCoreInputSize(buffer.length + chunk.length, name: 'Provider');
        buffer.add(chunk);
      }
      return ProviderDownload(buffer.takeBytes(), {
        for (final entry in response.headers.map.entries)
          if (entry.value.isNotEmpty) entry.key.toLowerCase(): entry.value.first,
      });
    } catch (_) {
      cancellation.cancel('Provider download rejected');
      rethrow;
    }
  }

  void close() => _dio.close(force: true);
}

Future<DateTime> providerCacheModifiedAt(String path) async {
  // Do not block service IPC while checking provider cache metadata.
  // ignore: avoid_slow_async_io
  final stat = await File(path).stat();
  return stat.type == FileSystemEntityType.file
      ? stat.modified.toUtc()
      : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Called only after the core accepts a refresh (bootstrap writes are separate).
Future<void> writeProviderCache(String path, Uint8List bytes) async {
  ensureCoreInputBytes(bytes, name: 'Provider');
  final file = File(path);
  await file.parent.create(recursive: true);
  final temporary = File('$path.tmp.${DateTime.now().microsecondsSinceEpoch}');
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(path);
  } finally {
    // Keep cleanup asynchronous on the service isolate too.
    // ignore: avoid_slow_async_io
    if (await temporary.exists()) await temporary.delete();
  }
}
