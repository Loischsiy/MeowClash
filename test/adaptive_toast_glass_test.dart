import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/manager/message_manager.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

import 'performance_test_support.dart';

/// Darwin app notifier: the glass toast (one blur, no `Opacity` above it,
/// macOS top trailing under the toolbar, iOS top center under the status
/// bar), its optional action, the Reduce Motion / opaque fallbacks; and the
/// Material notifier keeps its card.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(800, 600);
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  const apple = TargetPlatformVariant(
    {TargetPlatform.macOS, TargetPlatform.iOS},
  );

  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  late GlassAccessibilityController accessibility;

  Future<void> pumpHost(
    WidgetTester tester, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    initializePerformanceState();
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1
      ..padding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      );
    addTearDown(tester.view.reset);
    accessibility = GlassAccessibilityController();
    addTearDown(accessibility.dispose);
    await tester.pumpWidget(
      GlassAccessibilityScope(
        controller: accessibility,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MessageManager(child: child!),
          home: Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < 30; i++) ListTile(title: Text('Row $i')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MessageManagerState manager(WidgetTester tester) =>
      tester.state<MessageManagerState>(find.byType(MessageManager));

  /// Shows [text] and lets the enter animation finish; the removal is still
  /// pending, so [finish] must run before the test ends.
  Future<void> show(
    WidgetTester tester,
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    unawaited(manager(tester).message(
      text,
      actionLabel: actionLabel,
      onAction: onAction,
    ));
    await tester.pump();
    await tester.pump(GlassTokens.toastEnterDuration);
  }

  /// Lets a started exit run: the ticker starts on the first frame, and the
  /// switcher drops the faded-out toast on the next timed frame.
  Future<void> exit(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(GlassTokens.toastExitDuration);
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Runs past the display time and the exit animation.
  Future<void> finish(WidgetTester tester) async {
    // The notifier waits 1 s before it arms the removal timer, so step
    // past that first; one long pump does not reach the new timer.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await exit(tester);
  }

  Finder blurIn(Finder toast) =>
      find.descendant(of: toast, matching: find.byType(BackdropFilter));

  testWidgets('glass toast: one blur, no Opacity above it, disappears',
      (tester) async {
    await pumpHost(tester);
    await show(tester, 'Profile updated');

    final toast = find.byType(GlassToast);
    expect(toast, findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(blurIn(toast), findsOneWidget);
    expect(
      find.ancestor(of: blurIn(toast), matching: find.byType(Opacity)),
      findsNothing,
    );
    final surface = tester.widget<GlassSurface>(
      find.descendant(of: toast, matching: find.byType(GlassSurface)),
    );
    expect(surface.presence, 1);

    await finish(tester);
    expect(find.byType(GlassToast), findsNothing);
    expect(find.text('Profile updated'), findsNothing);
  }, variant: apple);

  testWidgets('macOS: top trailing corner under the toolbar', (tester) async {
    await pumpHost(tester);
    await show(tester, 'Saved');

    final rect = tester.getRect(find.byType(GlassToast));
    expect(rect.top, GlassTokens.toolbarHeightMac + GlassTokens.toastTopGap);
    expect(rect.right, size.width - GlassTokens.toastMargin);
    expect(rect.width, lessThanOrEqualTo(GlassTokens.toastMaxWidthMac));

    await finish(tester);
  }, variant: mac);

  testWidgets('iOS: top center under the status bar', (tester) async {
    const statusBar = 47.0;
    await pumpHost(tester, padding: const EdgeInsets.only(top: statusBar));
    await show(tester, 'Saved');

    final rect = tester.getRect(find.byType(GlassToast));
    expect(rect.top, statusBar + GlassTokens.toastTopGap);
    expect(rect.center.dx, moreOrLessEquals(size.width / 2));
    expect(rect.width, lessThanOrEqualTo(GlassTokens.toastMaxWidthIos));

    await finish(tester);
  }, variant: ios);

  testWidgets('toast never blocks taps on content beside it', (tester) async {
    await pumpHost(tester);
    await show(tester, 'Saved');

    final rect = tester.getRect(find.byType(GlassToast));
    final beside = Offset(GlassTokens.toastMargin + 4, rect.center.dy);
    final hits =
        tester.hitTestOnBinding(beside).path.map((e) => e.target).toList();
    expect(hits, isNot(contains(tester.renderObject(find.byType(GlassToast)))));
    expect(hits, contains(tester.renderObject(find.text('Row 1'))));

    await finish(tester);
  }, variant: mac);

  testWidgets('action runs its callback and dismisses the toast',
      (tester) async {
    await pumpHost(tester);
    var tapped = 0;
    await show(
      tester,
      'TUN restored',
      actionLabel: 'Logs',
      onAction: () => tapped++,
    );

    expect(find.text('Logs'), findsOneWidget);
    await tester.tap(find.text('Logs'));
    await tester.pump();
    await exit(tester);
    expect(tapped, 1);
    expect(find.byType(GlassToast), findsNothing);

    await finish(tester);
  }, variant: apple);

  testWidgets('no action label without a callback', (tester) async {
    await pumpHost(tester);
    await show(tester, 'Plain', actionLabel: 'Logs');
    expect(find.text('Logs'), findsNothing);
    await finish(tester);
  }, variant: mac);

  testWidgets('enters with a slide, mid-way presence is below 1',
      (tester) async {
    await pumpHost(tester);
    unawaited(manager(tester).message('Sliding'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final surface = tester.widget<GlassSurface>(find.descendant(
      of: find.byType(GlassToast),
      matching: find.byType(GlassSurface),
    ));
    expect(surface.presence, inExclusiveRange(0, 1));
    expect(
      find.ancestor(
        of: find.byType(GlassToast),
        matching: find.byType(Transform),
      ),
      findsWidgets,
    );

    await tester.pump(GlassTokens.toastEnterDuration);
    await finish(tester);
  }, variant: mac);

  testWidgets('Reduce Motion: appears at once, without a slide',
      (tester) async {
    await pumpHost(tester);
    accessibility.value = const GlassAccessibility(reduceMotion: true);
    await tester.pump();

    unawaited(manager(tester).message('Instant'));
    await tester.pump();

    final toast = find.byType(GlassToast);
    final surface = tester.widget<GlassSurface>(
      find.descendant(of: toast, matching: find.byType(GlassSurface)),
    );
    expect(surface.presence, 1);
    expect(
      tester.getRect(toast).top,
      GlassTokens.toolbarHeightMac + GlassTokens.toastTopGap,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byType(GlassToast), findsNothing);
  }, variant: mac);

  testWidgets('Reduce Transparency and the blur kill switch: opaque toast',
      (tester) async {
    await pumpHost(tester);
    accessibility.value = const GlassAccessibility(reduceTransparency: true);
    await tester.pump();
    await show(tester, 'Opaque');
    expect(blurIn(find.byType(GlassToast)), findsNothing);
    await finish(tester);

    accessibility.value = GlassAccessibility.fallback;
    GlassFlags.backdropBlurEnabled = false;
    await tester.pump();
    await show(tester, 'Kill switch');
    expect(blurIn(find.byType(GlassToast)), findsNothing);
    await finish(tester);
  }, variant: apple);

  testWidgets('Material: the notifier keeps its card, no glass toast',
      (tester) async {
    await pumpHost(tester);
    await show(tester, 'Material card');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GlassToast), findsNothing);
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Material card'), findsOneWidget);

    await finish(tester);
  },
      variant: const TargetPlatformVariant(
        {TargetPlatform.android, TargetPlatform.linux, TargetPlatform.windows},
      ));
}
