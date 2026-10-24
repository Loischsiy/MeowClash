import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/proxies/list.dart';
import 'package:meowclash/views/proxies/tab.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/card.dart';

import 'performance_test_support.dart';

/// Darwin glass on the "Proxies" screen: blur stays on the pinned chrome
/// (group bar, stuck group header, delay test button) and never multiplies
/// with the number of proxies; the fallbacks drop it entirely.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const url = 'https://test.invalid/generate_204';
  const size = Size(400, 640);
  const proxyCount = 150;

  final darwin = TargetPlatformVariant.only(TargetPlatform.macOS);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  List<Proxy> nodes(String prefix, int count) => List.generate(
        count,
        (i) => Proxy(
          name: '$prefix ${(i + 1).toString().padLeft(3, '0')}',
          type: 'Shadowsocks',
        ),
      );

  final groups = [
    Group(
      name: 'Select',
      type: GroupType.Selector,
      hidden: false,
      now: 'HK 002',
      testUrl: url,
      all: nodes('HK', proxyCount),
    ),
    Group(
      name: 'Auto',
      type: GroupType.URLTest,
      hidden: false,
      now: 'JP 001',
      testUrl: url,
      all: nodes('JP', proxyCount),
    ),
  ];

  const delays = {
    url: {'HK 001': 48, 'HK 002': 230, 'HK 003': -1, 'HK 004': 0},
  };

  Future<void> setUp(
    WidgetTester tester, {
    required ProxiesType type,
    List<Group>? groupsOverride,
  }) async {
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState(groups: groupsOverride ?? groups, delays: delays);
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    globalState.config = globalState.config.copyWith(
      currentProfileId: 'test',
      profiles: [
        Profile(
          id: 'test',
          autoUpdateDuration: const Duration(days: 1),
          unfoldSet: const {'Select', 'Auto'},
          selectedMap: const {'Select': 'HK 002'},
          currentGroupName: 'Select',
        ),
      ],
      proxiesStyle: ProxiesStyle(
        type: type,
        cardType: ProxyCardType.expand,
        iconStyle: ProxiesIconStyle.none,
      ),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(
    Widget child, {
    GlassAccessibility accessibility = GlassAccessibility.fallback,
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
                return child;
              }),
            ),
          ),
        ),
      );

  // The running delay test spins forever: pump a fixed timeline.
  Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> scrollList(WidgetTester tester, double by) async {
    await tester.drag(find.byType(CustomScrollView), Offset(0, -by));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final blur = find.byType(BackdropFilter);
  Finder blurInCards() => find.descendant(
        of: find.byType(AdaptiveCard),
        matching: find.byType(BackdropFilter),
      );

  group('list mode', () {
    testWidgets('no blur at rest, one stuck header blur after scrolling',
        (tester) async {
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(tester, host(const ProxiesListView()));
      expect(find.byType(AdaptiveCard), findsWidgets);
      expect(find.byType(CommonCard), findsNothing);
      expect(blur, findsNothing);

      for (final offset in [300.0, 1500.0, 6000.0]) {
        await scrollList(tester, offset);
        expect(blur, findsOneWidget, reason: 'after $offset px');
        expect(blurInCards(), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: darwin);

    testWidgets('Reduce Transparency keeps the stuck header opaque',
        (tester) async {
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(
        tester,
        host(
          const ProxiesListView(),
          accessibility: const GlassAccessibility(reduceTransparency: true),
        ),
      );
      await scrollList(tester, 1500);
      expect(blur, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: darwin);

    testWidgets('kill switch removes the stuck header blur', (tester) async {
      GlassFlags.backdropBlurEnabled = false;
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(tester, host(const ProxiesListView()));
      await scrollList(tester, 1500);
      expect(blur, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: darwin);

    testWidgets('Material keeps CommonCard, no glass and no blur',
        (tester) async {
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(tester, host(const ProxiesListView()));
      expect(find.byType(CommonCard), findsWidgets);
      expect(find.byType(GlassSurface), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      await scrollList(tester, 1500);
      expect(blur, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: android);
  });

  group('tab mode', () {
    testWidgets('the group bar is the only blur over $proxyCount proxies',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView()));
      expect(find.byType(AdaptiveCard), findsWidgets);
      expect(blur, findsOneWidget);
      expect(blurInCards(), findsNothing);

      await tester.drag(find.byType(GridView), const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 300));
      expect(blur, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: ios);

    testWidgets('the grid starts below the floating bar', (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView()));
      final bar = tester.getRect(find.byType(GlassSurface).first);
      final firstCard = tester.getRect(find.byType(AdaptiveCard).first);
      expect(firstCard.top, greaterThanOrEqualTo(bar.bottom));
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: ios);

    testWidgets('Reduce Transparency makes the group bar opaque',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(
        tester,
        host(
          const ProxiesTabView(),
          accessibility: const GlassAccessibility(reduceTransparency: true),
        ),
      );
      expect(blur, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: ios);

    testWidgets('Material keeps the TabBar without glass', (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView()));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(GlassSurface), findsNothing);
      expect(blur, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: android);
  });

  group('states', () {
    testWidgets('delay badge: spinner, pill and bolt in Apple style',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView()));
      expect(find.byType(CupertinoActivityIndicator), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('48 ms'), findsOneWidget);
      expect(find.text('Timeout'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.bolt_fill), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: darwin);

    testWidgets('empty screen uses the adaptive empty state', (tester) async {
      await setUp(tester, type: ProxiesType.list, groupsOverride: const []);
      await pumpScreen(tester, host(const ProxiesListView()));
      expect(find.byType(AdaptiveEmptyState), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
    }, variant: darwin);

    testWidgets('delay test button is one glass circle', (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(
        tester,
        host(Center(child: DelayTestButton(onClick: () async {}))),
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(blur, findsOneWidget);
    }, variant: darwin);

    testWidgets('delay test button shows a spinner while running',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      final done = ValueNotifier(false);
      addTearDown(done.dispose);
      await pumpScreen(
        tester,
        host(Center(
          child: DelayTestButton(onClick: () async {
            while (!done.value) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
          }),
        )),
      );
      await tester.tap(find.byType(DelayTestButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(DelayTestButton),
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsOneWidget,
      );
      done.value = true;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(DelayTestButton),
          matching: find.byType(CupertinoActivityIndicator),
        ),
        findsNothing,
      );
    }, variant: darwin);

    testWidgets('Reduce Motion drops the press animation', (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(
        tester,
        host(
          Center(
            child: AdaptiveFloatingButton(
              onPressed: () {},
              icon: const Icon(Icons.network_ping),
              glassIcon: const Icon(CupertinoIcons.speedometer),
            ),
          ),
          accessibility: const GlassAccessibility(reduceMotion: true),
        ),
      );
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration, Duration.zero);
    }, variant: darwin);

    test('Material is chosen off Darwin', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        final glass = platform == TargetPlatform.macOS ||
            platform == TargetPlatform.iOS;
        expect(AdaptiveGroupSelector.floats, glass, reason: '$platform');
        expect(
          AdaptiveGroupSelector.contentInset,
          glass ? greaterThan(0) : 0,
          reason: '$platform',
        );
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
