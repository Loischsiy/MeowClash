import 'dart:io';

import 'package:flutter/material.dart';
import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/common.dart';
import 'package:meowclash/services/async_polling_loop.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/visibility_polling.dart';
import 'package:meowclash/widgets/widgets.dart';

final _memoryInfoStateNotifier = ValueNotifier<TrafficValue>(
  const TrafficValue(value: 0),
);

class MemoryInfo extends StatefulWidget {
  const MemoryInfo({super.key, this.readMemory});

  final Future<int> Function()? readMemory;

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo>
    with VisibilityPollingMixin<MemoryInfo> {
  @override
  Duration get pollingInterval => const Duration(seconds: 2);

  @override
  Future<void> poll(PollingToken token) async {
    final reader = widget.readMemory;
    final int memory;
    if (reader != null) {
      memory = await reader();
    } else {
      final rss = ProcessInfo.currentRss;
      memory = clashLib != null ? rss : await clashCore.getMemory() + rss;
    }
    if (!mounted || !token.isCurrent) return;
    _memoryInfoStateNotifier.value = TrafficValue(value: memory);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          info: Info(
            iconData: Icons.memory,
            label: appLocalizations.memoryInfo,
          ),
          onPressed: clashCore.requestGc,
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(
              top: 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: globalState.measure.bodyMediumHeight + 2,
                  child: ValueListenableBuilder(
                    valueListenable: _memoryInfoStateNotifier,
                    builder: (_, trafficValue, __) => Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          trafficValue.showValue,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          trafficValue.showUnit,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
}

// class AnimatedCounter extends StatefulWidget {
//   final double value;
//   final TextStyle? style;
//
//   const AnimatedCounter({
//     super.key,
//     required this.value,
//     this.style,
//   });
//
//   @override
//   State<AnimatedCounter> createState() => _AnimatedCounterState();
// }
//
// class _AnimatedCounterState extends State<AnimatedCounter> {
//   late double _previousValue;
//   late double _currentValue;
//
//   @override
//   void initState() {
//     super.initState();
//     _previousValue = widget.value;
//     _currentValue = widget.value;
//   }
//
//   @override
//   void didUpdateWidget(AnimatedCounter oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.value != widget.value) {
//       // if (_previousValue == _currentValue) {
//       //   _previousValue = widget.value;
//       //   _currentValue = widget.value;
//       //   return;
//       // }
//       _currentValue = widget.value;
//     }
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       _currentValue.fixed(decimals: 1),
//       style: widget.style,
//     );
//     return TweenAnimationBuilder(
//       tween: Tween(
//         begin: _previousValue,
//         end: _currentValue,
//       ),
//       onEnd: () {
//         _previousValue = _currentValue;
//       },
//       duration: Duration(seconds: 6),
//       curve: Curves.easeOut,
//       builder: (_, value, ___) {
//         return Text(
//           value.fixed(decimals: 1),
//           style: widget.style,
//         );
//       },
//     );
//   }
// }
