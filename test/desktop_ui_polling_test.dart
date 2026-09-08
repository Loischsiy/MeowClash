// Explicit hide/show sequences exercise native events, not only app lifecycle.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/async_polling_loop.dart';
import 'package:meowclash/services/ui_lifecycle.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/visibility_polling.dart';

class _Poller extends StatefulWidget {
  const _Poller({required this.fetch, required this.publish});
  final Future<int> Function() fetch;
  final void Function(int) publish;

  @override
  State<_Poller> createState() => _PollerState();
}

class _PollerState extends State<_Poller> with VisibilityPollingMixin<_Poller> {
  @override
  Duration get pollingInterval => const Duration(seconds: 1);

  @override
  Future<void> poll(PollingToken token) async {
    final result = await widget.fetch();
    if (mounted && token.isCurrent) widget.publish(result);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    globalState.stopUpdateTasks();
    globalState.isService = false;
    globalState.tasks = [];
    uiLifecycle.updateWindowVisibility(visible: null);
    uiLifecycle.updateLifecycle(null);
  });

  test(
      'desktop tray start does not arm dashboard polling; restore can start it',
      () {
    fakeAsync((clock) {
      var calls = 0;
      uiLifecycle.updateWindowVisibility(visible: false);
      unawaited(globalState.startUpdateTasks([
        () {
          calls++;
        }
      ]));
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 5));
      expect(calls, 0);
      expect(clock.nonPeriodicTimerCount, 0);
      uiLifecycle.updateWindowVisibility(visible: true);
      unawaited(globalState.startUpdateTasks());
      clock.flushMicrotasks();
      expect(calls, 1);
      globalState.stopUpdateTasks();
    });
  });

  test('a hidden UI does not disable the independent service task loop', () {
    fakeAsync((clock) {
      var calls = 0;
      globalState.isService = true;
      uiLifecycle.updateWindowVisibility(visible: false);
      unawaited(globalState.startUpdateTasks([
        () {
          calls++;
        }
      ]));
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      expect(calls, greaterThan(1));
      globalState.stopUpdateTasks();
      uiLifecycle.updateWindowVisibility(visible: true);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  testWidgets(
      'native hide/show stops polls despite a resumed Flutter lifecycle',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    uiLifecycle.updateWindowVisibility(visible: true);
    final requests = <Completer<int>>[];
    final results = <int>[];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _Poller(
        fetch: () {
          final request = Completer<int>();
          requests.add(request);
          return request.future;
        },
        publish: results.add,
      ),
    ));
    uiLifecycle.updateWindowVisibility(visible: false);
    await tester.pump(const Duration(minutes: 5));
    expect(requests, hasLength(1));
    expect(isUiForeground, isFalse);
    uiLifecycle.updateWindowVisibility(visible: true);
    requests.first.complete(1);
    await tester.pump();
    await tester.pump(Duration.zero);
    expect(results, isEmpty, reason: 'the pre-hide response is stale');
    expect(requests, hasLength(2));
    requests.last.complete(2);
    await tester.pump();
    expect(results, [2]);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
