import 'dart:io';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/views/config/network.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void _showTunOptions(BuildContext context) {
  showSheet(
    context: context,
    builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: generateListView(
          generateSection(
            items: [
              if (system.isDesktop) const TUNItem(),
              if (Platform.isMacOS) const AutoSetSystemDnsItem(),
              const TunStackItem(),
            ],
          ),
        ),
        title: appLocalizations.tun,
      ),
  );
}

void _showSystemProxyOptions(BuildContext context) {
  showSheet(
    context: context,
    builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: generateListView(
          generateSection(
            items: [
              const SystemProxyItem(),
              const BypassDomainItem(),
            ],
          ),
        ),
        title: appLocalizations.systemProxy,
      ),
  );
}

void _showVpnOptions(BuildContext context) {
  showSheet(
    context: context,
    builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: generateListView(
          generateSection(
            items: [
              const VPNItem(),
              const VpnSystemProxyItem(),
              const TunStackItem(),
            ],
          ),
        ),
        title: "VPN",
      ),
  );
}

class TUNButton extends StatelessWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context) => AdaptivePlatform.useGlass
      ? _GlassQuickOptionTile(
          info: Info(
            label: appLocalizations.tun,
            iconData: Icons.stacked_line_chart,
          ),
          onPressed: () => _showTunOptions(context),
          toggle: Consumer(
            builder: (_, ref, __) => AdaptiveSwitch(
              value: ref.watch(
                patchClashConfigProvider.select((state) => state.tun.enable),
              ),
              onChanged: (value) =>
                  ref.read(patchClashConfigProvider.notifier).updateState(
                        (state) => state.copyWith.tun(enable: value),
                      ),
            ),
          ),
        )
      : SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () => _showTunOptions(context),
        info: Info(
          label: appLocalizations.tun,
          iconData: Icons.stacked_line_chart,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(
            top: 4,
            bottom: 8,
            right: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.adjustSize(-2)
                        .toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final enable = ref.watch(patchClashConfigProvider
                      .select((state) => state.tun.enable));
                  return Switch(
                    value: enable,
                    onChanged: (value) {
                      ref.read(patchClashConfigProvider.notifier).updateState(
                            (state) => state.copyWith.tun(
                              enable: value,
                            ),
                          );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) => AdaptivePlatform.useGlass
      ? _GlassQuickOptionTile(
          info: Info(
            label: appLocalizations.systemProxy,
            iconData: Icons.shuffle,
          ),
          onPressed: () => _showSystemProxyOptions(context),
          toggle: Consumer(
            builder: (_, ref, __) => AdaptiveSwitch(
              value: ref.watch(
                networkSettingProvider.select((state) => state.systemProxy),
              ),
              onChanged: (value) =>
                  ref.read(networkSettingProvider.notifier).updateState(
                        (state) => state.copyWith(systemProxy: value),
                      ),
            ),
          ),
        )
      : SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () => _showSystemProxyOptions(context),
        info: Info(
          label: appLocalizations.systemProxy,
          iconData: Icons.shuffle,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(
            top: 4,
            bottom: 8,
            right: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.adjustSize(-2)
                        .toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final systemProxy = ref.watch(networkSettingProvider
                      .select((state) => state.systemProxy));
                  return Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: systemProxy,
                    onChanged: (value) {
                      ref.read(networkSettingProvider.notifier).updateState(
                            (state) => state.copyWith(
                              systemProxy: value,
                            ),
                          );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) => AdaptivePlatform.useGlass
      ? _GlassQuickOptionTile(
          info: const Info(
            label: "VPN",
            iconData: Icons.stacked_line_chart,
          ),
          onPressed: () => _showVpnOptions(context),
          toggle: Consumer(
            builder: (_, ref, __) => AdaptiveSwitch(
              value: ref.watch(
                vpnSettingProvider.select((state) => state.enable),
              ),
              onChanged: (value) =>
                  ref.read(vpnSettingProvider.notifier).updateState(
                        (state) => state.copyWith(enable: value),
                      ),
            ),
          ),
        )
      : SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () => _showVpnOptions(context),
        info: const Info(
          label: "VPN",
          iconData: Icons.stacked_line_chart,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(
            top: 4,
            bottom: 8,
            right: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.adjustSize(-2)
                        .toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final enable = ref.watch(
                    vpnSettingProvider.select(
                      (state) => state.enable,
                    ),
                  );
                  return Switch(
                    value: enable,
                    onChanged: (value) {
                      ref.read(vpnSettingProvider.notifier).updateState(
                            (state) => state.copyWith(
                              enable: value,
                            ),
                          );
                    },
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
}

/// Glass quick-option tile: title row, "Options" in secondary text and the
/// switch on the trailing edge; the tile opens the option sheet. Darwin only.
class _GlassQuickOptionTile extends StatelessWidget {
  const _GlassQuickOptionTile({
    required this.info,
    required this.onPressed,
    required this.toggle,
  });

  final Info info;
  final VoidCallback onPressed;
  final Widget toggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: getWidgetHeight(1),
      child: AdaptiveWidgetTile(
        info: info,
        onPressed: onPressed,
        child: GlassWidgetTileBody(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  appLocalizations.options,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GlassTextStyles.widgetCaption(theme.textTheme)
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: GlassTokens.widgetRowGap),
              toggle,
            ],
          ),
        ),
      ),
    );
  }
}
