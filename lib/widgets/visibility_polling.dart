import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meowclash/services/async_polling_loop.dart';

bool get isUiForeground {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// Unlike animation tickers, ordinary Timers ignore TickerMode. Use the same
/// visibility signal as cached navigation pages, plus application lifecycle.
mixin VisibilityPollingMixin<T extends StatefulWidget> on State<T> {
  Duration get pollingInterval;
  Future<void> poll(PollingToken token);

  late final AsyncPollingLoop polling = AsyncPollingLoop(
    interval: pollingInterval,
    onTick: poll,
    onError: (error, stack) => debugPrint('UI polling failed: $error'),
  );
  late final AppLifecycleListener _pollingLifecycle;
  bool _tickerEnabled = false;

  @override
  void initState() {
    super.initState();
    _pollingLifecycle = AppLifecycleListener(
      onStateChange: (_) => _syncPolling(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Keep compatibility with the supported Flutter SDK versions.
    // ignore: deprecated_member_use
    _tickerEnabled = TickerMode.of(context);
    _syncPolling();
  }

  void _syncPolling() {
    if (mounted && _tickerEnabled && isUiForeground) {
      unawaited(polling.start());
    } else {
      polling.stop();
    }
  }

  @override
  void dispose() {
    polling.dispose();
    _pollingLifecycle.dispose();
    super.dispose();
  }
}
