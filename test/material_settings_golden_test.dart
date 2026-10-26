import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/constant.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/path.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'performance_test_support.dart';

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

  setUpAll(() async {
    // Network and resources read app directories: point them at an empty
    // temp dir and resolve them outside any test's fake-async zone.
    final dir = await Directory.systemTemp.createTemp('material_settings');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    await appPath.dataDir.future;
    await appPath.tempDir.future;
    await appPath.downloadDir.future;
    // About and Theme read the startup values `globalState.init` would set.
    globalState.packageInfo = PackageInfo(
      appName: 'MeowClash',
      packageName: 'com.meowclash.app',
      version: '1.0.0',
      buildNumber: '1',
    );
    globalState.accentColor = const Color(defaultPrimaryColor);
  });

  Future<void> setUp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(Brightness brightness, WidgetBuilder builder) => ProviderScope(
        overrides: [
          backgroundUrlProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              globalState.appController = AppController(context, ref);
              globalState.measure = Measure.of(context, 1);
              globalState.theme = CommonTheme.of(context, 1);
              return builder(context);
            }),
          ),
        ),
      );

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
        await setUp(tester);
        await tester.pumpWidget(host(brightness, builder));
        // Some pages keep a spinner or a polling timer alive, so never wait
        // for the tree to settle: pump a fixed second of frames.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_settings_${name}_$b.png'),
        );
      }, variant: android);
    }
  }
}
