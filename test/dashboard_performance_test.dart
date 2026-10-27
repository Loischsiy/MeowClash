import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/views/dashboard/dashboard.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

import 'dashboard_test_support.dart';
import 'settings_test_support.dart';

/// The live dashboard: a traffic sample lands every second, as the core
/// sends it, and the speed chart, the traffic tiles and the start button
/// rebuild. The frame times are printed for the PR description, glass
/// against Material; they are not asserted (the test machine is not a
/// device: no raster, no GPU).

const _size = Size(1100, 800);
const _ticks = 60;

const _widgets = [
  DashboardWidget.networkSpeed,
  DashboardWidget.outboundModeV2,
  DashboardWidget.trafficUsage,
  DashboardWidget.networkDetection,
  DashboardWidget.memoryInfo,
];

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(2);

Duration _percentile(List<Duration> sorted, double p) =>
    sorted[((sorted.length - 1) * p).round()];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('meowclash_dashboard_perf'));

  testWidgets(
    'traffic once a second: frame times',
    (tester) async {
      await setUpDashboardScreen(tester, _size,
          widgets: _widgets, started: true);
      await pumpDashboard(tester, dashboardHost(Brightness.light));

      final platform = defaultTargetPlatform;
      final glass = AdaptivePlatform.useGlass;
      expect(glass, platform != TargetPlatform.android);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardView)),
      );

      final frames = <Duration>[];
      final watch = Stopwatch();
      for (var i = 0; i < _ticks; i++) {
        container
            .read(trafficsProvider.notifier)
            .addTraffic(sampleTraffic(30 + i));
        watch
          ..reset()
          ..start();
        await tester.pump(const Duration(seconds: 1));
        watch.stop();
        frames.add(watch.elapsed);
      }
      expect(tester.takeException(), isNull);

      final sorted = [...frames]..sort();
      final total = frames.fold(Duration.zero, (a, b) => a + b);
      // ignore: avoid_print
      print(
        'dashboard perf [${glass ? 'glass ${platform.name}' : 'material'}] '
        '$_ticks traffic ticks: '
        'mean ${_ms(total ~/ frames.length)} ms, '
        'p50 ${_ms(_percentile(sorted, .5))} ms, '
        'p90 ${_ms(_percentile(sorted, .9))} ms, '
        'max ${_ms(sorted.last)} ms',
      );
      await tearDownDashboard(tester);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
