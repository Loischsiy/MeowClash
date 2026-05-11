import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/providers/config.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class OnlinePanel extends ConsumerWidget {
  const OnlinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          info: Info(
            label: appLocalizations.onlinePanel,
            iconData: Icons.launch,
          ),
          onPressed: () async {
            // Get external controller status and secret
            final clashConfig = ref.read(patchClashConfigProvider);
            final externalController = clashConfig.externalController;
            final secret = clashConfig.secret;

            // Pass secret only if external controller is enabled
            if (externalController == ExternalControllerStatus.open &&
                secret != null &&
                secret.isNotEmpty) {
              // Build URL with secret in fragment
              final uri = Uri.parse(
                'http://127.0.0.1:9090/ui/#/setup?hostname=127.0.0.1&port=9090&secret=$secret',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } else {
              // External controller not enabled or no secret
              final uri = Uri.parse('http://127.0.0.1:9090/ui/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
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
                        appLocalizations.openDashboard,
                        style: context.textTheme.bodyMedium?.toLight.adjustSize(
                          0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
