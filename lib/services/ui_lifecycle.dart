import 'dart:async';

import 'package:flutter/widgets.dart';

/// Visibility of the UI, independent of the proxy/core lifetime.
///
/// Native window/popover events are authoritative on desktop: losing focus is
/// not the same as hiding a window, and a macOS popover does not reliably drive
/// the lifecycle of the original (closed) Flutter window.
class UiLifecycleController extends ChangeNotifier {
  UiLifecycleController({this.unloadDelay = const Duration(seconds: 3)});

  final Duration unloadDelay;
  AppLifecycleState? _lifecycleState;
  bool? _windowVisible;
  Timer? _unloadTimer;
  bool _suspended = false;
  bool _disposed = false;
  int _generation = 0;
  int _windowRevision = 0;
  final _keepAlive = <Object>{};

  bool get hasWindowVisibility => _windowVisible != null;
  bool get isVisible =>
      _windowVisible ??
      (_lifecycleState != AppLifecycleState.hidden &&
          _lifecycleState != AppLifecycleState.paused &&
          _lifecycleState != AppLifecycleState.detached);
  bool get isForeground =>
      _windowVisible ??
      (_lifecycleState == null || _lifecycleState == AppLifecycleState.resumed);
  bool get isSuspended => _suspended;
  bool get hasKeepAlive => _keepAlive.isNotEmpty;

  /// Invalidates UI-only responses across hide/show and focus transitions.
  int get generation => _generation;

  void updateLifecycle(AppLifecycleState? state) {
    _update(() => _lifecycleState = state);
  }

  /// Null falls back to Flutter lifecycle (e.g. an older native dev runner).
  void updateWindowVisibility({required bool? visible}) {
    _windowRevision++;
    _update(() => _windowVisible = visible);
  }

  /// An initial asynchronous snapshot must not overwrite a newer native event.
  Future<void> synchronizeWindowVisibility(
    Future<bool> Function() readVisible,
  ) async {
    final revision = _windowRevision;
    final visible = await readVisible();
    if (!_disposed && revision == _windowRevision) {
      updateWindowVisibility(visible: visible);
    }
  }

  /// Protects an in-progress UI action whose continuation may still use its
  /// widget/ref. It does not enable polling or animation while hidden.
  VoidCallback keepAlive() {
    if (_disposed) return () {};
    final token = Object();
    // Acquiring a hold never changes the mounted UI. Releasing it notifies
    // the host so a deferred unload can finish even without normal frames.
    _keepAlive.add(token);
    return () {
      if (_disposed || !_keepAlive.remove(token)) return;
      notifyListeners();
    };
  }

  void _update(VoidCallback change) {
    if (_disposed) return;
    final wasVisible = isVisible;
    final wasForeground = isForeground;
    final wasSuspended = _suspended;
    change();
    if (isVisible) {
      _unloadTimer?.cancel();
      _unloadTimer = null;
      _suspended = false;
    } else if (!_suspended && _unloadTimer == null) {
      // Duplicate hide/minimize/lifecycle events do not extend the deadline.
      _unloadTimer = Timer(unloadDelay, () {
        _unloadTimer = null;
        if (_disposed || isVisible) return;
        _suspended = true;
        notifyListeners();
      });
    }
    if (wasVisible != isVisible || wasForeground != isForeground) {
      _generation++;
    }
    if (wasVisible != isVisible ||
        wasForeground != isForeground ||
        wasSuspended != _suspended) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _keepAlive.clear();
    _unloadTimer?.cancel();
    _unloadTimer = null;
    super.dispose();
  }
}

final uiLifecycle = UiLifecycleController();
