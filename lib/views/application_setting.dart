import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/providers/config.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      delegate: SwitchDelegate(
        value: closeConnections,
        onChanged: (value) async {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(closeConnections: value));
        },
      ),
    );
  }
}

class UsageItem extends ConsumerWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final onlyStatisticsProxy = ref.watch(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.onlyStatisticsProxy),
      subtitle: Text(appLocalizations.onlyStatisticsProxyDesc),
      delegate: SwitchDelegate(
        value: onlyStatisticsProxy,
        onChanged: (bool value) async {
          ref
              .read(appSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(onlyStatisticsProxy: value),
              );
        },
      ),
    );
  }
}

class AutoLaunchItem extends ConsumerWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoLaunch),
      subtitle: Text(appLocalizations.autoLaunchDesc),
      delegate: SwitchDelegate(
        value: autoLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(autoLaunch: value));
        },
      ),
    );
  }
}

class SmartDelayLaunchItem extends ConsumerWidget {
  const SmartDelayLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartDelayLaunch = ref.watch(
      appSettingProvider.select((state) => state.smartDelayLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.smartDelayLaunch),
      subtitle: Text(appLocalizations.smartDelayLaunchDesc),
      delegate: SwitchDelegate(
        value: smartDelayLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(smartDelayLaunch: value));
        },
      ),
    );
  }
}

class SilentLaunchItem extends ConsumerWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final silentLaunch = ref.watch(
      appSettingProvider.select((state) => state.silentLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.silentLaunch),
      subtitle: Text(appLocalizations.silentLaunchDesc),
      delegate: SwitchDelegate(
        value: silentLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(silentLaunch: value));
        },
      ),
    );
  }
}

class AutoRunItem extends ConsumerWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoRun = ref.watch(
      appSettingProvider.select((state) => state.autoRun),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoRun),
      subtitle: Text(appLocalizations.autoRunDesc),
      delegate: SwitchDelegate(
        value: autoRun,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(autoRun: value));
        },
      ),
    );
  }
}

class HiddenItem extends ConsumerWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hidden),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.exclude),
      subtitle: Text(appLocalizations.excludeDesc),
      delegate: SwitchDelegate(
        value: hidden,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(hidden: value));
        },
      ),
    );
  }
}

class AnimateTabItem extends ConsumerWidget {
  const AnimateTabItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnimateToPage = ref.watch(
      appSettingProvider.select((state) => state.isAnimateToPage),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.tabAnimation),
      subtitle: Text(appLocalizations.tabAnimationDesc),
      delegate: SwitchDelegate(
        value: isAnimateToPage,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(isAnimateToPage: value));
        },
      ),
    );
  }
}

class NavBarHapticFeedbackItem extends ConsumerWidget {
  const NavBarHapticFeedbackItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableNavBarHapticFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.navBarHapticFeedback),
      subtitle: Text(appLocalizations.navBarHapticFeedbackDesc),
      delegate: SwitchDelegate(
        value: enableNavBarHapticFeedback,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
            (state) => state.copyWith(enableNavBarHapticFeedback: value),
          );
        },
      ),
    );
  }
}

class HighRefreshRateItem extends ConsumerWidget {
  const HighRefreshRateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableHighRefreshRate = ref.watch(
      appSettingProvider.select((state) => state.enableHighRefreshRate),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.highRefreshRate),
      subtitle: Text(appLocalizations.highRefreshRateDesc),
      delegate: SwitchDelegate(
        value: enableHighRefreshRate,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
            (state) => state.copyWith(enableHighRefreshRate: value),
          );

          if (context.mounted) {
            context.showSnackBar(appLocalizations.restartTip);
          }
        },
      ),
    );
  }
}

class AutoCheckUpdateItem extends ConsumerWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoCheckUpdate = ref.watch(
      appSettingProvider.select((state) => state.autoCheckUpdate),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCheckUpdate),
      subtitle: Text(appLocalizations.autoCheckUpdateDesc),
      delegate: SwitchDelegate(
        value: autoCheckUpdate,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(autoCheckUpdate: value));
        },
      ),
    );
  }
}

class ApplicationSettingView extends StatelessWidget {
  const ApplicationSettingView({super.key});



  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final autoLaunch = ref.watch(
          appSettingProvider.select((state) => state.autoLaunch),
        );
        List<Widget> items = [
          AutoLaunchItem(),
          if (system.isDesktop) ...[
            if (system.isWindows && autoLaunch) SmartDelayLaunchItem(),
            SilentLaunchItem(),
          ],
          AutoRunItem(),
          if (system.isAndroid) ...[HiddenItem()],
          AnimateTabItem(),
          if (system.isAndroid) ...[
            NavBarHapticFeedbackItem(),
            HighRefreshRateItem(),
          ],
          CloseConnectionsItem(),
          UsageItem(),
          AutoCheckUpdateItem(),
        ];
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
      },
    );
  }
}
