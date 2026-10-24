import 'package:flutter/material.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/delay_test_runner.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight;
}

/// Line heights of a proxy card: name, description and delay badge.
///
/// Material measures `bodyMedium` / `bodySmall` / `labelSmall`; Darwin glass
/// measures the Apple type scale of [GlassTextStyles].
({double title, double desc, double delay}) get proxyCardLineHeights {
  final measure = globalState.measure;
  if (!AdaptivePlatform.useGlass) {
    return (
      title: measure.bodyMediumHeight,
      desc: measure.bodySmallHeight,
      delay: measure.labelSmallHeight,
    );
  }
  final textTheme = Theme.of(measure.context).textTheme;
  return (
    title: measure.heightOf(GlassTextStyles.cardTitle(textTheme)),
    desc: measure.heightOf(GlassTextStyles.cardSubtitle(textTheme)),
    delay: measure.heightOf(GlassTextStyles.delayBadge(textTheme)),
  );
}

double getItemHeight(ProxyCardType proxyCardType) {
  final lines = proxyCardLineHeights;
  final baseHeight = 16 + lines.title * 2 + lines.desc + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + lines.delay + 6,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - lines.title,
    ProxyCardType.oneline => 16 + lines.title + 4,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final appController = globalState.appController;
  final snapshot = appController.getProxyDelaySnapshot();
  appController.applyDelayTestConcurrency();
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
  final runner = appController.delayTests
    ..concurrency = appController.delayTestConcurrency;
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
