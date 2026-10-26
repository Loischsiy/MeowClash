import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/constant.dart'
    show defaultPrimaryColor, defaultPrimaryColors;
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/config.dart';
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
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/color_scheme_box.dart' show ColorSchemeBox;
import 'package:meowclash/widgets/widgets.dart'
    show CommonChip, SettingInfoCard, SettingTextCard, generateListView,
        generateSection;

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

  group('Backup, hotkeys, about, developer', () {
    List<String?> headers(WidgetTester tester) => tester
        .widgetList<GlassListSection>(find.byType(GlassListSection))
        .map((section) => section.header)
        .toList();

    for (final brightness in Brightness.values) {
      testWidgets('Backup: Remote / Local / Options, capsule, pop-up, '
          '$brightness', (tester) async {
        await pumpPage(
          tester,
          (_) => const BackupAndRecovery(),
          brightness: brightness,
        );
        expectGroupedList();
        expect(headers(tester), ['Remote', 'Local', 'Options']);
        // No account yet: the bind action is a glass capsule.
        expect(
          find.widgetWithText(GlassButton, 'Bind'),
          findsOneWidget,
        );
        expect(find.byType(FilledButton), findsNothing);
        final strategy = rows(tester).singleWhere(
          (row) => (row.title as Text).data == 'Recovery strategy',
        );
        expect(strategy.accessory, GlassRowAccessory.popUp);
        expect(strategy.value, isNotNull);
      }, variant: darwin);
    }

    testWidgets('Hotkeys: one section, a row per action', (tester) async {
      await pumpPage(tester, (_) => const HotKeyView());
      expectGroupedList();
      expect(find.byType(GlassListSection), findsOneWidget);
      expect(rows(tester), hasLength(HotAction.values.length));
      expect(find.byType(KeyboardKeyBox), findsNothing);
      expect(rows(tester).every((row) => row.onTap != null), isTrue);
    }, variant: darwin);

    test('Hotkey caps: macOS modifier order, Apple key symbols', () {
      expect(
        glassHotKeyLabels(
          {
            KeyboardModifier.meta,
            KeyboardModifier.shift,
            KeyboardModifier.alt,
            KeyboardModifier.control,
          },
          LogicalKeyboardKey.keyK.keyId,
        ),
        ['⌃', '⌥', '⇧', '⌘', 'K'],
      );
      expect(
        glassHotKeyLabels(
          {KeyboardModifier.meta},
          LogicalKeyboardKey.enter.keyId,
        ),
        ['⌘', '↩'],
      );
      expect(GlassKeyCaps.labelOf(LogicalKeyboardKey.arrowUp), '↑');
    });

    testWidgets('Hotkey recorder: large caps instead of Material key boxes',
        (tester) async {
      await pumpPage(
        tester,
        (_) => HotKeyRecorder(
          hotKeyAction: HotKeyAction(
            action: HotAction.view,
            key: LogicalKeyboardKey.keyM.keyId,
            modifiers: const {KeyboardModifier.meta, KeyboardModifier.shift},
          ),
        ),
      );
      final caps = tester.widget<GlassKeyCaps>(find.byType(GlassKeyCaps));
      expect(caps.large, isTrue);
      expect(caps.keys, ['⇧', '⌘', 'M']);
      expect(find.byType(KeyboardKeyBox), findsNothing);
      expect(find.text('+'), findsNothing);
    }, variant: darwin);

    testWidgets('About: centered header, Contributors and More with links',
        (tester) async {
      await pumpPage(tester, (_) => const AboutView());
      expectGroupedList();
      expect(headers(tester), ['Contributors', 'More']);
      expect(find.text('MeowClash'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(
        rows(tester).where((row) => row.accessory == GlassRowAccessory.link),
        hasLength(2),
      );
      expect(find.byType(Avatar), findsOneWidget);
    }, variant: darwin);

    testWidgets('Developer: mode switch alone, then the test actions',
        (tester) async {
      await pumpPage(tester, (_) => const DeveloperView());
      expectGroupedList();
      expect(headers(tester), [null, 'Options']);
      expect(find.byType(AdaptiveSwitch), findsOneWidget);
      final first = find.byType(GlassListSection).first;
      expect(
        find.descendant(of: first, matching: find.byType(GlassListRow)),
        findsOneWidget,
      );
      expect(rows(tester), hasLength(5));
    }, variant: darwin);
  });

  group('Theme', () {
    List<String?> headers(WidgetTester tester) => tester
        .widgetList<GlassListSection>(find.byType(GlassListSection))
        .map((section) => section.header)
        .toList();

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(ThemeView)));

    for (final brightness in Brightness.values) {
      testWidgets('appearance previews, swatches, scheme pop-up, slider, '
          '$brightness', (tester) async {
        await pumpPage(
          tester,
          (_) => const ThemeView(),
          brightness: brightness,
        );
        expectGroupedList();
        expect(headers(tester), ['Theme mode', 'Theme color', null, null]);
        // Material pieces are gone.
        expect(find.byType(ColorSchemeBox), findsNothing);
        expect(find.byType(ItemCard), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        // Three appearance previews, labelled.
        for (final label in ['Auto', 'Light', 'Dark']) {
          expect(find.text(label), findsOneWidget);
        }
        // Pure black + text scale.
        expect(find.byType(AdaptiveSwitch), findsNWidgets(2));
        expect(find.byType(AdaptiveSlider), findsOneWidget);
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          expect(find.byType(CupertinoSlider), findsOneWidget);
          expect(find.byType(Slider), findsNothing);
        } else {
          expect(find.byType(CupertinoSlider), findsNothing);
        }
        final scheme = rows(tester).singleWhere(
          (row) => (row.title as Text).data == 'Color schemes',
        );
        expect(scheme.accessory, GlassRowAccessory.popUp);
        expect(scheme.value, isNotNull);
      }, variant: darwin);
    }

    testWidgets('a tap on a preview changes the theme mode', (tester) async {
      await pumpPage(tester, (_) => const ThemeView());
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(
        container(tester).read(themeSettingProvider).themeMode,
        ThemeMode.dark,
      );
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Dark',
        ),
      );
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.selected, isTrue);
    }, variant: darwin);

    testWidgets('the slider follows the text scale switch', (tester) async {
      await pumpPage(tester, (_) => const ThemeView());
      final enabled =
          container(tester).read(themeSettingProvider).textScale.enable;
      AdaptiveSlider slider() =>
          tester.widget<AdaptiveSlider>(find.byType(AdaptiveSlider));
      expect(slider().onChanged != null, enabled);
      final row = find.ancestor(
        of: find.text('Text Scaling'),
        matching: find.byType(GlassListRow),
      );
      await tester.tap(row);
      await pumpSettingsFrames(tester);
      expect(
        container(tester).read(themeSettingProvider).textScale.enable,
        !enabled,
      );
      expect(slider().onChanged != null, !enabled);
      expect(find.text('100%'), findsOneWidget);
    }, variant: darwin);

    testWidgets('the red reset row only while the colors are not default',
        (tester) async {
      await pumpPage(tester, (_) => const ThemeView());
      ThemeSetting notifier() =>
          container(tester).read(themeSettingProvider.notifier);
      notifier().updateState(
        (state) => state.copyWith(
          primaryColors: defaultPrimaryColors,
          primaryColor: defaultPrimaryColor,
        ),
      );
      await pumpSettingsFrames(tester);
      expect(rows(tester).where((row) => row.destructive), isEmpty);
      notifier().updateState(
        (state) => state.copyWith(primaryColor: null),
      );
      await pumpSettingsFrames(tester);
      final reset = rows(tester).singleWhere((row) => row.destructive);
      expect((reset.title as Text).data, 'Reset');
    }, variant: darwin);
  });

  // Decision 2: the other `ListItem` / `generateSection` lists outside the
  // settings pages get the grouped style in the same PR.
  group('Decision 2: proxies sheets, quick options, resources, media unlock',
      () {
    testWidgets('proxies settings sheet: one section of pop-up rows',
        (tester) async {
      await pumpPage(tester, (_) => const ProxiesSetting());
      expect(find.byType(SettingInfoCard), findsNothing);
      expect(find.byType(SettingTextCard), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassListSection), findsOneWidget);
      // Style, sort, layout, size and (list type, the default) icon style.
      final accessories = rows(tester).map((row) => row.accessory).toList();
      expect(accessories, hasLength(5));
      expect(accessories, everyElement(GlassRowAccessory.popUp));
    }, variant: darwin);

    testWidgets('provider rows: capsule actions instead of chips',
        (tester) async {
      Widget item(ExternalProvider provider) => GlassListView(
            children: [
              GlassListSection(children: [ProviderItem(provider: provider)]),
            ],
          );
      final http = ExternalProvider(
        name: 'sub',
        type: 'Proxy',
        count: 3,
        vehicleType: 'HTTP',
        updateAt: DateTime(2026),
      );
      await pumpPage(tester, (_) => item(http));
      expectGroupedList();
      expect(find.byType(CommonChip), findsNothing);
      expect(find.byType(GlassButton), findsNWidgets(2));
      expect(find.byType(AdaptiveActivityIndicator), findsNothing);

      await pumpPage(
        tester,
        (_) => item(http.copyWith(isUpdating: true)),
      );
      expect(
        tester
            .widgetList<GlassButton>(find.byType(GlassButton))
            .where((button) => button.busy),
        hasLength(1),
      );
      expect(find.byType(AdaptiveActivityIndicator), findsNothing);

      await pumpPage(
        tester,
        (_) => item(http.copyWith(vehicleType: 'File', isUpdating: true)),
      );
      expect(find.byType(GlassButton), findsOneWidget);
      expect(find.byType(AdaptiveActivityIndicator), findsOneWidget);
    }, variant: darwin);

    testWidgets('dashboard quick options: one grouped section',
        (tester) async {
      await pumpPage(
        tester,
        (_) => generateListView(
          generateSection(
            items: const [TUNItem(), AutoSetSystemDnsItem(), TunStackItem()],
          ),
        ),
      );
      expectGroupedList();
      expect(find.byType(GlassListSection), findsOneWidget);
      expect(rows(tester), hasLength(3));
      expect(find.byType(AdaptiveSwitch), findsWidgets);
    }, variant: darwin);

    for (final brightness in Brightness.values) {
      testWidgets('resources: grouped files, glass buttons, $brightness',
          (tester) async {
        await pumpPage(
          tester,
          (_) => const ResourcesView(),
          brightness: brightness,
        );
        expectGroupedList();
        expect(find.byType(GlassListSection), findsOneWidget);
        expect(rows(tester), hasLength(4));
        expect(find.byType(GlassIconButton), findsNWidgets(4));
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final updateAll = tester.widget<GlassButton>(find.byType(GlassButton));
        expect(updateAll.kind, GlassButtonKind.filled);
        expect(updateAll.onPressed, isNotNull);
      }, variant: darwin);
    }

    testWidgets('media unlock: summary, capsules and status sections',
        (tester) async {
      await pumpPage(tester, (_) => const MediaUnlockPage());
      expectGroupedList();
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Summary + at least one status section.
      expect(find.byType(GlassListSection), findsAtLeastNWidgets(2));
      expect(rows(tester), isNotEmpty);
      expect(
        rows(tester).every((row) => row.trailing is GlassIconButton),
        isTrue,
      );

      List<GlassButton> capsules() =>
          tester.widgetList<GlassButton>(find.byType(GlassButton)).toList();
      expect(capsules().first.kind, GlassButtonKind.filled);
      await tester.tap(find.byWidget(capsules()[1]));
      await pumpSettingsFrames(tester);
      expect(capsules().first.kind, GlassButtonKind.tinted);
      expect(capsules()[1].kind, GlassButtonKind.filled);
    }, variant: darwin);

    testWidgets('media unlock dialogs: pinned checkmarks, misc switches',
        (tester) async {
      await pumpPage(tester, (_) => const MediaUnlockPage());
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(CheckboxListTile), findsNothing);
      final checked = rows(tester)
          .where((row) => row.accessory == GlassRowAccessory.checkmark);
      expect(checked, isNotEmpty);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(AdaptiveSwitch), findsNWidgets(5));
      expect(find.byType(Switch), findsNothing);
    }, variant: darwin);
  });

  group('AdaptiveSlider', () {
    Widget host(Widget child) => MaterialApp(
          home: Scaffold(body: Center(child: child)),
        );

    testWidgets('Darwin: Cupertino on iOS, thin AppKit track on macOS',
        (tester) async {
      AdaptivePlatform.debugUseGlassOverride = true;
      double? changed;
      await tester.pumpWidget(
        host(AdaptiveSlider(value: 0.5, onChanged: (v) => changed = v)),
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        expect(find.byType(CupertinoSlider), findsOneWidget);
      } else {
        expect(find.byType(CupertinoSlider), findsNothing);
        final theme = SliderTheme.of(tester.element(find.byType(Slider)));
        expect(theme.trackHeight, GlassTokens.sliderTrackHeightMac);
        expect(theme.overlayShape, SliderComponentShape.noOverlay);
      }
      await tester.drag(find.byType(AdaptiveSlider), const Offset(60, 0));
      expect(changed, isNotNull);
    }, variant: darwin);

    testWidgets('Material: the stock Slider', (tester) async {
      AdaptivePlatform.debugUseGlassOverride = false;
      await tester.pumpWidget(
        host(AdaptiveSlider(value: 0.5, onChanged: (_) {})),
      );
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(CupertinoSlider), findsNothing);
      final theme = SliderTheme.of(tester.element(find.byType(Slider)));
      expect(theme.trackHeight, isNot(GlassTokens.sliderTrackHeightMac));
    });
  });
}
