import 'dart:math' as math;

import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/app.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkSpeed extends StatefulWidget {
  const NetworkSpeed({super.key});

  @override
  State<NetworkSpeed> createState() => _NetworkSpeedState();
}

class _NetworkSpeedState extends State<NetworkSpeed> {
  List<Point> initPoints = const [Point(0, 0), Point(1, 0)];

  List<Point> _getPoints(List<Traffic> traffics) {
    final trafficPoints = traffics
        .toList()
        .asMap()
        .map(
          (index, e) => MapEntry(
            index,
            Point(
              (index + initPoints.length).toDouble(),
              e.speed.toDouble(),
            ),
          ),
        )
        .values
        .toList();

    return [...initPoints, ...trafficPoints];
  }

  Traffic _getLastTraffic(List<Traffic> traffics) {
    if (traffics.isEmpty) return Traffic();
    return traffics.last;
  }

  /// One series per direction for the glass chart, padded like
  /// [_getPoints] so both start from the same zero baseline.
  List<Point> _getSeries(List<Traffic> traffics, num Function(Traffic) value) {
    final trafficPoints = <Point>[
      for (var i = 0; i < traffics.length; i++)
        Point((i + initPoints.length).toDouble(), value(traffics[i]).toDouble()),
    ];
    return [...initPoints, ...trafficPoints];
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _buildGlass(context);
    final color = context.colorScheme.onSurfaceVariant.opacity80;
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        onPressed: () {},
        info: Info(
          label: appLocalizations.networkSpeed,
          iconData: Icons.speed_sharp,
        ),
        child: Consumer(
          builder: (_, ref, __) {
            final traffics = ref.watch(trafficsProvider).list;
            return Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16).copyWith(
                      bottom: 0,
                      left: 0,
                      right: 0,
                    ),
                    child: LineChart(
                      gradient: true,
                      color: Theme.of(context).colorScheme.primary,
                      points: _getPoints(traffics),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: const Offset(
                      -16,
                      -20,
                    ),
                    child: Text(
                      "${_getLastTraffic(traffics).up}↑   ${_getLastTraffic(traffics).down}↓",
                      style: context.textTheme.bodySmall?.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlass(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final download = GlassTokens.chartDownload(brightness);
    final upload = GlassTokens.chartUpload(brightness);
    final padding = AdaptiveWidgetTile.glassPadding();
    final captionStyle = GlassTextStyles.widgetCaption(theme.textTheme)
        .copyWith(color: theme.colorScheme.onSurfaceVariant);
    return SizedBox(
      height: getWidgetHeight(2),
      child: AdaptiveWidgetTile(
        info: Info(
          label: appLocalizations.networkSpeed,
          iconData: Icons.speed_sharp,
        ),
        child: Consumer(
          builder: (_, ref, __) {
            final traffics = ref.watch(trafficsProvider).list;
            final last = _getLastTraffic(traffics);
            final downPoints = _getSeries(traffics, (e) => e.down.value);
            final upPoints = _getSeries(traffics, (e) => e.up.value);
            // Shared scale: ↓ and ↑ are compared on one axis.
            final maxY = [...downPoints, ...upPoints]
                .fold<double>(0, (m, e) => math.max(m, e.y));
            Widget chart(List<Point> points, Color color) => LineChart(
                  gradient: true,
                  color: color,
                  points: points,
                  maxY: maxY,
                  strokeWidth: GlassTokens.chartLineWidth,
                  fillTopOpacity: GlassTokens.chartFillTopOpacity,
                  fillBottomOpacity: GlassTokens.chartFillBottomOpacity,
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    GlassTokens.widgetLineGap,
                    padding,
                    0,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: _GlassSpeedLabel(
                          arrow: '↓',
                          value: '${last.down}',
                          color: download,
                          style: captionStyle,
                        ),
                      ),
                      SizedBox(width: padding),
                      Flexible(
                        child: _GlassSpeedLabel(
                          arrow: '↑',
                          value: '${last.up}',
                          color: upload,
                          style: captionStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: GlassTokens.widgetRowGap,
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: chart(downPoints, download)),
                        Positioned.fill(child: chart(upPoints, upload)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "↓ 1.2 MB/s": the arrow in the series colour, the figure tabular.
class _GlassSpeedLabel extends StatelessWidget {
  const _GlassSpeedLabel({
    required this.arrow,
    required this.value,
    required this.color,
    required this.style,
  });

  final String arrow;
  final String value;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$arrow ', style: TextStyle(color: color)),
            TextSpan(text: value),
          ],
        ),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}
