import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/common/network_matcher.dart';
import 'package:meow_clash/plugins/app.dart';
import 'package:meow_clash/plugins/service.dart';
import 'package:meow_clash/providers/config.dart';
import 'package:meow_clash/providers/providers.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartAutoStopItem extends ConsumerWidget {
  const SmartAutoStopItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartAutoStop = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStop),
    );
    final isQuickResponseEnabled =
        system.isAndroid &&
        ref.watch(vpnSettingProvider.select((state) => state.quickResponse));

    return ListItem.switchItem(
      title: Text(appLocalizations.smartAutoStop),
      subtitle: Text(appLocalizations.smartAutoStopDesc),
      delegate: SwitchDelegate(
        value: smartAutoStop,
        onChanged: isQuickResponseEnabled
            ? null
            : (bool value) async {
                ref
                    .read(vpnSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(
                        smartAutoStop: value,
                        quickResponse: value ? false : state.quickResponse,
                      ),
                    );

                if (system.isAndroid) {
                  if (value) {
                    await service?.setQuickResponse(false);
                  } else {
                    // When turning off smart auto stop, no need to auto-turn-on quickResponse
                    // User has to explicitly turn it on.
                  }
                }
              },
      ),
    );
  }
}

class NetworkMatchItem extends ConsumerWidget {
  const NetworkMatchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartAutoStopNetworks = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStopNetworks),
    );
    final isQuickResponseEnabled =
        system.isAndroid &&
        ref.watch(vpnSettingProvider.select((state) => state.quickResponse));

    return ListItem.input(
      title: Text(appLocalizations.networkMatch),
      subtitle: Text(
        smartAutoStopNetworks.isEmpty
            ? appLocalizations.networkMatchHint
            : smartAutoStopNetworks,
      ),
      delegate: InputDelegate(
        title: appLocalizations.networkMatch,
        value: smartAutoStopNetworks,
        onChanged: isQuickResponseEnabled
            ? null
            : (String? value) {
                if (value != null) {
                  ref
                      .read(vpnSettingProvider.notifier)
                      .updateState(
                        (state) => state.copyWith(smartAutoStopNetworks: value),
                      );
                }
              },
        validator: (String? value) {
          if (value == null || value.isEmpty) return null;
          return NetworkMatcher.getValidationError(
            value,
            invalidFormatMsg: appLocalizations.invalidIpFormat,
            tooManyRulesMsg: appLocalizations.tooManyRules,
          );
        },
      ),
    );
  }
}

class DozeSuspendItem extends ConsumerWidget {
  const DozeSuspendItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dozeSuspend = ref.watch(
      vpnSettingProvider.select((state) => state.dozeSuspend),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.dozeSuspend),
      subtitle: Text(appLocalizations.dozeSuspendDesc),
      delegate: SwitchDelegate(
        value: dozeSuspend,
        onChanged: (bool value) {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(dozeSuspend: value));
        },
      ),
    );
  }
}

class StoreFixItem extends ConsumerWidget {
  const StoreFixItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeFix = ref.watch(
      vpnSettingProvider.select((state) => state.storeFix),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.storeFix),
      subtitle: Text(appLocalizations.storeFixDesc),
      delegate: SwitchDelegate(
        value: storeFix,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(storeFix: value));

          // Update hosts mapping
          final currentHosts = Map<String, String>.from(
            ref.read(patchClashConfigProvider).hosts,
          );

          if (value) {
            // Add the hosts mapping
            currentHosts['service.googleapis.cn'] = 'service.googleapis.com';
          } else {
            // Remove the hosts mapping
            currentHosts.remove('service.googleapis.cn');
          }

          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith(hosts: currentHosts));
        },
      ),
    );
  }
}

class FcmOptimizationItem extends ConsumerWidget {
  const FcmOptimizationItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fcmOptimization = ref.watch(
      vpnSettingProvider.select((state) => state.fcmOptimization),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.fcmOptimization),
      subtitle: Text(appLocalizations.fcmOptimizationDesc),
      delegate: SwitchDelegate(
        value: fcmOptimization,
        onChanged: (bool value) async {
          // Update FCM optimization state
          ref
              .read(vpnSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(
                  fcmOptimization: value,
                  // Force disable allowBypass when FCM optimization is on (Android only)
                  allowBypass: value && system.isAndroid
                      ? false
                      : state.allowBypass,
                ),
              );

          // Update hosts mapping
          final currentHosts = Map<String, String>.from(
            ref.read(patchClashConfigProvider).hosts,
          );

          if (value) {
            // Add FCM hosts mapping (comma-separated IPs)
            currentHosts['mtalk.google.com'] =
                '142.250.107.188, 108.177.125.188';
          } else {
            // Remove FCM hosts mapping
            currentHosts.remove('mtalk.google.com');
          }

          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith(hosts: currentHosts));
        },
      ),
    );
  }
}

