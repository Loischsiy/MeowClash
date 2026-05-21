import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart';

/// Default PBKDF2 iteration count.
///
/// Matches the `ITERATIONS` constant from the Python reference
/// implementation that produces the encrypted subscription files.
const int kDefaultPbkdf2Iterations = 480000;

/// Number of bytes used for the random salt prepended to each blob.
const int _kSaltSize = 16;

/// AES block size / IV size in bytes.
const int _kIvSize = 16;

/// AES-256 key size in bytes.
const int _kKeySize = 32;

/// Raised when a downloaded subscription looks encrypted (its bytes
/// resemble the AES-256-CBC blob produced by `crypto.py`) but the
/// caller did not provide a password to decrypt it.
class SubscriptionPasswordRequiredException implements Exception {
  const SubscriptionPasswordRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Decrypts a Base64-encoded blob produced by the companion `crypto.py`
/// script (AES-256-CBC with a key derived from the supplied password via
/// PBKDF2HMAC-SHA256).
///
/// The encrypted blob layout is:
///
/// ```
///   bytes 0..15   -> PBKDF2 salt
///   bytes 16..31  -> AES-CBC IV
///   bytes 32..    -> AES-CBC ciphertext (PKCS7 padded)
/// ```
///
/// Throws a [FormatException] when the input is not valid Base64 or
/// is shorter than the expected header size.  Throws a generic
/// [Exception] when the password / iteration count are wrong (PKCS7
/// padding fails to validate).
class SubscriptionCrypto {
  const SubscriptionCrypto._();

  /// Platform channel that delegates to the host platform's native
  /// AES-256-CBC + PBKDF2 implementation (BoringSSL on Android), which
  /// is one to two orders of magnitude faster than PointyCastle.
  static const MethodChannel _nativeChannel = MethodChannel('crypto');

  /// True once we've confirmed the native crypto channel is available.
  /// `null` means the probe hasn't been performed yet.
  static bool? _nativeAvailable;

  /// Small cache of recently derived keys keyed by password + salt +
  /// iteration count.  Subscription refreshes typically re-use the
  /// same password and salt for the lifetime of the profile, so this
  /// turns the second (and subsequent) updates into pure AES-CBC
  /// operations with no PBKDF2 cost at all.
  static final _KeyCache _keyCache = _KeyCache(maxEntries: 8);

