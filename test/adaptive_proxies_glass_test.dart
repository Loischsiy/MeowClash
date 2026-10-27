import 'dart:math';

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
import 'package:meowclash/views/proxies/common.dart';
import 'package:meowclash/views/proxies/list.dart';
import 'package:meowclash/views/proxies/tab.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/card.dart';
import 'package:meowclash/widgets/text.dart';

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
  const apple = TargetPlatformVariant(
    {TargetPlatform.macOS, TargetPlatform.iOS},
  );

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
        const Profile(
          id: 'test',
          autoUpdateDuration: Duration(days: 1),
          unfoldSet: {'Select', 'Auto'},
          selectedMap: {'Select': 'HK 002'},
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

    testWidgets('cards scroll under the stuck group header', (tester) async {
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(tester, host(const ProxiesListView()));
      await scrollList(tester, 600);
      final header = tester.getRect(find.byType(GlassSurface).first);
      expect(header.top, lessThanOrEqualTo(GlassTokens.groupHeaderMargin));
      final under = tester
          .widgetList(find.byType(AdaptiveCard))
          .map((card) => tester.getRect(find.byWidget(card)))
          .where((rect) => rect.overlaps(header));
      expect(under, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: apple);

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

  group('cards', () {
    Finder name(String proxy) =>
        find.byWidgetPredicate((w) => w is EmojiText && w.text == proxy);
    Finder cardOf(String proxy) =>
        find.ancestor(of: name(proxy), matching: find.byType(AdaptiveCard));

    testWidgets('names, descriptions and delays use the Apple type scale',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView()));
      final mac = defaultTargetPlatform == TargetPlatform.macOS;

      final title = tester.widget<EmojiText>(name('HK 001')).style!;
      expect(title.fontSize, mac ? 13 : 15);
      expect(title.fontSize! * title.height!, mac ? 16 : 20);
      expect(title.fontWeight, FontWeight.w500);
      final desc = tester
          .widgetList<EmojiText>(find.descendant(
            of: cardOf('HK 001'),
            matching: find.byType(EmojiText),
          ))
          .last
          .style!;
      expect(desc.fontSize, mac ? 11 : 13);
      final badge = tester.widget<Text>(find.text('48 ms')).style!;
      expect(badge.fontSize, mac ? 11 : 12);
      expect(badge.fontWeight, FontWeight.w600);

      // The grid extent is measured from the same styles.
      expect(
        tester.getSize(cardOf('HK 001')).height,
        moreOrLessEquals(getItemHeight(ProxyCardType.expand)),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: apple);

    testWidgets('selection is a light tint and a hairline, not an outline',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView()));
      ShapeDecoration decorationOf(String proxy) => tester
          .widget<AnimatedContainer>(find.descendant(
            of: cardOf(proxy),
            matching: find.byType(AnimatedContainer),
          ))
          .decoration! as ShapeDecoration;
      BorderSide sideOf(ShapeDecoration d) =>
          (d.shape as RoundedSuperellipseBorder).side;

      final selected = decorationOf('HK 002');
      final resting = decorationOf('HK 001');
      expect(sideOf(selected).width, GlassTokens.hairlineWidth);
      expect(sideOf(resting).width, GlassTokens.hairlineWidth);
      expect(selected.color, isNot(resting.color));
      expect(
        find.descendant(
          of: cardOf('HK 002'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardOf('HK 001'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: darwin);

    testWidgets('group header uses the Apple title scale', (tester) async {
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(tester, host(const ProxiesListView()));
      final title = tester.widget<Text>(find.text('Select').first).style!;
      expect(title.fontSize, 15);
      expect(title.fontWeight, FontWeight.w600);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: darwin);
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

    testWidgets('the grid scrolls under the floating bar', (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView()));
      final bar = tester.getRect(find.byType(GlassSurface).first);
      await tester.drag(find.byType(GridView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
      final under = tester
          .widgetList(find.byType(AdaptiveCard))
          .map((card) => tester.getRect(find.byWidget(card)))
          .where((rect) => rect.overlaps(bar));
      expect(under, isNotEmpty);
      // ...and the bar stays on top of them.
      expect(tester.getRect(find.byType(GlassSurface).first), bar);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: apple);

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

  group('under the glass toolbar', () {
    const bar = 100.0;
    Iterable<Rect> cardRects(WidgetTester tester) => tester
        .widgetList(find.byType(AdaptiveCard))
        .map((card) => tester.getRect(find.byWidget(card)));

    testWidgets('list: starts below the bar, header sticks right under it',
        (tester) async {
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(
        tester,
        host(const ProxiesListView(), topInset: bar),
      );
      expect(tester.getRect(find.byType(CustomScrollView)).top, 0);
      expect(cardRects(tester).map((r) => r.top).reduce(min),
          greaterThanOrEqualTo(bar));
      expect(blur, findsNothing);

      await scrollList(tester, 600);
      // The stuck header pins below the toolbar, not under its glass...
      final header = tester.getRect(find.byType(GlassSurface).first);
      expect(header.top, greaterThanOrEqualTo(bar));
      expect(header.top, lessThanOrEqualTo(bar + GlassTokens.groupHeaderMargin));
      // ...while the cards scroll on under the toolbar.
      expect(cardRects(tester).where((r) => r.top < bar), isNotEmpty);
      expect(blur, findsOneWidget);
      expect(blurInCards(), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: apple);

    testWidgets('list: header is glass from the first pixel under the bar',
        (tester) async {
      // Less than the toolbar height: the header sticks through the toolbar
      // overlap while its own shrinkOffset is still 0.
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(
        tester,
        host(const ProxiesListView(), topInset: bar),
      );
      expect(blur, findsNothing);

      await scrollList(tester, bar / 2);
      final header = tester.getRect(find.byType(GlassSurface).first);
      expect(header.top, greaterThanOrEqualTo(bar));
      expect(cardRects(tester).where((r) => r.top < header.bottom), isNotEmpty);
      expect(blur, findsOneWidget);
      expect(blurInCards(), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: apple);

    testWidgets('tabs: group bar below the toolbar, grid scrolls under both',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView(), topInset: bar));
      final groupBar = tester.getRect(find.byType(GlassSurface).first);
      expect(groupBar.top, greaterThanOrEqualTo(bar));
      expect(
        groupBar.top,
        lessThanOrEqualTo(bar + GlassTokens.groupBarTopMargin),
      );
      expect(tester.getRect(find.byType(AdaptiveCard).first).top,
          greaterThanOrEqualTo(groupBar.bottom));

      await tester.drag(find.byType(GridView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(cardRects(tester).where((r) => r.top < bar), isNotEmpty);
      expect(tester.getRect(find.byType(GlassSurface).first), groupBar);
      expect(blur, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: apple);

    testWidgets('empty state stays centred below the bar', (tester) async {
      await setUp(tester, type: ProxiesType.list, groupsOverride: const []);
      await pumpScreen(
        tester,
        host(const ProxiesListView(), topInset: bar),
      );
      expect(tester.getRect(find.byType(AdaptiveEmptyState)).top, bar);
    }, variant: darwin);

    testWidgets('Material ignores the inset: no spacer, TabBar on top',
        (tester) async {
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(tester, host(const ProxiesListView(), topInset: bar));
      expect(find.byType(SliverToolbarInset), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      await setUp(tester, type: ProxiesType.tab);
      await pumpScreen(tester, host(const ProxiesTabView(), topInset: bar));
      expect(tester.getTopLeft(find.byType(TabBar)).dy, 0);
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
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: darwin);

    testWidgets('empty screen uses the adaptive empty state', (tester) async {
      await setUp(tester, type: ProxiesType.list, groupsOverride: const []);
      await pumpScreen(tester, host(const ProxiesListView()));
      expect(find.byType(AdaptiveEmptyState), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    }, variant: darwin);

    testWidgets('group header absorbs a subtitle taller than measured',
        (tester) async {
      // Emoji (Twemoji) spans are taller than the measured subtitle line.
      await setUp(tester, type: ProxiesType.list);
      await pumpScreen(
        tester,
        // globalState.measure is set by host() during the build.
        host(Builder(builder: (context) {
          final measure = globalState.measure;
          final textTheme = Theme.of(context).textTheme;
          final subtitleHeight =
              measure.heightOf(GlassTextStyles.groupSubtitle(textTheme));
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: AdaptiveGroupHeader.extent(
                titleHeight:
                    measure.heightOf(GlassTextStyles.groupTitle(textTheme)),
                subtitleHeight: subtitleHeight,
              ),
              child: AdaptiveGroupHeader(
                materialBuilder: (_) => const SizedBox.shrink(),
                title: 'Proxy',
                subtitle: SizedBox(height: subtitleHeight + 6),
                expanded: true,
                onToggle: () {},
                onTest: () {},
              ),
            ),
          );
        })),
      );
      expect(tester.takeException(), isNull);
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
              glassIcon: const Icon(Icons.speed_rounded),
            ),
          ),
          accessibility: const GlassAccessibility(reduceMotion: true),
        ),
      );
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.duration, Duration.zero);
    }, variant: darwin);

    testWidgets('prominent button is accent glass with an onPrimary symbol',
        (tester) async {
      await setUp(tester, type: ProxiesType.tab);
      Widget button({required bool prominent}) => AdaptiveFloatingButton(
            onPressed: () {},
            icon: const Icon(Icons.add),
            glassIcon: const Icon(Icons.add_rounded),
            prominent: prominent,
          );
      await pumpScreen(
        tester,
        host(Center(child: button(prominent: true))),
      );
      final context = tester.element(find.byType(AdaptiveFloatingButton));
      final scheme = Theme.of(context).colorScheme;
      final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(surface.color, scheme.primary);
      expect(surface.opaqueColor, scheme.primary);
      expect(
        surface.tintOpacity,
        GlassTokens.floatingButtonProminentTintOpacity,
      );
      final icon = tester.widget<IconTheme>(
        find
            .ancestor(
              of: find.byIcon(Icons.add_rounded),
              matching: find.byType(IconTheme),
            )
            .first,
      );
      expect(icon.data.color, scheme.onPrimary);
      expect(blur, findsOneWidget);

      await pumpScreen(
        tester,
        host(Center(child: button(prominent: false))),
      );
      final plain = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(plain.color, isNull);
      expect(plain.tintOpacity, isNull);
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
