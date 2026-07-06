import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/core_input_guard.dart';

void main() {
  group('core input guard', () {
    test('allows data at the limit', () {
      ensureCoreInputSize(maxCoreInputBytes, name: 'Profile');
    });

    test('blocks bytes over the limit', () {
      expect(
        () => ensureCoreInputBytes(
          Uint8List(maxCoreInputBytes + 1),
          name: 'Provider',
        ),
        throwsA(isA<CoreInputTooLargeException>()),
      );
    });

    test('blocks files over the limit', () async {
      final file = File('${Directory.systemTemp.path}/meowclash-big-profile');
      await file.writeAsBytes(Uint8List(maxCoreInputBytes + 1));
      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      expect(
        () => ensureCoreInputFileFits(file, name: 'Profile'),
        throwsA(isA<CoreInputTooLargeException>()),
      );
    });
  });
}
