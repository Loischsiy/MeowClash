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

  group('GlassWindowAppearance', () {
    const channel = GlassAccessibilityController.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<Object?> modes;

    setUp(() {
      modes = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'setAppearance') {
          modes.add((call.arguments as Map)['mode']);
        }
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Widget host(ThemeMode mode) => GlassWindowAppearance(
          themeMode: mode,
          child: const SizedBox(),
        );

    testWidgets('macOS: sends the theme mode at start and on change',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await tester.pumpWidget(host(ThemeMode.light));
      expect(modes, ['light']);
      await tester.pumpWidget(host(ThemeMode.light));
      expect(modes, ['light'], reason: 'no call when nothing changed');
      await tester.pumpWidget(host(ThemeMode.dark));
      await tester.pumpWidget(host(ThemeMode.system));
      expect(modes, ['light', 'dark', 'system']);
      debugDefaultTargetPlatformOverride = null;
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('${platform.name}: never touches the channel',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await tester.pumpWidget(host(ThemeMode.light));
        await tester.pumpWidget(host(ThemeMode.dark));
        expect(modes, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('survives an older runner without the method',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      messenger.setMockMethodCallHandler(channel, null);
      await tester.pumpWidget(host(ThemeMode.dark));
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
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

  group('Dark glass rim', () {
    test('dark rim is a faint hairline, light rim unchanged', () {
      expect(GlassTokens.rimWidth(Brightness.light), 1);
      expect(GlassTokens.rimWidth(Brightness.dark), 0.5);
      expect(GlassTokens.rimTopOpacity(Brightness.light), 0.72);
      expect(GlassTokens.rimTopOpacity(Brightness.dark), 0.12);
      expect(GlassTokens.rimBottomOpacity(Brightness.dark), 0.03);
    });
  });

  group('Close button', () {
    testWidgets('GlassTheme draws the SF xmark in every CloseButton',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: GlassTheme.apply(ThemeData()),
        home: const Scaffold(body: Center(child: CloseButton())),
      ));
      expect(find.byType(GlassCloseIcon), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      final icon = tester.getSize(find.byType(GlassCloseIcon));
      expect(icon.width, icon.height);
    });

    testWidgets('Material theme keeps Icons.close', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(),
        home: const Scaffold(body: Center(child: CloseButton())),
      ));
      expect(find.byType(GlassCloseIcon), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: capsule inside a glass sheet is a '
          'filled disc', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: Center(
              child: GlassSurface(
                child: GlassToolbarGroup(
                  children: [
                    IconButton(onPressed: () {}, icon: const GlassCloseIcon()),
                  ],
                ),
              ),
            ),
          ),
        ));
        final capsule = tester.widget<GlassSurface>(find.descendant(
          of: find.byType(GlassToolbarGroup),
          matching: find.byType(GlassSurface),
        ));
        expect(capsule.backdrop, GlassBackdrop.native);
        expect(
          capsule.tintOpacity,
          GlassTokens.toolbarItemTintOverGlass(brightness),
        );
        // Light keeps the wash it had; dark gets a denser fill.
        if (brightness == Brightness.light) {
          expect(
            capsule.tintOpacity,
            GlassTokens.nativeBackdropTint(brightness),
          );
        } else {
          expect(
            capsule.tintOpacity,
            greaterThan(GlassTokens.nativeBackdropTint(brightness)),
          );
        }
      });
    }

    testWidgets('capsule over the window keeps the default blur tint',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassToolbarGroup(
              children: [
                IconButton(onPressed: () {}, icon: const GlassCloseIcon()),
              ],
            ),
          ),
        ),
      ));
      final capsule = tester.widget<GlassSurface>(find.byType(GlassSurface));
      expect(capsule.backdrop, GlassBackdrop.blur);
      expect(capsule.tintOpacity, isNull);
    });
  });
}
