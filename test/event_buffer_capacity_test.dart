import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';

import 'connections_logs_test_support.dart';
import 'performance_test_support.dart';

class _NoCoreController extends AppController {
  _NoCoreController(super.context, super.ref);

  @override
  Future<T?> runWithOptionalUi<T>(Future<T> Function() action,
          {String? title}) =>
      // Do not apply a profile to a real core in a widget test.
      Future<T?>.value();

  @override
  void addCheckIpNumDebounce() {}
}

void main() {
  test('event buffers are created with maxLength capacity', () {
    expect(createEventBuffer<Log>().maxLength, maxLength);
    expect(createEventBuffer<Connection>().maxLength, maxLength);
  });

  testWidgets('profile switches keep log/request buffers at maxLength',
      (tester) async {
    // Start from buffers of another size so the reset is visible.
    initializePerformanceState();
    expect(globalState.appState.logs.maxLength, isNot(maxLength));
    late AppController controller;
    late WidgetRef widgetRef;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          controller = _NoCoreController(context, ref);
          widgetRef = ref;
          return const SizedBox();
        }),
      ),
    ));

    // Three switches in a row (measurement scenario d).
    for (var round = 0; round < 3; round++) {
      controller.handleChangeProfile();
      await tester.pump();
      expect(globalState.appState.logs.maxLength, maxLength);
      expect(globalState.appState.requests.maxLength, maxLength);
      expect(globalState.appState.logs.length, 0);
      expect(globalState.appState.requests.length, 0);

      final logs = widgetRef.read(logsProvider.notifier);
      final requests = widgetRef.read(requestsProvider.notifier);
      for (var i = 0; i < maxLength + 50; i++) {
        logs.addLog(sampleLog(i));
        requests.addRequest(sampleConnection(i));
      }
      expect(widgetRef.read(logsProvider).length, maxLength);
      expect(widgetRef.read(requestsProvider).length, maxLength);
    }
  });
}
