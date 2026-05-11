import 'dart:async';

import 'package:meow_clash/clash/clash.dart';
import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/models/common.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class MemoryInfo extends StatefulWidget {
  const MemoryInfo({super.key});

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo> {
  late final VoidCallback _tickListener;
  // Cache last memory value to avoid showing 0 on rebuild
  static TrafficValue _lastMemoryValue = TrafficValue(value: 0);
  TrafficValue _memoryValue = _lastMemoryValue;
  Timer? _initTimer;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _tickListener = _updateMemory;
    dashboardRefreshManager.tick2s.addListener(_tickListener);

    // Get immediately on first open, otherwise delay 1000ms
    if (_lastMemoryValue.value == 0) {
      _retryUpdateMemory();
    } else {
      // Has cached value, delay
      _initTimer = Timer(const Duration(milliseconds: 1000), _updateMemory);
    }
  }

  Future<void> _retryUpdateMemory() async {
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      await _updateMemory();
      if (_memoryValue.value > 0) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    dashboardRefreshManager.tick2s.removeListener(_tickListener);
    super.dispose();
  }

  Future<void> _updateMemory() async {
    if (!mounted) return;
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final memoryValue = await clashCore.getMemory();
      // Update only if valid (non-zero)
      if (memoryValue > 0) {
        final adjustedValue = memoryValue;

        if (mounted) {
          setState(() {
            _memoryValue = TrafficValue(value: adjustedValue);
            _lastMemoryValue = _memoryValue; // Cache latest valid value
          });
        }
      }
      // If 0, keep last valid value
    } catch (e) {
      // Ignore error, keep current value
    } finally {
      _isUpdating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(iconData: Icons.memory, label: appLocalizations.memoryInfo),
        onLongPress: () async {
          // Show confirmation dialog
          final result = await globalState.showCommonDialog<bool>(
            child: CommonDialog(
              title: appLocalizations.forceGCTitle,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop(false);
                  },
                  child: Text(appLocalizations.cancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop(true);
                  },
                  child: Text(appLocalizations.confirm),
                ),
              ],
              child: Text(appLocalizations.forceGCDesc),
            ),
          );

          // Execute force GC after user confirms
          if (result == true) {
            await clashCore.requestGc();
            globalState.showNotifier(appLocalizations.success);
          }
        },
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      _memoryValue.showValue,
                      style: context.textTheme.bodyMedium?.toLight.adjustSize(
                        1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _memoryValue.showUnit,
                      style: context.textTheme.bodyMedium?.toLight.adjustSize(
                        1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}