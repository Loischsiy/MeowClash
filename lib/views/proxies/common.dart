import 'package:meow_clash/clash/clash.dart';
import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/models/models.dart';
import 'package:meow_clash/state.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight - measure.bodySmallHeight + measure.labelSmallHeight * 2 + 4,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
  };
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final appController = globalState.appController;
  final state = appController.getProxyCardState(proxy.name);
  final url = appController.getRealTestUrl(state.testUrl.getSafeValue(testUrl ?? ''));
  if (state.proxyName.isEmpty) {
    return;
  }
  // Set testing state
  appController.setDelay(Delay(url: url, name: state.proxyName, value: 0));
  // Get and set delay
  appController.setDelay(await clashCore.getDelay(url, state.proxyName));
}

bool _isNonTestableProxy(String proxyName) {
  final name = proxyName.toUpperCase();
  return name == 'REJECT' || name == 'REJECT-DROP' || name == 'PASS';
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final appController = globalState.appController;
  final proxyNames = proxies
      .map((proxy) => proxy.name)
      .where((name) => !_isNonTestableProxy(name))
      .toSet()
      .toList();
  final concurrencyLimit = globalState.config.proxiesStyle.concurrencyLimit;

  // Create lazy task
  final delayTasks = proxyNames.map((proxyName) {
    return () async {
      final state = appController.getProxyCardState(proxyName);
      final url = appController.getRealTestUrl(
        state.testUrl.getSafeValue(testUrl ?? ''),
      );
      final name = state.proxyName;
      if (name.isEmpty) {
        return;
      }
      // Set testing state
      appController.setDelay(Delay(url: url, name: name, value: 0));
      // Get and set delay
      appController.setDelay(await clashCore.getDelay(url, name));
    };
  }).toList();

  // Execute tasks in batches
  final batchedTasks = delayTasks.batch(concurrencyLimit);
  for (final batchTasks in batchedTasks) {
    await Future.wait(batchTasks.map((task) => task()));
  }
  appController.addSortNum();
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
