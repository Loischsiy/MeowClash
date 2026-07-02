import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:path/path.dart';

/// Abstracts where the cache JSON lives so tests can supply an in-memory or
/// temp-dir store instead of the real app data directory.
abstract class Zapret2CacheStore {
  Future<String?> read();
  Future<void> write(String contents);
  Future<void> delete();
}

/// Default store: a single JSON file at `<homeDir>/zapret2/strategy_cache.json`.
/// Kept as its own file (not inside the SharedPreferences config blob) because,
/// like profiles, it is engine/version-scoped state with its own lifecycle.
class FileZapret2CacheStore implements Zapret2CacheStore {
  const FileZapret2CacheStore(this._resolveDir);

  /// Returns the directory that holds the cache file (created if missing).
  final Future<String> Function() _resolveDir;

  Future<File> _file() async {
    final dir = Directory(await _resolveDir());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(join(dir.path, "strategy_cache.json"));
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String contents) async {
    final file = await _file();
    // Atomic-ish write: temp then rename, matching the profile save pattern.
    final tmp = File("${file.path}.tmp");
    await tmp.writeAsString(contents);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Persists, loads and invalidates the selected-strategy cache. All parsing is
/// defensive: a corrupt or schema-drifted file is treated as "no cache" rather
/// than throwing, so a bad file can never brick the feature.
class Zapret2StrategyCache {
  const Zapret2StrategyCache(this.store);

  final Zapret2CacheStore store;

  /// Loads and returns the cache, or null if absent/unparseable.
  Future<Zapret2Cache?> load() async {
    try {
      final raw = await store.read();
      if (raw == null || raw.trim().isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return Zapret2Cache.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached selection only if it is still valid for the current
  /// engine version, platform and target set; otherwise null (forcing a fresh
  /// auto-selection). This is the single reuse gate used at startup.
  Future<Zapret2Cache?> loadValid({
    required String engineVersion,
    required SupportPlatform platform,
    required List<Zapret2Target> targets,
  }) async {
    final cache = await load();
    if (cache == null) return null;
    final valid = cache.isValidFor(
      engineVersion: engineVersion,
      platform: platform,
      targets: targets,
    );
    return valid ? cache : null;
  }

  Future<void> save(Zapret2Cache cache) async {
    await store.write(jsonEncode(cache.toJson()));
  }

  /// "Перепроверить/сбросить" — drop the cached selection entirely.
  Future<void> invalidate() async {
    await store.delete();
  }
}
