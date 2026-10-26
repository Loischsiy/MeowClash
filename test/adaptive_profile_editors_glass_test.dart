import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/app_localizations.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/add_profile.dart';
import 'package:meowclash/views/profiles/edit_profile.dart';
import 'package:meowclash/views/profiles/override_profile.dart';
import 'package:meowclash/views/profiles/scripts.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'performance_test_support.dart';
import 'profile_editors_test_support.dart';

/// Darwin profile editors: grouped sections of flat rows (no blur in the
/// scrolling content), Apple switches and fields, the glass "Save" capsule,
/// and the Reduce Transparency / blur kill switch fallbacks. The Material
/// editors are pinned by `material_profile_editors_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mobile = Size(400, 720);
  late Directory dir;

  setUpAll(() async {
    EditableText.debugDeterministicCursor = true;
    dir = await Directory.systemTemp.createTemp('meowclash_glass_editors');
    await mockProfileFiles(dir);
  });
  tearDownAll(() async {
    EditableText.debugDeterministicCursor = false;
    await dir.delete(recursive: true);
  });
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  Future<void> setUp(WidgetTester tester) async {
    AdaptivePlatform.debugUseGlassOverride = true;
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: mobile);
    globalState.config = globalState.config.copyWith(
      currentProfileId: editorProfileId,
      profiles: [editorProfile()],
      scriptProps: editorScripts,
    );
    tester.view
      ..physicalSize = mobile
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(
    WidgetBuilder builder, {
    List<Override> overrides = const [],
    GlassAccessibilityController? accessibility,
  }) =>
      ProviderScope(
        overrides: [
          backgroundUrlProvider.overrideWith((ref) => null),
          ...overrides,
        ],
        child: _maybeAccessibility(
          accessibility,
          MaterialApp(
            navigatorKey: globalState.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
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
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> pumpEdit(WidgetTester tester) async {
    await setUp(tester);
    await tester.pumpWidget(
      host(
        (context) =>
            EditProfileView(context: context, profile: editorProfile()),
      ),
    );
    await settle(tester);
    await waitForProfileFileRow(tester);
  }

  const darwin = TargetPlatformVariant(
    {TargetPlatform.iOS, TargetPlatform.macOS},
  );

  group('AddProfileView', () {
    testWidgets('one section of rows with chevrons, no blur', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(
        host((context) => AddProfileView(context: context)),
      );
      await settle(tester);
      expect(find.byType(GlassListSection), findsOneWidget);
      expect(find.byType(GlassListRow), findsNWidgets(3));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    }, variant: darwin);
  });

  group('EditProfileView', () {
    testWidgets('sections, Apple fields, one glass layer (Save)',
        (tester) async {
      await pumpEdit(tester);
      // Fields, auto update, profile file, decryption.
      expect(find.byType(GlassListSection), findsNWidgets(4));
      expect(find.byType(GlassListField), findsNWidgets(6));
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Only the floating Save capsule blurs, never the scrolling rows.
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(BackdropFilter),
          matching: find.byType(AdaptiveFloatingButton),
        ),
        findsOneWidget,
      );
      expect(find.text(appLocalizations.save), findsOneWidget);
      // The fields are filled Apple fields, not outlined.
      final field = tester.widget<InputDecorator>(
        find
            .descendant(
              of: find.byType(GlassListField).first,
              matching: find.byType(InputDecorator),
            )
            .first,
      );
      final context = tester.element(find.byWidget(field));
      expect(
        Theme.of(context).inputDecorationTheme.enabledBorder,
        isA<GlassFieldBorder>(),
      );
    }, variant: darwin);

    testWidgets('auto update switch and row toggle the interval field',
        (tester) async {
      await pumpEdit(tester);
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.text(appLocalizations.autoUpdateInterval), findsOneWidget);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(find.text(appLocalizations.autoUpdateInterval), findsNothing);
      await tester.tap(find.text(appLocalizations.autoUpdate));
      await tester.pumpAndSettle();
      expect(find.text(appLocalizations.autoUpdateInterval), findsOneWidget);
    }, variant: darwin);

    testWidgets('validation errors show under the Apple field', (tester) async {
      await pumpEdit(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(GlassListField).first,
          matching: find.byType(EditableText),
        ),
        '',
      );
      await tester.tap(find.text(appLocalizations.save));
      await tester.pumpAndSettle();
      expect(
        find.text(appLocalizations.profileNameNullValidationDesc),
        findsOneWidget,
      );
      expect(find.byType(EditProfileView), findsOneWidget);
      // iOS announces the form error to VoiceOver after a one second timer.
      await tester.pump(const Duration(seconds: 1));
    }, variant: darwin);

    testWidgets('file rows open the editor / upload; size is the footer',
        (tester) async {
      await pumpEdit(tester);
      expect(find.text(appLocalizations.profile), findsOneWidget);
      expect(
        find.widgetWithText(GlassListRow, appLocalizations.edit),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(GlassListRow, appLocalizations.upload),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
            GlassButton, appLocalizations.profileDecryptionAction),
        findsOneWidget,
      );
    }, variant: darwin);

    testWidgets('blur kill switch: the Save capsule is opaque', (tester) async {
      GlassFlags.backdropBlurEnabled = false;
      await pumpEdit(tester);
      expect(find.byType(BackdropFilter), findsNothing);
    }, variant: darwin);
  });

  group('ScriptsView', () {
    Finder checkIn(String label) => find.descendant(
          of: find.widgetWithText(GlassListRow, label),
          matching: find.byIcon(Icons.check_rounded),
        );

    testWidgets('one section, checkmark instead of radio, ⋯ menus',
        (tester) async {
      await setUp(tester);
      await tester.pumpWidget(host((_) => const ScriptsView()));
      await settle(tester);
      expect(find.byType(GlassListSection), findsOneWidget);
      expect(find.byType(GlassListRow), findsNWidgets(2));
      expect(find.byType(GlassIconButton), findsNWidgets(2));
      expect(find.byType(Radio<String>), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(checkIn('Add DNS'), findsOneWidget);
      expect(checkIn('Rename nodes'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      expect(find.byType(AdaptiveFloatingButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    }, variant: darwin);

    testWidgets('tapping a row makes it the current script', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(host((_) => const ScriptsView()));
      await settle(tester);
      await tester.tap(find.text('Rename nodes'));
      await tester.pumpAndSettle();
      expect(checkIn('Rename nodes'), findsOneWidget);
      expect(checkIn('Add DNS'), findsNothing);
    }, variant: darwin);

    testWidgets('empty: Apple empty state', (tester) async {
      await setUp(tester);
      globalState.config =
          globalState.config.copyWith(scriptProps: const ScriptProps());
      await tester.pumpWidget(host((_) => const ScriptsView()));
      await settle(tester);
      expect(find.byType(AdaptiveEmptyState), findsOneWidget);
      expect(find.text(appLocalizations.nullScriptTip), findsOneWidget);
      expect(find.byType(GlassListSection), findsNothing);
    }, variant: darwin);
  });

  group('OverrideProfileView', () {
    Future<void> pumpOverride(
      WidgetTester tester, {
      OverrideData? data,
      Set<String> selected = const {},
    }) async {
      await setUp(tester);
      await tester.pumpWidget(
        host(
          (_) => const _GlassOverrideSections(),
          overrides: [fixedOverrideState(data: data, selected: selected)],
        ),
      );
      await settle(tester);
    }

    testWidgets('sections, Apple switches, no blur in 150 rules',
        (tester) async {
      await pumpOverride(tester, data: editorOverrideData(rules: 150));
      // Override switch + chains; rules are flat cards.
      expect(find.byType(GlassListSection), findsNWidgets(2));
      expect(find.byType(GlassSectionHeader), findsNWidgets(2));
      // Override + two chains.
      expect(find.byType(CupertinoSwitch), findsNWidgets(3));
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(AdaptiveCard), findsWidgets);
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: darwin);

    testWidgets('rule extent matches the rendered card', (tester) async {
      final long = List.filled(6, 'very-long-domain-name').join('.');
      await pumpOverride(
        tester,
        data: editorOverrideData().copyWith(
          rule: OverrideRule(
            addedRules: [
              const Rule(id: 's', value: 'MATCH,DIRECT'),
              Rule(id: 'l', value: 'DOMAIN-SUFFIX,$long,Proxy'),
            ],
          ),
        ),
      );
      final pad = AdaptivePlatform.isMacOSGlass
          ? GlassTokens.ruleRowVerticalPaddingMac
          : GlassTokens.ruleRowVerticalPaddingIos;
      final check = AdaptivePlatform.isMacOSGlass
          ? GlassTokens.ruleCheckSizeMac
          : GlassTokens.ruleCheckSizeIos;
      final heights = <double>[];
      for (final value in ['MATCH,DIRECT', 'DOMAIN-SUFFIX,$long,Proxy']) {
        final text = tester.getSize(find.text(value)).height;
        final item = tester.getSize(
          find
              .ancestor(
                of: find.text(value),
                matching: find.byType(ReorderableDelayedDragStartListener),
              )
              .first,
        );
        heights.add(text);
        // The test font renders a wrapped paragraph up to 1 px shorter than
        // TextPainter measures it; the card never overflows.
        expect(
          item.height,
          moreOrLessEquals(
            GlassTokens.ruleRowGap + 2 * pad + (text > check ? text : check),
            epsilon: 1,
          ),
        );
      }
      // The long rule wraps, so the extent really follows the text.
      expect(heights.last, greaterThan(heights.first));
    }, variant: darwin);

    testWidgets('tapping a rule selects it with the circle', (tester) async {
      await pumpOverride(tester);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(3));
      await tester.tap(find.text('DOMAIN-SUFFIX,example1.com,Proxy'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      // Edit mode: "Select all" replaces "Add" in the rules header.
      expect(
        find.widgetWithText(GlassButton, appLocalizations.selectAll),
        findsOneWidget,
      );
    }, variant: darwin);

    testWidgets('override and chain switches toggle', (tester) async {
      await pumpOverride(tester);
      bool value(int index) => tester
          .widget<CupertinoSwitch>(find.byType(CupertinoSwitch).at(index))
          .value;
      expect([value(0), value(1), value(2)], [true, true, false]);
      await tester.tap(find.text(appLocalizations.enableOverride));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoSwitch).at(2));
      await tester.pumpAndSettle();
      expect([value(0), value(1), value(2)], [false, true, true]);
    }, variant: darwin);

    testWidgets('empty added rules and chains: Apple empty states',
        (tester) async {
      await pumpOverride(
        tester,
        data: editorOverrideData().copyWith(
          chains: const [],
          rule: const OverrideRule(),
        ),
      );
      expect(find.byType(AdaptiveEmptyState), findsOneWidget);
      expect(
        find.text(appLocalizations.nullTip(appLocalizations.proxyChains)),
        findsOneWidget,
      );
      expect(find.byType(AdaptiveCard), findsNothing);
    }, variant: darwin);

    testWidgets('empty override rules: "Get origin rules" glass button',
        (tester) async {
      await pumpOverride(
        tester,
        data: editorOverrideData().copyWith(
          rule: const OverrideRule(type: OverrideRuleType.override),
        ),
      );
      expect(
        find.widgetWithText(GlassButton, appLocalizations.getOriginRules),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(appLocalizations.overrideOriginRules), findsOneWidget);
    }, variant: darwin);
  });

  group('Override dialogs', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(
      () =>
          messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel, null),
    );

    /// macOS: the native pop-up menu "picks" the entry labelled [label] and
    /// records which entry came checked.
    void nativePick(String label, {void Function(String? checked)? onMenu}) {
      messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
          (call) async {
        final items = ((call.arguments as Map)['items'] as List)
            .cast<Map<Object?, Object?>>();
        onMenu?.call(
          items
              .where((item) => item['checked'] == true)
              .map((item) => item['title'] as String?)
              .firstOrNull,
        );
        return items.indexWhere((item) => item['title'] == label);
      });
    }

    Future<T?> Function() openDialog<T>(
      WidgetTester tester,
      Widget dialog,
    ) {
      T? result;
      var done = false;
      globalState.showCommonDialog<T>(child: dialog).then((value) {
        result = value;
        done = true;
      });
      return () async {
        await tester.pumpAndSettle();
        expect(done, isTrue);
        return result;
      };
    }

    Future<void> pumpHost(WidgetTester tester) async {
      await setUp(tester);
      await tester.pumpWidget(host((_) => const SizedBox()));
    }

    testWidgets('add rule: pop-up buttons instead of dropdowns',
        (tester) async {
      await pumpHost(tester);
      openDialog<Rule>(
        tester,
        const AddRuleDialog(snippet: editorSnippet, chainNames: ['Via Tokyo']),
      );
      await settle(tester);
      expect(find.byType(GlassPopUpButton<RuleAction>), findsOneWidget);
      // Default DOMAIN rule: content field + target.
      expect(find.byType(GlassPopUpButton<String>), findsOneWidget);
      expect(find.text('Via Tokyo'), findsOneWidget);
      expect(find.byType(DropdownMenu<String>), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(CommonCard), findsNothing);
    }, variant: darwin);

    testWidgets('add rule: RULE-SET from the native menu, checked current',
        (tester) async {
      await pumpHost(tester);
      String? checked;
      nativePick(RuleAction.RULE_SET.value, onMenu: (value) => checked = value);
      final result = openDialog<Rule>(
        tester,
        const AddRuleDialog(snippet: editorSnippet, chainNames: ['Via Tokyo']),
      );
      await settle(tester);
      await tester.tap(find.byType(GlassPopUpButton<RuleAction>));
      await tester.pumpAndSettle();
      expect(checked, RuleAction.DOMAIN.value);
      // Provider + target.
      expect(find.byType(GlassPopUpButton<String>), findsNWidgets(2));
      expect(find.text('ads'), findsOneWidget);
      nativePick('Proxy');
      await tester.tap(find.byType(GlassPopUpButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(appLocalizations.confirm));
      expect((await result())?.value, 'RULE-SET,ads,Proxy');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('add rule: parameters are switch rows', (tester) async {
      await pumpHost(tester);
      nativePick(RuleAction.GEOIP.value);
      final result = openDialog<Rule>(
        tester,
        const AddRuleDialog(snippet: editorSnippet),
      );
      await settle(tester);
      await tester.tap(find.byType(GlassPopUpButton<RuleAction>));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoSwitch), findsNWidgets(2));
      await tester.enterText(find.byType(EditableText), 'CN');
      await tester.tap(find.text(appLocalizations.noResolve));
      await tester.pumpAndSettle();
      await tester.tap(find.text(appLocalizations.confirm));
      expect((await result())?.value, 'GEOIP,CN,Proxy,no-resolve');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('add rule: empty fields show errors, dialog stays',
        (tester) async {
      await pumpHost(tester);
      openDialog<Rule>(tester, const AddRuleDialog(snippet: editorSnippet));
      await settle(tester);
      await tester.tap(find.text(appLocalizations.confirm));
      await tester.pumpAndSettle();
      expect(
        find.text(appLocalizations.emptyTip(appLocalizations.content)),
        findsOneWidget,
      );
      expect(find.byType(AddRuleDialog), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    }, variant: darwin);

    testWidgets('add chain: hop pop-ups, add and remove hops', (tester) async {
      await pumpHost(tester);
      final result = openDialog<ProxyChain>(
        tester,
        AddChainDialog(
          snippet: editorSnippet,
          chain: editorOverrideData().chains.first,
        ),
      );
      await settle(tester);
      expect(find.byType(GlassPopUpButton<String>), findsNWidgets(2));
      expect(find.byType(DropdownMenu<String>), findsNothing);
      expect(find.byType(GlassIconButton), findsNothing);
      await tester.tap(
        find.widgetWithText(GlassButton, appLocalizations.addHop),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassPopUpButton<String>), findsNWidgets(3));
      expect(find.byType(GlassIconButton), findsNWidgets(3));
      // iOS: the glass menu (no native channel call).
      await tester.tap(find.byType(GlassPopUpButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto').last);
      await tester.pumpAndSettle();
      expect(find.text('Auto'), findsOneWidget);
      await tester.tap(find.text(appLocalizations.confirm));
      expect((await result())?.hops, ['Tokyo', 'Frankfurt', 'Auto']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('add chain: removing a hop drops its minus buttons',
        (tester) async {
      await pumpHost(tester);
      openDialog<ProxyChain>(
        tester,
        const AddChainDialog(
          snippet: editorSnippet,
          chain: ProxyChain(
            id: 'c3',
            name: 'Three',
            hops: ['Tokyo', 'Auto', 'Frankfurt'],
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(GlassIconButton), findsNWidgets(3));
      await tester.tap(find.byType(GlassIconButton).at(1));
      await tester.pumpAndSettle();
      expect(find.byType(GlassPopUpButton<String>), findsNWidgets(2));
      expect(find.byType(GlassIconButton), findsNothing);
      expect(find.text('Auto'), findsNothing);
    }, variant: darwin);

    testWidgets('add chain: empty hops show errors under the pop-ups',
        (tester) async {
      await pumpHost(tester);
      openDialog<ProxyChain>(
        tester,
        const AddChainDialog(snippet: editorSnippet),
      );
      await settle(tester);
      await tester.enterText(find.byType(EditableText), 'New');
      await tester.tap(find.text(appLocalizations.confirm));
      await tester.pumpAndSettle();
      expect(
        find.text(appLocalizations.emptyTip(appLocalizations.firstHop)),
        findsOneWidget,
      );
      expect(
        find.text(appLocalizations.emptyTip(appLocalizations.secondHop)),
        findsOneWidget,
      );
      expect(find.byType(AddChainDialog), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    }, variant: darwin);
  });

  group('Fallbacks', () {
    testWidgets(
        'Reduce Transparency and the kill switch: rule dialog and its '
        'pop-up menu do not blur', (tester) async {
      await setUp(tester);
      final accessibility = GlassAccessibilityController();
      addTearDown(accessibility.dispose);
      accessibility.value = const GlassAccessibility(reduceTransparency: true);
      await tester.pumpWidget(
        host((_) => const SizedBox(), accessibility: accessibility),
      );
      Future<void> openMenu() async {
        unawaited(globalState.showCommonDialog<Rule>(
          child: const AddRuleDialog(snippet: editorSnippet),
        ));
        await settle(tester);
        // iOS: the glass menu of the rule type.
        await tester.tap(find.byType(GlassPopUpButton<RuleAction>));
        await tester.pumpAndSettle();
        expect(find.byType(GlassSurface), findsWidgets);
      }

      await openMenu();
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.tap(find.text(RuleAction.DOMAIN.value).last);
      await tester.pumpAndSettle();
      Navigator.of(globalState.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();

      accessibility.value = GlassAccessibility.fallback;
      GlassFlags.backdropBlurEnabled = false;
      await openMenu();
      expect(find.byType(BackdropFilter), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    Future<double> draggedWidth(
      WidgetTester tester, {
      required bool reduceMotion,
    }) async {
      await setUp(tester);
      final accessibility = GlassAccessibilityController();
      addTearDown(accessibility.dispose);
      accessibility.value = GlassAccessibility(reduceMotion: reduceMotion);
      await tester.pumpWidget(
        host(
          (_) => const _GlassOverrideSections(),
          overrides: [fixedOverrideState()],
          accessibility: accessibility,
        ),
      );
      await settle(tester);
      const value = 'DOMAIN-SUFFIX,example0.com,Proxy';
      double width() =>
          tester.getBottomRight(find.text(value).last).dx -
          tester.getTopLeft(find.text(value).last).dx;
      final resting = width();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(value)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      final lifted = width();
      await gesture.up();
      await tester.pumpAndSettle();
      return lifted / resting;
    }

    testWidgets('a dragged rule grows a little', (tester) async {
      expect(
        await draggedWidth(tester, reduceMotion: false),
        moreOrLessEquals(GlassTokens.listRowDragScale, epsilon: 0.01),
      );
    }, variant: darwin);

    testWidgets('Reduce Motion: a dragged rule keeps its size', (tester) async {
      expect(await draggedWidth(tester, reduceMotion: true), 1);
    }, variant: darwin);
  });
}

Widget _maybeAccessibility(
  GlassAccessibilityController? controller,
  Widget child,
) =>
    controller == null
        ? child
        : GlassAccessibilityScope(controller: controller, child: child);

/// The Darwin sections of `OverrideProfileView` (`_buildGlassList`) without
/// the disk loading: same paddings and the same rule text width.
class _GlassOverrideSections extends StatelessWidget {
  const _GlassOverrideSections();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) {
          final padding = GlassListSection.listPadding;
          final gap = GlassListSection.gap;
          final horizontal = EdgeInsets.symmetric(horizontal: padding.left);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: padding.top)),
              SliverPadding(
                padding: horizontal,
                sliver: SliverList.list(
                  children: [
                    const OverrideSwitch(),
                    SizedBox(height: gap),
                    const ChainTitle(profileId: editorProfileId),
                    const ChainContent(profileId: editorProfileId),
                    SizedBox(height: gap),
                    const RuleTitle(profileId: editorProfileId),
                  ],
                ),
              ),
              SliverPadding(
                padding: horizontal.copyWith(bottom: padding.bottom),
                sliver: RuleContent(
                  maxWidth: constraints.maxWidth -
                      padding.horizontal -
                      RuleContent.glassTextReserve,
                ),
              ),
            ],
          );
        },
      );
}
