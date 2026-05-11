import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/models/clash_config.dart';
import 'package:meow_clash/models/config.dart';
import 'package:meow_clash/providers/providers.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/views/config/dns.dart';
import 'package:meow_clash/views/config/general.dart';
import 'package:meow_clash/views/config/network.dart';
import 'package:meow_clash/views/config/ntp.dart';
import 'package:meow_clash/views/config/sniffer.dart';
import 'package:meow_clash/views/config/tunnel.dart';
import 'package:meow_clash/views/config/experimental.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConfigView extends StatefulWidget {
  const ConfigView({super.key});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      ListItem.open(
        title: Text(appLocalizations.general),
        subtitle: Text(appLocalizations.generalDesc),
        leading: const Icon(Icons.build),
        delegate: OpenDelegate(
          title: appLocalizations.general,
          widget: generateListView(generalItems),
          blur: false,
        ),
      ),
      ListItem.open(
        title: Text(appLocalizations.network),
        subtitle: Text(appLocalizations.networkDesc),
        leading: const Icon(Icons.vpn_key),
        delegate: OpenDelegate(
          title: appLocalizations.network,
          blur: false,
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await globalState.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(vpnSettingProvider.notifier)
                        .updateState(
                          (state) => defaultVpnProps.copyWith(
                            accessControl: state.accessControl,
                          ),
                        );
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(tun: defaultTun),
                        );
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Icons.replay),
                );
              },
            ),
          ],
          widget: const NetworkListView(),
        ),
      ),
      ListItem.open(
        title: const Text('DNS'),
        subtitle: Text(appLocalizations.dnsDesc),
        leading: const Icon(Icons.dns),
        delegate: OpenDelegate(
          title: 'DNS',
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await globalState.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(dns: defaultDns),
                        );
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Icons.replay),
                );
              },
            ),
          ],
          widget: const DnsListView(),
          blur: false,
        ),
      ),
      ListItem.open(
        title: const Text('NTP'),
        subtitle: Text(appLocalizations.ntpDesc),
        leading: const Icon(Icons.access_time),
        delegate: OpenDelegate(
          title: 'NTP',
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await globalState.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(ntp: defaultNtp),
                        );
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Icons.replay),
                );
              },
            ),
          ],
          widget: const NtpListView(),
          blur: false,
        ),
      ),
      ListItem.open(
        title: const Text('Hosts'),
        subtitle: Text(appLocalizations.hostsDesc),
        leading: const Icon(Icons.view_list_outlined),
        delegate: OpenDelegate(
          blur: false,
          title: 'Hosts',
          widget: Consumer(
            builder: (_, ref, _) {
              final hosts = ref.watch(
                patchClashConfigProvider.select((state) => state.hosts),
              );
              return MapInputPage(
                title: 'Hosts',
                map: hosts,
                titleBuilder: (item) => Text(item.key),
                subtitleBuilder: (item) => Text(item.value),
                onChange: (value) {
                  ref
                      .read(patchClashConfigProvider.notifier)
                      .updateState((state) => state.copyWith(hosts: value));
                },
              );
            },
          ),
        ),
      ),
      ListItem.open(
        title: Text(appLocalizations.sniffer),
        subtitle: Text(appLocalizations.snifferDesc),
        leading: const Icon(Icons.radar),
        delegate: OpenDelegate(
          title: appLocalizations.sniffer,
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await globalState.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(sniffer: defaultSniffer),
                        );
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Icons.replay),
                );
              },
            ),
          ],
          widget: const SnifferListView(),
          blur: false,
        ),
      ),
      ListItem.open(
        title: Text(appLocalizations.tunnel),
        subtitle: Text(appLocalizations.tunnelDesc),
        leading: const Icon(Icons.swap_horiz),
        delegate: OpenDelegate(
          title: appLocalizations.tunnel,
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await globalState.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(tunnels: defaultTunnel),
                        );
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Icons.replay),
                );
              },
            ),
          ],
          widget: const TunnelListView(),
          blur: false,
        ),
      ),
      ListItem.open(
        title: Text(appLocalizations.experimental),
        subtitle: Text(appLocalizations.experimentalDesc),
        leading: const Icon(Icons.science),
        delegate: OpenDelegate(
          title: appLocalizations.experimental,
          actions: [
            Consumer(
              builder: (_, ref, _) {
                return IconButton(
                  onPressed: () async {
                    final res = await globalState.showMessage(
                      title: appLocalizations.reset,
                      message: TextSpan(text: appLocalizations.resetTip),
                    );
                    if (res != true) {
                      return;
                    }
                    ref
                        .read(patchClashConfigProvider.notifier)
                        .updateState(
                          (state) =>
                              state.copyWith(experimental: defaultExperimental),
                        );
                  },
                  tooltip: appLocalizations.reset,
                  icon: const Icon(Icons.replay),
                );
              },
            ),
          ],
          widget: const ExperimentalListView(),
          blur: false,
        ),
      ),
    ];
    return generateListView(items.separated(const Divider(height: 0)).toList());
  }
}
