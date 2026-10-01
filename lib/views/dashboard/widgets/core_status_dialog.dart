// Ported from Bettbox (GPL-3.0): lib/views/dashboard/widgets/core_status_dialog.dart.
// MeowClash additions: separate RAM stats for the Flutter shell and the core,
// visibility-aware polling and a manual "free memory" action.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/async_polling_loop.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/visibility_polling.dart';
import 'package:meowclash/widgets/widgets.dart';

/// Resident memory of the Flutter (UI) process.
typedef ShellMemory = ({int rss, int maxRss});

ShellMemory _readShellMemory() =>
    (rss: ProcessInfo.currentRss, maxRss: ProcessInfo.maxRss);

Future<void> showCoreStatusDialog() async {
  await globalState.showCommonDialog<void>(
    child: const CoreStatusDialog(),
  );
}

class CoreStatusDialog extends StatefulWidget {
  const CoreStatusDialog({
    super.key,
    this.loadStatus,
    this.loadCoreRss,
    this.readShellMemory,
    this.coreInAppProcess,
    this.onReleaseMemory,
  });

  final Future<CoreStatus?> Function()? loadStatus;

  /// RSS of the separate core process (desktop service, iOS extension).
  final Future<int> Function()? loadCoreRss;
  final ShellMemory Function()? readShellMemory;

  /// Android loads the core into the app process, so there is no separate
  /// core RSS and the shell RSS already contains the core.
  final bool? coreInAppProcess;
  final VoidCallback? onReleaseMemory;

  @override
  State<CoreStatusDialog> createState() => _CoreStatusDialogState();
}

