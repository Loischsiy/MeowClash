import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/views/connection/requests.dart';
import 'package:meowclash/views/logs.dart';

import 'connections_logs_test_support.dart';
import 'settings_test_support.dart';

/// Open Logs / Requests pages follow their buffer through the version select:
/// new core events show up after the throttle, and so do the events of a
/// buffer replaced by a profile switch.
const _size = Size(400, 900);

const _platforms = TargetPlatformVariant(
  {TargetPlatform.android, TargetPlatform.macOS},
);

Finder _log(int i) => find.textContaining('192.168.1.2:${50000 + i} ');

Connection _request(int i) {
  final connection = sampleConnection(i);
  return connection.copyWith(
    metadata: connection.metadata.copyWith(host: 'live-$i.example'),
  );
}

Finder _requestRow(int i) => find.textContaining('live-$i.example');

ProviderContainer _container(WidgetTester tester, Type page) =>
    ProviderScope.containerOf(tester.element(find.byType(page)));

/// Draws only the frames the app asked for, like an otherwise idle screen.
Future<void> _pumpScheduledFrames(WidgetTester tester) async {
  for (var i = 0; i < 20 && tester.binding.hasScheduledFrame; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The event's own frame (Riverpod) is drawn at once; the page throttle fires
/// later on an idle screen. The page applies the update in a post-frame
/// callback, so it must ask for that frame itself.
Future<void> _pumpThrottled(WidgetTester tester) async {
  await _pumpScheduledFrames(tester);
  await tester.binding
      .delayed(commonDuration + const Duration(milliseconds: 50));
  await _pumpScheduledFrames(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('event_buffer_live_update'));

  testWidgets('logs page shows new logs and a replaced buffer',
      (tester) async {
    await setUpStreamScreen(tester, _size,
        page: PageLabel.logs, logs: sampleLogs(3));
    await tester
        .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
    await pumpSettingsFrames(tester);
    expect(_log(2), findsOneWidget);

    final notifier = _container(tester, LogsView).read(logsProvider.notifier)
      ..addLog(sampleLog(100));
    await _pumpThrottled(tester);
    expect(_log(100), findsOneWidget);

    // Profile switch: a new buffer that sees as many adds as the old one
    // (one), so a per-buffer counter would repeat the shown version.
    notifier
      ..value = createEventBuffer()
      ..addLog(sampleLog(200));
    await _pumpThrottled(tester);
    expect(tester.takeException(), isNull);
    expect(_log(200), findsOneWidget);
    expect(_log(100), findsNothing);
    expect(_log(2), findsNothing);

    // Stop timers before the test ends.
    await tester.pumpWidget(const SizedBox());
  }, variant: _platforms);

  testWidgets('requests page shows new requests and a replaced buffer',
      (tester) async {
    await setUpStreamScreen(tester, _size,
        page: PageLabel.requests, requests: [_request(1), _request(2)]);
    await tester.pumpWidget(
        streamHost(Brightness.light, 'Requests', const RequestsView()));
    await pumpSettingsFrames(tester);
    expect(_requestRow(2), findsOneWidget);

    final notifier = _container(tester, RequestsView)
        .read(requestsProvider.notifier)
      ..addRequest(_request(100));
    await _pumpThrottled(tester);
    expect(_requestRow(100), findsOneWidget);

    notifier
      ..value = createEventBuffer()
      ..addRequest(_request(200));
    await _pumpThrottled(tester);
    expect(tester.takeException(), isNull);
    expect(_requestRow(200), findsOneWidget);
    expect(_requestRow(100), findsNothing);
    expect(_requestRow(2), findsNothing);

    await tester.pumpWidget(const SizedBox());
  }, variant: _platforms);
}
