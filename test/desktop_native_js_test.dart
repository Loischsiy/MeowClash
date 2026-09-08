import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/profile_script_evaluator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // CI supplies the freshly built target-architecture bridge, not pub's x64 DLL.
  final enabled = Platform.environment['MEOW_NATIVE_JS_SMOKE'] == '1' &&
      (Platform.isWindows || Platform.isLinux);
  test('desktop native profile scripts preserve helpers and isolate cleanup',
      () async {
    for (var i = 0; i < 10; i++) {
      final result = await evaluateProfileScript('''
        function main(config) {
          setTimeout(function() { throw new Error('late callback'); }, 1);
          if (typeof fetch !== 'function' || typeof XMLHttpRequest !== 'function') {
            throw new Error('missing HTTP helpers');
          }
          config.rules.push('MATCH,DIRECT');
          config.nested.value += 1;
          return config;
        }
      ''', {
        'rules': <String>[],
        'nested': {'value': i}
      });
      expect(result, {
        'rules': ['MATCH,DIRECT'],
        'nested': {'value': i + 1}
      });
    }
  }, skip: !enabled);
}
