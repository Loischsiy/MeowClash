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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'performance_test_support.dart';

/// Shared host of the settings screen tests (Material goldens and the Darwin
/// glass pages).

/// Call from `setUpAll`. Network and resources read app directories: point
/// them at an empty temp dir and resolve them outside any test's fake-async
/// zone. About and Theme read the startup values `globalState.init` would
/// set.
Future<void> setUpSettingsEnvironment(String tempPrefix) async {
  final dir = await Directory.systemTemp.createTemp(tempPrefix);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );
  await appPath.dataDir.future;
  await appPath.tempDir.future;
  await appPath.downloadDir.future;
  globalState.packageInfo = PackageInfo(
    appName: 'MeowClash',
    packageName: 'com.meowclash.app',
    version: '1.0.0',
    buildNumber: '1',
  );
  globalState.accentColor = const Color(defaultPrimaryColor);
}

/// Per test: fresh app state at [size] and a view of the same size.
Future<void> setUpSettingsScreen(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await AppLocalizations.load(const Locale('en'));
  initializePerformanceState();
  globalState.appState = globalState.appState.copyWith(viewSize: size);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget settingsHost(Brightness brightness, WidgetBuilder builder) =>
    ProviderScope(
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

/// Some pages keep a spinner or a polling timer alive, so never wait for the
/// tree to settle: pump a fixed second of frames.
Future<void> pumpSettingsFrames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
