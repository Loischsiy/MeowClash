import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/state.dart';

class _RecordingController extends AppController {
  _RecordingController(super.context, super.ref);
  int operations = 0;

  @override
  Future<T?> runWithOptionalUi<T>(Future<T> Function() action,
      {String? title}) {
    operations++;
    // Do not start a real proxy or request OS privileges in a widget test.
    return Future<T?>.value();
  }

  @override
  void addCheckIpNumDebounce() {}
}

void main() {
  testWidgets('headless core/config actions do not require a home scaffold',
      (tester) async {
    late _RecordingController controller;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          controller = _RecordingController(context, ref);
          return const SizedBox();
        }),
      ),
    ));
    expect(globalState.homeScaffoldKey.currentState, isNull);
    await controller.updateClashConfig();
    await controller.setupClashConfig();
    await controller.applyProfile();
    expect(controller.operations, 3);
  });

  testWidgets('optional UI runner executes and returns data after UI unloading',
      (tester) async {
    late AppController controller;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          controller = AppController(context, ref);
          return const SizedBox();
        }),
      ),
    ));
    var calls = 0;
    final value = await controller.runWithOptionalUi(() async {
      calls++;
      return 'completed without UI';
    });
    expect(value, 'completed without UI');
    expect(calls, 1);
    expect(globalState.homeScaffoldKey.currentState, isNull);
  });
}
