import 'dart:io';

import 'package:meowclash/common/common.dart';
import 'package:path/path.dart';

/// Resolves the on-disk location of a bundled zapret2 engine binary without
/// hardcoding any absolute path (requirement: "никаких хардкод-путей").
///
/// Layout mirrors how setup.dart stages binaries next to MeowClashCore:
///   - Windows/Linux: `<executableDir>/zapret/<name>`
///   - macOS: `Application Support/com.meowclash.app/zapret/<name>` (staged like
///     the core), with an executable-dir fallback.
///   - Android: not a file path — the nfqws seam is native, so callers use the
///     backend directly rather than this resolver.
/// A `customPath` (from settings) always wins when non-empty.
class ZapretBinaryResolver {
  const ZapretBinaryResolver();

  /// Returns the first existing candidate path for [binaryName], or null when
  /// nothing is bundled (backend then reports [missingBinary]).
  Future<String?> resolve(String binaryName, {String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      return await File(customPath).exists() ? customPath : null;
    }
    for (final candidate in await _candidates(binaryName)) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  Future<List<String>> _candidates(String binaryName) async {
    final execDir = appPath.executableDirPath;
    final candidates = <String>[
      join(execDir, "zapret", binaryName),
      join(execDir, binaryName),
    ];
    if (Platform.isMacOS) {
      final home = Platform.environment["HOME"] ?? "";
      if (home.isNotEmpty) {
        candidates.add(join(
          home,
          "Library",
          "Application Support",
          "com.meowclash.app",
          "zapret",
          binaryName,
        ));
      }
    }
    // Allow a portable/dev override via environment (still not hardcoded).
    final envDir = Platform.environment["ZAPRET2_BIN_DIR"];
    if (envDir != null && envDir.isNotEmpty) {
      candidates.insert(0, join(envDir, binaryName));
    }
    return candidates;
  }
}

const zapretBinaryResolver = ZapretBinaryResolver();
