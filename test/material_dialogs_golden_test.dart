import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/add_profile.dart';
import 'package:meowclash/widgets/dialog.dart';
import 'package:meowclash/widgets/input.dart';

import 'performance_test_support.dart';

/// Pixel baseline of the Material dialogs (`CommonDialog` and what is built
/// on it, `CommonModal`) that Android, Linux and Windows must keep after the
/// Darwin glass dialogs. The images were generated on `main` before the glass
/// dialogs landed and must still match. Regenerate only for an intended
/// Material change:
/// `flutter test --update-goldens test/material_dialogs_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mobile = Size(400, 720);
  const desktop = Size(800, 520);

  setUpAll(() {
    // A blinking cursor never lets the dialog settle.
    EditableText.debugDeterministicCursor = true;
  });
  tearDownAll(() {
    EditableText.debugDeterministicCursor = false;
  });

  Future<void> setUp(WidgetTester tester, Size size) async {
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(Brightness brightness) => ProviderScope(
        overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
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
              // Something behind the barrier, so the dimming shows.
              return ListView(
                children: [
                  for (var i = 0; i < 20; i++)
                    ListTile(title: Text('Row $i')),
                ],
              );
            }),
          ),
        ),
      );

  Future<void> open(
    WidgetTester tester,
    Brightness brightness,
    void Function() show, {
    Size size = mobile,
  }) async {
    await setUp(tester, size);
    await tester.pumpWidget(host(brightness));
    show();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> expectScreen(WidgetTester tester, String name) => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_dialogs_$name.png'),
      );

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('message, two buttons, $b', (tester) async {
      await open(
        tester,
        brightness,
        () => globalState.showMessage(
          title: 'Delete profile',
          message: const TextSpan(
            text: 'The profile and its override rules will be removed.',
          ),
        ),
      );
      await expectScreen(tester, 'message_two_$b');
    }, variant: android);

    testWidgets('message, one button, $b', (tester) async {
      await open(
        tester,
        brightness,
        () => globalState.showMessage(
          message: const TextSpan(text: 'Profile updated.'),
          cancelable: false,
        ),
      );
      await expectScreen(tester, 'message_one_$b');
    }, variant: android);

    testWidgets('input, $b', (tester) async {
      await open(
        tester,
        brightness,
        () => globalState.showCommonDialog<String>(
          child: const InputDialog(
            title: 'Mixed port',
            value: '7890',
            resetValue: '7891',
            labelText: 'Port',
          ),
        ),
      );
      await expectScreen(tester, 'input_$b');
    }, variant: android);

    testWidgets('options, $b', (tester) async {
      await open(
        tester,
        brightness,
        () => globalState.showCommonDialog<String>(
          child: OptionsDialog<String>(
            title: 'Mode',
            options: const ['Rule', 'Global', 'Direct'],
            value: 'Global',
            textBuilder: (value) => value,
          ),
        ),
      );
      await expectScreen(tester, 'options_$b');
    }, variant: android);

    testWidgets('url form, $b', (tester) async {
      await open(
        tester,
        brightness,
        () => globalState.showCommonDialog<URLFormResult>(
          child: const URLFormDialog(),
        ),
      );
      await expectScreen(tester, 'url_form_$b');
    }, variant: android);

    testWidgets('modal, desktop, $b', (tester) async {
      await open(
        tester,
        brightness,
        () => globalState.showCommonDialog<void>(
          child: const CommonModal(
            child: Scaffold(
              body: Center(child: Text('Editor')),
            ),
          ),
        ),
        size: desktop,
      );
      await expectScreen(tester, 'modal_desktop_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
