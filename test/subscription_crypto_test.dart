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
    test('decrypts a payload produced by crypto.py', () async {
      final plaintext = await SubscriptionCrypto.decryptBase64(
        encrypted,
        password: password,
      );
      expect(utf8.decode(plaintext), expectedPlaintext);
    });

    test('rejects the wrong password', () async {
      expect(
        () async => await SubscriptionCrypto.decryptBase64(
          encrypted,
          password: 'wrong-password',
        ),
        throwsException,
      );
    });

    test('rejects a mismatched iteration count', () async {
      expect(
        () async => await SubscriptionCrypto.decryptBase64(
          encrypted,
          password: password,
          iterations: 100,
        ),
        throwsException,
      );
    });

    test('rejects non-Base64 garbage', () async {
      expect(
        () async => await SubscriptionCrypto.decryptBase64(
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

    test('looksLikeEncryptedPayload rejects V2Ray base64 subscriptions', () {
      // Standard V2Ray-style subscription: a newline-separated list of
      // share-link URIs (vless://, vmess://, trojan://, ss://, ...)
      // that the provider returns base64-encoded. None of these are
      // encrypted -- they must NOT trigger the password prompt.
      const plainList = 'vless://[email protected]:443?type=tcp&security=tls#A\n'
          'vmess://eyJhZGQiOiJleGFtcGxlLmNvbSIsImFpZCI6IjAiLCJob3N0IjoiIiwiaWQiOiJjMjMzMTk2NS01M2NkLTQ0YzAtOTM1ZS0xZjA2Y2I3M2I3MzIiLCJuZXQiOiJ3cyIsInBhdGgiOiIvIiwicG9ydCI6IjQ0MyIsInBzIjoiVmlubmV0IiwidGxzIjoidGxzIiwidHlwZSI6IiIsInYiOiIyIn0=\n'
          'trojan://[email protected]:443?sni=example.com#C\n'
          'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@example.com:8388#D\n';
      final b64 = base64.encode(utf8.encode(plainList));
      expect(SubscriptionCrypto.looksLikeEncryptedPayload(b64), isFalse);

      // Same content but double-base64 wrapped, which a few providers
      // still do.
      final doubleB64 = base64.encode(utf8.encode(b64));
      expect(
        SubscriptionCrypto.looksLikeEncryptedPayload(doubleB64),
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