  /// Returns the PBKDF2-derived 32-byte key for [password] and [salt].
  ///
  /// Mirrors the `derive_key` helper from `crypto.py`.
  static Uint8List deriveKey(
    String password,
    Uint8List salt, {
    int iterations = kDefaultPbkdf2Iterations,
  }) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, _kKeySize));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Decrypts [encoded] (Base64 text) using [password].
  ///
  /// The optional [iterations] parameter overrides the default
  /// PBKDF2 iteration count and must match the value that was used
  /// when the file was encrypted.
  static Future<Uint8List> decryptBase64(
    String encoded, {
    required String password,
    int iterations = kDefaultPbkdf2Iterations,
  }) async {
    final cleaned = encoded
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll(' ', '')
        .trim();
    if (cleaned.isEmpty) {
      throw const FormatException('Empty encrypted payload');
    }

    final Uint8List blob;
    try {
      blob = base64.decode(cleaned);
    } on FormatException catch (e) {
      throw FormatException('Invalid Base64 payload: ${e.message}');
    }

    if (blob.length < _kSaltSize + _kIvSize + _kIvSize) {
      throw const FormatException(
        'Encrypted payload is too short to contain salt, IV and a block',
      );
    }

    final salt = Uint8List.fromList(blob.sublist(0, _kSaltSize));
    final iv = Uint8List.fromList(
      blob.sublist(_kSaltSize, _kSaltSize + _kIvSize),
    );
    final ciphertext = Uint8List.fromList(blob.sublist(_kSaltSize + _kIvSize));

    if (ciphertext.length % _kIvSize != 0) {
      throw const FormatException(
        'Ciphertext length is not a multiple of the AES block size',
      );
    }

    final cachedKey = _keyCache.lookup(password, salt, iterations);
    if (cachedKey != null) {
      return _decryptCbcWithKey(
        key: cachedKey,
        iv: iv,
        ciphertext: ciphertext,
      );
    }

    if (await _isNativeAvailable()) {
      try {
        final plaintext = await _decryptNative(
          password: password,
          salt: salt,
          iv: iv,
          ciphertext: ciphertext,
          iterations: iterations,
        );
        unawaited(_warmKeyCache(password, salt, iterations));
        return plaintext;
      } on PlatformException catch (e) {
        if (e.code == 'DECRYPT_FAILED') {
          throw Exception(
            'Failed to decrypt subscription: wrong password or iteration count',
          );
        }
        _nativeAvailable = false;
      }
    }

    return Isolate.run(() {
      final key = deriveKey(password, salt, iterations: iterations);
      return _decryptCbcWithKey(key: key, iv: iv, ciphertext: ciphertext);
    });
  }

  /// Heuristic check for whether [data] looks like a Base64 encoded
  /// AES-256-CBC blob produced by `crypto.py`.  Used by the UI to
  /// decide whether to show the decryption controls on the edit
  /// profile screen.
  ///
  /// V2Ray-style subscriptions are themselves a Base64 blob (a list
  /// of `vless://`, `vmess://`, `trojan://`, ... share-link URIs that
  /// happens to be Base64-encoded by the provider) and would otherwise
  /// pass the basic length/alignment checks for an AES-CBC payload --
  /// so we additionally peek at the decoded bytes and treat them as
  /// plaintext (not encrypted) when they look like ASCII / URI text.
  static bool looksLikeEncryptedPayload(String data) {
    final cleaned = data
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll(' ', '')
        .trim();
    if (cleaned.length < 64) {
      return false;
    }
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
    if (!base64Pattern.hasMatch(cleaned)) {
      return false;
    }
    if (cleaned.length % 4 != 0) {
      return false;
    }
    final Uint8List decoded;
    try {
      decoded = base64.decode(cleaned);
    } catch (_) {
      return false;
    }
    if (decoded.length < _kSaltSize + _kIvSize + _kIvSize) {
      return false;
    }
    if ((decoded.length - _kSaltSize - _kIvSize) % _kIvSize != 0) {
      return false;
    }
    // The decoded blob has the right length to be an AES-CBC payload,
    // but a V2Ray subscription decodes to ASCII share-link URIs.
    // Differentiate by looking at the decoded bytes themselves.
    if (_looksLikeSubscriptionPlaintext(decoded)) {
      return false;
    }
    return true;
  }

  /// Returns true when [decoded] (the result of base64-decoding a
  /// subscription blob) plausibly contains share-link URIs rather
  /// than random AES-CBC ciphertext bytes.
  ///
  /// A real encrypted blob starts with 16 random salt bytes followed
  /// by 16 random IV bytes -- random binary almost never decodes as
  /// valid UTF-8 of any meaningful length, and never contains a
  /// scheme separator `://` near the start.
  static bool _looksLikeSubscriptionPlaintext(Uint8List decoded) {
    final String text;
    try {
      text = utf8.decode(decoded, allowMalformed: false);
    } on FormatException {
      return false;
    }
    if (text.contains('://')) {
      return true;
    }
    // The provider may have wrapped the share-link list in an extra
    // base64 layer -- in which case the first decode yields more
    // base64 text that still looks like a "valid" AES-CBC payload by
    // length but is in fact ASCII.  Detect this by recursively
    // peeking one more level.
    final trimmed = text.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length >= 8 &&
        RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(trimmed) &&
        trimmed.length % 4 == 0) {
      try {
        final inner = base64.decode(trimmed);
        final innerText = utf8.decode(inner, allowMalformed: false);
        if (innerText.contains('://')) {
          return true;
        }
      } catch (_) {
        // fall through
      }
    }
    return false;
  }

  static Future<bool> _isNativeAvailable() async {
    if (_nativeAvailable != null) {
      return _nativeAvailable!;
    }
    if (kIsWeb || !Platform.isAndroid) {
      _nativeAvailable = false;
      return false;
    }
    try {
      final ok = await _nativeChannel.invokeMethod<bool>('isSupported');
      _nativeAvailable = ok == true;
    } on PlatformException {
      _nativeAvailable = false;
    } on MissingPluginException {
      _nativeAvailable = false;
    }
    return _nativeAvailable ?? false;
  }

  static Future<Uint8List> _decryptNative({
    required String password,
    required Uint8List salt,
    required Uint8List iv,
    required Uint8List ciphertext,
    required int iterations,
  }) async {
    final result = await _nativeChannel.invokeMethod<Uint8List>(
      'decryptAesCbc',
      <String, Object>{
        'password': password,
        'salt': salt,
        'iv': iv,
        'ciphertext': ciphertext,
        'iterations': iterations,
        'keyBits': _kKeySize * 8,
      },
    );
    if (result == null) {
      throw Exception('Native crypto returned an empty payload');
    }
    return result;
  }

  static Uint8List _decryptCbcWithKey({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List ciphertext,
  }) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    )..init(
        false,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );

    try {
      return cipher.process(ciphertext);
    } catch (_) {
      throw Exception(
        'Failed to decrypt subscription: wrong password or iteration count',
      );
    }
  }

  static Future<void> _warmKeyCache(
    String password,
    Uint8List salt,
    int iterations,
  ) async {
    if (_keyCache.lookup(password, salt, iterations) != null) {
      return;
    }
    final key = await Isolate.run(
      () => deriveKey(password, salt, iterations: iterations),
    );
    _keyCache.store(password, salt, iterations, key);
  }
}

class _KeyCache {
  _KeyCache({required this.maxEntries});

  final int maxEntries;
  final List<_KeyCacheEntry> _entries = <_KeyCacheEntry>[];

  Uint8List? lookup(String password, Uint8List salt, int iterations) {
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.matches(password, salt, iterations)) {
        _entries.removeAt(i);
        _entries.insert(0, entry);
        return entry.key;
      }
    }
    return null;
  }

  void store(String password, Uint8List salt, int iterations, Uint8List key) {
    _entries.removeWhere((e) => e.matches(password, salt, iterations));
    _entries.insert(
      0,
      _KeyCacheEntry(
        password: password,
        salt: Uint8List.fromList(salt),
        iterations: iterations,
        key: Uint8List.fromList(key),
      ),
    );
    while (_entries.length > maxEntries) {
      _entries.removeLast();
    }
  }
}

class _KeyCacheEntry {
  _KeyCacheEntry({
    required this.password,
    required this.salt,
    required this.iterations,
    required this.key,
  });

  final String password;
  final Uint8List salt;
  final int iterations;
  final Uint8List key;

  bool matches(String otherPassword, Uint8List otherSalt, int otherIterations) {
    if (iterations != otherIterations) return false;
    if (password != otherPassword) return false;
    if (salt.length != otherSalt.length) return false;
    for (var i = 0; i < salt.length; i++) {
      if (salt[i] != otherSalt[i]) return false;
    }
    return true;
  }
}
