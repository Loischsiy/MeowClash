// Explicit lifecycle steps keep ordering and timer assertions readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/connection/connections.dart';
import 'package:meowclash/views/dashboard/widgets/memory_info.dart';

import 'performance_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    initializePerformanceState();
    globalState.stopUpdateTasks();
  });
  tearDown(globalState.stopUpdateTasks);

  test('global dashboard stop invalidates an awaited task and skips the rest',
      () {
    fakeAsync((clock) {
      final blocked = Completer<void>();
      var first = 0;
      var second = 0;
      globalState.startUpdateTasks([
        () {
          first++;
          return blocked.future;
        },
        () {
          second++;
        },
      ]);
      globalState.stopUpdateTasks();
      blocked.complete();
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 5));
      expect(first, 1);
      expect(second, 0);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('global dashboard restarts once with the latest task list', () {
    fakeAsync((clock) {
      final blocked = Completer<void>();
      var fresh = 0;
      globalState.startUpdateTasks([() => blocked.future]);
      globalState.stopUpdateTasks();
      globalState.startUpdateTasks([
        () {
          fresh++;
        }
      ]);
      expect(fresh, 0);
      blocked.complete();
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      expect(fresh, 1);
      globalState.stopUpdateTasks();
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  Widget host(Widget child) => ProviderScope(child: MaterialApp(
        home: Builder(builder: (context) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return Scaffold(body: SizedBox(width: 400, child: child));
        }),
      ));

  testWidgets(
      'real memory card cannot re-arm after an awaited load is disposed',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    var calls = 0;
    final blocked = Completer<int>();
    await tester.pumpWidget(host(MemoryInfo(readMemory: () {
      calls++;
      return blocked.future;
    })));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    blocked.complete(1024);
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real connections view cannot publish or re-arm after disposal',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    var calls = 0;
    final blocked = Completer<List<Connection>>();
    await tester.pumpWidget(host(ConnectionsView(loadConnections: () {
      calls++;
      return blocked.future;
    })));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    blocked.complete([]);
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
