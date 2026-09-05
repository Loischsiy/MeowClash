import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/clash/proxy_groups.dart';
import 'package:meowclash/common/proxy_delay.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';

const node = Proxy(name: 'leaf', type: 'Shadowsocks');
void main() {
  test('resolves nested groups, computed selection, URL and cycles', () {
    final snapshot = ProxyDelaySnapshot(
      groups: {
        'outer':
            const Group(name: 'outer', type: GroupType.Selector, now: 'wrong'),
        'auto': const Group(
            name: 'auto',
            type: GroupType.URLTest,
            now: 'leaf',
            testUrl: 'https://inner/204'),
        'cycle':
            const Group(name: 'cycle', type: GroupType.Selector, now: 'cycle'),
      },
      selectedMap: {'outer': 'auto', 'auto': 'ignored'},
      delays: {},
      defaultTestUrl: 'https://default/204',
    );
    expect(snapshot.target('outer'), (name: 'leaf', url: 'https://inner/204'));
    expect(snapshot.target('cycle').name, 'cycle');
    expect(snapshot.target('leaf', 'https://custom/204').url,
        'https://custom/204');
    expect(snapshot.target('leaf').url, 'https://default/204');
  });

  test('all-group targets preserve distinct test URLs for a shared node', () {
    final snapshot = ProxyDelaySnapshot(
        groups: {}, selectedMap: {}, delays: {}, defaultTestUrl: 'default');
    final groups = [
      const Group(
          name: 'a', type: GroupType.Selector, all: [node], testUrl: 'a-url'),
      const Group(
          name: 'b', type: GroupType.Selector, all: [node], testUrl: 'b-url'),
    ];
    expect(snapshot.targetsForGroups(groups).toList(),
        [(name: 'leaf', url: 'a-url'), (name: 'leaf', url: 'b-url')]);
  });

  test('delay sort is stable, handles failures and does not change input', () {
    final names = ['timeout', 'slow', 'fast', 'equal', 'pending', 'unknown'];
    final proxies = names.map((n) => Proxy(name: n, type: 'Direct')).toList();
    final snapshot = ProxyDelaySnapshot(
        groups: {},
        selectedMap: {},
        defaultTestUrl: 'url',
        delays: {
          'url': {
            'timeout': -1,
            'slow': 80,
            'fast': 10,
            'equal': 10,
            'pending': 0
          },
        });
    expect(snapshot.sort(proxies).map((p) => p.name),
        ['fast', 'equal', 'slow', 'timeout', 'pending', 'unknown']);
    expect(proxies.map((p) => p.name), names);
    for (final a in <int?>[null, -1, 0, 1, 20]) {
      for (final b in <int?>[null, -1, 0, 1, 20]) {
        expect(compareProxyDelays(a, b).sign, -compareProxyDelays(b, a).sign);
      }
    }
  });

  test('group parsing shares proxy instances and keeps drilldown groups',
      () async {
    final raw = <String, dynamic>{
      'GLOBAL': {
        'name': 'GLOBAL',
        'type': 'Selector',
        'all': ['A', 'leaf']
      },
      'A': {
        'name': 'A',
        'type': 'Selector',
        'all': ['leaf', 'missing'],
        'testUrl': 'https://custom/204'
      },
      'Hidden': {
        'name': 'Hidden',
        'type': 'URLTest',
        'all': ['leaf'],
        'hidden': true
      },
      'Nested': {
        'name': 'Nested',
        'type': 'Fallback',
        'all': ['leaf']
      },
      'leaf': {
        'name': 'leaf',
        'type': 'Shadowsocks',
        'serverDescription': 'custom info'
      },
    };
    final groups = await compute(parseProxyGroups, raw);
    expect(groups.map((g) => g.name), ['GLOBAL', 'A', 'Hidden', 'Nested']);
    expect(groups.take(2).every((g) => g.hidden == false), isTrue);
    expect(groups.skip(2).every((g) => g.hidden == true), isTrue);
    expect(groups[1].all, hasLength(1));
    expect(identical(groups[1].all.single, groups[2].all.single), isTrue);
    expect(groups[1].all.single.serverDescription, 'custom info');
    expect(raw['A']['all'], ['leaf', 'missing']);
  });

  test('group parsing handles empty or missing GLOBAL safely', () {
    expect(parseProxyGroups({}), isEmpty);
    final groups = parseProxyGroups({
      'A': {'name': 'A', 'type': 'Selector', 'all': []}
    });
    expect(groups.single.name, 'A');
    expect(groups.single.hidden, isTrue);
  });
}
