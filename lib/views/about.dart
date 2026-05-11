import 'dart:async';

import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/providers/config.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/widgets/list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class Contributor {
  final String avatar;
  final String name;

  const Contributor({required this.avatar, required this.name});
}

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  Future<void> _checkUpdate(BuildContext context) async {
    final commonScaffoldState = context.commonScaffoldState;
    if (commonScaffoldState?.mounted != true) return;
    final data = await globalState.appController.safeRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: appLocalizations.checkUpdate,
      needLoading: true,
    );
    globalState.appController.checkUpdateResultHandle(
      data: data,
      handleError: true,
    );
  }

  List<Widget> _buildMoreSection(BuildContext context) {
    return generateSection(
      separated: false,
      title: appLocalizations.more,
      items: [
        ListItem(
          title: Text(appLocalizations.checkUpdate),
          onTap: () {
            _checkUpdate(context);
          },
        ),
        ListItem(
          title: const Text('Github Releases'),
          onTap: () {
            globalState.openUrl('https://github.com/appshubcc/MeowClash');
          },
          trailing: const Icon(Icons.star),
        ),
        ListItem(
          title: const Text('Telegram Group'),
          onTap: () {
            globalState.openUrl('https://t.me/appshub_chat');
          },
          trailing: const Icon(Icons.launch),
        ),
        ListItem(
          title: const Text('Telegram Channel'),
          onTap: () {
            globalState.openUrl('https://t.me/appshub_channel');
          },
          trailing: const Icon(Icons.launch),
        ),
        ListItem(
          title: const Text('FlClash'),
          onTap: () {
            globalState.openUrl('https://github.com/chen08209/FlClash');
          },
          trailing: const Icon(Icons.launch),
        ),
        ListItem(
          title: const Text('Mihomo'),
          onTap: () {
            globalState.openUrl('https://github.com/MetaCubeX/mihomo');
          },
          trailing: const Icon(Icons.launch),
        ),
      ],
    );
  }

  List<Widget> _buildContributorsSection() {
    const contributors = [
      Contributor(avatar: 'assets/images/avatars/june2.jpg', name: 'June2'),
      Contributor(avatar: 'assets/images/avatars/arue.jpg', name: 'Arue'),
      Contributor(avatar: 'assets/images/avatars/dabaozi.jpg', name: '大包子'),
      Contributor(avatar: 'assets/images/avatars/xiaolou.jpg', name: '小楼'),
      Contributor(avatar: 'assets/images/avatars/www.jpg', name: 'Www'),
      Contributor(avatar: 'assets/images/avatars/AIsouler.jpg', name: 'AIsouler'),
      Contributor(avatar: 'assets/images/avatars/songchenwen.jpg', name: 'songchenwen'),
      Contributor(avatar: 'assets/images/avatars/EriDeLee.jpg', name: 'EriDeLee'),
    ];
    return generateSection(
      separated: false,
      title: appLocalizations.otherContributors,
      items: [
        ListItem(
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 24,
              children: [
                for (final contributor in contributors)
                  Avatar(contributor: contributor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer(
              builder: (_, ref, _) {
                return _DeveloperModeDetector(
                  child: Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/icon.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            '${globalState.packageInfo.version}+${globalState.packageInfo.buildNumber}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                  onEnterDeveloperMode: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .updateState(
                          (state) => state.copyWith(developerMode: true),
                        );
                    context.showNotifier(
                      appLocalizations.developerModeEnableTip,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ..._buildContributorsSection(),
      ..._buildMoreSection(context),
    ];
    return Padding(
      padding: kMaterialListPadding.copyWith(top: 16, bottom: 16),
      child: generateListView(items),
    );
  }
}

class Avatar extends StatelessWidget {
  final Contributor contributor;

  const Avatar({super.key, required this.contributor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: CircleAvatar(foregroundImage: AssetImage(contributor.avatar)),
        ),
        const SizedBox(height: 4),
        Text(contributor.name, style: context.textTheme.bodySmall),
      ],
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
