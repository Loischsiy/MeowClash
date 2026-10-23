import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  group('AdaptivePlatform', () {
    test('uses glass on macOS and iOS only', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        final darwin = platform == TargetPlatform.macOS ||
            platform == TargetPlatform.iOS;
        expect(AdaptivePlatform.useGlass, darwin, reason: '$platform');
        expect(
          AdaptivePlatform.isMacOSGlass,
          platform == TargetPlatform.macOS,
          reason: '$platform',
        );
        expect(
          AdaptivePlatform.isIOSGlass,
          platform == TargetPlatform.iOS,
          reason: '$platform',
        );
      }
    });

    test('debug override wins over the platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      AdaptivePlatform.debugUseGlassOverride = false;
      expect(AdaptivePlatform.useGlass, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AdaptivePlatform.debugUseGlassOverride = true;
      expect(AdaptivePlatform.useGlass, isTrue);
    });
  });

  group('GlassAccessibility', () {
    test('parses the native snapshot', () {
      final value = GlassAccessibility.fromMap(const {
        'reduceTransparency': false,
        'reduceMotion': true,
        'accentColor': 0xFF007AFF,
      });
      expect(value.reduceTransparency, isFalse);
      expect(value.reduceMotion, isTrue);
      expect(value.accentColor, const Color(0xFF007AFF));
      expect(value.opaque, isFalse);
    });

    test('Increase Contrast makes glass opaque', () {
      final value = GlassAccessibility.fromMap(const {
        'increaseContrast': true,
      });
      expect(value.reduceTransparency, isTrue);
      expect(value.opaque, isTrue);
      expect(value.accentColor, isNull);
    });

    test('kill switch makes glass opaque', () {
      GlassFlags.backdropBlurEnabled = false;
      expect(GlassAccessibility.fallback.opaque, isTrue);
    });

    test('reduced motion zeroes durations', () {
      expect(
        GlassTokens.motion(GlassTokens.morphDuration, reduceMotion: true),
        Duration.zero,
      );
      expect(
        GlassTokens.motion(GlassTokens.morphDuration, reduceMotion: false),
        GlassTokens.morphDuration,
      );
    });
  });

  group('GlassAccessibilityController', () {
    const channel = GlassAccessibilityController.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('stays on the fallback off Darwin without touching the channel',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return null;
      });
      final controller = GlassAccessibilityController();
      await controller.start();
      expect(calls, 0);
      expect(controller.value, GlassAccessibility.fallback);
      controller.dispose();
    });

    test('reads the snapshot and follows native changes', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'snapshot');
        return {'reduceTransparency': true, 'reduceMotion': false};
      });
      final controller = GlassAccessibilityController();
      await controller.start();
      expect(controller.value.reduceTransparency, isTrue);

      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('changed', {
            'reduceTransparency': false,
            'reduceMotion': true,
            'accentColor': 0xFFFF2D55,
          }),
        ),
        (_) {},
      );
      expect(controller.value.reduceTransparency, isFalse);
      expect(controller.value.reduceMotion, isTrue);
      expect(controller.value.accentColor, const Color(0xFFFF2D55));
      controller.dispose();
    });

    test('survives an older runner without the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final controller = GlassAccessibilityController();
      await controller.start();
      expect(controller.value, GlassAccessibility.fallback);
      controller.dispose();
    });
  });

  group('GlassSurface', () {
    Widget host(
      Widget child, {
      GlassAccessibilityController? controller,
      bool highContrast = false,
    }) =>
        GlassAccessibilityScope(
          controller: controller ?? GlassAccessibilityController(),
          child: MaterialApp(
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: highContrast),
              child: app!,
            ),
            home: Scaffold(body: Center(child: child)),
          ),
        );

    const surface = SizedBox(
      width: 200,
      height: 60,
      child: GlassSurface(
        borderRadius: BorderRadius.all(Radius.circular(30)),
        shadow: true,
        child: Text('glass'),
      ),
    );

    testWidgets('uses exactly one BackdropFilter', (tester) async {
      await tester.pumpWidget(host(surface));
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('glass'), findsOneWidget);
    });

    testWidgets('native backdrop needs no BackdropFilter', (tester) async {
      await tester.pumpWidget(host(const GlassSurface(
        backdrop: GlassBackdrop.native,
        child: SizedBox(width: 84, height: 400),
      )));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('Reduce Transparency renders the opaque fallback',
        (tester) async {
      final controller = GlassAccessibilityController()
        ..value = const GlassAccessibility(reduceTransparency: true);
      await tester.pumpWidget(host(surface, controller: controller));
      expect(find.byType(BackdropFilter), findsNothing);

      controller.value = GlassAccessibility.fallback;
      await tester.pump();
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('Increase Contrast renders the opaque fallback',
        (tester) async {
      await tester.pumpWidget(host(surface, highContrast: true));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('kill switch removes every BackdropFilter', (tester) async {
      GlassFlags.backdropBlurEnabled = false;
      await tester.pumpWidget(host(surface));
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
