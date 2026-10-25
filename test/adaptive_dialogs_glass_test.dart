import 'package:animations/animations.dart';
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
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/dialog.dart';
import 'package:meowclash/widgets/input.dart';

import 'performance_test_support.dart';

/// Darwin glass dialogs: one blur per dialog (the panel; the backdrop is only
/// dimmed), the system-alert appearance without an `Opacity` above the blur,
/// iOS / macOS button layouts, Apple fields and pickers, the fallbacks; and
/// Material keeps its `showModal` dialogs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 720);
  const desktop = Size(800, 520);

  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  const apple = TargetPlatformVariant(
    {TargetPlatform.macOS, TargetPlatform.iOS},
  );

  setUpAll(() {
    EditableText.debugDeterministicCursor = true;
  });
  tearDownAll(() {
    EditableText.debugDeterministicCursor = false;
  });
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  late GlassAccessibilityController accessibility;

  Future<void> setUp(WidgetTester tester, {Size viewSize = size}) async {
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: viewSize);
    tester.view
      ..physicalSize = viewSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    accessibility = GlassAccessibilityController();
    addTearDown(accessibility.dispose);
  }

  Widget host() => ProviderScope(
        overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
        child: GlassAccessibilityScope(
          controller: accessibility,
          child: MaterialApp(
            navigatorKey: globalState.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
              ),
            ),
            home: Scaffold(
              body: Consumer(builder: (context, ref, _) {
                globalState.appController = AppController(context, ref);
                globalState.measure = Measure.of(context, 1);
                globalState.theme = CommonTheme.of(context, 1);
                return ListView(
                  children: [
                    for (var i = 0; i < 30; i++)
                      ListTile(title: Text('Row $i')),
                  ],
                );
              }),
            ),
          ),
        ),
      );

  Future<void> open(
    WidgetTester tester,
    void Function() show, {
    Size viewSize = size,
    bool settle = true,
  }) async {
    await setUp(tester, viewSize: viewSize);
    await tester.pumpWidget(host());
    show();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  }

  void showTwoButtons() => globalState.showMessage(
        title: 'Delete profile',
        message: const TextSpan(text: 'The profile will be removed.'),
        confirmText: 'Delete',
      );

  void showThreeButtons() => globalState.showCommonDialog<void>(
        child: CommonDialog(
          title: 'Update',
          actions: [
            TextButton(onPressed: () {}, child: const Text('Later')),
            TextButton(onPressed: () {}, child: const Text('Skip')),
            TextButton(onPressed: () {}, child: const Text('Install')),
          ],
          child: const Text('A new version is available.'),
        ),
      );

  Finder blurs() => find.byType(BackdropFilter);

  /// Every `Opacity` above the blur must be fully opaque, or the backdrop
  /// read happens inside an offscreen layer and the blur disappears.
  void expectNoFadeAboveBlur(WidgetTester tester) {
    final above = find.ancestor(
      of: blurs(),
      matching: find.byWidgetPredicate(
        (widget) =>
            (widget is Opacity && widget.opacity < 1) ||
            widget is FadeTransition,
      ),
    );
    expect(above, findsNothing);
  }

  double panelScale(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .ancestor(
              of: find.byType(GlassSurface), matching: find.byType(Transform))
          .first,
    );
    return transform.transform.getMaxScaleOnAxis();
  }

  group('Darwin', () {
    testWidgets('one blur per dialog, none behind it', (tester) async {
      await open(tester, showTwoButtons);
      expect(find.byType(GlassDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(blurs(), findsOneWidget);
      expect(
        find.descendant(of: find.byType(GlassSurface), matching: blurs()),
        findsOneWidget,
      );
      expectNoFadeAboveBlur(tester);
    }, variant: apple);

    testWidgets('appears like a system alert, blur kept while fading',
        (tester) async {
      await open(tester, showTwoButtons, settle: false);
      await tester.pump(GlassTokens.dialogEnterDuration ~/ 3);
      expect(blurs(), findsOneWidget);
      expectNoFadeAboveBlur(tester);
      expect(panelScale(tester), greaterThan(1));
      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).presence,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      expect(panelScale(tester), 1);
      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).presence,
        1,
      );

      // Closing only fades.
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(GlassTokens.dialogExitDuration ~/ 2);
      expect(panelScale(tester), 1);
      expectNoFadeAboveBlur(tester);
      await tester.pumpAndSettle();
      expect(find.byType(GlassDialog), findsNothing);
    }, variant: apple);

    testWidgets('Reduce Motion: fade only, no scale', (tester) async {
      await setUp(tester);
      await tester.pumpWidget(host());
      accessibility.value = const GlassAccessibility(reduceMotion: true);
      showTwoButtons();
      await tester.pump();
      await tester.pump(GlassTokens.dialogEnterDuration ~/ 3);
      expect(panelScale(tester), 1);
      expect(
        tester.widget<GlassSurface>(find.byType(GlassSurface)).presence,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
    }, variant: apple);

    testWidgets('Reduce Transparency and the kill switch: opaque, no blur',
        (tester) async {
      await setUp(tester);
      await tester.pumpWidget(host());
      accessibility.value = const GlassAccessibility(reduceTransparency: true);
      showTwoButtons();
      await tester.pumpAndSettle();
      expect(find.byType(GlassDialog), findsOneWidget);
      expect(blurs(), findsNothing);
      Navigator.of(globalState.navigatorKey.currentContext!).pop();
      await tester.pumpAndSettle();

      accessibility.value = GlassAccessibility.fallback;
      GlassFlags.backdropBlurEnabled = false;
      showTwoButtons();
      await tester.pumpAndSettle();
      expect(find.byType(GlassDialog), findsOneWidget);
      expect(blurs(), findsNothing);
    }, variant: apple);

    testWidgets('a raw AlertDialog still fades in', (tester) async {
      await open(
        tester,
        () => globalState.showCommonDialog<void>(
          child: const AlertDialog(title: Text('Raw')),
        ),
        settle: false,
      );
      await tester.pump(GlassTokens.dialogEnterDuration ~/ 3);
      final fade = tester.widget<Opacity>(
        find
            .ancestor(
                of: find.byType(AlertDialog), matching: find.byType(Opacity))
            .first,
      );
      expect(fade.opacity, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('Raw'), findsOneWidget);
    }, variant: apple);

    testWidgets('macOS: capsules at the trailing edge, confirm in the accent',
        (tester) async {
      await open(tester, showTwoButtons);
      final scheme = Theme.of(
        tester.element(find.byType(GlassDialog)),
      ).colorScheme;
      final panel = tester.getRect(find.byType(GlassSurface));
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final delete = tester.getRect(find.widgetWithText(TextButton, 'Delete'));
      expect(cancel.center.dy, delete.center.dy);
      expect(cancel.right, lessThan(delete.left));
      expect(
        panel.right - delete.right,
        moreOrLessEquals(GlassTokens.dialogPadding, epsilon: 0.5),
      );
      expect(delete.height, GlassTokens.dialogButtonHeightMac);
      Color fill(String label) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.widgetWithText(TextButton, label),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(fill('Delete'), scheme.primary);
      expect(fill('Cancel'), isNot(scheme.primary));
    }, variant: mac);

    testWidgets('iOS: two full-width buttons side by side', (tester) async {
      await open(tester, showTwoButtons);
      final panel = tester.getRect(find.byType(GlassSurface));
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final delete = tester.getRect(find.widgetWithText(TextButton, 'Delete'));
      expect(cancel.center.dy, delete.center.dy);
      expect(cancel.left, moreOrLessEquals(panel.left, epsilon: 0.5));
      expect(delete.right, moreOrLessEquals(panel.right, epsilon: 0.5));
      expect(cancel.width, moreOrLessEquals(delete.width, epsilon: 0.5));
      expect(delete.height, GlassTokens.dialogButtonHeightIos);
      expect(delete.bottom, moreOrLessEquals(panel.bottom, epsilon: 0.5));
    }, variant: ios);

    testWidgets('iOS: three or more buttons stack', (tester) async {
      await open(tester, showThreeButtons);
      final panel = tester.getRect(find.byType(GlassSurface));
      final rects = [
        for (final label in ['Later', 'Skip', 'Install'])
          tester.getRect(find.widgetWithText(TextButton, label)),
      ];
      for (final rect in rects) {
        expect(rect.width, moreOrLessEquals(panel.width, epsilon: 0.5));
      }
      expect(rects[0].bottom, lessThanOrEqualTo(rects[1].top));
      expect(rects[1].bottom, lessThanOrEqualTo(rects[2].top));
    }, variant: ios);

    testWidgets('spacers between actions are dropped', (tester) async {
      await open(
        tester,
        () => globalState.showCommonDialog<URLFormResult>(
          child: const URLFormDialog(),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GlassDialogActions),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
      expect(blurs(), findsOneWidget);
    }, variant: apple);

    testWidgets('fields are Apple fields without editing the call site',
        (tester) async {
      await open(
        tester,
        () => globalState.showCommonDialog<String>(
          child: const InputDialog(
            title: 'Mixed port',
            value: '7890',
            labelText: 'Port',
          ),
        ),
      );
      final context = tester.element(find.byType(TextField));
      final theme = Theme.of(context);
      expect(theme.inputDecorationTheme.enabledBorder, isA<GlassFieldBorder>());
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(
        theme.textTheme.bodyLarge?.fontSize,
        GlassTextStyles.inputText(theme.textTheme).fontSize,
      );
      final focused = theme.inputDecorationTheme.focusedBorder!;
      final mac = theme.platform == TargetPlatform.macOS;
      expect(
          focused.borderSide.style, mac ? BorderStyle.solid : BorderStyle.none);
      expect(const GlassFieldBorder().isOutline, isFalse);
    }, variant: apple);

    testWidgets('pickers mark the choice with a checkmark', (tester) async {
      String? picked;
      await open(
        tester,
        () async {
          picked = await globalState.showCommonDialog<String>(
            child: OptionsDialog<String>(
              title: 'Mode',
              options: const ['Rule', 'Global', 'Direct'],
              value: 'Global',
              textBuilder: (value) => value,
            ),
          );
        },
      );
      expect(find.byType(GlassOptionRow), findsNWidgets(3));
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(GlassOptionRow, 'Global'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Direct'));
      await tester.pumpAndSettle();
      expect(picked, 'Direct');
    }, variant: apple);

    testWidgets('macOS modal: one glass panel, the page shows it through',
        (tester) async {
      await open(
        tester,
        () => globalState.showCommonDialog<void>(
          child: const CommonModal(
            child: Scaffold(body: Center(child: Text('Editor'))),
          ),
        ),
        viewSize: desktop,
      );
      expect(find.byType(GlassModalPanel), findsOneWidget);
      expect(blurs(), findsOneWidget);
      expectNoFadeAboveBlur(tester);
      final scaffold = tester.element(find.text('Editor'));
      expect(Theme.of(scaffold).scaffoldBackgroundColor, Colors.transparent);
      final panel = tester.getSize(find.byType(GlassSurface));
      expect(panel.width, moreOrLessEquals(desktop.width * 0.85));
      expect(panel.height, moreOrLessEquals(desktop.height * 0.85));
    }, variant: mac);
  });

  group('Material', () {
    testWidgets('keeps showModal and AlertDialog', (tester) async {
      await open(tester, showTwoButtons, settle: false);
      expect(find.byType(FadeScaleTransition), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(GlassDialog), findsNothing);
      expect(find.byType(GlassSurface), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('glass override off on Darwin falls back to Material',
        (tester) async {
      AdaptivePlatform.debugUseGlassOverride = false;
      await open(tester, showTwoButtons);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(GlassDialog), findsNothing);
    }, variant: mac);
  });
}
