import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/app_localizations.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/add_profile.dart';
import 'package:meowclash/views/profiles/edit_profile.dart';
import 'package:meowclash/views/profiles/scripts.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

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

  Widget host(WidgetBuilder builder, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: [
          backgroundUrlProvider.overrideWith((ref) => null),
          ...overrides,
        ],
        child: MaterialApp(
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
}
