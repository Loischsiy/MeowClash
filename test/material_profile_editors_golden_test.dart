import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/add_profile.dart';
import 'package:meowclash/views/profiles/edit_profile.dart';
import 'package:meowclash/views/profiles/override_profile.dart';
import 'package:meowclash/views/profiles/scripts.dart';

import 'performance_test_support.dart';
import 'profile_editors_test_support.dart';

/// Pixel baseline of the Material profile editors (add, edit, scripts,
/// override and its rule / chain dialogs) that Android, Linux and Windows
/// must keep after the Darwin glass editors. The images were generated on
/// `main` before the glass editors landed and must still match. Regenerate
/// only for an intended Material change:
/// `flutter test --update-goldens test/material_profile_editors_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mobile = Size(400, 720);
  late Directory dir;

  setUpAll(() async {
    // A blinking cursor never lets a form settle.
    EditableText.debugDeterministicCursor = true;
    dir = await Directory.systemTemp.createTemp('meowclash_editors');
    await mockProfileFiles(dir);
  });
  tearDownAll(() async {
    EditableText.debugDeterministicCursor = false;
    await dir.delete(recursive: true);
  });

  Future<void> setUp(WidgetTester tester) async {
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
    Brightness brightness,
    WidgetBuilder builder, {
    List<Override> overrides = const [],
  }) =>
      ProviderScope(
        overrides: [
          backgroundUrlProvider.overrideWith((ref) => null),
          ...overrides,
        ],
        child: MaterialApp(
          navigatorKey: globalState.navigatorKey,
          debugShowCheckedModeBanner: false,
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

  Future<void> settle(WidgetTester tester) async {
    // The edit view reads its profile file with real I/O: interleave real
    // time (file system) with fake time (channel replies, rebuilds).
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> expectScreen(WidgetTester tester, String name) => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_profile_editors_$name.png'),
      );

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('add, $b', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(
        host(brightness, (context) => AddProfileView(context: context)),
      );
      await settle(tester);
      await expectScreen(tester, 'add_$b');
    }, variant: android);

    testWidgets('edit, $b', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(
        host(
          brightness,
          (context) => EditProfileView(
            context: context,
            profile: editorProfile(),
          ),
        ),
      );
      await settle(tester);
      await waitForProfileFileRow(tester);
      await expectScreen(tester, 'edit_$b');
    }, variant: android);

    testWidgets('scripts, $b', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(
        host(brightness, (_) => const ScriptsView()),
      );
      await settle(tester);
      await expectScreen(tester, 'scripts_$b');
    }, variant: android);

    testWidgets('scripts, empty, $b', (tester) async {
      await setUp(tester);
      globalState.config =
          globalState.config.copyWith(scriptProps: const ScriptProps());
      await tester.pumpWidget(
        host(brightness, (_) => const ScriptsView()),
      );
      await settle(tester);
      await expectScreen(tester, 'scripts_empty_$b');
    }, variant: android);

    testWidgets('override, $b', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(
        host(
          brightness,
          (_) => const OverrideSections(),
          overrides: [fixedOverrideState(selected: {'r1'})],
        ),
      );
      await settle(tester);
      await expectScreen(tester, 'override_$b');
    }, variant: android);

    testWidgets('add rule dialog, $b', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(host(brightness, (_) => const SizedBox()));
      unawaited(globalState.showCommonDialog<Rule>(
        child: const AddRuleDialog(
          snippet: editorSnippet,
          chainNames: ['Via Tokyo'],
        ),
      ));
      await settle(tester);
      await expectScreen(tester, 'add_rule_$b');
    }, variant: android);

    testWidgets('add chain dialog, $b', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(host(brightness, (_) => const SizedBox()));
      unawaited(globalState.showCommonDialog<ProxyChain>(
        child: AddChainDialog(
          snippet: editorSnippet,
          chain: editorOverrideData().chains.first,
        ),
      ));
      await settle(tester);
      await expectScreen(tester, 'add_chain_$b');
    }, variant: android);
  }
}
