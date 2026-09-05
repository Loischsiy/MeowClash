import 'package:meowclash/common/string.dart';
import 'package:meowclash/models/app.dart';
import 'package:meowclash/models/common.dart';
import 'package:meowclash/models/profile.dart';
import 'package:meowclash/models/selector.dart';
import 'package:meowclash/services/delay_test_runner.dart';

ProxyCardState resolveProxyCardState(
  Map<String, Group> groups,
  SelectedMap selectedMap,
  String proxyName,
) {
  var name = proxyName;
  String? testUrl;
  final seen = <String>{};
  while (name.isNotEmpty && seen.add(name)) {
    final group = groups[name];
    if (group == null) break;
    final selected = group.getCurrentSelectedName(selectedMap[name] ?? '');
    if (selected.isEmpty) break;
    name = selected;
    testUrl = group.testUrl;
  }
  return ProxyCardState(proxyName: name, testUrl: testUrl);
}

/// Immutable input snapshot: sorting/testing must not create thousands of
/// Riverpod family providers for proxies that are not even visible.
class ProxyDelaySnapshot {
  ProxyDelaySnapshot({
    required this.groups,
    required this.selectedMap,
    required this.delays,
    required this.defaultTestUrl,
  });

  final Map<String, Group> groups;
  final SelectedMap selectedMap;
  final DelayMap delays;
  final String defaultTestUrl;
  final _resolved = <String, ProxyCardState>{};

  DelayTestTarget target(String proxyName, [String? testUrl]) {
    final state = _resolved.putIfAbsent(
      proxyName,
      () => resolveProxyCardState(groups, selectedMap, proxyName),
    );
    return (
      name: state.proxyName,
      url: state.testUrl.getSafeValue(testUrl.getSafeValue(defaultTestUrl)),
    );
  }

  Iterable<DelayTestTarget> targetsForGroups(Iterable<Group> input) sync* {
    for (final group in input) {
      for (final proxy in group.all) {
        yield target(proxy.name, group.testUrl);
      }
    }
  }

  int? delay(String proxyName, [String? testUrl]) {
    final resolved = target(proxyName, testUrl);
    return delays[resolved.url]?[resolved.name];
  }

  List<Proxy> sort(List<Proxy> proxies, [String? testUrl]) {
    final ranked = [
      for (var i = 0; i < proxies.length; i++)
        (proxy: proxies[i], index: i, delay: delay(proxies[i].name, testUrl)),
    ]..sort((a, b) {
        final comparison = compareProxyDelays(a.delay, b.delay);
        return comparison != 0 ? comparison : a.index.compareTo(b.index);
      });
    return ranked.map((item) => item.proxy).toList();
  }
}

/// Unknown, pending and timed-out nodes all follow successful tests. Returning
/// zero for ties also makes the comparator antisymmetric (unlike -1 vs -1).
int compareProxyDelays(int? a, int? b) {
  final aValid = a != null && a > 0;
  final bValid = b != null && b > 0;
  if (aValid != bValid) return aValid ? -1 : 1;
  return aValid && bValid ? a.compareTo(b) : 0;
}
