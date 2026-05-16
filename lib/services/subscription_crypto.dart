import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

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
  }) {
    return Isolate.run(() {
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

      final salt = Uint8List.sublistView(blob, 0, _kSaltSize);
      final iv = Uint8List.sublistView(blob, _kSaltSize, _kSaltSize + _kIvSize);
      final ciphertext = Uint8List.sublistView(blob, _kSaltSize + _kIvSize);

      if (ciphertext.length % _kIvSize != 0) {
        throw const FormatException(
          'Ciphertext length is not a multiple of the AES block size',
        );
      }

      final key = deriveKey(password, salt, iterations: iterations);

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
    });
  }

  /// Heuristic check for whether [data] looks like a Base64 encoded
  /// AES-256-CBC blob produced by `crypto.py`.  Used by the UI to
  /// decide whether to show the decryption controls on the edit
  /// profile screen.
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
    try {
      final decoded = base64.decode(cleaned);
      return decoded.length >= _kSaltSize + _kIvSize + _kIvSize &&
          (decoded.length - _kSaltSize - _kIvSize) % _kIvSize == 0;
    } catch (_) {
      return false;
    }
  }
}
