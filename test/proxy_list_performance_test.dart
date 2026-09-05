import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/proxies/card.dart';
import 'package:meowclash/views/proxies/list.dart';
import 'package:meowclash/views/proxies/tab.dart';

import 'performance_test_support.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  testWidgets(
      '5000-node expanded groups mount only viewport cards, including after scrolling',
      (tester) async {
    final nodes =
        List.generate(5000, (i) => Proxy(name: 'node$i', type: 'Shadowsocks'));
    final groups = [
      Group(
          name: 'A',
          type: GroupType.Selector,
          hidden: false,
          now: 'node0',
          testUrl: 'url',
          all: nodes),
      Group(
          name: 'B',
          type: GroupType.Selector,
          hidden: false,
          now: 'node0',
          testUrl: 'url',
          all: nodes),
    ];
    initializePerformanceState(groups: groups);
    globalState.config = globalState.config.copyWith(
      currentProfileId: 'test',
      profiles: [
        const Profile(
            id: 'test',
            autoUpdateDuration: Duration(days: 1),
            unfoldSet: {'A', 'B'})
      ],
      proxiesStyle: const ProxiesStyle(iconStyle: ProxiesIconStyle.none),
    );
    late WidgetRef testRef;
    await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: Scaffold(body: Consumer(
      builder: (context, ref, child) {
        testRef = ref;
        globalState.appController = AppController(context, ref);
        globalState.measure = Measure.of(context, 1);
        return const ProxiesListView();
      },
    )))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final before =
        tester.widgetList<ProxyCard>(find.byType(ProxyCard)).toList();
    expect(before.length, inInclusiveRange(1, 100));
    // A scalar update must not rebuild/recreate the list or its ProxyCards.
    final notifier = testRef.read(delayDataSourceProvider.notifier);
    for (var i = 0; i < 1000; i++) {
      notifier.setDelay(Delay(name: 'node$i', url: 'url', value: i + 1));
    }
    await tester.pump(const Duration(milliseconds: 60));
    final after = tester.widgetList<ProxyCard>(find.byType(ProxyCard)).toList();
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(identical(before[i], after[i]), isTrue);
    }

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(tester.widgetList<ProxyCard>(find.byType(ProxyCard)).length,
        inInclusiveRange(1, 100));
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();

    // The real header control updates the saved per-profile expansion set.
    final buttons = find.descendant(
        of: find.byType(ProxyGroupCard).first,
        matching: find.byType(IconButton));
    await tester.tap(buttons.last);
    await tester.pumpAndSettle();
    expect(testRef.read(unfoldSetProvider), {'B'});
    expect(
        tester
            .widgetList<ProxyCard>(find.byType(ProxyCard))
            .where((p) => p.groupName == 'A'),
        isEmpty);
    globalState.appController.updateCurrentUnfoldSet({'A', 'B'});
    testRef.read(proxiesQueryProvider.notifier).value = 'node4999';
    await tester.pumpAndSettle();
    expect(tester.widgetList<ProxyCard>(find.byType(ProxyCard)).length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'delay button rejects repeat presses until completion and unlocks after failure',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DelayTestButton(onClick: () {
      calls++;
      return calls == 1 ? pending.future : Future<void>.value();
    }))));
    final run = tester
        .widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .onPressed! as Future<void> Function();
    final first = run();
    final failed = expectLater(first, throwsStateError);
    await tester.pump(const Duration(milliseconds: 250));
    await run();
    expect(calls, 1);
    pending.completeError(StateError('test failure'));
    await failed;
    await tester.pumpAndSettle();
    await run();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
