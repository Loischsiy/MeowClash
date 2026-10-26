import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/navigator.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/sheet.dart';
import 'package:meowclash/widgets/side_sheet.dart';

import 'performance_test_support.dart';

/// Darwin settings navigation: iPhone pushes are Cupertino slides with the
/// back swipe, macOS / iPad pushes are NavigationStack slides and the glass
/// side sheet springs in from the trailing edge. Reduce Motion makes all of
/// them instant; Material keeps its stock routes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mobile = Size(400, 720);
  const desktop = Size(1200, 800);

  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
  });

  Future<_RouteLog> pumpHost(
    WidgetTester tester, {
    required Size size,
    bool glass = true,
    bool reduceMotion = false,
  }) async {
    AdaptivePlatform.debugUseGlassOverride = glass;
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = _RouteLog();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [log],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: const Scaffold(body: Text('Root')),
      ),
    );
    return log;
  }

  BuildContext rootContext(WidgetTester tester) =>
      tester.element(find.text('Root'));

  group('GlassSpringCurve', () {
    test('starts at 0, settles at 1 and is mostly there halfway', () {
      const curve = GlassTokens.sideSheetEnterCurve;
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      expect(curve.transform(0.5), greaterThan(0.8));
      // Settled before the end, so the final snap to 1 is invisible.
      expect(curve.transform(0.99), closeTo(1, 0.01));
      // dampingFraction 0.9: at most a hair of overshoot.
      for (var t = 0.0; t <= 1.0; t += 0.01) {
        expect(curve.transform(t), lessThan(1.01));
      }
    });
  });

  group('iPhone push', () {
    testWidgets('Cupertino slide with back swipe', (tester) async {
      final log = await pumpHost(tester, size: mobile);
      unawaited(
        BaseNavigator.push<void>(rootContext(tester), const Text('Page')),
      );
      await tester.pump();
      final route = log.last;
      expect(route, isA<GlassPageRoute<void>>());
      expect(route, isA<CupertinoRouteTransitionMixin<void>>());
      expect(
        (route as GlassPageRoute<void>).transitionDuration,
        GlassTokens.pushDuration,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CupertinoPageTransition), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('Page'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Reduce Motion: instant', (tester) async {
      final log =
          await pumpHost(tester, size: mobile, reduceMotion: true);
      unawaited(
        BaseNavigator.push<void>(rootContext(tester), const Text('Page')),
      );
      await tester.pump();
      expect(
        (log.last as GlassPageRoute<void>).transitionDuration,
        Duration.zero,
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Page'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('macOS / iPad push', () {
    testWidgets('NavigationStack slide, no back swipe, no fade',
        (tester) async {
      final log = await pumpHost(tester, size: desktop);
      unawaited(
        BaseNavigator.push<void>(rootContext(tester), const Text('Page')),
      );
      await tester.pump();
      final route = log.last as PageRoute<void>;
      expect(route, isNot(isA<CupertinoRouteTransitionMixin<void>>()));
      expect(route.transitionDuration, GlassTokens.desktopPushDuration);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.ancestor(
          of: find.text('Page'),
          matching: find.byType(CupertinoPageTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Page'),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.text('Page'), findsOneWidget);
    }, variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    }));

    testWidgets('Reduce Motion: instant', (tester) async {
      final log =
          await pumpHost(tester, size: desktop, reduceMotion: true);
      unawaited(
        BaseNavigator.push<void>(rootContext(tester), const Text('Page')),
      );
      await tester.pump();
      expect((log.last as PageRoute<void>).transitionDuration, Duration.zero);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('side sheet', () {
    testWidgets('glass panel springs in, leaves on an ease', (tester) async {
      final log = await pumpHost(tester, size: desktop);
      unawaited(
        showExtend<void>(
          rootContext(tester),
          builder: (_, __) => const Text('Sheet'),
        ),
      );
      await tester.pump();
      final route = log.last as ModalSideSheetRoute<void>;
      expect(route.motion, isNotNull);
      expect(route.transitionDuration, GlassTokens.sideSheetEnterDuration);
      expect(
        route.reverseTransitionDuration,
        GlassTokens.sideSheetExitDuration,
      );
      expect(route.motion!.curve, GlassTokens.sideSheetEnterCurve);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
      Navigator.of(tester.element(find.text('Sheet'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing);
    }, variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    }));

    testWidgets('Reduce Motion: instant', (tester) async {
      final log =
          await pumpHost(tester, size: desktop, reduceMotion: true);
      unawaited(
        showExtend<void>(
          rootContext(tester),
          builder: (_, __) => const Text('Sheet'),
        ),
      );
      await tester.pump();
      final route = log.last as ModalSideSheetRoute<void>;
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('Material', () {
    testWidgets('pushes and side sheets keep the stock routes',
        (tester) async {
      var log = await pumpHost(tester, size: mobile, glass: false);
      unawaited(
        BaseNavigator.push<void>(rootContext(tester), const Text('Page')),
      );
      await tester.pump();
      expect(log.last, isA<CommonRoute<void>>());
      expect(log.last, isNot(isA<GlassPageRoute<void>>()));

      log = await pumpHost(tester, size: desktop, glass: false);
      unawaited(
        showExtend<void>(
          rootContext(tester),
          builder: (_, __) => const Text('Sheet'),
        ),
      );
      await tester.pump();
      final sheet = log.last as ModalSideSheetRoute<void>;
      expect(sheet.motion, isNull);
      expect(sheet.transitionDuration, const Duration(milliseconds: 300));
    }, variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }));
  });
}

class _RouteLog extends NavigatorObserver {
  final routes = <Route<dynamic>>[];

  Route<dynamic> get last => routes.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }
}
