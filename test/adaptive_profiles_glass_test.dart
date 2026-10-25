import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/profiles.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/card.dart';
import 'package:meowclash/widgets/sheet.dart';

import 'performance_test_support.dart';

/// Darwin glass on the "Profiles" screen: flat translucent cards (no blur
/// per profile), selection without a check badge, Apple traffic colors and
/// the fallbacks; Material keeps its widgets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 720);
  const gib = 1024 * 1024 * 1024;
  const expire = 1798804800;

  final darwin = TargetPlatformVariant.only(TargetPlatform.macOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  const apple = TargetPlatformVariant(
    {TargetPlatform.macOS, TargetPlatform.iOS},
  );

  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  Profile subscription(String id, String label, int used, int total) =>
      Profile(
        id: id,
        label: label,
        url: 'https://test.invalid/$id',
        autoUpdateDuration: const Duration(days: 1),
        lastUpdateDate: DateTime.now().subtract(const Duration(days: 3)),
        subscriptionInfo: SubscriptionInfo(
          download: used,
          total: total,
          expire: expire,
        ),
      );

  List<Profile> profiles() => [
        Profile(
          id: 'file',
          label: 'Local file',
          autoUpdateDuration: const Duration(days: 1),
          lastUpdateDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
        subscription('half', 'Half', 5 * gib, 10 * gib),
        subscription('warn', 'Warn', 15 * gib, 20 * gib),
        subscription('almost', 'Almost', 19 * gib, 20 * gib),
        const Profile(
          id: 'updating',
          label: 'Updating',
          url: 'https://test.invalid/updating',
          autoUpdateDuration: Duration(days: 1),
          isUpdating: true,
        ),
      ];

  Future<void> setUp(WidgetTester tester, {List<Profile>? override}) async {
    await AppLocalizations.load(const Locale('en'));
    await initializeDateFormatting('en');
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    globalState.config = globalState.config.copyWith(
      currentProfileId: 'half',
      profiles: override ?? profiles(),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // [topInset] stands in for `CommonScaffold(scrollUnderToolbar: true)`:
  // the Scaffold then reports the glass toolbar as top padding.
  Widget host(
    Widget child, {
    GlassAccessibility accessibility = GlassAccessibility.fallback,
    double topInset = 0,
  }) =>
      ProviderScope(
        overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
        child: GlassAccessibilityScope(
          controller: GlassAccessibilityController()..value = accessibility,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Consumer(builder: (context, ref, _) {
                globalState.appController = AppController(context, ref);
                globalState.measure = Measure.of(context, 1);
                globalState.theme = CommonTheme.of(context, 1);
                if (topInset == 0) return child;
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: EdgeInsets.only(top: topInset),
                  ),
                  child: child,
                );
              }),
            ),
          ),
        ),
      );

  // The updating profile spins forever: pump a fixed timeline.
  Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  final blur = find.byType(BackdropFilter);
  Finder cardOf(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(AdaptiveCard));
  Finder barOf(String label) => find.descendant(
        of: cardOf(label),
        matching: find.byType(AdaptiveProgressBar),
      );
  Color trackOf(WidgetTester tester, String label) {
    final track = tester.widget<DecoratedBox>(
      find.descendant(of: barOf(label), matching: find.byType(DecoratedBox))
          .first,
    );
    return (track.decoration as BoxDecoration).color!;
  }

  group('list', () {
    testWidgets('flat glass cards, no blur even for 120 profiles',
        (tester) async {
      await setUp(
        tester,
        override: [
          for (var i = 0; i < 120; i++)
            subscription('p$i', 'Profile $i', i * gib, 120 * gib),
        ],
      );
      await pumpScreen(tester, host(const ProfilesView()));
      expect(find.byType(AdaptiveCard), findsNWidgets(120));
      expect(find.byType(CommonCard), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(blur, findsNothing);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -6000),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(blur, findsNothing);
      await unmount(tester);
    }, variant: apple);

    testWidgets('selection is a tint and a hairline without a check badge',
        (tester) async {
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView()));
      ShapeDecoration decorationOf(String label) => tester
          .widget<AnimatedContainer>(find
              .descendant(
                of: cardOf(label),
                matching: find.byType(AnimatedContainer),
              )
              .first)
          .decoration! as ShapeDecoration;
      BorderSide sideOf(ShapeDecoration d) =>
          (d.shape as RoundedSuperellipseBorder).side;

      final selected = decorationOf('Half');
      final resting = decorationOf('Warn');
      expect(sideOf(selected).width, GlassTokens.hairlineWidth);
      expect(sideOf(resting).width, GlassTokens.hairlineWidth);
      expect(selected.color, isNot(resting.color));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await unmount(tester);
    }, variant: darwin);

    testWidgets('names and details use the Apple type scale', (tester) async {
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView()));
      final mac = defaultTargetPlatform == TargetPlatform.macOS;
      final title = tester.widget<Text>(find.text('Half')).style!;
      expect(title.fontSize, mac ? 15 : 17);
      expect(title.fontWeight, FontWeight.w600);
      final detail = tester
          .widget<Text>(find.textContaining('Traffic').first)
          .style!;
      expect(detail.fontSize, mac ? 11 : 13);
      await unmount(tester);
    }, variant: apple);

    testWidgets('traffic bar turns orange, then red, with Apple colors',
        (tester) async {
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView()));
      final brightness =
          Theme.of(tester.element(find.byType(ProfilesView))).brightness;
      Color? colorOf(String label) =>
          tester.widget<AdaptiveProgressBar>(barOf(label)).glassColor;
      expect(colorOf('Half'), GlassTokens.trafficColor(0.5, brightness));
      expect(colorOf('Warn'), GlassTokens.trafficColor(0.75, brightness));
      expect(colorOf('Almost'), GlassTokens.trafficColor(0.95, brightness));
      expect(
        {colorOf('Half'), colorOf('Warn'), colorOf('Almost')},
        hasLength(3),
      );
      expect(barOf('Local file'), findsNothing);
      await unmount(tester);
    }, variant: darwin);

    testWidgets('an updating profile shows the Cupertino spinner',
        (tester) async {
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView()));
      expect(
        find.descendant(
          of: cardOf('Updating'),
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsOneWidget,
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNWidgets(4));
      await unmount(tester);
    }, variant: apple);

    testWidgets('the list starts below the glass toolbar', (tester) async {
      const inset = 60.0;
      await setUp(
        tester,
        override: [
          for (var i = 0; i < 20; i++)
            subscription('p$i', 'Profile $i', i * gib, 20 * gib),
        ],
      );
      await pumpScreen(tester, host(const ProfilesView(), topInset: inset));
      final first = tester.getRect(find.byType(AdaptiveCard).first);
      expect(first.top, moreOrLessEquals(inset + 16));

      // ...and scrolls under it.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getRect(find.byType(AdaptiveCard).first).top,
        lessThan(inset),
      );
      await unmount(tester);
    }, variant: apple);

    testWidgets('Reduce Transparency and the kill switch make tracks opaque',
        (tester) async {
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView()));
      final scheme =
          Theme.of(tester.element(find.byType(ProfilesView))).colorScheme;
      expect(trackOf(tester, 'Half').a, lessThan(1));
      // The scope reads its controller once: remount to switch it.
      await unmount(tester);

      await pumpScreen(
        tester,
        host(
          const ProfilesView(),
          accessibility: const GlassAccessibility(reduceTransparency: true),
        ),
      );
      expect(trackOf(tester, 'Half'), scheme.surfaceContainerHighest);
      expect(blur, findsNothing);
      await unmount(tester);

      GlassFlags.backdropBlurEnabled = false;
      await pumpScreen(tester, host(const ProfilesView()));
      expect(trackOf(tester, 'Half'), scheme.surfaceContainerHighest);
      await unmount(tester);
    }, variant: darwin);

    testWidgets('the glass override off falls back to Material',
        (tester) async {
      AdaptivePlatform.debugUseGlassOverride = false;
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView(), topInset: 60));
      expect(find.byType(AdaptiveCard), findsNothing);
      expect(find.byType(CommonCard), findsWidgets);
      // Material ignores the toolbar inset.
      expect(
        tester.getRect(find.byType(CommonCard).first).top,
        lessThan(60),
      );
      await unmount(tester);
    }, variant: darwin);

    testWidgets('Material keeps CommonCard, LinearProgressIndicator, no glass',
        (tester) async {
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView()));
      expect(find.byType(CommonCard), findsWidgets);
      expect(find.byType(AdaptiveCard), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(find.byType(GlassSurface), findsNothing);
      expect(find.byType(GlassIconButton), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(blur, findsNothing);
      await unmount(tester);
    }, variant: android);
  });

  group('empty state', () {
    testWidgets('Darwin shows a folder symbol below the toolbar',
        (tester) async {
      const inset = 60.0;
      await setUp(tester, override: const []);
      await pumpScreen(tester, host(const ProfilesView(), topInset: inset));
      expect(find.byType(AdaptiveEmptyState), findsOneWidget);
      final icon = find.byIcon(Icons.folder_outlined);
      expect(icon, findsOneWidget);
      final center = tester.getCenter(find.byType(AdaptiveEmptyState));
      expect(center.dy, moreOrLessEquals(inset + (size.height - inset) / 2));
      await unmount(tester);
    }, variant: apple);

    testWidgets('Material keeps the text-only placeholder', (tester) async {
      await setUp(tester, override: const []);
      await pumpScreen(tester, host(const ProfilesView()));
      expect(find.byIcon(Icons.folder_outlined), findsNothing);
      await unmount(tester);
    }, variant: android);
  });

  group('floating button', () {
    testWidgets('uses the rounded glass symbol', (tester) async {
      await setUp(tester);
      await pumpScreen(tester, host(const ProfilesView()));
      final fab = (tester.state(find.byType(ProfilesView)) as dynamic)
          .floatingActionButton as AdaptiveFloatingButton;
      expect((fab.icon as Icon).icon, Icons.add);
      expect((fab.glassIcon as Icon).icon, Icons.add_rounded);
      await unmount(tester);
    }, variant: darwin);
  });

  group('sort sheet', () {
    Widget opener() => Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showSheet<void>(
                context: context,
                builder: (_, type) => ReorderableProfilesSheet(
                  type: type,
                  profiles: globalState.config.profiles,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        );

    Future<void> open(
      WidgetTester tester, {
      GlassAccessibility accessibility = GlassAccessibility.fallback,
    }) async {
      await setUp(
        tester,
        override: profiles().where((p) => !p.isUpdating).toList(),
      );
      await tester.pumpWidget(host(opener(), accessibility: accessibility));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    // The largest scale among the transforms above [finder].
    double liftOf(WidgetTester tester, Finder finder) => tester
        .widgetList<Transform>(
          find.ancestor(of: finder, matching: find.byType(Transform)),
        )
        .map((t) => t.transform.getMaxScaleOnAxis())
        .fold(1, (a, b) => a > b ? a : b);

    testWidgets('rows are flat glass cards with rounded symbols',
        (tester) async {
      await open(tester);
      expect(find.byType(CommonCard), findsNothing);
      expect(find.byType(AdaptiveCard), findsNWidgets(4));
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AdaptiveCard),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(AdaptiveCard).first).height,
        GlassTokens.listRowHeight,
      );
      await unmount(tester);
    }, variant: apple);

    testWidgets('the dragged row lifts, but not with Reduce Motion',
        (tester) async {
      for (final reduceMotion in [false, true]) {
        await open(
          tester,
          accessibility: GlassAccessibility(reduceMotion: reduceMotion),
        );
        final handle = find.byIcon(Icons.drag_handle_rounded).first;
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 500));

        // The dragged row leaves a gap and lifts in the overlay with the
        // floating shadow.
        final shadow = GlassTokens.floatingShadow(Brightness.light);
        expect(
          find.byWidgetPredicate((w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              listEquals(
                (w.decoration as BoxDecoration).boxShadow,
                shadow,
              )),
          findsOneWidget,
        );
        final rows = find.byIcon(Icons.drag_handle_rounded);
        final lift = [
          for (var i = 0; i < rows.evaluate().length; i++)
            liftOf(tester, rows.at(i)),
        ].reduce((a, b) => a > b ? a : b);
        expect(
          lift,
          moreOrLessEquals(reduceMotion ? 1 : GlassTokens.listRowDragScale),
          reason: 'reduceMotion: $reduceMotion',
        );

        await gesture.up();
        await tester.pumpAndSettle();
        await unmount(tester);
      }
    }, variant: darwin);

    testWidgets('Material keeps the filled cards and the save icon',
        (tester) async {
      await open(tester);
      expect(find.byType(AdaptiveCard), findsNothing);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(4));
      expect(find.byIcon(Icons.save), findsOneWidget);
      await unmount(tester);
    }, variant: android);
  });

  test('traffic thresholds', () {
    for (final brightness in Brightness.values) {
      Color at(double p) => GlassTokens.trafficColor(p, brightness);
      expect(at(0), at(GlassTokens.trafficWarningThreshold));
      expect(at(0.71), isNot(at(0.7)));
      expect(at(0.71), at(GlassTokens.trafficCriticalThreshold));
      expect(at(0.91), isNot(at(0.9)));
      expect(at(0.91), at(1));
    }
    expect(
      GlassTokens.trafficColor(0.5, Brightness.light),
      isNot(GlassTokens.trafficColor(0.5, Brightness.dark)),
    );
  });
}
