import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/views/about.dart';
import 'package:meowclash/views/application_setting.dart';
import 'package:meowclash/views/backup_and_recovery.dart';
import 'package:meowclash/views/config/config.dart';
import 'package:meowclash/views/config/dns.dart';
import 'package:meowclash/views/config/general.dart';
import 'package:meowclash/views/config/network.dart';
import 'package:meowclash/views/developer.dart';
import 'package:meowclash/views/hotkey.dart';
import 'package:meowclash/views/media_unlock/media_unlock_page.dart';
import 'package:meowclash/views/proxies/providers.dart';
import 'package:meowclash/views/proxies/setting.dart';
import 'package:meowclash/views/resources.dart';
import 'package:meowclash/views/theme.dart';
import 'package:meowclash/views/tools.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'settings_test_support.dart';

/// Pixel baseline of the Material settings screens (Tools tab and every page
/// it opens, plus the other `ListItem` / `generateSection` lists: proxies
/// settings and providers sheets, dashboard quick options, resources, media
/// unlock) that Android, Linux and Windows must keep after the Darwin glass
/// settings. The images were generated on `main` before the glass settings
/// landed and must still match. Regenerate only for an intended Material
/// change: `flutter test --update-goldens test/material_settings_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Tall enough for the longest page (General) without scrolling.
  const size = Size(400, 1400);

  setUpAll(() => setUpSettingsEnvironment('material_settings'));

  final screens = <String, WidgetBuilder>{
    'tools': (_) => const ToolsView(),
    'application': (_) => const ApplicationSettingView(),
    'config': (_) => const ConfigView(),
    'general': (_) => generateListView(generalItems),
    'network': (_) => const NetworkListView(),
    'dns': (_) => const DnsListView(),
    'backup': (_) => const BackupAndRecovery(),
    'hotkeys': (_) => const HotKeyView(),
    'about': (_) => const AboutView(),
    'developer': (_) => const DeveloperView(),
    'theme': (_) => const ThemeView(),
    'proxies_setting': (_) => const ProxiesSetting(),
    'providers': (_) => const ProvidersView(),
    'quick_options_tun': (_) => generateListView(
          generateSection(
            items: const [TUNItem(), AutoSetSystemDnsItem(), TunStackItem()],
          ),
        ),
    'resources': (_) => const ResourcesView(),
    'media_unlock': (_) => const MediaUnlockPage(),
  };

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  for (final brightness in Brightness.values) {
    final b = brightness.name;
    for (final MapEntry(key: name, value: builder) in screens.entries) {
      testWidgets('$name, $b', (tester) async {
        await setUpSettingsScreen(tester, size);
        await tester.pumpWidget(settingsHost(brightness, builder));
        await pumpSettingsFrames(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_settings_${name}_$b.png'),
        );
      }, variant: android);
    }
  }
}
