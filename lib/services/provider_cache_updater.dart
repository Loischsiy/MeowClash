import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meowclash/common/core_input_guard.dart';

import 'provider_payload.dart';
import 'subscription_crypto.dart';

/// Why a provider could not be brought into the local cache. The UI maps these
/// to localized text; the English [message] is the log/test-facing fallback.
enum ProviderFailureReason {
  passwordRequired,
  wrongPassword,
  download,
  pathUnavailable,
}

class ProviderFetchException implements Exception {
  const ProviderFetchException(this.reason, this.providerName, [this.cause]);

  final ProviderFailureReason reason;
  final String providerName;
  final Object? cause;

  String get message => switch (reason) {
        ProviderFailureReason.passwordRequired =>
          'Provider "$providerName" is encrypted but no decryption password '
              'is set for this profile',
        ProviderFailureReason.wrongPassword =>
          'Provider "$providerName" could not be decrypted: wrong password '
              'or iteration count',
        ProviderFailureReason.download =>
          'Provider "$providerName" could not be downloaded'
              '${cause == null ? '' : ' (${cause.runtimeType})'}',
        ProviderFailureReason.pathUnavailable =>
          'The core did not report a cache path for provider "$providerName"',
      };

  @override
  String toString() => message;
}

class ProviderCacheRequest {
  const ProviderCacheRequest({
    required this.kind,
    required this.name,
    required this.url,
    required this.path,
    required this.userAgent,
    this.headers = const {},
    this.password,
    this.iterations = kDefaultPbkdf2Iterations,
  });

  /// `proxies` or `rules`, exactly as the core names them.
  final String kind;
  final String name;
  final String url;

  /// Always the path reported by the core (getProviderCachePath).
  final String path;
  final String userAgent;
  final Map<String, dynamic> headers;
  final String? password;
  final int iterations;
}

typedef ProviderDownloadFn = Future<ProviderDownload> Function(
  ProviderCacheRequest request,
  CancelToken cancellation,
);
typedef ProviderCacheWriteFn = Future<void> Function(
  String path,
  Uint8List bytes,
);

/// The one place that turns a provider URL into a decrypted cache file.
/// Preload, the scheduler and manual refresh all call it, so two callers asking
/// for the same cache file at the same time share a single download.
class ProviderCacheUpdater {
  ProviderCacheUpdater({
    required this.download,
    ProviderCacheWriteFn? write,
  }) : _write = write ?? writeProviderCache;

  final ProviderDownloadFn download;
  final ProviderCacheWriteFn _write;
  final _inFlight = <String, Future<Uint8List>>{};
  final _cancellations = <CancelToken>{};

  /// Cancels every running download (profile switch, shutdown). Results of
  /// cancelled work are never written.
  void cancelAll() {
    for (final token in _cancellations.toList()) {
      token.cancel('Provider context changed');
    }
    _inFlight.clear();
  }

  bool isRefreshing(String path) => _inFlight.containsKey(path);

  /// Downloads, decrypts and atomically writes [request.path].
  ///
  /// [beforeCommit] runs on the decrypted bytes before they reach the disk (the
  /// scheduler uses it to side-load into a running core); throwing from it
  /// leaves the previous cache untouched.
  Future<Uint8List> refresh(
    ProviderCacheRequest request, {
    Future<void> Function(Uint8List bytes)? beforeCommit,
  }) {
    final existing = _inFlight[request.path];
    if (existing != null) return existing;
    final cancellation = CancelToken();
    _cancellations.add(cancellation);
    late final Future<Uint8List> future;
    future = () async {
      try {
        final bytes = await _fetch(request, cancellation);
        if (cancellation.isCancelled) {
          throw ProviderFetchException(
              ProviderFailureReason.download, request.name, 'cancelled');
        }
        if (beforeCommit != null) await beforeCommit(bytes);
        if (cancellation.isCancelled) {
          throw ProviderFetchException(
              ProviderFailureReason.download, request.name, 'cancelled');
        }
        await _write(request.path, bytes);
        return bytes;
      } finally {
        _cancellations.remove(cancellation);
        if (identical(_inFlight[request.path], future)) {
          unawaited(_inFlight.remove(request.path));
        }
      }
    }();
    _inFlight[request.path] = future;
    return future;
  }

  Future<Uint8List> _fetch(
    ProviderCacheRequest request,
    CancelToken cancellation,
  ) async {
    final ProviderDownload downloaded;
    try {
      downloaded = await download(request, cancellation);
    } on CoreInputTooLargeException {
      rethrow;
    } catch (error) {
      throw ProviderFetchException(
          ProviderFailureReason.download, request.name, error);
    }
    // Profile credentials win; response headers are the fallback.
    var password = request.password;
    var iterations = request.iterations;
    if (password == null || password.isEmpty) {
      password = downloaded.headers['meowclash-password'];
      iterations =
          int.tryParse(downloaded.headers['meowclash-password-iterations'] ?? '') ??
              iterations;
    }
    try {
      return await decryptProviderPayload(
        downloaded.bytes,
        password: password,
        iterations: iterations,
      );
    } on SubscriptionPasswordRequiredException {
      throw ProviderFetchException(
          ProviderFailureReason.passwordRequired, request.name);
    } on CoreInputTooLargeException {
      rethrow;
    } catch (error) {
      throw ProviderFetchException(
          ProviderFailureReason.wrongPassword, request.name, error);
    }
  }
}
