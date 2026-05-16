import 'dart:convert';

import 'package:meowclash/services/subscription_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies that the Dart implementation in [SubscriptionCrypto] is
/// binary compatible with the Python `crypto.py` reference script.
///
/// The fixtures below were produced with:
///
/// ```
///   python crypto.py enc -i sample.yaml -o sample.enc -p testpass123
/// ```
///
/// against the YAML content stored in [_kExpectedPlaintext].
void main() {
  const expectedPlaintext = _kExpectedPlaintext;
  const password = 'testpass123';
  const encrypted =
      '+0tbzxMkCQGUYEJqAWN+nD9mL7/2lRB9fS+B86IN/LwPL9QwLzY2+kqTPRAPYyNZ'
      'aGb5jFbn/lgQtBucrPYwzqrDZ50nT8Ms85BJKQDUGXWbh6yajX70+4TPSfHeDDx/'
      'elkhGA9mTCgsF2scgj4z0sIDzk6/i1+npnmdvgcn+vvWBIAdJzl3HRU2OayTDY+J';

  group('SubscriptionCrypto', () {
    test('decrypts a payload produced by crypto.py', () {
      final plaintext = SubscriptionCrypto.decryptBase64(
        encrypted,
        password: password,
      );
      expect(utf8.decode(plaintext), expectedPlaintext);
    });

    test('rejects the wrong password', () {
      expect(
        () => SubscriptionCrypto.decryptBase64(
          encrypted,
          password: 'wrong-password',
        ),
        throwsException,
      );
    });

    test('rejects a mismatched iteration count', () {
      expect(
        () => SubscriptionCrypto.decryptBase64(
          encrypted,
          password: password,
          iterations: 100,
        ),
        throwsException,
      );
    });

    test('rejects non-Base64 garbage', () {
      expect(
        () => SubscriptionCrypto.decryptBase64(
          'this is not base64!',
          password: password,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('looksLikeEncryptedPayload recognises Base64 blobs', () {
      expect(SubscriptionCrypto.looksLikeEncryptedPayload(encrypted), isTrue);
      expect(
        SubscriptionCrypto.looksLikeEncryptedPayload(expectedPlaintext),
        isFalse,
      );
    });
  });
}

const String _kExpectedPlaintext = '''mixed-port: 7890
external-controller: 127.0.0.1:9090
proxies: []
proxy-groups: []
rules:
  - MATCH,DIRECT
''';
