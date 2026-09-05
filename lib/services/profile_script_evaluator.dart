import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Pointer;
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_js/extensions/xhr.dart';
import 'package:flutter_js/flutter_js.dart';

/// Preserve the app's routing decision inside the worker: isolates do not
/// inherit HttpOverrides.global. Localhost bypass remains identical to the app.
class ProfileScriptHttpOverrides extends HttpOverrides {
  ProfileScriptHttpOverrides(this.proxy, this.bypassHost);
  final String proxy;
  final String bypassHost;

  String findProxy(Uri url) => url.host == bypassHost ? 'DIRECT' : proxy;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = findProxy;
}

/// Profile scripts are one-shot transformations. Keep native work off the UI
/// isolate, materialize the result, then close the engine and its callbacks.
/// The optional factory permits deterministic ownership tests without FFI.
Future<Map<String, dynamic>> evaluateProfileScript(
  String script,
  Map<String, dynamic> config, {
  JavascriptRuntime Function()? createRuntime,
  String httpProxy = 'DIRECT',
  String proxyBypassHost = 'localhost',
}) async {
  if (createRuntime != null) {
    return _evaluate(script, config, createRuntime);
  }
  // Asset bundles belong to the Flutter engine's root isolate. Load before
  // spawning; the package factory otherwise starts this load without awaiting
  // it and may evaluate the polyfill after an early engine disposal.
  final fetchPolyfill =
      await rootBundle.loadString('packages/flutter_js/assets/js/fetch.js');
  return Isolate.run(() => HttpOverrides.runWithHttpOverrides(
        () => _evaluate(script, config, () => getJavascriptRuntime(xhr: false),
            fetchPolyfill: fetchPolyfill),
        ProfileScriptHttpOverrides(httpProxy, proxyBypassHost),
      ));
}

Future<Map<String, dynamic>> _evaluate(
  String script,
  Map<String, dynamic> config,
  JavascriptRuntime Function() createRuntime, {
  String? fetchPolyfill,
}) {
  // flutter_js does not cancel its Dart-backed setTimeout callbacks on dispose.
  // Scope timers to this evaluation so none can call a released native context.
  final timers = <Timer>{};
  var closed = false;
  return runZoned(() async {
    JavascriptRuntime? runtime;
    String? engineId;
    try {
      final configJs = json.encode(config);
      runtime = createRuntime();
      engineId = runtime.getEngineInstanceId();
      if (fetchPolyfill != null) {
        runtime.enableXhr();
        final bootstrap = runtime.evaluate(fetchPolyfill);
        if (bootstrap.isError) throw StateError(bootstrap.stringResult);
      }
      final result = await runtime.evaluateAsync("""
        $script
        main($configJs)
      """);
      // Preserve the error text expected by existing profile import dialogs.
      // ignore: only_throw_errors
      if (result.isError) throw result.stringResult;
      final value = result.rawResult is Pointer
          ? runtime.convertValue<Map<String, dynamic>>(result)
          : Map<String, dynamic>.from(result.rawResult);
      return value ?? config;
    } finally {
      closed = true;
      for (final timer in timers) {
        timer.cancel();
      }
      timers.clear();
      try {
        runtime?.dispose();
      } finally {
        // The package's static bridge registry otherwise retains old engines.
        if (engineId != null) {
          JavascriptRuntime.channelFunctionsRegistered.remove(engineId);
        }
      }
    }
  },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          late final Timer timer;
          timer = parent.createTimer(zone, duration, () {
            timers.remove(timer);
            if (!closed) callback();
          });
          if (closed) {
            timer.cancel();
          } else {
            timers.add(timer);
          }
          return timer;
        },
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createPeriodicTimer(zone, duration, (timer) {
            if (!closed) callback(timer);
          });
          if (closed) {
            timer.cancel();
          } else {
            timers.add(timer);
          }
          return timer;
        },
      ));
}
