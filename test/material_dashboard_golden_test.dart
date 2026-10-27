import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';

import 'dashboard_test_support.dart';
import 'settings_test_support.dart';

/// Pixel baseline of the Material "Dashboard" screen that Android, Linux and
/// Windows must keep after the Darwin glass work on that screen. The images
/// were generated on `main` before the glass dashboard landed and must still
/// match. Regenerate only for an intended Material change:
/// `flutter test --update-goldens test/material_dashboard_golden_test.dart`.
///
/// Which toggles show (TUN / system proxy vs VPN) follows the host OS of the
/// run, so compare on the same OS the images were made on (macOS).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('meowclash_dashboard_golden'));

  const mobile = Size(400, 900);
  const wide = Size(1100, 800);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Future<void> expectScreen(WidgetTester tester, String name) => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_dashboard_$name.png'),
      );

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('widgets A, idle, $b', (tester) async {
      await setUpDashboardScreen(tester, mobile);
      await pumpDashboard(tester, dashboardHost(brightness));
      await expectScreen(tester, 'widgets_a_idle_$b');
      await tearDownDashboard(tester);
    }, variant: android);

    testWidgets('widgets B, started, $b', (tester) async {
      await setUpDashboardScreen(
        tester,
        mobile,
        widgets: dashboardWidgetsB,
        started: true,
      );
      await pumpDashboard(tester, dashboardHost(brightness));
      await expectScreen(tester, 'widgets_b_started_$b');
      await tearDownDashboard(tester);
    }, variant: android);

    testWidgets('all widgets, wide, started, $b', (tester) async {
      await setUpDashboardScreen(
        tester,
        wide,
        widgets: dashboardWidgetsAll,
        started: true,
      );
      await pumpDashboard(tester, dashboardHost(brightness));
      await expectScreen(tester, 'all_wide_$b');
      await tearDownDashboard(tester);
    }, variant: android);

    testWidgets('edit mode, $b', (tester) async {
      await setUpDashboardScreen(tester, mobile);
      await pumpDashboard(tester, dashboardHost(brightness));
      await toggleDashboardEdit(tester);
      await expectScreen(tester, 'edit_$b');
      await tearDownDashboard(tester);
    }, variant: android);

    // The small media unlock tile only fits its status texts in the test
    // font on the wide grid (the sheet is narrower), so it stays placed.
    testWidgets('add widgets sheet, $b', (tester) async {
      const hidden = {
        DashboardWidget.outboundMode,
        DashboardWidget.networkDetection,
        DashboardWidget.intranetIp,
        DashboardWidget.memoryInfo,
      };
      await setUpDashboardScreen(
        tester,
        wide,
        widgets: [
          for (final w in dashboardWidgetsAll)
            if (!hidden.contains(w)) w,
        ],
      );
      await pumpDashboard(tester, dashboardHost(brightness));
      await toggleDashboardEdit(tester);
      await tester.tap(find.byIcon(Icons.add_circle));
      await pumpSettingsFrames(tester);
      await pumpShakeToRest(tester);
      await expectScreen(tester, 'add_sheet_$b');
      await tearDownDashboard(tester);
    }, variant: android);

    testWidgets('no profiles, $b', (tester) async {
      await setUpDashboardScreen(tester, mobile, profiles: const []);
      await pumpDashboard(tester, dashboardHost(brightness));
      await expectScreen(tester, 'empty_$b');
      await tearDownDashboard(tester);
    }, variant: android);

    // The failure line only fits the test font on a wide window.
    testWidgets('TUN failure, $b', (tester) async {
      await setUpDashboardScreen(tester, wide);
      await pumpDashboard(
        tester,
        dashboardHost(brightness, tunFailure: 'route: operation not permitted'),
      );
      await expectScreen(tester, 'tun_failure_$b');
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await pumpSettingsFrames(tester);
      await expectScreen(tester, 'tun_failure_dialog_$b');
      await tearDownDashboard(tester);
    }, variant: android);

    testWidgets('IP details dialog, $b', (tester) async {
      await setUpDashboardScreen(tester, mobile, widgets: dashboardWidgetsB);
      await pumpDashboard(tester, dashboardHost(brightness));
      await openIpDetailsDialog(tester);
      await expectScreen(tester, 'ip_details_$b');
      await tearDownDashboard(tester);
    }, variant: android);
  }
}
