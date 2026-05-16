import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/clash_config.dart';
import 'package:meowclash/providers/config.dart' show patchClashConfigProvider;
import 'package:meowclash/state.dart';
import 'package:meowclash/views/config/dns.dart';
import 'package:meowclash/views/config/general.dart';
import 'package:meowclash/views/config/network.dart';
import 'package:meowclash/widgets/widgets.dart';
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
    final items = <Widget>[
      ListItem.open(
        title: Text(appLocalizations.general),
        subtitle: Text(appLocalizations.generalDesc),
        leading: const Icon(Icons.build),
        delegate: OpenDelegate(
          title: appLocalizations.general,
          widget: generateListView(
            generalItems,
          ),
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
          widget: const NetworkListView(),
        ),
      ),
      ListItem.open(
        title: const Text("DNS"),
        subtitle: Text(appLocalizations.dnsDesc),
        leading: const Icon(Icons.dns),
        delegate: OpenDelegate(
          title: "DNS",
          action: Consumer(builder: (_, ref, __) => IconButton(
              onPressed: () async {
                final res = await globalState.showMessage(
                  title: appLocalizations.reset,
                  message: TextSpan(
                    text: appLocalizations.resetTip,
                  ),
                );
                if (res != true) {
                  return;
                }
                ref.read(patchClashConfigProvider.notifier).updateState(
                      (state) => state.copyWith(
                        dns: defaultDns,
                      ),
                    );
              },
              tooltip: appLocalizations.reset,
              icon: const Icon(
                Icons.replay,
              ),
            )),
          widget: const DnsListView(),
          blur: false,
        ),
      )
    ];
    return generateListView(
      items
          .separated(
            const Divider(
              height: 0,
            ),
          )
          .toList(),
    );
  }
}
