import 'dart:math';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/app.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrafficUsage extends StatelessWidget {
  const TrafficUsage({super.key});

  Widget _buildTrafficDataItem(
    BuildContext context,
    Icon icon,
    TrafficValue trafficValue,
  ) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          flex: 1,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              icon,
              const SizedBox(
                width: 8,
              ),
              Flexible(
                flex: 1,
                child: Text(
                  trafficValue.showValue,
                  style: context.textTheme.bodySmall,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        Text(
          trafficValue.showUnit,
          style: context.textTheme.bodySmall?.toLighter,
        ),
      ],
    );

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _buildGlass(context);
    final primaryColor = globalState.theme.darken3PrimaryContainer;
    final secondaryColor = globalState.theme.darken2SecondaryContainer;
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        info: Info(
          label: appLocalizations.trafficUsage,
          iconData: Icons.data_saver_off,
        ),
        onPressed: () {},
        child: Consumer(
          builder: (_, ref, __) {
            final totalTraffic = ref.watch(totalTrafficProvider);
            final upTotalTrafficValue = totalTraffic.up;
            final downTotalTrafficValue = totalTraffic.down;
            return Padding(
              padding: baseInfoEdgeInsets.copyWith(
                top: 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: DonutChart(
                              data: [
                                DonutChartData(
                                  value: upTotalTrafficValue.value.toDouble(),
                                  color: primaryColor,
                                ),
                                DonutChartData(
                                  value: downTotalTrafficValue.value.toDouble(),
                                  color: secondaryColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Flexible(
                            child: LayoutBuilder(
                              builder: (_, container) {
                                final uploadText = Text(
                                  maxLines: 1,
                                  appLocalizations.upload,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.bodySmall,
                                );
                                final downloadText = Text(
                                  maxLines: 1,
                                  appLocalizations.download,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.bodySmall,
                                );
                                final uploadTextSize = globalState.measure
                                    .computeTextSize(uploadText);
                                final downloadTextSize = globalState.measure
                                    .computeTextSize(downloadText);
                                final maxTextWidth = max(uploadTextSize.width,
                                    downloadTextSize.width);
                                if (maxTextWidth + 24 > container.maxWidth) {
                                  return Container();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 8,
                                          decoration: ShapeDecoration(
                                            color: primaryColor,
                                            shape: RoundedSuperellipseBorder(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 4,
                                        ),
                                        Text(
                                          maxLines: 1,
                                          appLocalizations.upload,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 8,
                                          decoration: ShapeDecoration(
                                            color: secondaryColor,
                                            shape: RoundedSuperellipseBorder(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 4,
                                        ),
                                        Text(
                                          maxLines: 1,
                                          appLocalizations.download,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildTrafficDataItem(
                    context,
                    Icon(
                      Icons.arrow_upward,
                      color: primaryColor,
                      size: 14,
                    ),
                    upTotalTrafficValue,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  _buildTrafficDataItem(
                    context,
                    Icon(
                      Icons.arrow_downward,
                      color: secondaryColor,
                      size: 14,
                    ),
                    downTotalTrafficValue,
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGlass(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final upload = GlassTokens.chartUpload(brightness);
    final download = GlassTokens.chartDownload(brightness);
    final padding = AdaptiveWidgetTile.glassPadding();
    return SizedBox(
      height: getWidgetHeight(2),
      child: AdaptiveWidgetTile(
        info: Info(
          label: appLocalizations.trafficUsage,
          iconData: Icons.data_saver_off,
        ),
        child: Consumer(
          builder: (_, ref, __) {
            final totalTraffic = ref.watch(totalTrafficProvider);
            final up = totalTraffic.up;
            final down = totalTraffic.down;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                GlassTokens.widgetRowGap,
                padding,
                padding,
              ),
              child: Row(
                children: [
                  // Flexible: on a narrow tile the ring gives way to the
                  // legend instead of pushing it out.
                  Flexible(
                    child: AspectRatio(
                    aspectRatio: 1,
                    child: DonutChart(
                      strokeFraction: GlassTokens.chartDonutStrokeFraction,
                      trackColor: GlassTokens.segmentedTrack(brightness),
                      data: [
                        DonutChartData(
                          value: up.value.toDouble(),
                          color: upload,
                        ),
                        DonutChartData(
                          value: down.value.toDouble(),
                          color: download,
                        ),
                      ],
                    ),
                  ),
                  ),
                  SizedBox(width: padding),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlassTrafficLegend(
                          color: upload,
                          label: appLocalizations.upload,
                          value: up,
                        ),
                        const SizedBox(height: GlassTokens.widgetRowGap),
                        _GlassTrafficLegend(
                          color: download,
                          label: appLocalizations.download,
                          value: down,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Legend entry of the glass traffic ring: a coloured dot with the series
/// name, the total in tabular figures under it.
class _GlassTrafficLegend extends StatelessWidget {
  const _GlassTrafficLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final TrafficValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = GlassTextStyles.widgetCaption(theme.textTheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: GlassTokens.chartLegendDotSize,
              height: GlassTokens.chartLegendDotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: GlassTokens.chartLegendGap),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: caption.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: GlassTokens.widgetLineGap),
        Text(
          '${value.showValue} ${value.showUnit}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: caption.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
