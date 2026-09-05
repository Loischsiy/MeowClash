import 'dart:async';

/// A token becomes invalid on stop/dispose, even if a new loop already started.
class PollingToken {
  PollingToken._(this._loop, this._generation);
  final AsyncPollingLoop _loop;
  final int _generation;
  bool get isCurrent => _loop.isActive && _loop._generation == _generation;
}

/// A cancellable, single-flight polling loop. Timers are armed only after work
/// finishes. Stopping during an await cannot resurrect a background timer.
class AsyncPollingLoop {
  AsyncPollingLoop({
    required this.interval,
    required this.onTick,
    this.onError,
  }) : assert(interval > Duration.zero, 'Polling interval must be positive.');

  final Duration interval;
  final FutureOr<void> Function(PollingToken token) onTick;
  final void Function(Object error, StackTrace stack)? onError;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _enabled = false;
  bool _disposed = false;
  bool _refreshPending = false;
  int _generation = 0;

  bool get isActive => _enabled && !_disposed;

  Future<void> start() {
    if (_disposed) return Future<void>.value();
    if (_enabled) return _inFlight ?? Future<void>.value();
    _enabled = true;
    _generation++;
    return refresh();
  }

  Future<void> refresh() {
    if (!isActive) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    if (_inFlight != null) {
      _refreshPending = true;
      return _inFlight!;
    }
    return _tick();
  }

  Future<void> _tick() {
    if (!isActive) return Future<void>.value();
    final token = PollingToken._(this, _generation);
    final completion = Completer<void>();
    _inFlight = completion.future;
    unawaited(() async {
      try {
        await onTick(token);
      } catch (error, stack) {
        onError?.call(error, stack);
      } finally {
        _inFlight = null;
        if (isActive) {
          final delay =
              _refreshPending || !token.isCurrent ? Duration.zero : interval;
          _refreshPending = false;
          _timer = Timer(delay, () {
            _timer = null;
            unawaited(_tick());
          });
        }
        completion.complete();
      }
    }());
    return completion.future;
  }

  void stop() {
    _enabled = false;
    _generation++;
    _refreshPending = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _disposed = true;
  }
}
