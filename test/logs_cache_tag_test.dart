import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/logs.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'connections_logs_test_support.dart';
import 'settings_test_support.dart';

/// The Logs page keeps its row heights and scroll offset under
/// [CacheTag.logs], apart from the rules editor ([CacheTag.rules]).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => setUpSettingsEnvironment('logs_cache_tag'));

  testWidgets('logs page does not touch the rules editor caches',
      (tester) async {
    await setUpStreamScreen(tester, const Size(400, 900),
        page: PageLabel.logs, logs: sampleLogs(80));
    // A rules editor that was open before.
    globalState.cacheHeightMap[CacheTag.rules] = FixedMap<String, double>(1)
      ..updateCacheValue('rule', () => 42);
    globalState.cacheScrollPosition[CacheTag.rules] = 7;

    await tester
        .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
    await pumpSettingsFrames(tester);
    await tester.drag(
        find.byType(CacheItemExtentListView), const Offset(0, -300));
    await pumpSettingsFrames(tester);
    expect(tester.takeException(), isNull);

    final rules = globalState.cacheHeightMap[CacheTag.rules]!;
    expect(rules.length, 1);
    expect(rules.get('rule'), 42);
    expect(globalState.cacheScrollPosition[CacheTag.rules], 7);

    expect(globalState.cacheHeightMap[CacheTag.logs]?.length,
        greaterThan(0));
    expect(globalState.cacheScrollPosition.containsKey(CacheTag.logs),
        isTrue);

    // Stop timers before the test ends.
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
