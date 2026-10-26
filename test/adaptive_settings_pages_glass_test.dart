import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/views/application_setting.dart';
import 'package:meowclash/views/config/config.dart';
import 'package:meowclash/views/config/dns.dart';
import 'package:meowclash/views/config/general.dart';
import 'package:meowclash/views/config/network.dart';
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

  group('Basic config', () {
    const managed = 'These settings are managed by your provider';

    // The note is the section footer, not a Material banner in the card.
    void expectNoBanner() => expect(
          find.descendant(
            of: find.byType(GlassListRow),
            matching: find.text(managed),
          ),
          findsNothing,
        );

    testWidgets('General, Network and DNS rows in one section',
        (tester) async {
      await pumpPage(tester, (_) => const ConfigView());
      expectGroupedList();
      expect(find.byType(GlassListSection), findsOneWidget);
      expect(rows(tester), hasLength(3));
      expect(
        rows(tester).every((row) => row.accessory == GlassRowAccessory.chevron),
        isTrue,
      );
    }, variant: darwin);

    testWidgets('General: override section with the provider note as footer',
        (tester) async {
      await pumpPage(tester, (_) => const GeneralListView());
      expectGroupedList();
      // Override / core options / ports and inbound / behaviour.
      expect(find.byType(GlassListSection), findsNWidgets(4));
      final first = tester.widget<GlassListSection>(
        find.byType(GlassListSection).first,
      );
      expect(first.footer, managed);
      expect(find.text(managed), findsOneWidget);
      expectNoBanner();
      expect(find.byType(AdaptiveSwitch), findsWidgets);
      expect(rows(tester).length, greaterThanOrEqualTo(14));
    }, variant: darwin);

    testWidgets('Network: override section first, then the option groups',
        (tester) async {
      await pumpPage(tester, (_) => const NetworkListView());
      expectGroupedList();
      expect(find.byType(GlassListSection), findsAtLeastNWidgets(2));
      // (System on desktop,) override, Options.
      final sections = tester
          .widgetList<GlassListSection>(find.byType(GlassListSection))
          .toList();
      final override = sections.singleWhere((s) => s.footer == managed);
      expect(override.header, isNull);
      expect(override.children, hasLength(1));
      expect(sections.indexOf(override) + 1, lessThan(sections.length));
      expect(sections[sections.indexOf(override) + 1].header, 'Options');
      expect(find.text(managed), findsOneWidget);
      expectNoBanner();
      expect(find.text('Options'), findsOneWidget);
      // The stack mode is picked from a pop-up menu.
      expect(
        rows(tester).map((row) => row.accessory),
        contains(GlassRowAccessory.popUp),
      );
    }, variant: darwin);

    testWidgets('DNS: override row, Options and Fallback filter sections',
        (tester) async {
      await pumpPage(tester, (_) => const DnsListView());
      expectGroupedList();
      expect(find.byType(GlassListSection), findsNWidgets(3));
      expect(find.text('Options'), findsOneWidget);
      expect(rows(tester).length, greaterThanOrEqualTo(20));
    }, variant: darwin);
  });
}