class QuickResponseItem extends ConsumerWidget {
  const QuickResponseItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickResponse = ref.watch(
      vpnSettingProvider.select((state) => state.quickResponse),
    );
    final isSmartAutoStopEnabled = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStop),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.quickResponse),
      subtitle: Text(appLocalizations.quickResponseDesc),
      delegate: SwitchDelegate(
        value: quickResponse,
        onChanged: isSmartAutoStopEnabled
            ? null
            : (bool value) async {
                ref
                    .read(vpnSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(
                        quickResponse: value,
                        smartAutoStop: value ? false : state.smartAutoStop,
                      ),
                    );

                if (system.isAndroid) {
                  await service?.setQuickResponse(value);
                }
              },
      ),
    );
  }
}

class NetworkFixItem extends ConsumerWidget {
  const NetworkFixItem({super.key});

  Future<void> _applyNetworkFix(bool enable) async {
    try {
      // Registry path
      const regPath =
          r'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet';

      if (enable) {
        // Apply NETFIX config
        final commands = [
          // DNS probe config
          'reg add "$regPath" /v ActiveDnsProbeContent /t REG_SZ /d "131.107.255.255" /f',
          'reg add "$regPath" /v ActiveDnsProbeContentV6 /t REG_SZ /d "fd3e:4f5a:5b81::1" /f',
          'reg add "$regPath" /v ActiveDnsProbeHost /t REG_SZ /d "dns.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveDnsProbeHostV6 /t REG_SZ /d "dns.msftncsi.com" /f',

          // Web probe config
          'reg add "$regPath" /v ActiveWebProbeContent /t REG_SZ /d "" /f',
          'reg add "$regPath" /v ActiveWebProbeContentV6 /t REG_SZ /d "" /f',
          'reg add "$regPath" /v ActiveWebProbeHost /t REG_SZ /d "dns.alidns.com" /f',
          'reg add "$regPath" /v ActiveWebProbeHostV6 /t REG_SZ /d "dns.alidns.com" /f',
          'reg add "$regPath" /v ActiveWebProbePath /t REG_SZ /d "dns-query" /f',
          'reg add "$regPath" /v ActiveWebProbePathV6 /t REG_SZ /d "dns-query" /f',

          // Other config
          'reg add "$regPath" /v CaptivePortalTimer /t REG_DWORD /d 0x00000000 /f',
          'reg add "$regPath" /v CaptivePortalTimerBackOffIncrementsInSeconds /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v CaptivePortalTimerMaxInSeconds /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v EnableActiveProbing /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v PassivePollPeriod /t REG_DWORD /d 0x0000000f /f',
          'reg add "$regPath" /v StaleThreshold /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v WebTimeout /t REG_DWORD /d 0x00000023 /f',
        ];

        for (final cmd in commands) {
          windows?.runas(cmd, '', showWindow: false);
        }
      } else {
        // Restore WinNET default config
        final commands = [
          // DNS probe config
          'reg add "$regPath" /v ActiveDnsProbeContent /t REG_SZ /d "131.107.255.255" /f',
          'reg add "$regPath" /v ActiveDnsProbeContentV6 /t REG_SZ /d "fd3e:4f5a:5b81::1" /f',
          'reg add "$regPath" /v ActiveDnsProbeHost /t REG_SZ /d "dns.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveDnsProbeHostV6 /t REG_SZ /d "dns.msftncsi.com" /f',

          // Web probe config - restore to Microsoft NCSI
          'reg add "$regPath" /v ActiveWebProbeContent /t REG_SZ /d "Microsoft NCSI" /f',
          'reg add "$regPath" /v ActiveWebProbeContentV6 /t REG_SZ /d "Microsoft NCSI" /f',
          'reg add "$regPath" /v ActiveWebProbeHost /t REG_SZ /d "www.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveWebProbeHostV6 /t REG_SZ /d "ipv6.msftncsi.com" /f',
          'reg add "$regPath" /v ActiveWebProbePath /t REG_SZ /d "ncsi.txt" /f',
          'reg add "$regPath" /v ActiveWebProbePathV6 /t REG_SZ /d "ncsi.txt" /f',

          // Other config
          'reg add "$regPath" /v CaptivePortalTimer /t REG_DWORD /d 0x00000000 /f',
          'reg add "$regPath" /v CaptivePortalTimerBackOffIncrementsInSeconds /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v CaptivePortalTimerMaxInSeconds /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v EnableActiveProbing /t REG_DWORD /d 0x00000001 /f',
          'reg add "$regPath" /v PassivePollPeriod /t REG_DWORD /d 0x0000000f /f',
          'reg add "$regPath" /v StaleThreshold /t REG_DWORD /d 0x0000001e /f',
          'reg add "$regPath" /v WebTimeout /t REG_DWORD /d 0x00000023 /f',
        ];

        for (final cmd in commands) {
          windows?.runas(cmd, '', showWindow: false);
        }
      }
    } catch (e) {
      commonPrint.log('Network fix error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkFix = ref.watch(
      vpnSettingProvider.select((state) => state.networkFix),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.networkFix),
      subtitle: Text(appLocalizations.networkFixDesc),
      delegate: SwitchDelegate(
        value: networkFix,
        onChanged: (bool value) async {
          try {
            await _applyNetworkFix(value);

            ref
                .read(vpnSettingProvider.notifier)
                .updateState((state) => state.copyWith(networkFix: value));
          } catch (e) {
            // Show error if failed
            if (context.mounted) {
              context.showSnackBar('Network fix failed: $e');
            }
          }
        },
      ),
    );
  }
}

