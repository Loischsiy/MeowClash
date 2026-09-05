// Explicit lifecycle steps keep ordering and timer assertions readable.
// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/profile_script_evaluator.dart';

class _Runtime implements JavascriptRuntime {
  _Runtime(this.run, {this.converted, this.conversionError});
  final Future<JsEvalResult> Function(String) run;
  final Map<String, dynamic>? converted;
  final Error? conversionError;
  int disposals = 0;
  bool convertedBeforeDispose = false;
  @override
  Future<JsEvalResult> evaluateAsync(String code, {String? sourceUrl}) =>
      run(code);
  @override
  void dispose() {
    disposals++;
  }

  @override
  T? convertValue<T>(JsEvalResult value) {
    convertedBeforeDispose = disposals == 0;
    if (conversionError != null) throw conversionError!;
    return converted as T?;
  }

  @override
  String getEngineInstanceId() => 'test-${identityHashCode(this)}';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('worker preserves proxy routing and the configured loopback bypass', () {
    final overrides =
        ProfileScriptHttpOverrides('PROXY localhost:7890', '127.0.0.1');
    expect(overrides.findProxy(Uri.parse('https://example.com')),
        'PROXY localhost:7890');
    expect(overrides.findProxy(Uri.parse('http://127.0.0.1:9090')), 'DIRECT');
    expect(
        ProfileScriptHttpOverrides('DIRECT', '127.0.0.1')
            .findProxy(Uri.parse('https://example.com')),
        'DIRECT');
  });
  test('registered bridge callbacks are released with their engine', () async {
    final runtime =
        _Runtime((_) async => JsEvalResult('', <String, dynamic>{}));
    final id = runtime.getEngineInstanceId();
    JavascriptRuntime.channelFunctionsRegistered[id] = {
      'retainsRuntime': (_) => runtime
    };
    await evaluateProfileScript('', {}, createRuntime: () => runtime);
    expect(
        JavascriptRuntime.channelFunctionsRegistered.containsKey(id), isFalse);
  });

  test('one-shot and periodic callbacks cannot outlive the engine', () async {
    var callbacks = 0;
    final timers = <Timer>[];
    final runtime = _Runtime((_) async {
      timers.add(Timer(const Duration(milliseconds: 10), () {
        callbacks++;
      }));
      timers.add(Timer.periodic(const Duration(milliseconds: 10), (_) {
        callbacks++;
      }));
      return JsEvalResult('', <String, dynamic>{});
    });
    await evaluateProfileScript('', {}, createRuntime: () => runtime);
    expect(timers.every((timer) => !timer.isActive), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(callbacks, 0);
  });

  test('native JavaScript transformations work in short-lived isolates',
      () async {
    for (var i = 0; i < 10; i++) {
      final result = await evaluateProfileScript('''
        function main(config) {
          setTimeout(function() { throw new Error('late callback'); }, 1);
          config.rules.push('MATCH,DIRECT');
          config.nested.value += 1;
          if (typeof fetch !== 'function' || typeof XMLHttpRequest !== 'function') {
            throw new Error('missing HTTP helpers');
          }
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
  }, skip: !Platform.isMacOS);

  test('successful script releases its engine after Dart result conversion',
      () async {
    final runtime = _Runtime((code) async => JsEvalResult('', {
          'rules': ['DIRECT'],
          'port': 7890
        }));
    final result = await evaluateProfileScript(
        'function main(c) { return c; }', {},
        createRuntime: () => runtime);
    expect(result, {
      'rules': ['DIRECT'],
      'port': 7890
    });
    expect(runtime.disposals, 1);
  });

  test('FFI result is materialized before releasing the native context',
      () async {
    final runtime = _Runtime(
        (_) async => JsEvalResult('', Pointer<Void>.fromAddress(1)),
        converted: {
          'rules': ['DIRECT']
        });
    final result =
        await evaluateProfileScript('', {}, createRuntime: () => runtime);
    expect(result['rules'], ['DIRECT']);
    expect(runtime.convertedBeforeDispose, isTrue);
    expect(runtime.disposals, 1);
  });

  test('null native conversion preserves config fallback and still disposes',
      () async {
    final runtime =
        _Runtime((_) async => JsEvalResult('', Pointer<Void>.fromAddress(1)));
    final config = <String, dynamic>{'port': 7890};
    expect(
        await evaluateProfileScript('', config, createRuntime: () => runtime),
        same(config));
    expect(runtime.disposals, 1);
  });

  test('JavaScript errors preserve the original error and dispose once',
      () async {
    final runtime = _Runtime(
        (_) async => JsEvalResult('bad override', null, isError: true));
    await expectLater(
        evaluateProfileScript('', {}, createRuntime: () => runtime),
        throwsA('bad override'));
    expect(runtime.disposals, 1);
  });

  test('async evaluation failure releases the runtime', () async {
    final runtime =
        _Runtime((_) async => throw StateError('evaluation failed'));
    await expectLater(
        evaluateProfileScript('', {}, createRuntime: () => runtime),
        throwsStateError);
    expect(runtime.disposals, 1);
  });

  test('bad Dart result conversion still releases the runtime', () async {
    final runtime = _Runtime((_) async => JsEvalResult('', 42));
    await expectLater(
        evaluateProfileScript('', {}, createRuntime: () => runtime),
        throwsA(isA<TypeError>()));
    expect(runtime.disposals, 1);
  });

  test('bad FFI conversion still releases the runtime', () async {
    final runtime = _Runtime(
        (_) async => JsEvalResult('', Pointer<Void>.fromAddress(1)),
        conversionError: StateError('conversion failed'));
    await expectLater(
        evaluateProfileScript('', {}, createRuntime: () => runtime),
        throwsStateError);
    expect(runtime.disposals, 1);
  });

  test('engine lives until evaluation completes and input is JSON escaped',
      () async {
    final blocked = Completer<JsEvalResult>();
    String? source;
    final runtime = _Runtime((code) {
      source = code;
      return blocked.future;
    });
    final config = <String, dynamic>{'name': 'quoted " value\\newline\n日本'};
    final result = evaluateProfileScript(
        'function main(c) { return c; }', config,
        createRuntime: () => runtime);
    expect(source, contains(jsonEncode(config)));
    expect(runtime.disposals, 0);
    blocked.complete(JsEvalResult('', config));
    expect(await result, config);
    expect(runtime.disposals, 1);
  });
}
