import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/manager/message_manager.dart';

import 'performance_test_support.dart';

/// Pixel baseline of the Material app notifier (`MessageManager`'s card) that
/// Android, Linux and Windows must keep after the Darwin glass toast. The
/// images were generated with the notifier from `main` before the glass toast
/// landed and must still match. Regenerate only for an intended Material
/// change:
/// `flutter test --update-goldens test/material_notifier_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(800, 520);

  // The notifier logs every message to the file log, which asks
  // path_provider for its directories.
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            pathProvider, (call) async => Directory.systemTemp.path);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Material notifier card (${brightness.name})', (tester) async {
      initializePerformanceState();
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MessageManager(child: child!),
        home: Scaffold(
          appBar: AppBar(title: const Text('Proxies')),
          body: ListView(
            children: [
              for (var i = 0; i < 12; i++) ListTile(title: Text('Row $i')),
            ],
          ),
        ),
      ));

      final manager =
          tester.state<MessageManagerState>(find.byType(MessageManager));
      unawaited(manager.message('Profile updated: subscription refreshed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_notifier_${brightness.name}.png'),
      );

      // Let the notifier remove the card so no timer outlives the test.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
