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
    final bytes = await _download(plan, target, cancellation).timeout(
      const Duration(minutes: 1),
      onTimeout: () {
        cancellation.cancel('Provider download timed out');
        throw TimeoutException('Provider download timed out');
      },
    );
    if (cancellation.isCancelled) throw StateError('Provider update cancelled');
    final result = await decryptProviderPayload(
      bytes,
      password: plan.password,
      iterations: plan.iterations,
    );
    if (cancellation.isCancelled) throw StateError('Provider update cancelled');
    return result;
  }

  Future<Uint8List> _download(
    ProviderRefreshPlan plan,
    ProviderRefreshTarget target,
    CancelToken cancellation,
  ) async {
    final headers = Map<String, dynamic>.from(target.headers);
    if (!headers.keys.any((key) => key.toLowerCase() == 'user-agent')) {
      headers['User-Agent'] = plan.userAgent;
    }
    final response = await _dio.get<ResponseBody>(
      target.url,
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
      return buffer.takeBytes();
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
