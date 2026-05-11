import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/providers/config.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OutboundMode extends StatelessWidget {
  const OutboundMode({super.key});

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(2);
    return SizedBox(
      height: height,
      child: Consumer(
        builder: (_, ref, _) {
          final mode = ref.watch(
            patchClashConfigProvider.select((state) => state.mode),
          );
          return CommonCard(
            onPressed: () {},
            info: Info(
              label: appLocalizations.outboundMode,
              iconData: Icons.call_split_sharp,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final item in Mode.values)
                    Flexible(
                      fit: FlexFit.tight,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            globalState.appController.changeMode(item);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.ap,
                              vertical: 8.ap,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item == mode
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 21,
                                  color: item == mode
                                      ? context.colorScheme.primary
                                      : context.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                ),
                                SizedBox(width: 12.ap),
                                Expanded(
                                  child: Text(
                                    Intl.message(item.name),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.toSoftBold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class OutboundModeV2 extends StatelessWidget {
  const OutboundModeV2({super.key});

  Color _getTextColor(BuildContext context, Mode mode) {
    return switch (mode) {
      Mode.rule => context.colorScheme.onSecondaryContainer,
      Mode.global => context.colorScheme.onPrimaryContainer,
      Mode.direct => context.colorScheme.onTertiaryContainer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(0.72);
    return SizedBox(
      height: height,
      child: CommonCard(
        padding: EdgeInsets.zero,
        child: Consumer(
          builder: (_, ref, _) {
            final mode = ref.watch(
              patchClashConfigProvider.select((state) => state.mode),
            );
            final thumbColor = switch (mode) {
              Mode.rule => context.colorScheme.secondaryContainer,
              Mode.global => globalState.theme.darken3PrimaryContainer,
              Mode.direct => context.colorScheme.tertiaryContainer,
            };
            return Container(
              constraints: BoxConstraints.expand(),
              child: CommonTabBar<Mode>(
                children: Map.fromEntries(
                  Mode.values.map(
                    (item) => MapEntry(
                      item,
                      Container(
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(),
                        height: height - 16,
                        child: Text(
                          Intl.message(item.name),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.adjustSize(1)
                              .copyWith(
                                color: item == mode
                                    ? _getTextColor(context, item)
                                    : null,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 8),
                groupValue: mode,
                onValueChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  globalState.appController.changeMode(value);
                },
                thumbColor: thumbColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
