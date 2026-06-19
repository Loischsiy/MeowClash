import 'dart:io';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

class OpenLogsFolderItem extends ConsumerWidget {
  const OpenLogsFolderItem({super.key});

  Future<void> _openLogsFolder() async {
    try {
      final homePath = await appPath.homeDirPath;
      final logsPath = join(homePath, 'logs');
      final logsDir = Directory(logsPath);
      
      // Create logs directory if it doesn't exist
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }
      
      // Open the folder based on platform
      if (Platform.isWindows) {
        await Process.run('explorer', [logsPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [logsPath]);
      } else if (Platform.isLinux) {
        await _openLinuxFolder(logsPath);
      }
    } catch (e) {
      commonPrint.log('Failed to open logs folder: $e');
    }
  }

  Future<void> _openLinuxFolder(String path) async {
    // When running from an AppImage (or other bundled build) the process
    // environment is polluted with loader/library paths (LD_LIBRARY_PATH, GTK,
    // GDK, etc.) that point at the bundle. A system file manager launched with
    // that environment inherits these paths and usually fails to start, so the
    // folder never opens. Strip those variables for the spawned process and try
    // several common openers as a fallback.
    final cleanEnv = Map<String, String>.from(Platform.environment);
    const pollutedKeys = [
      'LD_LIBRARY_PATH',
      'LD_PRELOAD',
      'GTK_PATH',
      'GTK_EXE_PREFIX',
      'GTK_DATA_PREFIX',
      'GDK_PIXBUF_MODULE_FILE',
      'GDK_PIXBUF_MODULEDIR',
      'GSETTINGS_SCHEMA_DIR',
      'GIO_MODULE_DIR',
      'GIO_EXTRA_MODULES',
      'FONTCONFIG_FILE',
      'FONTCONFIG_PATH',
      'GCONV_PATH',
      'QT_PLUGIN_PATH',
      'PYTHONPATH',
      'PYTHONHOME',
      'PERLLIB',
    ];
    for (final key in pollutedKeys) {
      cleanEnv.remove(key);
    }
    // AppRun stores the pre-launch loader path here; restore it if present so
    // the file manager uses the host system libraries.
    final originalLdPath = Platform.environment['APPDIR_LD_LIBRARY_PATH'] ??
        Platform.environment['LD_LIBRARY_PATH_ORIG'];
    if (originalLdPath != null && originalLdPath.isNotEmpty) {
      cleanEnv['LD_LIBRARY_PATH'] = originalLdPath;
    }

    const openers = <List<String>>[
      ['xdg-open'],
      ['gio', 'open'],
      ['nautilus'],
      ['dolphin'],
      ['nemo'],
      ['thunar'],
      ['pcmanfm'],
      ['caja'],
    ];
    for (final opener in openers) {
      try {
        final result = await Process.run(
          opener.first,
          [...opener.skip(1), path],
          environment: cleanEnv,
          includeParentEnvironment: false,
        );
        if (result.exitCode == 0) {
          return;
        }
        commonPrint.log(
          'open logs folder: ${opener.first} exited ${result.exitCode}: ${result.stderr}',
        );
      } catch (e) {
        commonPrint.log('open logs folder: ${opener.first} not available: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(appLocalizations.openLogsFolder),
        leading: const Icon(Icons.folder_open),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _openLogsFolder,
      );
}

class ResetAppItem extends ConsumerWidget {
  const ResetAppItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(
          appLocalizations.clearData,
          style: TextStyle(
            color: context.colorScheme.error,
            fontWeight: FontWeight.bold,
        ),
      ),
      leading: Icon(
        Icons.delete_forever,
        color: context.colorScheme.error,
      ),
      onTap: () async {
        final res = await globalState.showMessage(
          title: appLocalizations.clearData,
          message: TextSpan(
            text: appLocalizations.clearDataTip,
            style: TextStyle(
              color: context.colorScheme.onSurface,
            ),
          ),
        );
        if (res == true) {
          await globalState.appController.handleClear();
          system.exit();
        }
      },
    );
}

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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  closeConnections: value,
                ),
              );
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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  onlyStatisticsProxy: value,
                ),
              );
        },
      ),
    );
  }
}

class MinimizeItem extends ConsumerWidget {
  const MinimizeItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimizeOnExit = ref.watch(
      appSettingProvider.select((state) => state.minimizeOnExit),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.minimizeOnExit),
      subtitle: Text(appLocalizations.minimizeOnExitDesc),
      delegate: SwitchDelegate(
        value: minimizeOnExit,
        onChanged: (bool value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  minimizeOnExit: value,
                ),
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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  autoLaunch: value,
                ),
              );
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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  silentLaunch: value,
                ),
              );
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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  autoRun: value,
                ),
              );
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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  hidden: value,
                ),
              );
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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  isAnimateToPage: value,
                ),
              );
        },
      ),
    );
  }
}

class OpenLogsItem extends ConsumerWidget {
  const OpenLogsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openLogs = ref.watch(
      appSettingProvider.select((state) => state.openLogs),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.logcat),
      subtitle: Text(appLocalizations.logcatDesc),
      delegate: SwitchDelegate(
        value: openLogs,
        onChanged: (bool value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  openLogs: value,
                ),
              );
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
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  autoCheckUpdate: value,
                ),
              );
        },
      ),
    );
  }
}

class RestartCoreItem extends ConsumerWidget {
  const RestartCoreItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(appLocalizations.restartCore),
        subtitle: Text(appLocalizations.restartCoreDesc),
        leading: const Icon(Icons.restart_alt),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          final res = await globalState.showMessage(
            title: appLocalizations.restartCore,
            message: TextSpan(
              text: appLocalizations.restartCoreTip,
              style: TextStyle(
                color: context.colorScheme.onSurface,
              ),
            ),
          );
          if (res != true) return;
          await globalState.appController.restartCore();
          globalState.showMessage(
            title: appLocalizations.restartCore,
            message: TextSpan(
              text: appLocalizations.restartCoreSuccess,
              style: TextStyle(
                color: context.colorScheme.onSurface,
              ),
            ),
            confirmText: appLocalizations.confirm,
          );
        },
      );
}

class ApplicationSettingView extends StatelessWidget {
  const ApplicationSettingView({super.key});

  String getLocaleString(Locale? locale) {
    if (locale == null) return appLocalizations.defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      MinimizeItem(),
      if (system.isDesktop) ...[
        AutoLaunchItem(),
        SilentLaunchItem(),
      ],
      AutoRunItem(),
      if (Platform.isAndroid) ...[
        HiddenItem(),
      ],
      AnimateTabItem(),
      OpenLogsItem(),
      CloseConnectionsItem(),
      AutoCheckUpdateItem(),
      if (system.isDesktop) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OpenLogsFolderItem(),
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: RestartCoreItem(),
      ),
      Padding(
        padding: EdgeInsets.only(top: system.isDesktop ? 0 : 16),
        child: ResetAppItem(),
      ),
    ];
    return ListView.separated(
      itemBuilder: (_, index) => items[index],
      separatorBuilder: (_, __) => const Divider(
        height: 0,
      ),
      itemCount: items.length,
    );
  }
}
