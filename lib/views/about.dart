import 'dart:async';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';

@immutable
class Contributor {
  const Contributor({
    this.avatar,
    required this.name,
    required this.link,
    this.clickable = true,
  });
  final String? avatar;
  final String name;
  final String link;
  final bool clickable;
}

const _contributors = [
  Contributor(
    avatar: "assets/images/avatars/loischsiy.jpeg",
    name: "Loischsiy",
    link: "https://github.com/Loischsiy",
  ),
];

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  void _showEasterEgg(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'REMNAFAMILY ONE LOVE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '❤️',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                globalState.openUrl('https://docs.rw');
              },
              child: const Text(
                'TRY REMNAWAVE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blue,
                  fontFamily: 'Unbounded',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Darwin: the app icon, name and versions centered on top (macOS About
  /// window), then Contributors and More as grouped sections; web links get
  /// the `arrow.up.forward` accessory.
  Widget _buildGlass(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mac = AdaptivePlatform.isMacOSGlass;
    final iconSize =
        mac ? GlassTokens.aboutIconSizeMac : GlassTokens.aboutIconSizeIos;
    final iconRadius =
        mac ? GlassTokens.aboutIconRadiusMac : GlassTokens.aboutIconRadiusIos;
    final secondary = GlassTextStyles.listRowSubtitle(theme.textTheme)
        .copyWith(color: scheme.onSurfaceVariant);
    final footnote = GlassTextStyles.listSectionFooter(theme.textTheme)
        .copyWith(color: scheme.onSurfaceVariant);
    final coreVersion = globalState.coreVersion;
    return GlassListView(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: GlassListSection.rowPadding,
          ),
          child: Column(
            children: [
              _EasterEggDetector(
                onEasterEgg: () => _showEasterEgg(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(iconRadius),
                      child: Image.asset(
                        'assets/images/icon.png',
                        width: iconSize,
                        height: iconSize,
                      ),
                    ),
                    const SizedBox(height: GlassTokens.aboutHeaderGap),
                    Text(
                      appName,
                      style: GlassTextStyles.aboutTitle(theme.textTheme)
                          .copyWith(color: scheme.onSurface),
                    ),
                    Text(globalState.packageInfo.version, style: secondary),
                    if (coreVersion != null && coreVersion.isNotEmpty)
                      Text('Core: $coreVersion', style: footnote),
                  ],
                ),
              ),
              const SizedBox(height: GlassTokens.aboutHeaderGap),
              Text(
                appLocalizations.desc,
                style: footnote,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        GlassListSection(
          header: appLocalizations.otherContributors,
          children: [
            GlassListField(
              child: Wrap(
                spacing: GlassTokens.aboutAvatarGap,
                runSpacing: GlassTokens.aboutAvatarGap,
                children: [
                  for (final contributor in _contributors)
                    Avatar(
                      contributor: contributor,
                      size: GlassTokens.aboutAvatarSize,
                    ),
                ],
              ),
            ),
          ],
        ),
        GlassListSection(
          header: appLocalizations.more,
          children: [
            GlassListRow(
              title: Text(appLocalizations.checkUpdate),
              onTap: () => _checkUpdate(context),
            ),
            GlassListRow(
              title: Text(appLocalizations.project),
              accessory: GlassRowAccessory.link,
              onTap: () => globalState.openUrl(
                "https://github.com/Loischsiy/MeowClash",
              ),
            ),
            GlassListRow(
              title: Text(appLocalizations.originalRepository),
              accessory: GlassRowAccessory.link,
              onTap: () => globalState.openUrl(
                "https://github.com/pluralplay/FlClashX",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final commonScaffoldState = context.commonScaffoldState;
    if (commonScaffoldState?.mounted != true) return;
    final data = await commonScaffoldState?.loadingRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: appLocalizations.checkUpdate,
    );
    globalState.appController.checkUpdateResultHandle(
      data: data,
      handleError: true,
    );
  }

  List<Widget> _buildMoreSection(BuildContext context) => generateSection(
        separated: false,
        title: appLocalizations.more,
        items: [
          ListItem(
            title: Text(appLocalizations.checkUpdate),
            onTap: () {
              _checkUpdate(context);
            },
            trailing: const Icon(Icons.update),
          ),
          ListItem(
            title: Text(appLocalizations.project),
            onTap: () {
              globalState.openUrl(
                "https://github.com/Loischsiy/MeowClash",
              );
            },
            trailing: const Icon(Icons.insert_link),
          ),
          ListItem(
            title: Text(appLocalizations.originalRepository),
            onTap: () {
              globalState.openUrl(
                "https://github.com/pluralplay/FlClashX",
              );
            },
            trailing: const Icon(Icons.insert_link),
          ),
        ],
      );

  List<Widget> _buildContributorsSection() {
    const contributors = _contributors;
    return generateSection(
      separated: false,
      title: appLocalizations.otherContributors,
      items: [
        ListItem(
          title: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final contributor in contributors)
                Avatar(
                  contributor: contributor,
                ),
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _buildGlass(context);
    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EasterEggDetector(
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
                        globalState.packageInfo.version,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      const _CoreVersionWidget(),
                    ],
                  )
                ],
              ),
              onEasterEgg: () => _showEasterEgg(context),
            ),
            const SizedBox(
              height: 24,
            ),
            Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(
        height: 12,
      ),
      ..._buildContributorsSection(),
      ..._buildMoreSection(context),
    ];
    return Padding(
      padding: kMaterialListPadding.copyWith(
        top: 16,
        bottom: 16,
      ),
      child: generateListView(items),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.contributor,
    this.size = 56.0,
  });
  final Contributor contributor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarSize = size;
    final fontSize = size * 0.25; // 14.0 for 56px
    final avatarFontSize = size * 0.46; // 26.0 for 56px

    final avatarWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: CircleAvatar(
            foregroundImage: contributor.avatar != null
                ? AssetImage(contributor.avatar!) as ImageProvider
                : null,
            backgroundColor: contributor.avatar == null
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: contributor.avatar == null
                ? Text(
                    contributor.name[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Unbounded',
                      fontSize: avatarFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          contributor.name,
          style: TextStyle(
            fontFamily: 'Unbounded',
            fontSize: fontSize,
          ),
        )
      ],
    );

    if (contributor.clickable) {
      return GestureDetector(
        onTap: () {
          globalState.openUrl(contributor.link);
        },
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}

class _CoreVersionWidget extends StatelessWidget {
  const _CoreVersionWidget();

  @override
  Widget build(BuildContext context) {
    final coreVersion = globalState.coreVersion;
    if (coreVersion == null || coreVersion.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      'Core: $coreVersion',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _EasterEggDetector extends StatefulWidget {
  const _EasterEggDetector({
    required this.child,
    required this.onEasterEgg,
  });
  final Widget child;
  final VoidCallback onEasterEgg;

  @override
  State<_EasterEggDetector> createState() => _EasterEggDetectorState();
}

class _EasterEggDetectorState extends State<_EasterEggDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 10) {
      widget.onEasterEgg();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: _handleTap,
        child: widget.child,
      );
}
