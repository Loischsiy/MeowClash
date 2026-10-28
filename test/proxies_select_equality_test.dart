import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';

import 'performance_test_support.dart';

/// Proxy pages read group names through providers. A group change that keeps
/// the names (a new selection, a delay refresh) must not recompute them.
/// Counts are printed for before/after comparison.

final _nodes = [
  const Proxy(name: 'n0', type: 'Shadowsocks'),
  const Proxy(name: 'n1', type: 'Shadowsocks'),
];

Group _group(String name, {String now = 'n0', bool hidden = false}) => Group(
      name: name,
      type: GroupType.Selector,
      hidden: hidden,
      now: now,
      testUrl: 'url',
      all: _nodes,
    );

class _Counts {
  int listBuilds = 0;
  int tabBuilds = 0;
  int listChanges = 0;
  int tabChanges = 0;
  int namesChanges = 0;
  int rawSelectChanges = 0;

  void reset() {
    listBuilds = 0;
    tabBuilds = 0;
    listChanges = 0;
    tabChanges = 0;
    namesChanges = 0;
    rawSelectChanges = 0;
  }

  @override
  String toString() => 'list builds $listBuilds, tab builds $tabBuilds, '
      'list notifications $listChanges, tab notifications $tabChanges, '
      'names notifications $namesChanges, '
      'raw toList select notifications $rawSelectChanges';
}

(ProviderContainer, _Counts) _setUp(List<Group> groups) {
  initializePerformanceState(groups: groups);
  globalState.config = globalState.config.copyWith(
    currentProfileId: 'test',
    profiles: [
      const Profile(id: 'test', autoUpdateDuration: Duration(days: 1)),
    ],
  );
  final counts = _Counts();
  final container = ProviderContainer(overrides: [
    proxiesListSelectorStateProvider.overrideWith((ref) {
      counts.listBuilds++;
      return proxiesListSelectorState(ref);
    }),
    proxiesSelectorStateProvider.overrideWith((ref) {
      counts.tabBuilds++;
      return proxiesSelectorState(ref);
    }),
  ]);
  addTearDown(container.dispose);
  container
    ..listen(proxiesListSelectorStateProvider, (_, __) => counts.listChanges++)
    ..listen(proxiesSelectorStateProvider, (_, __) => counts.tabChanges++)
    ..listen(groupNamesStateProvider, (_, __) => counts.namesChanges++)
    // The select the proxy providers and the unfold-all button used before.
    ..listen(
      currentGroupsStateProvider
          .select((state) => state.value.map((e) => e.name).toList()),
      (_, __) => counts.rawSelectChanges++,
    );
  counts.reset();
  return (container, counts);
}

/// Reads what the proxy pages read in a frame.
void _read(ProviderContainer container) {
  container
    ..read(proxiesListSelectorStateProvider)
    ..read(proxiesSelectorStateProvider)
    ..read(groupNamesStateProvider);
}

List<String> _currentNames(ProviderContainer container) => container
    .read(currentGroupsStateProvider)
    .value
    .map((e) => e.name)
    .toList();

void main() {
  test('selection changes keep group names and do not recompute them', () {
    final (container, counts) = _setUp([_group('A'), _group('B')]);
    _read(container);
    counts.reset();
    final notifier = container.read(groupsProvider.notifier);
    for (var i = 0; i < 100; i++) {
      final changed = notifier.setGroups([
        _group('A', now: i.isEven ? 'n1' : 'n0'),
        _group('B'),
      ]);
      expect(changed, isTrue);
      _read(container);
    }
    // ignore: avoid_print
    print('select equality: 100 selection changes: $counts');
    expect(counts.rawSelectChanges, 100);
    expect(counts.namesChanges, 0);
    expect(counts.listChanges, 0);
    expect(counts.tabChanges, 0);
    expect(counts.listBuilds, 0);
    expect(counts.tabBuilds, 0);
    expect(container.read(currentGroupsStateProvider).value.first.now, 'n0');
  });

  test('a name change recomputes and notifies once', () {
    final (container, counts) = _setUp([_group('A'), _group('B')]);
    _read(container);
    counts.reset();
    container
        .read(groupsProvider.notifier)
        .setGroups([_group('A'), _group('B'), _group('C')]);
    _read(container);
    // ignore: avoid_print
    print('select equality: 1 added group: $counts');
    expect(counts.namesChanges, 1);
    expect(counts.listChanges, 1);
    expect(counts.tabChanges, 1);
    expect(counts.listBuilds, 1);
    expect(counts.tabBuilds, 1);
    expect(
      container.read(proxiesListSelectorStateProvider).groupNames,
      ['A', 'B', 'C'],
    );
    expect(
      container.read(proxiesSelectorStateProvider).groupNames,
      ['A', 'B', 'C'],
    );
  });

  test('names follow mode, hidden groups and order (behavior kept)', () {
    final (container, _) = _setUp([
      _group('B'),
      _group(GroupName.GLOBAL.name),
      _group('A'),
      _group('H', hidden: true),
    ]);
    void expectNames(List<String> names) {
      expect(_currentNames(container), names);
      expect(container.read(groupNamesStateProvider).groupNames, names);
      expect(
        container.read(proxiesListSelectorStateProvider).groupNames,
        names,
      );
      expect(container.read(proxiesSelectorStateProvider).groupNames, names);
    }

    final config = container.read(patchClashConfigProvider.notifier)
      ..updateState((state) => state.copyWith(mode: Mode.rule));
    expectNames(['B', 'A']);
    config.updateState((state) => state.copyWith(mode: Mode.global));
    expectNames(['B', GroupName.GLOBAL.name, 'A']);
    container.read(groupsProvider.notifier).setGroups([
      _group('A'),
      _group(GroupName.GLOBAL.name),
      _group('B', now: 'n1'),
    ]);
    expectNames(['A', GroupName.GLOBAL.name, 'B']);
    config.updateState((state) => state.copyWith(mode: Mode.direct));
    expectNames([]);
  });
}
