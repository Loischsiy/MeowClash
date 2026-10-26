import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

import 'dashboard_test_support.dart';
import 'settings_test_support.dart';

/// Darwin glass "Dashboard": the widget tiles, their states and fallbacks.
/// The Material screen is pinned by `material_dashboard_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('meowclash_dashboard_glass'));

  const mobile = Size(400, 900);
  const wide = Size(1100, 800);
  final darwin =
      TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.iOS});

  group('tiles', () {
    for (final brightness in Brightness.values) {
      final b = brightness.name;

      testWidgets('all widgets, wide, started, $b', (tester) async {
        await setUpDashboardScreen(
          tester,
          wide,
          widgets: dashboardWidgetsAll,
          started: true,
        );
        await pumpDashboard(tester, dashboardHost(brightness));
        expect(tester.takeException(), isNull);
        expect(find.byType(AdaptiveWidgetTile), findsWidgets);
        expect(
          find.descendant(
            of: find.byType(AdaptiveWidgetTile),
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );
        expect(find.byType(Switch), findsNothing);
        expect(find.byType(Radio<Object?>), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tearDownDashboard(tester);
      }, variant: darwin);

      testWidgets('widgets A and B, mobile, $b', (tester) async {
        await setUpDashboardScreen(tester, mobile);
        await pumpDashboard(tester, dashboardHost(brightness));
        expect(tester.takeException(), isNull);
        await tearDownDashboard(tester);

        await setUpDashboardScreen(
          tester,
          mobile,
          widgets: dashboardWidgetsB,
          started: true,
        );
        await pumpDashboard(tester, dashboardHost(brightness));
        expect(tester.takeException(), isNull);
        await tearDownDashboard(tester);
      }, variant: darwin);

      testWidgets('no profiles, $b', (tester) async {
        await setUpDashboardScreen(tester, mobile, profiles: const []);
        await pumpDashboard(tester, dashboardHost(brightness));
        expect(tester.takeException(), isNull);
        expect(find.byType(GlassButton), findsWidgets);
        await tearDownDashboard(tester);
      }, variant: darwin);
    }
  });
}