class _CoreStatusDialogState extends State<CoreStatusDialog>
    with VisibilityPollingMixin<CoreStatusDialog> {
  CoreStatus? _status;
  ShellMemory? _shell;
  int? _coreRss;

  bool get _coreInAppProcess => widget.coreInAppProcess ?? clashLib != null;

  // Polls only while the dialog is open and the UI is in the foreground.
  @override
  Duration get pollingInterval => const Duration(seconds: 1);

  @override
  Future<void> poll(PollingToken token) async {
    final shell = (widget.readShellMemory ?? _readShellMemory)();
    if (mounted && token.isCurrent && shell != _shell) {
      setState(() => _shell = shell);
    }
    final status = await (widget.loadStatus ?? clashCore.getCoreStatus)();
    final coreRss = _coreInAppProcess
        ? null
        : await (widget.loadCoreRss ?? clashCore.getMemory)();
    if (!mounted || !token.isCurrent) return;
    if ((status != null && status != _status) || coreRss != _coreRss) {
      setState(() {
        _status = status ?? _status;
        _coreRss = coreRss;
      });
    }
  }

  String _formatBytes(int bytes) => TrafficValue(value: bytes).shortShow;

  String _formatCount(int count) => NumberFormat.decimalPattern().format(count);

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          '[ $title ]',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
    required String percent,
    required bool isTight,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isTight)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($percent)',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (isTight) ...[
                    const SizedBox(width: 4),
                    Text(
                      '($percent)',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.outline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );

  Widget _buildMemoryCard({
    required int inUse,
    required int reclaimable,
    required int physical,
  }) {
    final totalMemory =
        (inUse + reclaimable) > 0 ? (inUse + reclaimable) : physical;
    final totalTraffic = TrafficValue(value: totalMemory);
    final inUseTraffic = _formatBytes(inUse);
    final reclaimableTraffic = _formatBytes(reclaimable);

    final allocatedPercent = totalMemory > 0
        ? (inUse / totalMemory * 100).toStringAsFixed(1)
        : '0.0';
    final reclaimablePercent = totalMemory > 0
        ? (reclaimable / totalMemory * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _MemoryRingChart(
            allocated: inUse.toDouble(),
            reclaimable: reclaimable.toDouble(),
            allocatedColor: context.colorScheme.primary,
            reclaimableColor: context.colorScheme.tertiary,
            trackColor: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            centerChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalTraffic.showValue,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    height: 1.0,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalTraffic.showUnit,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                    height: 1.0,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fontSize =
                    context.textTheme.labelMedium?.fontSize ?? 12.0;
                final reclaimText =
                    '${appLocalizations.reclaimableMemory} ($reclaimablePercent%)';
                final allocText =
                    '${appLocalizations.allocatedMemory} ($allocatedPercent%)';
                final maxChars = max(reclaimText.length, allocText.length);
                final maxNeededWidth = maxChars * (fontSize * 0.85) + 18;
                final isTight = maxNeededWidth > constraints.maxWidth;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(
                      color: context.colorScheme.primary,
                      label: appLocalizations.allocatedMemory,
                      value: inUseTraffic,
                      percent: '$allocatedPercent%',
                      isTight: isTight,
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      color: context.colorScheme.tertiary,
                      label: appLocalizations.reclaimableMemory,
                      value: reclaimableTraffic,
                      percent: '$reclaimablePercent%',
                      isTight: isTight,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildGridItem(_MetricItem item, {bool isFullWidth = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                size: 14,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isFullWidth) ...[
                    const SizedBox(height: 1),
                    Text(
                      item.value,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (isFullWidth) ...[
              const SizedBox(width: 8),
              Text(
                item.value,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildMetricGrid(List<_MetricItem> items) {
    final rows = <Widget>[];
    var i = 0;
    while (i < items.length) {
      if (i == items.length - 1) {
        rows.add(_buildGridItem(items[i], isFullWidth: true));
        i++;
      } else {
        final item1 = items[i];
        final item2 = items[i + 1];
        rows.add(
          Row(
            children: [
              Expanded(child: _buildGridItem(item1)),
              const SizedBox(width: 8),
              Expanded(child: _buildGridItem(item2)),
            ],
          ),
        );
        i += 2;
      }

      if (i < items.length) {
        rows.add(const SizedBox(height: 8));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildGeodataSection(String geodataUse) {
    final chips = <Widget>[];
    final isNone = geodataUse.isEmpty || geodataUse == 'None';

    if (isNone) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            appLocalizations.none,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
      );
    } else {
      final parts =
          geodataUse.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (final part in parts) {
        chips.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              part,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.colorScheme.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.travel_explore_rounded,
              size: 14,
              color: context.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appLocalizations.geodataUse,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: chips,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final inUse = status?.inUse ?? 0;
    final reclaimable = status?.reclaimable ?? 0;
    final physical = status?.physical ?? 0;

    final goroutinesText =
        status != null ? _formatCount(status.goroutines) : '-';
    final heapObjectsText =
        status != null ? _formatCount(status.heapObjects) : '-';
    final rulesText = status != null ? _formatCount(status.rules) : '-';
    final proxiesText = status != null ? _formatCount(status.proxies) : '-';
    final proxyGroupsText =
        status != null ? _formatCount(status.proxyGroups) : '-';
    final ruleProvidersText =
        status != null ? _formatCount(status.ruleProviders) : '-';
    final proxyProvidersText =
        status != null ? _formatCount(status.proxyProviders) : '-';
    final geodataUseText = status?.geodataUse ?? 'None';

    final metricItems = <_MetricItem>[
      _MetricItem(
        icon: Icons.rule_rounded,
        label: appLocalizations.rulesCount,
        value: rulesText,
      ),
      _MetricItem(
        icon: Icons.dns_rounded,
        label: appLocalizations.proxiesCount,
        value: proxiesText,
      ),
      _MetricItem(
        icon: Icons.hub_rounded,
        label: appLocalizations.proxyGroupsCount,
        value: proxyGroupsText,
      ),
      if ((status?.ruleProviders ?? 0) > 0)
        _MetricItem(
          icon: Icons.library_books_rounded,
          label: appLocalizations.ruleProvidersCount,
          value: ruleProvidersText,
        ),
      if ((status?.proxyProviders ?? 0) > 0)
        _MetricItem(
          icon: Icons.cloud_sync_rounded,
          label: appLocalizations.proxyProvidersCount,
          value: proxyProvidersText,
        ),
    ];

    final shell = _shell;
    final ramItems = <_MetricItem>[
      _MetricItem(
        icon: Icons.flutter_dash_rounded,
        label: appLocalizations.flutterShellMemory,
        value: shell != null ? _formatBytes(shell.rss) : '-',
      ),
      _MetricItem(
        icon: Icons.trending_up_rounded,
        label: appLocalizations.peakMemory,
        value: shell != null ? _formatBytes(shell.maxRss) : '-',
      ),
      if (!_coreInAppProcess)
        _MetricItem(
          icon: Icons.developer_board_rounded,
          label: appLocalizations.coreProcessMemory,
          value: _coreRss != null ? _formatBytes(_coreRss!) : '-',
        ),
      _MetricItem(
        icon: Icons.memory_rounded,
        label: appLocalizations.goRuntimeMemory,
        value: status != null ? _formatBytes(status.sys) : '-',
      ),
    ];

    return CommonDialog(
      title: appLocalizations.coreStatus,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      actions: [
        TextButton(
          onPressed: widget.onReleaseMemory ?? clashCore.requestGc,
          child: Text(appLocalizations.releaseMemory),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(appLocalizations.memoryAndRuntime),
          _buildMemoryCard(
            inUse: inUse,
            reclaimable: reclaimable,
            physical: physical,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  icon: Icons.alt_route_rounded,
                  iconColor: context.colorScheme.primary,
                  label: appLocalizations.activeGoroutines,
                  value: goroutinesText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatCard(
                  icon: Icons.layers_rounded,
                  iconColor: context.colorScheme.tertiary,
                  label: appLocalizations.heapObjects,
                  value: heapObjectsText,
                ),
              ),
            ],
          ),
          _buildSectionHeader(appLocalizations.ramUsage),
          _buildMetricGrid(ramItems),
          if (_coreInAppProcess) ...[
            const SizedBox(height: 6),
            Text(
              appLocalizations.sharedProcessMemoryHint,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          _buildSectionHeader(appLocalizations.profileAndRules),
          _buildMetricGrid(metricItems),
          const SizedBox(height: 8),
          _buildGeodataSection(geodataUseText),
        ],
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

class _MemoryRingChart extends StatelessWidget {
  const _MemoryRingChart({
    required this.allocated,
    required this.reclaimable,
    required this.allocatedColor,
    required this.reclaimableColor,
    required this.trackColor,
    required this.centerChild,
  });
  final double allocated;
  final double reclaimable;
  final Color allocatedColor;
  final Color reclaimableColor;
  final Color trackColor;
  final Widget centerChild;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => CustomPaint(
                size: const Size(76, 76),
                painter: _RingPainter(
                  allocated: allocated,
                  reclaimable: reclaimable,
                  allocatedColor: allocatedColor,
                  reclaimableColor: reclaimableColor,
                  trackColor: trackColor,
                  progress: progress,
                ),
              ),
            ),
            centerChild,
          ],
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.allocated,
    required this.reclaimable,
    required this.allocatedColor,
    required this.reclaimableColor,
    required this.trackColor,
    required this.progress,
  });
  final double allocated;
  final double reclaimable;
  final Color allocatedColor;
  final Color reclaimableColor;
  final Color trackColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 5.8;
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;

    canvas.drawCircle(center, radius, trackPaint);

    final total = allocated + reclaimable;
    if (total <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final hasBoth = allocated > 0 && reclaimable > 0;
    final gap = hasBoth ? (strokeWidth + 2.5) / radius : 0.0;
    final availableAngle = 2 * pi - (hasBoth ? gap * 2 : 0);

    var startAngle = -pi / 2 + (hasBoth ? gap / 2 : 0);

    if (allocated > 0) {
      final sweepAngle = (allocated / total) * availableAngle * progress;
      if (sweepAngle > 0) {
        final allocPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = allocatedColor;
        canvas.drawArc(rect, startAngle, sweepAngle, false, allocPaint);
        startAngle += sweepAngle + (hasBoth ? gap : 0);
      }
    }

    if (reclaimable > 0) {
      final sweepAngle = (reclaimable / total) * availableAngle * progress;
      if (sweepAngle > 0) {
        final recPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = reclaimableColor;
        canvas.drawArc(rect, startAngle, sweepAngle, false, recPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.allocated != allocated ||
      oldDelegate.reclaimable != reclaimable ||
      oldDelegate.allocatedColor != allocatedColor ||
      oldDelegate.reclaimableColor != reclaimableColor;
}
