import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/scaffold.dart';
import 'package:meowclash/widgets/subscription_info_view.dart';

import 'performance_test_support.dart';

/// Pixel baseline of the Material loading indicators that Android, Linux and
/// Windows must keep after the Darwin glass ones: the `loadingRun` bar under
/// the app bar and the provider subscription bar (`SubscriptionInfoView`).
/// The images were generated on `main` before the glass indicators landed and
/// must still match. Regenerate only for an intended Material change:
/// `flutter test --update-goldens test/material_loading_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 320);

  Future<void> setUpView(WidgetTester tester) async {
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(Brightness brightness, Widget home) => ProviderScope(
        overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6750A4),
              brightness: brightness,
            ),
          ),
          home: Builder(builder: (context) {
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return home;
          }),
        ),
      );

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('loadingRun bar under the app bar, $b', (tester) async {
      await setUpView(tester);
      await tester.pumpWidget(host(
        brightness,
        const CommonScaffold(
          title: 'Resources',
          body: Center(child: Text('Body')),
        ),
      ));
      await tester.pump();

      final completer = Completer<void>();
      final scaffold =
          tester.state<CommonScaffoldState>(find.byType(CommonScaffold));
      unawaited(scaffold.loadingRun(() => completer.future));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_loading_bar_$b.png'),
      );

      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('provider subscription bar, $b', (tester) async {
      await setUpView(tester);
      await tester.pumpWidget(host(
        brightness,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: SubscriptionInfoView(
              subscriptionInfo: SubscriptionInfo(
                upload: 3 * 1024 * 1024 * 1024,
                download: 12 * 1024 * 1024 * 1024,
                total: 50 * 1024 * 1024 * 1024,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_subscription_bar_$b.png'),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
