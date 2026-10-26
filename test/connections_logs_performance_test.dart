import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/views/logs.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

import 'connections_logs_test_support.dart';
import 'settings_test_support.dart';

/// 1000 logs: only the rows of the viewport are mounted (before and after
/// scrolling), on the Darwin glass list and on the Material one. The frame
/// times of a scripted scroll are printed for the PR description; they are
/// not asserted (the test machine is not a device: no raster, no GPU).

const _size = Size(400, 900);
const _logs = 1000;
const _frames = 120;

/// The list's own scroll view: the logs list is reversed (newest at the
/// bottom), and every [SelectableText] of a row has a Scrollable too.
final _reverseList = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.up,
);

/// One finder for both looks: glass rows are [GlassStreamRow]s, Material rows
/// are [LogItem]s.
final _rows = find.byWidgetPredicate(
  (w) => w is GlassStreamRow || w is LogItem,
);

int _mountedRows() => _rows.evaluate().length;

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(2);

Duration _percentile(List<Duration> sorted, double p) =>
    sorted[((sorted.length - 1) * p).round()];

void main() {
  testWidgets(
    '$_logs logs: only viewport rows are mounted, scroll frame times',
    (tester) async {
      await setUpStreamScreen(
        tester,
        _size,
        page: PageLabel.logs,
        logs: sampleLogs(_logs),
      );
      await tester.pumpWidget(
        streamHost(Brightness.light, 'Logs', const LogsView()),
      );
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);

      final platform = defaultTargetPlatform;
      final glass = AdaptivePlatform.useGlass;
      expect(glass, platform != TargetPlatform.android);
      final mounted = <int>[_mountedRows()];
      expect(mounted.first, inInclusiveRange(1, 80));

      final position = tester.state<ScrollableState>(_reverseList).position;
      final max = position.maxScrollExtent;
      expect(max, greaterThan(_size.height * 10));

      // A scripted scroll through the whole list, one jump per frame.
      final frames = <Duration>[];
      final watch = Stopwatch();
      for (var i = 1; i <= _frames; i++) {
        position.jumpTo(max * i / _frames);
        watch
          ..reset()
          ..start();
        await tester.pump(const Duration(milliseconds: 16));
        watch.stop();
        frames.add(watch.elapsed);
        if (i % 30 == 0) mounted.add(_mountedRows());
      }
      expect(tester.takeException(), isNull);
      for (final count in mounted) {
        expect(count, inInclusiveRange(1, 80));
      }

      // And back to the newest rows.
      position.jumpTo(0);
      await pumpSettingsFrames(tester);
      expect(_mountedRows(), inInclusiveRange(1, 80));

      final sorted = [...frames]..sort();
      final total = frames.fold(Duration.zero, (a, b) => a + b);
      // ignore: avoid_print
      print(
        'logs perf [${glass ? 'glass ${platform.name}' : 'material'}] '
        '$_logs logs, $_frames frames: '
        'mean ${_ms(total ~/ frames.length)} ms, '
        'p50 ${_ms(_percentile(sorted, .5))} ms, '
        'p90 ${_ms(_percentile(sorted, .9))} ms, '
        'max ${_ms(sorted.last)} ms; '
        'mounted rows ${mounted.join('/')}',
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
