import 'dart:io';

import 'package:flutter/services.dart';
import 'package:meowclash/common/print.dart';

/// Bundled Mozilla CA root certificates (from https://curl.se/ca/cacert.pem).
///
/// Used on Windows to work around Dart's BoringSSL integration not triggering
/// Windows' lazy root certificate download (dart-lang/sdk#52266).
const String bundledCaAssetPath = 'assets/data/cacert.pem';

Uint8List? _bundledCaBytes;
bool _windowsRootsApplied = false;

/// Cached PEM bytes loaded on Windows so worker isolates can apply the same
/// roots without touching [rootBundle].
Uint8List? get bundledTrustedRootsBytes => _bundledCaBytes;

/// Appends the PEM-encoded CA bundle in [pemBytes] to [context] (or
/// [SecurityContext.defaultContext]) without removing existing OS/user roots.
void applyTrustedRootsPem(
  Uint8List pemBytes, {
  SecurityContext? context,
}) {
  (context ?? SecurityContext.defaultContext)
      .setTrustedCertificatesBytes(pemBytes);
}

/// Loads the bundled Mozilla CA roots into [SecurityContext.defaultContext] on
/// Windows. No-op on other platforms and idempotent on repeated calls.
Future<void> initWindowsTrustedRoots({
  bool? isWindowsOverride,
  AssetBundle? bundle,
  SecurityContext? context,
}) async {
  final isWindows = isWindowsOverride ?? Platform.isWindows;
  if (!isWindows) return;
  if (context == null && _windowsRootsApplied) return;

  try {
    final data = await (bundle ?? rootBundle).load(bundledCaAssetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    applyTrustedRootsPem(bytes, context: context);
    if (context == null) {
      _bundledCaBytes = bytes;
      _windowsRootsApplied = true;
    }
    commonPrint.log(
      '[DART] Loaded bundled Mozilla CA roots (${bytes.length} bytes)',
    );
  } catch (e) {
    commonPrint.log(
      '[DART] Failed to load bundled Mozilla CA roots: $e',
    );
  }
}
