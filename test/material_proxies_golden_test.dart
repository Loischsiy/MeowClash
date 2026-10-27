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
import 'package:meowclash/widgets/setting.dart';

import 'performance_test_support.dart';

/// Pixel baseline of the Material "Proxies" screen that Android, Linux and
/// Windows must keep after the Darwin glass work on that screen. The images
/// were generated on `main` before the glass proxies screen landed and must
/// still match. Regenerate only for an intended Material change:
/// `flutter test --update-goldens test/material_proxies_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const url = 'https://test.invalid/generate_204';
  const mobile = Size(400, 640);
  const desktop = Size(800, 520);

  List<Proxy> nodes(String prefix, int count) => List.generate(
        count,
        (i) => Proxy(
          name: '$prefix ${(i + 1).toString().padLeft(2, '0')}',
          type: i.isEven ? 'Shadowsocks' : 'Vmess',
        ),
      );

  final groups = [
    Group(
      name: 'Select',
      type: GroupType.Selector,
      hidden: false,
      now: 'HK 02',
      testUrl: url,
      all: nodes('HK', 6),
    ),
    Group(
      name: 'Auto',
      type: GroupType.URLTest,
      hidden: false,
      now: 'JP 01',
      testUrl: url,
      all: nodes('JP', 4),
    ),
    Group(
      name: 'Fallback',
      type: GroupType.Fallback,
      hidden: false,
      now: 'US 01',
      testUrl: url,
      all: nodes('US', 3),
    ),
  ];

  // Every delay state a card can show: measured (fast / medium / slow),
  // timeout, in progress (0) and untested (absent).
  const delays = {
    url: {
      'HK 01': 48,
      'HK 02': 230,
      'HK 03': 820,
      'HK 04': -1,
      'HK 05': 0,
      'JP 01': 95,
      'JP 02': -1,
      'US 01': 160,
    },
  };

  Future<void> setUp(
    WidgetTester tester, {
    required Size size,
    required ProxiesType type,
    ProxyCardType cardType = ProxyCardType.expand,
    ProxiesIconStyle iconStyle = ProxiesIconStyle.icon,
    List<Group>? groupsOverride,
    Set<String> unfold = const {'Select', 'Auto'},
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
          unfoldSet: unfold,
          selectedMap: const {'Select': 'HK 02'},
          currentGroupName: 'Select',
        ),
      ],
      proxiesStyle: ProxiesStyle(
        type: type,
        cardType: cardType,
        iconStyle: iconStyle,
      ),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(Brightness brightness, Widget child) => ProviderScope(
        overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
        child: MaterialApp(
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
              return child;
            }),
          ),
        ),
      );

  // The in-progress delay shows an indeterminate spinner, so the screen never
  // settles: pump a fixed timeline instead to keep the frame deterministic.
  Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> expectScreen(WidgetTester tester, String name) => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_proxies_$name.png'),
      );

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    for (final cardType in ProxyCardType.values) {
      testWidgets('list, ${cardType.name} cards, $b', (tester) async {
        await setUp(
          tester,
          size: mobile,
          type: ProxiesType.list,
          cardType: cardType,
        );
        await pumpScreen(tester, host(brightness, const ProxiesListView()));
        await expectScreen(tester, 'list_${cardType.name}_$b');
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }

    testWidgets('list, desktop, $b', (tester) async {
      await setUp(
        tester,
        size: desktop,
        type: ProxiesType.list,
        iconStyle: ProxiesIconStyle.none,
        unfold: const {'Auto'},
      );
      await pumpScreen(tester, host(brightness, const ProxiesListView()));
      await expectScreen(tester, 'list_desktop_$b');
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('tab, mobile, $b', (tester) async {
      await setUp(tester, size: mobile, type: ProxiesType.tab);
      await pumpScreen(tester, host(brightness, const ProxiesTabView()));
      await expectScreen(tester, 'tab_mobile_$b');
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('group sheet, mobile, $b', (tester) async {
      // The Material more button shows only once the tabs overflow.
      final manyGroups = [
        ...groups,
        for (var i = 1; i <= 6; i++)
          Group(
            name: 'Region ${i.toString().padLeft(2, '0')}',
            type: GroupType.Selector,
            hidden: false,
            testUrl: url,
            all: nodes('R$i', 2),
          ),
      ];
      await setUp(
        tester,
        size: mobile,
        type: ProxiesType.tab,
        groupsOverride: manyGroups,
      );
      await pumpScreen(tester, host(brightness, const ProxiesTabView()));
      // The more button: expand_more in the mobile view, chevron_right else.
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              (widget.icon == Icons.expand_more ||
                  widget.icon == Icons.chevron_right),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(SettingTextCard), findsNWidgets(manyGroups.length));
      await expectScreen(tester, 'group_sheet_$b');
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('tab, desktop, $b', (tester) async {
      await setUp(
        tester,
        size: desktop,
        type: ProxiesType.tab,
        cardType: ProxyCardType.shrink,
      );
      await pumpScreen(tester, host(brightness, const ProxiesTabView()));
      await expectScreen(tester, 'tab_desktop_$b');
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('empty, list, $b', (tester) async {
      await setUp(
        tester,
        size: mobile,
        type: ProxiesType.list,
        groupsOverride: const [],
      );
      await pumpScreen(tester, host(brightness, const ProxiesListView()));
      await expectScreen(tester, 'empty_list_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('empty, tab, $b', (tester) async {
      await setUp(
        tester,
        size: mobile,
        type: ProxiesType.tab,
        groupsOverride: const [],
      );
      await pumpScreen(tester, host(brightness, const ProxiesTabView()));
      await expectScreen(tester, 'empty_tab_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('delay test button, $b', (tester) async {
      await setUp(tester, size: const Size(120, 120), type: ProxiesType.tab);
      await pumpScreen(
        tester,
        host(
          brightness,
          Center(child: DelayTestButton(onClick: () async {})),
        ),
      );
      await expectLater(
        find.byType(DelayTestButton),
        matchesGoldenFile('goldens/material_proxies_delay_button_$b.png'),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
