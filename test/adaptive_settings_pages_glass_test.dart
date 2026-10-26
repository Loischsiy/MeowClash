import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/views/application_setting.dart';
import 'package:meowclash/views/tools.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

import 'settings_test_support.dart';

/// Darwin settings pages: each renders as an Apple grouped list (sections of
/// `GlassListRow`s, no Material tiles or dividers, no blur in the scroll
/// view). The Material pages are pinned by `material_settings_golden_test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 1400);
  const darwin = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  });

  setUpAll(() => setUpSettingsEnvironment('glass_settings_pages'));
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  Future<void> pumpPage(
    WidgetTester tester,
    WidgetBuilder builder, {
    Brightness brightness = Brightness.light,
  }) async {
    AdaptivePlatform.debugUseGlassOverride = true;
    await setUpSettingsScreen(tester, size);
    await tester.pumpWidget(settingsHost(brightness, builder));
    await pumpSettingsFrames(tester);
    expect(tester.takeException(), isNull);
  }

  Iterable<GlassListRow> rows(WidgetTester tester) =>
      tester.widgetList<GlassListRow>(find.byType(GlassListRow));

  void expectGroupedList() {
    expect(find.byType(GlassListView), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(
      find.descendant(
        of: find.byType(GlassListView),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  }

  group('Tools tab', () {
    for (final brightness in Brightness.values) {
      testWidgets('grouped sections, chevrons, language pop-up, $brightness',
          (tester) async {
        await pumpPage(
          tester,
          (_) => const ToolsView(),
          brightness: brightness,
        );
        expectGroupedList();
        // More (when it has items) + Settings + Other.
        expect(find.byType(GlassListSection), findsAtLeastNWidgets(2));
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Other'), findsOneWidget);
        final accessories = rows(tester).map((row) => row.accessory).toList();
        expect(accessories, contains(GlassRowAccessory.popUp));
        expect(
          accessories.where((a) => a == GlassRowAccessory.chevron).length,
          greaterThanOrEqualTo(4),
        );
      }, variant: darwin);
    }
  });

  group('Application page', () {
    testWidgets('switches, actions and the red reset in three sections',
        (tester) async {
      await pumpPage(tester, (_) => const ApplicationSettingView());
      expectGroupedList();
      expect(find.byType(GlassListSection), findsNWidgets(3));
      expect(find.byType(AdaptiveSwitch), findsWidgets);
      // Action rows have no Material disclosure arrow.
      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
      final reset = rows(tester).singleWhere((row) => row.destructive);
      expect((reset.title as Text).data, 'Clear Data');
      expect(reset.onTap, isNotNull);
      // The reset row is alone in the last section.
      final lastSection = find.byType(GlassListSection).last;
      expect(
        find.descendant(of: lastSection, matching: find.byType(GlassListRow)),
        findsOneWidget,
      );
    }, variant: darwin);
  });
}
