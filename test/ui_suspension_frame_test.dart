// Explicit lifecycle transitions are part of this regression test.
// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/ui_lifecycle.dart';
import 'package:meowclash/widgets/suspendable_ui.dart';

class _FrameBinding extends AutomatedTestWidgetsFlutterBinding {
  int warmUpRequests = 0;

  @override
  void scheduleWarmUpFrame() {
    warmUpRequests++;
    super.scheduleWarmUpFrame();
  }
}

void main() {
  final binding = _FrameBinding();
  testWidgets('hidden teardown and restore request frames without native vsync',
      (tester) async {
    final controller = UiLifecycleController();
    var unloaded = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => UiActivityScope(
        controller: controller,
        child: child!,
      ),
      home: SuspendableUi(
        controller: controller,
        onUnload: () => unloaded++,
        builder: (_) => const Text('heavy UI'),
      ),
    ));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(binding.framesEnabled, isFalse);
    final beforeHide = binding.warmUpRequests;
    controller.updateWindowVisibility(visible: false);
    expect(binding.warmUpRequests, beforeHide + 1);
    await tester.pump();
    final beforeUnload = binding.warmUpRequests;
    await tester.pump(const Duration(seconds: 3));
    expect(binding.warmUpRequests, beforeUnload + 1);
    await tester.pump();
    expect(unloaded, 1);
    expect(find.text('heavy UI'), findsNothing);
    final backgroundFrames = binding.warmUpRequests;
    await tester.pump(const Duration(minutes: 5));
    expect(binding.warmUpRequests, backgroundFrames,
        reason: 'do not force recurring idle frames');
    controller.updateWindowVisibility(visible: true);
    expect(binding.warmUpRequests, backgroundFrames + 1);
    await tester.pump();
    expect(find.text('heavy UI'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });
}
