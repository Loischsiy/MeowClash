import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/views/dashboard/widgets/start_button.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'dashboard_test_support.dart';
import 'settings_test_support.dart';

/// Darwin glass "Dashboard": the widget tiles, their states and fallbacks.
/// The Material screen is pinned by `material_dashboard_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('meowclash_dashboard_glass'));

  const mobile = Size(400, 900);
  const wide = Size(1100, 800);
  const darwin =
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

  group('start button', () {
    Finder inButton(Finder matching) =>
        find.descendant(of: find.byType(StartButton), matching: matching);

    Color? fill(WidgetTester tester) {
      final container = tester
          .widget<AnimatedContainer>(inButton(find.byType(AnimatedContainer)));
      return (container.decoration as BoxDecoration?)?.color;
    }

    for (final brightness in Brightness.values) {
      final b = brightness.name;

      testWidgets('idle and connected fills, press dims, $b', (tester) async {
        await setUpDashboardScreen(tester, mobile);
        await pumpDashboard(tester, dashboardHost(brightness));
        expect(tester.takeException(), isNull);
        expect(fill(tester), GlassTokens.startButtonIdleFill(brightness));
        expect(inButton(find.byType(AnimatedSwitcher)), findsNothing);

        final gesture = await tester
            .startGesture(tester.getCenter(find.byType(StartButton)));
        // onTapDown fires after kPressTimeout; the next frame animates.
        await tester.pump(kPressTimeout + const Duration(milliseconds: 10));
        await tester.pump(const Duration(milliseconds: 200));
        expect(inButton(find.byType(Transform)), findsNothing);
        expect(
          tester.widget<Opacity>(inButton(find.byType(Opacity))).opacity,
          lessThan(1),
        );
        await gesture.cancel();
        await tester.pump(const Duration(milliseconds: 200));
        await tearDownDashboard(tester);

        await setUpDashboardScreen(tester, mobile, started: true);
        await pumpDashboard(tester, dashboardHost(brightness));
        expect(tester.takeException(), isNull);
        expect(fill(tester), GlassTokens.systemGreen(brightness));
        await tearDownDashboard(tester);
      }, variant: darwin);

      testWidgets('TUN failure uses glass buttons, 1.5x text, $b',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await setUpDashboardScreen(tester, const Size(320, 700));
        await pumpDashboard(
          tester,
          dashboardHost(brightness, tunFailure: 'tun: permission denied'),
        );
        expect(tester.takeException(), isNull);
        expect(inButton(find.byType(GlassIconButton)), findsOneWidget);
        expect(inButton(find.byType(GlassButton)), findsOneWidget);
        expect(inButton(find.byType(IconButton)), findsNothing);
        expect(inButton(find.byType(TextButton)), findsNothing);
        await tearDownDashboard(tester);
      }, variant: darwin);
    }

    testWidgets('Reduce Motion: the cat sits still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await setUpDashboardScreen(tester, mobile);
      await pumpDashboard(tester, dashboardHost(Brightness.light));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tearDownDashboard(tester);
    }, variant: darwin);
  });

  group('editing', () {
    Finder inGrid(Finder matching) =>
        find.descendant(of: find.byType(SuperGrid), matching: matching);

    bool anyTileTilted(WidgetTester tester) => tester
        .widgetList<Transform>(inGrid(find.byType(Transform)))
        .any((t) => t.transform.entry(1, 0).abs() > 1e-6);

    for (final brightness in Brightness.values) {
      final b = brightness.name;

      testWidgets('Edit / Done text, remove and add badges, $b',
          (tester) async {
        // The add sheet lists only the two missing widgets: the media unlock
        // tile fits its status texts in the test font only in the wide grid.
        await setUpDashboardScreen(tester, wide, widgets: [
          for (final w in dashboardWidgetsAll)
            if (w != DashboardWidget.intranetIp &&
                w != DashboardWidget.memoryInfo)
              w,
        ]);
        await pumpDashboard(tester, dashboardHost(brightness));
        expect(find.text('Edit'), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsNothing);
        expect(find.byType(GlassEditBadge), findsNothing);

        await toggleDashboardEdit(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Done'), findsOneWidget);
        expect(find.byIcon(Icons.save), findsNothing);
        expect(inGrid(find.byType(GlassEditBadge)), findsWidgets);
        expect(inGrid(find.byType(IconButton)), findsNothing);
        expect(inGrid(find.byType(BackdropFilter)), findsNothing);

        await tester.tap(find.byIcon(Icons.add_rounded));
        await pumpSettingsFrames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(GlassEditBadge), findsWidgets);
        await tester.tapAt(const Offset(4, 4));
        await pumpSettingsFrames(tester);

        await toggleDashboardEdit(tester);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.byType(GlassEditBadge), findsNothing);
        await tearDownDashboard(tester);
      }, variant: darwin);
    }

    testWidgets('Reduce Motion: no wiggle while editing', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await setUpDashboardScreen(tester, wide);
      await pumpDashboard(tester, dashboardHost(Brightness.light));
      await tester.tap(find.byType(GlassToolbarTextButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 37));
        expect(anyTileTilted(tester), isFalse);
      }
      expect(inGrid(find.byType(GlassEditBadge)), findsWidgets);
      await tearDownDashboard(tester);
    }, variant: darwin);
  });
}
