import 'dart:async';

import 'package:flutter_js/flutter_js.dart';
import 'package:synchronized/synchronized.dart';

class JavaScriptRuntimeManager {
  static JavascriptRuntime? _instance;
  static final Lock _lock = Lock();
  static int _activeCount = 0;
  static bool _isDisposing = false;
  static Timer? _disposeTimer;
  static const Duration _disposeDelay = Duration(seconds: 10);

  static Future<T> execute<T>(
    Future<T> Function(JavascriptRuntime runtime) task,
  ) async {
    final runtime = await _acquire();
    try {
      return await task(runtime);
    } finally {
      await _release();
    }
  }

  static Future<JavascriptRuntime> _acquire() async {
    return _lock.synchronized(() async {
      while (_isDisposing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      _disposeTimer?.cancel();
      _disposeTimer = null;
      _activeCount++;
      _instance ??= getJavascriptRuntime();
      return _instance!;
    });
  }

  static Future<void> _release() async {
    await _lock.synchronized(() async {
      _activeCount--;
      if (_activeCount <= 0 && _instance != null) {
        _disposeTimer?.cancel();
        _disposeTimer = Timer(_disposeDelay, () {
          dispose();
        });
      }
    });
  }

  static Future<void> dispose() async {
    return _lock.synchronized(() async {
      if (_activeCount > 0) return;
      if (_instance != null) {
        _isDisposing = true;
        try {
          _instance!.dispose();
        } catch (_) {}
        _instance = null;
        _isDisposing = false;
      }
    });
  }
}
