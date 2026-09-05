import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/delay_test_runner.dart';
import 'package:meowclash/state.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + measure.labelSmallHeight + 6,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
    ProxyCardType.oneline => 16 + measure.bodyMediumHeight + 4,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final appController = globalState.appController;
  final snapshot = appController.getProxyDelaySnapshot();
  await appController.delayTests.test(snapshot.target(proxy.name, testUrl));
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) {
  final snapshot = globalState.appController.getProxyDelaySnapshot();
  return _runDelayTargets(
      proxies.map((proxy) => snapshot.target(proxy.name, testUrl)));
}

Future<void> delayTestGroups(Iterable<Group> groups) {
  final snapshot = globalState.appController.getProxyDelaySnapshot();
  return _runDelayTargets(snapshot.targetsForGroups(groups));
}

Future<void> _runDelayTargets(Iterable<DelayTestTarget> targets) async {
  final appController = globalState.appController;
  final runner = appController.delayTests;
  final generation = runner.generation;
  await runner.testAll(targets);
  if (generation != runner.generation || !appController.context.mounted) return;
  appController
    ..flushDelays()
    ..addSortNum()
    ..updateGroupsDebounce();
}

double getScrollToSelectedOffset({
  required String groupName,
  required List<Proxy> proxies,
}) {
  final appController = globalState.appController;
  final columns = appController.getProxiesColumns();
  final proxyCardType = globalState.config.proxiesStyle.cardType;
  final selectedProxyName = appController.getSelectedProxyName(groupName);
  final findSelectedIndex = proxies.indexWhere(
    (proxy) => proxy.name == selectedProxyName,
  );
  final selectedIndex = findSelectedIndex != -1 ? findSelectedIndex : 0;
  final rows = (selectedIndex / columns).floor();
  return rows * getItemHeight(proxyCardType) + (rows - 1) * 8;
}
