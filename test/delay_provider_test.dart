import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';

import 'performance_test_support.dart';

void main() {
  testWidgets('1000 delay events publish one immutable snapshot',
      (tester) async {
    initializePerformanceState(delays: {
      'url': {'old': 12},
      'untouched': {'a': 9}
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final changes = <DelayMap>[];
    container.listen(delayDataSourceProvider, (_, next) => changes.add(next));
    final before = container.read(delayDataSourceProvider);
    final notifier = container.read(delayDataSourceProvider.notifier);
    for (var i = 0; i < 1000; i++) {
      notifier.setDelay(Delay(name: 'p$i', url: 'url', value: i + 1));
    }
    expect(changes, isEmpty);
    await tester.pump(const Duration(milliseconds: 50));
    expect(changes, hasLength(1));
    final after = changes.single;
    expect(after['url'], hasLength(1001));
    expect(before['url'], {'old': 12});
    expect(identical(before['url'], after['url']), isFalse);
    expect(identical(before['untouched'], after['untouched']), isTrue);
    expect(globalState.appState.delayMap, after);
  });

  testWidgets('duplicates and loading-to-same-value do not publish',
      (tester) async {
    initializePerformanceState(delays: {
      'url': {'a': 12}
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var changes = 0;
    container.listen(delayDataSourceProvider, (_, __) => changes++);
    container.read(delayDataSourceProvider.notifier)
      ..setDelay(const Delay(name: 'a', url: 'url', value: 12))
      ..setDelay(const Delay(name: 'a', url: 'url', value: 0))
      ..setDelay(const Delay(name: 'a', url: 'url', value: 12));
    await tester.pump(const Duration(milliseconds: 50));
    expect(changes, 0);
  });

  testWidgets('scalar selectors notify only the changed proxy', (tester) async {
    initializePerformanceState(delays: {
      'url': {'a': 10, 'b': 20}
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var aChanges = 0;
    var bChanges = 0;
    container
      ..listen(delayDataSourceProvider.select((m) => m['url']?['a']),
          (_, __) => aChanges++)
      ..listen(delayDataSourceProvider.select((m) => m['url']?['b']),
          (_, __) => bChanges++)
      ..read(delayDataSourceProvider.notifier)
          .setDelay(const Delay(name: 'a', url: 'url', value: 15));
    await tester.pump(const Duration(milliseconds: 50));
    expect(aChanges, 1);
    expect(bChanges, 0);
  });

  testWidgets('pending events survive no listeners and clear cancels them',
      (tester) async {
    initializePerformanceState();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(delayDataSourceProvider.notifier)
        .setDelay(const Delay(name: 'a', url: 'url', value: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(globalState.appState.delayMap['url']?['a'], 1);
    container.read(delayDataSourceProvider.notifier)
      ..setDelay(const Delay(name: 'stale', url: 'url', value: 99))
      ..clear();
    await tester.pump(const Duration(milliseconds: 100));
    expect(globalState.appState.delayMap, isEmpty);
  });

  test(
      'identical group polls do not notify and unchanged groups retain identity',
      () {
    const a = Group(name: 'a', type: GroupType.Selector, now: 'p');
    const b = Group(name: 'b', type: GroupType.Selector, now: 'q');
    initializePerformanceState(groups: [a, b]);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var changes = 0;
    container.listen(groupsProvider, (_, __) => changes++);
    final notifier = container.read(groupsProvider.notifier);
    expect(notifier.setGroups([a.copyWith(), b.copyWith()]), isFalse);
    expect(changes, 0);
    expect(
        notifier.setGroups([a.copyWith(now: 'other'), b.copyWith()]), isTrue);
    expect(changes, 1);
    expect(identical(container.read(groupsProvider)[1], b), isTrue);
    expect(globalState.appState.groups.first.now, 'other');
  });
}
