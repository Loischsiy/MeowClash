import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/views/connection/requests.dart';
import 'package:meowclash/views/logs.dart';

import 'connections_logs_test_support.dart';
import 'dashboard_test_support.dart';
import 'settings_test_support.dart';

/// Every [TextPainter] owns a native `ui.Paragraph`. One that is never
/// disposed keeps it until a GC finalizer runs, so measuring code must
/// dispose its painters. Debug builds report painter creation and disposal
/// through [FlutterMemoryAllocations]; these tests count the painters that
/// are still alive once the measured screen is gone.

class _PainterCount {
  int created = 0;
  final Set<Object> _live = Set.identity();

  int get leaked => _live.length;

  void _onEvent(ObjectEvent event) {
    if (event.object is! TextPainter) return;
    if (event is ObjectCreated) {
      created++;
      _live.add(event.object);
    } else if (event is ObjectDisposed) {
      _live.remove(event.object);
    }
  }

  @override
  String toString() => 'created $created, not disposed $leaked';
}

Future<_PainterCount> _countPainters(Future<void> Function() body) async {
  final count = _PainterCount();
  FlutterMemoryAllocations.instance.addListener(count._onEvent);
  try {
    await body();
  } finally {
    FlutterMemoryAllocations.instance.removeListener(count._onEvent);
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('text_painter_dispose'));

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('Measure.computeTextSize disposes its painter', (tester) async {
    late Measure measure;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        measure = Measure.of(context, 1);
        return const SizedBox();
      }),
    ));
    const text = Text(
      'a log line that is long enough to wrap',
      style: TextStyle(fontSize: 14),
    );
    late Size size;
    final count = await _countPainters(() async {
      size = measure.computeTextSize(text, maxWidth: 120);
    });
    expect(count.created, 1);
    expect(count.leaked, 0);

    final reference = TextPainter(
      text: TextSpan(text: text.data, style: text.style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    addTearDown(reference.dispose);
    expect(size, reference.size);
  });

  testWidgets('Logs page leaves no painter behind', (tester) async {
    final count = await _countPainters(() async {
      await setUpStreamScreen(tester, const Size(400, 900),
          page: PageLabel.logs, logs: sampleLogs(maxLength));
      await tester
          .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    debugPrint('[text painters] Logs, $maxLength rows: $count');
    expect(count.created, greaterThan(0));
    expect(count.leaked, 0);
  }, variant: android);

  testWidgets('Requests page leaves no painter behind', (tester) async {
    final count = await _countPainters(() async {
      await setUpStreamScreen(tester, const Size(400, 900),
          page: PageLabel.requests,
          requests: List.generate(maxLength, sampleConnection));
      await tester.pumpWidget(
          streamHost(Brightness.light, 'Requests', const RequestsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      // Stops the 1 s polling loop too.
      await tester.pumpWidget(const SizedBox());
    });
    debugPrint('[text painters] Requests, $maxLength rows: $count');
    expect(count.created, greaterThan(0));
    expect(count.leaked, 0);
  }, variant: android);

  testWidgets('idle start button leaves no painter behind', (tester) async {
    await setUpDashboardScreen(tester, const Size(1100, 800));
    final count = await _countPainters(() async {
      await pumpDashboard(tester, dashboardHost(Brightness.light));
      // One more second of the sleeping cat ("z" drawn every frame).
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tearDownDashboard(tester);
    });
    debugPrint('[text painters] dashboard, idle cat ~2 s: $count');
    expect(count.created, greaterThan(0));
    expect(count.leaked, 0);
  }, variant: android);
}