class BatteryOptimizationItem extends ConsumerWidget {
  const BatteryOptimizationItem({super.key});

  Future<void> _handleTap(BuildContext context) async {
    try {
      // Check if already in whitelist
      final isIgnoring = await app.isIgnoringBatteryOptimizations();

      if (isIgnoring) {
        // Already in whitelist
        if (context.mounted) {
          context.showSnackBar(appLocalizations.alreadyInWhitelist);
        }
      } else {
        // Request to add to whitelist
        await app.requestIgnoreBatteryOptimizations();
      }
    } catch (e) {
      commonPrint.log('Battery optimization error: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListItem(
      title: Text(appLocalizations.batteryOptimization),
      subtitle: Text(appLocalizations.batteryOptimizationDesc),
      onTap: () => _handleTap(context),
    );
  }
}

class DisableQuicItem extends ConsumerWidget {
  const DisableQuicItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disableQuic = ref.watch(
      vpnSettingProvider.select((state) => state.disableQuic),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.disableQuic),
      subtitle: Text(appLocalizations.disableQuicDesc),
      delegate: SwitchDelegate(
        value: disableQuic,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(disableQuic: value));
          globalState.appController.setupClashConfigDebounce();
        },
      ),
    );
  }
}

class ExcludeChinaItem extends ConsumerWidget {
  const ExcludeChinaItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excludeChina = ref.watch(
      vpnSettingProvider.select((state) => state.excludeChina),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.excludeChina),
      subtitle: Text(appLocalizations.excludeChinaDesc),
      delegate: SwitchDelegate(
        value: excludeChina,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(excludeChina: value));
          globalState.appController.setupClashConfigDebounce();
        },
      ),
    );
  }
}

class OtherSettingView extends ConsumerWidget {
  const OtherSettingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartAutoStop = ref.watch(
      vpnSettingProvider.select((state) => state.smartAutoStop),
    );
    final disableQuic = ref.watch(
      vpnSettingProvider.select((state) => state.disableQuic),
    );
    final locale = ref.watch(appSettingProvider.select((state) => state.locale));
    final isRussian = locale?.toLowerCase().startsWith('ru') ?? false;

    List<Widget> items = [
      const SmartAutoStopItem(),
      if (smartAutoStop) const NetworkMatchItem(),
      if (system.isAndroid) const DozeSuspendItem(),
      if (system.isAndroid) const QuickResponseItem(),
      const FcmOptimizationItem(),
      const StoreFixItem(),
      const DisableQuicItem(),
      if (disableQuic && !isRussian) const ExcludeChinaItem(),
      if (system.isWindows) const NetworkFixItem(),
      if (system.isAndroid) const BatteryOptimizationItem(),
    ];

    if (items.isEmpty) {
      return const Center(child: Text('No settings available'));
    }

    return ListView.separated(
      itemBuilder: (_, index) {
        final item = items[index];
        return item;
      },
      separatorBuilder: (_, _) {
        return const Divider(height: 0);
      },
      itemCount: items.length,
    );
  }
}
