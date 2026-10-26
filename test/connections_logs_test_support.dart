import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'settings_test_support.dart';

/// Shared host and sample data of the Requests / Connections / Logs tests
/// (Material goldens, Darwin glass checks, performance).

const _hosts = [
  'www.apple.com',
  'api.github.com',
  'a-very-long-subdomain.cdn.example-content-delivery.network',
  'push.services.mozilla.com',
];

const _chains = [
  ['DIRECT'],
  ['HK 01', 'Proxy'],
  ['Japan Tokyo 03 | IEPL', 'Auto', 'Streaming', 'Final'],
];

/// Deterministic connection [i]; `start` stays a few hours back so
/// `lastUpdateTimeDesc` reads the same for the whole run.
Connection sampleConnection(int i) => Connection(
      id: 'c$i',
      upload: 1024 * (i + 1),
      download: 4096 * (i * i + 1),
      start: DateTime.now().subtract(Duration(hours: 2 + i % 3)),
      metadata: Metadata(
        uid: 0,
        network: i.isEven ? 'tcp' : 'udp',
        sourceIP: '192.168.1.2',
        sourcePort: '${50000 + i}',
        destinationIP: '17.253.144.${i % 250}',
        destinationPort: i.isEven ? '443' : '53',
        host: _hosts[i % _hosts.length],
        process: i % 3 == 0 ? '' : 'Safari',
        remoteDestination: '',
      ),
      chains: _chains[i % _chains.length],
    );

const _levels = [
  LogLevel.info,
  LogLevel.warning,
  LogLevel.error,
  LogLevel.debug,
  LogLevel.app,
];

Log sampleLog(int i) => Log(
      logLevel: _levels[i % _levels.length],
      payload: i % 4 == 2
          ? '[TCP] 192.168.1.2:${50000 + i} --> '
              'a-very-long-subdomain.cdn.example-content-delivery.network:443 '
              'match DomainSuffix(example-content-delivery.network) using '
              'Streaming[Japan Tokyo 03 | IEPL]'
          : '[UDP] 192.168.1.2:${50000 + i} --> 1.1.1.1:53 match Match using '
              'DIRECT',
      dateTime: '2026-10-26 18:${(i ~/ 60 % 60).toString().padLeft(2, '0')}:'
          '${(i % 60).toString().padLeft(2, '0')}.000000',
    );

List<Connection> sampleConnections(int count) =>
    List.generate(count, sampleConnection);

List<Log> sampleLogs(int count) => List.generate(count, sampleLog);

/// Per test: [setUpSettingsScreen] + the page as the current one (so
/// `PageMixin` wires actions, search and keyword filters into the scaffold),
/// fresh height / scroll caches and the given requests / logs.
Future<void> setUpStreamScreen(
  WidgetTester tester,
  Size size, {
  required PageLabel page,
  List<Connection> requests = const [],
  List<Log> logs = const [],
}) async {
  await setUpSettingsScreen(tester, size);
  globalState.cacheHeightMap = {};
  globalState.cacheScrollPosition = {};
  globalState.appState = globalState.appState.copyWith(
    pageLabel: page,
    requests: FixedList<Connection>(
      requests.length.clamp(10, 1 << 20),
      list: List.of(requests),
    ),
    logs: FixedList<Log>(logs.length.clamp(10, 1 << 20), list: List.of(logs)),
  );
}

/// The page inside a real [CommonScaffold] (toolbar, keyword chips).
Widget streamHost(Brightness brightness, String title, Widget page) =>
    settingsHost(
      brightness,
      (_) => CommonScaffold(title: title, body: page),
    );

CommonScaffoldState scaffoldStateOf(WidgetTester tester) =>
    tester.state<CommonScaffoldState>(find.byType(CommonScaffold));
