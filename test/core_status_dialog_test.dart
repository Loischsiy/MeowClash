import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/dashboard/widgets/core_status_dialog.dart';

import 'performance_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(initializePerformanceState);

  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          home: Builder(builder: (context) {
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return Scaffold(body: child);
          }),
        ),
      );

  const status = CoreStatus(
    physical: 30 << 20,
    inUse: 20 << 20,
    reclaimable: 10 << 20,
    sys: 40 << 20,
    goroutines: 42,
    heapObjects: 1234,
    rules: 7,
    proxies: 5,
    proxyGroups: 3,
    ruleProviders: 2,
    geodataUse: 'MMDB, Site',
  );

  testWidgets('shows core counters and separate shell/core RAM',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    var gcCalls = 0;
    await tester.pumpWidget(host(CoreStatusDialog(
      loadStatus: () async => status,
      loadCoreRss: () async => 50 << 20,
      readShellMemory: () => (rss: 100 << 20, maxRss: 120 << 20),
      coreInAppProcess: false,
      onReleaseMemory: () => gcCalls++,
    )));
    await tester.pump();
    await tester.pump();

    final l10n = AppLocalizations.current;
    for (final text in [
      l10n.coreStatus,
      l10n.allocatedMemory,
      l10n.reclaimableMemory,
      l10n.flutterShellMemory,
      l10n.coreProcessMemory,
      l10n.goRuntimeMemory,
      l10n.rulesCount,
      l10n.ruleProvidersCount,
      'MMDB',
      'Site',
      '42',
    ]) {
      expect(find.textContaining(text), findsWidgets, reason: text);
    }
    expect(find.text(l10n.proxyProvidersCount), findsNothing);
    expect(find.text(l10n.sharedProcessMemoryHint), findsNothing);

    await tester.tap(find.text(l10n.releaseMemory));
    expect(gcCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in-process core hides core RSS and explains the overlap',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    var coreRssCalls = 0;
    await tester.pumpWidget(host(CoreStatusDialog(
      loadStatus: () async => status,
      loadCoreRss: () async {
        coreRssCalls++;
        return 0;
      },
      readShellMemory: () => (rss: 1, maxRss: 1),
      coreInAppProcess: true,
    )));
    await tester.pump();
    final l10n = AppLocalizations.current;
    expect(find.text(l10n.coreProcessMemory), findsNothing);
    expect(find.text(l10n.sharedProcessMemoryHint), findsOneWidget);
    expect(coreRssCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stops polling after the dialog is closed', (tester) async {
    await AppLocalizations.load(const Locale('en'));
    var calls = 0;
    final blocked = Completer<CoreStatus?>();
    await tester.pumpWidget(host(CoreStatusDialog(
      loadStatus: () {
        calls++;
        return blocked.future;
      },
      readShellMemory: () => (rss: 1, maxRss: 1),
      coreInAppProcess: true,
    )));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    blocked.complete(status);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
