import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/scaffold.dart';
import 'package:meowclash/widgets/subscription_info_view.dart';

import 'performance_test_support.dart';

/// Darwin loading indicators outside the screens' own glass branches: the
/// `loadingRun` bar under the glass toolbar (thin accent sweep, still with
/// Reduce Motion) and the provider subscription capsule. Material keeps the
/// stock bars (pixels pinned by `material_loading_golden_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const apple = TargetPlatformVariant(
    {TargetPlatform.macOS, TargetPlatform.iOS},
  );
  const material = TargetPlatformVariant(
    {TargetPlatform.android, TargetPlatform.linux, TargetPlatform.windows},
  );
  const size = Size(800, 600);

  Future<void> setUpView(WidgetTester tester) async {
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState();
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<CommonScaffoldState> pumpScaffold(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    await setUpView(tester);
    final key = GlobalKey<CommonScaffoldState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
      child: MaterialApp(
        theme: GlassTheme.apply(ThemeData(useMaterial3: true)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Consumer(builder: (context, ref, _) {
          globalState.appController = AppController(context, ref);
          return CommonScaffold(
            key: key,
            title: 'Resources',
            body: const SizedBox.expand(),
          );
        }),
      ),
    ));
    await tester.pump();
    return key.currentState!;
  }

  Finder bar() => find.byType(AdaptiveLoadingBar);

  group('loadingRun bar', () {
    testWidgets('glass: thin accent sweep along the toolbar bottom',
        (tester) async {
      final scaffold = await pumpScaffold(tester);
      expect(bar(), findsNothing);

      final completer = Completer<void>();
      unawaited(scaffold.loadingRun(() => completer.future));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(bar(), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final rect = tester.getRect(bar());
      expect(rect.height, GlassTokens.loadingBarHeight);
      expect(rect.width, size.width);
      expect(rect.bottom, tester.getRect(find.byType(AdaptiveAppBar)).bottom);
      expect(
        find.descendant(of: bar(), matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
      // The sweep keeps ticking while the task runs.
      expect(tester.binding.hasScheduledFrame, isTrue);

      completer.complete();
      await tester.pump();
      await tester.pump();
      expect(bar(), findsNothing);
    }, variant: apple);

    testWidgets('glass + Reduce Motion: a still accent hairline',
        (tester) async {
      final scaffold = await pumpScaffold(tester, reduceMotion: true);
      final completer = Completer<void>();
      unawaited(scaffold.loadingRun(() => completer.future));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(bar(), findsOneWidget);
      final fill = tester.widget<ColoredBox>(
        find.descendant(of: bar(), matching: find.byType(ColoredBox)),
      );
      final context = tester.element(bar());
      expect(fill.color, Theme.of(context).colorScheme.primary);
      expect(
        find.descendant(of: bar(), matching: find.byType(CustomPaint)),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);

      completer.complete();
      await tester.pump();
      await tester.pump();
    }, variant: apple);

    testWidgets('Material: the stock LinearProgressIndicator', (tester) async {
      final scaffold = await pumpScaffold(tester);
      final completer = Completer<void>();
      unawaited(scaffold.loadingRun(() => completer.future));
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
      expect(indicator.minHeight, isNull);
      expect(indicator.color, isNull);
      expect(indicator.backgroundColor, isNull);

      completer.complete();
      await tester.pump();
      await tester.pump();
    }, variant: material);
  });

  group('provider subscription bar', () {
    Future<void> pumpInfo(WidgetTester tester) async {
      await setUpView(tester);
      await tester.pumpWidget(MaterialApp(
        theme: GlassTheme.apply(ThemeData(useMaterial3: true)),
        home: const Scaffold(
          body: SubscriptionInfoView(
            subscriptionInfo: SubscriptionInfo(
              upload: 10,
              download: 30,
              total: 100,
            ),
          ),
        ),
      ));
    }

    testWidgets('glass: the thin capsule, no Material bar', (tester) async {
      await pumpInfo(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final capsule =
          tester.widget<AdaptiveProgressBar>(find.byType(AdaptiveProgressBar));
      expect(capsule.value, closeTo(0.4, 1e-9));
      expect(
        tester.getSize(find.byType(AdaptiveProgressBar)).height,
        GlassTokens.progressBarHeight,
      );
    }, variant: apple);

    testWidgets('Material: the stock 6 px bar', (tester) async {
      await pumpInfo(tester);
      expect(find.byType(AdaptiveProgressBar), findsNothing);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.minHeight, 6);
      expect(indicator.value, closeTo(0.4, 1e-9));
    }, variant: material);
  });
}
