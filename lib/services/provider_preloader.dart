import 'dart:async';
import 'dart:io';

import 'provider_cache_updater.dart';
import 'subscription_crypto.dart';

const _sections = {'proxy-providers': 'proxies', 'rule-providers': 'rules'};

/// Size and age of a provider cache file; null when absent or empty.
typedef ProviderCacheStat = Future<DateTime?> Function(String path);

Future<DateTime?> statProviderCache(String path) async {
  // ignore: avoid_slow_async_io
  final stat = await File(path).stat();
  if (stat.type != FileSystemEntityType.file || stat.size == 0) return null;
  return stat.modified.toUtc();
}

class ProviderPreloadResult {
  const ProviderPreloadResult(this.warnings);

  /// Providers that kept an older cache because the refresh failed.
  final List<ProviderFetchException> warnings;
}

/// Runs before `setupConfig`. Marks every http provider with a url as
/// `meowclash-external` (the core then reads only the cache and never touches
/// the network) and makes sure the cache file the core will read exists.
class ProviderPreloader {
  ProviderPreloader({
    required this.resolvePath,
    required this.updater,
    ProviderCacheStat? stat,
    DateTime Function()? now,
    this.concurrency = 4,
  })  : _stat = stat ?? statProviderCache,
        _now = now ?? DateTime.now;

  /// Asks the core for the cache path; an empty answer means "unknown".
  final Future<String> Function(String kind, String url) resolvePath;
  final ProviderCacheUpdater updater;
  final ProviderCacheStat _stat;
  final DateTime Function() _now;
  final int concurrency;

  /// Mutates [config] in place (sections and provider maps may be shared with
  /// the caller) and throws [ProviderFetchException] when a provider has no
  /// usable cache and could not be fetched.
  Future<ProviderPreloadResult> prepare(
    Map config, {
    required String userAgent,
    String? password,
    int iterations = kDefaultPbkdf2Iterations,
  }) async {
    final jobs = <Future<void> Function()>[];
    final warnings = <ProviderFetchException>[];
    ProviderFetchException? failure;

    for (final section in _sections.entries) {
      final providers = config[section.key];
      if (providers is! Map) continue;
      for (final entry in providers.entries) {
        final provider = entry.value;
        if (provider is! Map || provider['type'] != 'http') continue;
        final url = provider['url'];
        if (url is! String || url.isEmpty) continue;
        final name = entry.key.toString();
        final String path;
        try {
          path = await resolvePath(section.value, url);
        } catch (_) {
          throw ProviderFetchException(ProviderFailureReason.pathUnavailable, name);
        }
        if (path.isEmpty) {
          throw ProviderFetchException(ProviderFailureReason.pathUnavailable, name);
        }
        // The core derives the very same path from the url when `path` is
        // absent, which is what keeps preload and core in step.
        provider.remove('path');
        provider['meowclash-external'] = true;
        final interval = int.tryParse('${provider['interval']}') ?? 0;
        final request = ProviderCacheRequest(
          kind: section.value,
          name: name,
          url: url,
          path: path,
          userAgent: userAgent,
          headers: Map<String, dynamic>.from(
              provider['header'] is Map ? provider['header'] as Map : const {}),
          password: password,
          iterations: iterations,
        );
        jobs.add(() async {
          final cachedAt = await _stat(path);
          final stale = cachedAt != null &&
              interval > 0 &&
              _now().toUtc().difference(cachedAt) >= Duration(seconds: interval);
          if (cachedAt != null && !stale) return;
          try {
            await updater.refresh(request);
          } on ProviderFetchException catch (error) {
            if (cachedAt != null) {
              warnings.add(error);
            } else {
              failure ??= error;
            }
          }
        });
      }
    }

    var next = 0;
    Future<void> worker() async {
      while (next < jobs.length) {
        await jobs[next++]();
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency && i < jobs.length; i++) worker(),
    ]);
    if (failure != null) throw failure!;
    return ProviderPreloadResult(warnings);
  }
}
