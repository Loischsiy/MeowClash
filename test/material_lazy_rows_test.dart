import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/views/connection/item.dart';
import 'package:meowclash/views/connection/requests.dart';
import 'package:meowclash/views/logs.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'connections_logs_test_support.dart';
import 'settings_test_support.dart';

/// The Material Logs and Requests lists build their rows by index (even =
/// row, odd = divider) instead of building every row up front. Each index
/// must still give the row, key, extent and height-cache key of the eager
/// list, and row chips must still reach the scaffold. The last test prints
/// the wall time of page updates on a full buffer (not asserted) and the
/// rows the list keeps mounted.
const _size = Size(400, 900);
const _updates = 60;

final _android = TargetPlatformVariant.only(TargetPlatform.android);

CacheItemExtentListView _list(WidgetTester tester) =>
    tester.widget(find.byType(CacheItemExtentListView));

BuildContext _listContext(WidgetTester tester) =>
    tester.element(find.byType(CacheItemExtentListView));

/// Every row of the list (not only the mounted ones), through its builder.
List<T> _rows<T extends Widget>(WidgetTester tester) {
  final list = _list(tester);
  final context = _listContext(tester);
  return [
    for (var i = 0; i < list.itemCount; i += 2)
      list.itemBuilder(context, i)! as T,
  ];
}

void _expectDivider(CacheItemExtentListView list, BuildContext context, int i) {
  expect(
    list.itemBuilder(context, i),
    isA<Divider>().having((d) => d.height, 'height', 0),
  );
  expect(list.keyBuilder(i), 'divider');
  expect(list.itemExtentBuilder(i), 0);
}

/// The first on-screen chip inside a row of type [T], and that row.
(Finder, T) _visibleChip<T extends Widget>(WidgetTester tester) {
  final chip = find
      .descendant(of: find.byType(T), matching: find.byType(CommonChip))
      .hitTestable()
      .first;
  final row = tester.widget<T>(
    find.ancestor(of: chip, matching: find.byType(T)),
  );
  return (chip, row);
}

/// Wall time of one page update: the throttle fires, a post-frame callback
/// hands the new snapshot to the page, and the list rebuilds. Which of the
/// frames rebuilds depends on what else scheduled one, so all are timed.
Future<Duration> _timedUpdate(WidgetTester tester) async {
  final watch = Stopwatch()..start();
  await tester.pump(commonDuration + const Duration(milliseconds: 50));
  tester.binding.scheduleFrame();
  await tester.pump();
  await tester.pump();
  watch.stop();
  return watch.elapsed;
}

String _summary(List<Duration> frames) {
  String ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(2);
  final sorted = [...frames]..sort();
  final total = frames.fold(Duration.zero, (a, b) => a + b);
  return 'mean ${ms(total ~/ frames.length)} ms, '
      'p50 ${ms(sorted[(sorted.length - 1) ~/ 2])} ms, '
      'p90 ${ms(sorted[((sorted.length - 1) * .9).round()])} ms';
}

