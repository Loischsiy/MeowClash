import 'package:flutter/material.dart';

import 'dart:async';

typedef TickWidgetBuilder = Widget Function(BuildContext context, int tick);

class TickBuilder extends StatefulWidget {
  final Duration duration;
  final TickWidgetBuilder builder;

  const TickBuilder({super.key, required this.duration, required this.builder})
    : assert(duration > Duration.zero);

  @override
  State<TickBuilder> createState() => _TickBuilderState();
}

class _TickBuilderState extends State<TickBuilder> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant TickBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.duration, (_) {
      if (!mounted) return;
      setState(() {
        _tick++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _tick);
  }
}


class ScrollOverBuilder extends StatefulWidget {

  const ScrollOverBuilder({
    super.key,
    required this.builder,
  });
  final Widget Function(bool isOver) builder;

  @override
  State<ScrollOverBuilder> createState() => _ScrollOverBuilderState();
}

class _ScrollOverBuilderState extends State<ScrollOverBuilder> {
  final isOverNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    isOverNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
      onNotification: (scrollNotification) {
        isOverNotifier.value = scrollNotification.metrics.maxScrollExtent > 0;
        return true;
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: isOverNotifier,
        builder: (_, isOver, __) => widget.builder(isOver),
      ),
    );
}

// class ProxiesActionsBuilder extends StatelessWidget {
//   final Widget? child;
//   final Widget Function(
//     ProxiesActionsState state,
//     Widget? child,
//   ) builder;
//
//   const ProxiesActionsBuilder({
//     super.key,
//     required this.child,
//     required this.builder,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Selector<AppState, ProxiesActionsState>(
//       selector: (_, appState) => ProxiesActionsState(
//         isCurrent: appState.currentLabel == "proxies",
//         hasProvider: appState.providers.isNotEmpty,
//       ),
//       builder: (_, state, child) => builder(state, child),
//       child: child,
//     );
//   }
// }

// class ActiveBuilder extends StatelessWidget {
//   final String label;
//   final StateAndChildWidgetBuilder<bool> builder;
//   final Widget? child;
//
//   const ActiveBuilder({
//     super.key,
//     required this.label,
//     required this.builder,
//     required this.child,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Selector<AppState, bool>(
//       selector: (_, appState) => appState.currentLabel == label,
//       builder: (_, state, child) {
//         return builder(
//           state,
//           child,
//         );
//       },
//       child: child,
//     );
//   }
// }

typedef StateWidgetBuilder<T> = Widget Function(T state);

typedef StateAndChildWidgetBuilder<T> = Widget Function(T state, Widget? child);
