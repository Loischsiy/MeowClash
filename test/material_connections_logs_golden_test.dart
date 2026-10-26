import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/views/connection/connections.dart';
import 'package:meowclash/views/connection/requests.dart';
import 'package:meowclash/views/logs.dart';

import 'connections_logs_test_support.dart';
import 'settings_test_support.dart';

/// Pixel baseline of the Material Requests, Connections and Logs pages (with
/// data, empty, loading, keyword filter chips) that Android, Linux and
/// Windows must keep after the Darwin glass work. Generated on `main` before
/// the glass connections and logs landed. Regenerate only for an intended
/// Material change:
/// `flutter test --update-goldens test/material_connections_logs_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 900);

  setUpAll(() => setUpSettingsEnvironment('material_connections_logs'));

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  Future<void> golden(WidgetTester tester, String name, Brightness b) =>
      expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/material_connections_logs_${name}_${b.name}.png',
        ),
      );

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('requests, $b', (tester) async {
      await setUpStreamScreen(tester, size,
          page: PageLabel.requests, requests: sampleConnections(20));
      await tester.pumpWidget(
          streamHost(brightness, 'Requests', const RequestsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      await golden(tester, 'requests', brightness);
    }, variant: android);

    testWidgets('requests empty, $b', (tester) async {
      await setUpStreamScreen(tester, size, page: PageLabel.requests);
      await tester.pumpWidget(
          streamHost(brightness, 'Requests', const RequestsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      await golden(tester, 'requests_empty', brightness);
    }, variant: android);

    for (final count in [10, 0]) {
      final name = count == 0 ? 'connections_empty' : 'connections';
      testWidgets('$name, $b', (tester) async {
        await setUpStreamScreen(tester, size, page: PageLabel.connections);
        await tester.pumpWidget(streamHost(
          brightness,
          'Connections',
          ConnectionsView(
            loadConnections: () async => sampleConnections(count),
          ),
        ));
        await pumpSettingsFrames(tester);
        expect(tester.takeException(), isNull);
        await golden(tester, name, brightness);
        // Stop the 1 s polling loop before the test ends.
        await tester.pumpWidget(const SizedBox());
      }, variant: android);
    }

    testWidgets('logs, $b', (tester) async {
      await setUpStreamScreen(tester, size,
          page: PageLabel.logs, logs: sampleLogs(20));
      await tester.pumpWidget(streamHost(brightness, 'Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      await golden(tester, 'logs', brightness);
    }, variant: android);

    testWidgets('logs loading, $b', (tester) async {
      await setUpStreamScreen(tester, size,
          page: PageLabel.logs, logs: sampleLogs(20));
      await tester.pumpWidget(streamHost(brightness, 'Logs', const LogsView()));
      expect(tester.takeException(), isNull);
      await golden(tester, 'logs_loading', brightness);
      await pumpSettingsFrames(tester);
    }, variant: android);

    testWidgets('logs empty, $b', (tester) async {
      await setUpStreamScreen(tester, size, page: PageLabel.logs);
      await tester.pumpWidget(streamHost(brightness, 'Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      await golden(tester, 'logs_empty', brightness);
    }, variant: android);

    testWidgets('logs keyword filters, $b', (tester) async {
      await setUpStreamScreen(tester, size,
          page: PageLabel.logs, logs: sampleLogs(20));
      await tester.pumpWidget(streamHost(brightness, 'Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      // Log keywords are level names, matched with AND: one chip keeps rows.
      scaffoldStateOf(tester).addKeyword('info');
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      await golden(tester, 'logs_filters', brightness);
    }, variant: android);
  }
}
