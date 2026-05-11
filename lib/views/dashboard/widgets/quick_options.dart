import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/providers/config.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/views/config/network.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TUNButton extends StatelessWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_, type) {
              return AdaptiveSheetScaffold(
                type: type,
                body: generateListView(
                  generateSection(
                    items: [
                      if (system.isDesktop) const TUNItem(),
                      if (system.isMacOS) const AutoSetSystemDnsItem(),
                      const StrictRouteItem(),
                      const IcmpForwardingItem(),
                      const TunStackItem(),
                    ],
                  ),
                ),
                title: appLocalizations.tun,
              );
            },
          );
        },
        info: Info(
          label: appLocalizations.tun,
          iconData: Icons.stacked_line_chart,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
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
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final enable = ref.watch(
                    patchClashConfigProvider.select(
                      (state) => state.tun.enable,
                    ),
                  );

                  // Windows 桌面端：检查系统代理是否开启
                  final systemProxyEnabled = system.isWindows
                      ? ref.watch(
                          networkSettingProvider.select(
                            (state) => state.systemProxy,
                          ),
                        )
                      : false;

                  return Switch(
                    value: enable,
                    onChanged: systemProxyEnabled && system.isWindows
                        ? null // Disable when system proxy is on
                        : (value) {
                            // Windows: prompt to close system proxy first
                            if (system.isWindows && systemProxyEnabled) {
                              globalState.showNotifier(
                                appLocalizations.pleaseCloseSystemProxyFirst,
                              );
                              return;
                            }

                            ref
                                .read(patchClashConfigProvider.notifier)
                                .updateState(
                                  (state) => state.copyWith.tun(enable: value),
                                );
                          },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_, type) {
              return AdaptiveSheetScaffold(
                type: type,
                body: generateListView(
                  generateSection(
                    items: [SystemProxyItem(), BypassDomainItem()],
                  ),
                ),
                title: appLocalizations.systemProxy,
              );
            },
          );
        },
        info: Info(
          label: appLocalizations.systemProxy,
          iconData: Icons.shuffle,
        ),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
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
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final systemProxy = ref.watch(
                    networkSettingProvider.select((state) => state.systemProxy),
                  );

                  // Windows 桌面端：检查 TUN 是否开启
                  final tunEnabled = system.isWindows
                      ? ref.watch(
                          patchClashConfigProvider.select(
                            (state) => state.tun.enable,
                          ),
                        )
                      : false;

                  return Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: systemProxy,
                    onChanged: tunEnabled && system.isWindows
                        ? null // TUN 开启时禁用开关
                        : (value) {
                            // Windows 桌面端：如果 TUN 开启，提示用户先关闭
                            if (system.isWindows && tunEnabled) {
                              globalState.showNotifier(
                                appLocalizations.pleaseCloseTunFirst,
                              );
                              return;
                            }

                            ref
                                .read(networkSettingProvider.notifier)
                                .updateState(
                                  (state) => state.copyWith(systemProxy: value),
                                );
                          },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_, type) {
              return AdaptiveSheetScaffold(
                type: type,
                body: generateListView(
                  generateSection(
                    items: [
                      const VPNItem(),
                      const StrictRouteItem(),
                      const IcmpForwardingItem(),
                      const TunStackItem(),
                    ],
                  ),
                ),
                title: 'VPN',
              );
            },
          );
        },
        info: Info(label: 'VPN', iconData: Icons.stacked_line_chart),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 4, bottom: 8, right: 8),
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
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final enable = ref.watch(
                    vpnSettingProvider.select((state) => state.enable),
                  );
                  return Switch(
                    value: enable,
                    onChanged: (value) {
                      ref
                          .read(vpnSettingProvider.notifier)
                          .updateState(
                            (state) => state.copyWith(enable: value),
                          );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
