import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/trusted_roots.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._data);

  final Map<String, Uint8List> _data;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount++;
    final bytes = _data[key];
    if (bytes == null) {
      throw StateError('Asset not found: $key');
    }
    return ByteData.sublistView(bytes);
  }
}

void main() {
  group('Windows bundled Mozilla CA roots', () {
    late Uint8List bundleBytes;

    setUpAll(() {
      final file = File(bundledCaAssetPath);
      expect(file.existsSync(), isTrue, reason: 'cacert.pem asset must exist');
      bundleBytes = file.readAsBytesSync();
    });

    test('cacert.pem contains valid PEM certificates including ISRG Root X1',
        () {
      final pemText = String.fromCharCodes(bundleBytes);
      expect(pemText, contains('-----BEGIN CERTIFICATE-----'));
      expect(pemText, contains('-----END CERTIFICATE-----'));
      expect(pemText, contains('ISRG Root X1'));
    });

    test('applyTrustedRootsPem loads bundle into SecurityContext cleanly', () {
      final context = SecurityContext(withTrustedRoots: true);
      expect(
        () => applyTrustedRootsPem(bundleBytes, context: context),
        returnsNormally,
      );
      // Applying again on a context that already holds the roots must not fail.
      expect(
        () => applyTrustedRootsPem(bundleBytes, context: context),
        returnsNormally,
      );
    });

    test('initWindowsTrustedRoots is a no-op off Windows', () async {
      final fakeBundle = _FakeAssetBundle({bundledCaAssetPath: bundleBytes});
      final context = SecurityContext(withTrustedRoots: true);

      await initWindowsTrustedRoots(
        isWindowsOverride: false,
        bundle: fakeBundle,
        context: context,
      );

      expect(fakeBundle.loadCount, 0);
    });

    test('initWindowsTrustedRoots loads and applies bundle on Windows',
        () async {
      final fakeBundle = _FakeAssetBundle({bundledCaAssetPath: bundleBytes});
      final context = SecurityContext(withTrustedRoots: true);

      await initWindowsTrustedRoots(
        isWindowsOverride: true,
        bundle: fakeBundle,
        context: context,
      );

      expect(fakeBundle.loadCount, 1);
    });
  });
}