ProviderContainer _container(WidgetTester tester, Type page) =>
    ProviderScope.containerOf(tester.element(find.byType(page)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('material_lazy_rows'));

  testWidgets('logs: every index gives its row or a divider', (tester) async {
    final logs = sampleLogs(maxLength);
    await setUpStreamScreen(tester, _size, page: PageLabel.logs, logs: logs);
    await tester
        .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
    await pumpSettingsFrames(tester);
    expect(tester.takeException(), isNull);

    final list = _list(tester);
    final context = _listContext(tester);
    expect(list.itemCount, logs.length * 2 - 1);
    for (var i = 0; i < list.itemCount; i++) {
      if (i.isOdd) {
        _expectDivider(list, context, i);
        continue;
      }
      final log = logs[i ~/ 2];
      expect(
        list.itemBuilder(context, i),
        isA<LogItem>()
            .having((w) => w.log, 'log', log)
            .having((w) => w.key, 'key', Key(log.dateTime)),
      );
      expect(list.keyBuilder(i), log.payload);
      expect(list.itemExtentBuilder(i), greaterThan(0));
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: _android);

  testWidgets('logs: a row level chip filters the page', (tester) async {
    await setUpStreamScreen(tester, _size,
        page: PageLabel.logs, logs: sampleLogs(20));
    await tester
        .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
    await pumpSettingsFrames(tester);
    Set<LogLevel> levels() =>
        _rows<LogItem>(tester).map((w) => w.log.logLevel).toSet();
    expect(levels().length, greaterThan(1));

    final (chip, row) = _visibleChip<LogItem>(tester);
    await tester.tap(chip);
    await pumpSettingsFrames(tester);
    expect(tester.takeException(), isNull);
    expect(levels(), {row.log.logLevel});
    await tester.pumpWidget(const SizedBox());
  }, variant: _android);

  testWidgets('requests: every index gives its row or a divider',
      (tester) async {
    final requests = sampleConnections(maxLength);
    await setUpStreamScreen(tester, _size,
        page: PageLabel.requests, requests: requests);
    await tester.pumpWidget(
        streamHost(Brightness.light, 'Requests', const RequestsView()));
    await pumpSettingsFrames(tester);
    expect(tester.takeException(), isNull);

    final list = _list(tester);
    final context = _listContext(tester);
    expect(list.itemCount, requests.length * 2 - 1);
    for (var i = 0; i < list.itemCount; i++) {
      if (i.isOdd) {
        _expectDivider(list, context, i);
        continue;
      }
      final request = requests[i ~/ 2];
      expect(
        list.itemBuilder(context, i),
        isA<ConnectionItem>()
            .having((w) => w.connection, 'connection', request)
            .having((w) => w.key, 'key', Key(request.id)),
      );
      expect(list.keyBuilder(i), request.id);
      expect(list.itemExtentBuilder(i), greaterThan(0));
    }
    // Stops the 1 s polling loop too.
    await tester.pumpWidget(const SizedBox());
  }, variant: _android);

  testWidgets('requests: a row chain chip filters the page', (tester) async {
    await setUpStreamScreen(tester, _size,
        page: PageLabel.requests, requests: sampleConnections(20));
    await tester.pumpWidget(
        streamHost(Brightness.light, 'Requests', const RequestsView()));
    await pumpSettingsFrames(tester);
    final before = _rows<ConnectionItem>(tester).length;
    expect(before, 20);

    final (chip, _) = _visibleChip<ConnectionItem>(tester);
    final chain = tester.widget<CommonChip>(chip).label;
    await tester.tap(chip);
    await pumpSettingsFrames(tester);
    expect(tester.takeException(), isNull);
    final after = _rows<ConnectionItem>(tester);
    expect(after, isNotEmpty);
    expect(after.length, lessThan(before));
    for (final row in after) {
      expect(row.connection.chains, contains(chain));
    }
    await tester.pumpWidget(const SizedBox());
  }, variant: _android);

  testWidgets('page updates on a full buffer: times and mounted rows',
      (tester) async {
    await setUpStreamScreen(tester, _size,
        page: PageLabel.logs, logs: sampleLogs(maxLength));
    await tester
        .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
    await pumpSettingsFrames(tester);
    final logs = _container(tester, LogsView).read(logsProvider.notifier);
    final logFrames = <Duration>[];
    for (var k = 0; k < _updates; k++) {
      logs.addLog(sampleLog(1000 + k));
      logFrames.add(await _timedUpdate(tester));
    }
    expect(tester.takeException(), isNull);
    // The page shows the last snapshot: the newest log is the last row.
    final list = _list(tester);
    expect(
      list.itemBuilder(_listContext(tester), list.itemCount - 1),
      isA<LogItem>()
          .having((w) => w.log, 'log', sampleLog(1000 + _updates - 1)),
    );
    // Rows the list keeps built, cache extent included; a lazy list builds
    // only these per update.
    final mountedLogs =
        find.byType(LogItem, skipOffstage: false).evaluate().length;
    expect(mountedLogs, lessThan(maxLength));
    await tester.pumpWidget(const SizedBox());

    await setUpStreamScreen(tester, _size,
        page: PageLabel.requests, requests: sampleConnections(maxLength));
    await tester.pumpWidget(
        streamHost(Brightness.light, 'Requests', const RequestsView()));
    await pumpSettingsFrames(tester);
    final requests =
        _container(tester, RequestsView).read(requestsProvider.notifier);
    final requestFrames = <Duration>[];
    for (var k = 0; k < _updates; k++) {
      requests.addRequest(sampleConnection(1000 + k));
      requestFrames.add(await _timedUpdate(tester));
    }
    expect(tester.takeException(), isNull);
    final mountedRequests =
        find.byType(ConnectionItem, skipOffstage: false).evaluate().length;
    expect(mountedRequests, lessThan(maxLength));
    await tester.pumpWidget(const SizedBox());

    debugPrint('[lazy rows] material, $maxLength rows, $_updates updates: '
        'logs ${_summary(logFrames)}, mounted rows $mountedLogs; '
        'requests ${_summary(requestFrames)}, '
        'mounted rows $mountedRequests');
  }, variant: _android);
}
