import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/pages/home.dart';
import 'package:meowclash/state.dart';

import 'performance_test_support.dart';

/// Pixel baseline of the Material chrome that Android, Linux and Windows must
/// keep after the Darwin glass work. Regenerate only for an intended Material
/// change: `flutter test --update-goldens test/adaptive_chrome_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(initializePerformanceState);

  const items = [
    NavigationItem(
      icon: Icon(Icons.space_dashboard),
      label: PageLabel.dashboard,
      view: SizedBox(),
    ),
    NavigationItem(
      icon: Icon(Icons.article),
      label: PageLabel.proxies,
      view: SizedBox(),
    ),
    NavigationItem(
      icon: Icon(Icons.folder),
      label: PageLabel.profiles,
      view: SizedBox(),
    ),
    NavigationItem(
      icon: Icon(Icons.construction),
      label: PageLabel.tools,
      view: SizedBox(),
    ),
  ];

  Widget host(Widget child, Brightness brightness) => ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
              brightness: brightness,
            ),
          ),
          home: Builder(builder: (context) {
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return Scaffold(body: child);
          }),
        ),
      );

  for (final brightness in Brightness.values) {
    testWidgets('mobile navigation bar, ${brightness.name}', (tester) async {
      await AppLocalizations.load(const Locale('en'));
      tester.view
        ..physicalSize = const Size(400, 120)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(
        const Align(
          alignment: Alignment.bottomCenter,
          child: CommonNavigationBar(
            viewMode: ViewMode.mobile,
            navigationItems: items,
            currentIndex: 1,
          ),
        ),
        brightness,
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CommonNavigationBar),
        matchesGoldenFile(
          'goldens/material_navigation_bar_${brightness.name}.png',
        ),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('desktop navigation rail, ${brightness.name}', (tester) async {
      await AppLocalizations.load(const Locale('en'));
      tester.view
        ..physicalSize = const Size(120, 520)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(
        const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 520,
            child: CommonNavigationBar(
              viewMode: ViewMode.desktop,
              navigationItems: items,
              currentIndex: 2,
            ),
          ),
        ),
        brightness,
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CommonNavigationBar),
        matchesGoldenFile(
          'goldens/material_navigation_rail_${brightness.name}.png',
        ),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
