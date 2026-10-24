import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

const _destinations = [
  AdaptiveDestination(icon: Icon(Icons.home), label: 'Home'),
  AdaptiveDestination(icon: Icon(Icons.public), label: 'Proxies'),
  AdaptiveDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

Widget _tabBar({int selectedIndex = 1, bool reduceTransparency = false}) =>
    MaterialApp(
      home: GlassAccessibilityScope(
        controller: GlassAccessibilityController()
          ..value = GlassAccessibility(
            reduceTransparency: reduceTransparency,
          ),
        child: Scaffold(
          bottomNavigationBar: AdaptiveTabBar(
            destinations: _destinations,
            selectedIndex: selectedIndex,
            onSelected: (_) {},
          ),
        ),
      ),
    );

GlassRefraction? _tabBarRefraction(WidgetTester tester) =>
    tester.widget<GlassSurface>(find.byType(GlassSurface)).refraction;

void main() {
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassRefractionShader.debugSupportedOverride = null;
    GlassFlags.refractionEnabled = true;
    debugDefaultTargetPlatformOverride = null;
  });

  group('glass_refraction.frag', () {
    test('is declared as a shader asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('  shaders:\n    - ${GlassRefractionShader.asset}'));
      expect(File(GlassRefractionShader.asset).existsSync(), isTrue);
    });

    testWidgets('loads and declares exactly the uniforms Dart writes',
        (tester) async {
      final program = await tester.runAsync(
        () => ui.FragmentProgram.fromAsset(GlassRefractionShader.asset),
      );
      final shader = program!.fragmentShader();
      for (var i = 0; i < GlassRefractionShader.floatCount; i++) {
        shader.setFloat(i, 0);
      }
      expect(
        () => shader.setFloat(GlassRefractionShader.floatCount, 0),
        throwsA(anything),
      );
      shader.dispose();
    });
  });

  group('glassRefractionUniforms', () {
    const refraction = GlassRefraction(
      bevel: 14,
      depth: 10,
      dispersion: 1,
      segment: GlassRefractionSegment(
        index: 1,
        count: 4,
        inset: 4,
        radius: 26,
        bevel: 8,
        depth: 4,
      ),
    );

    test('maps pane and selected cell to physical px', () {
      final values = glassRefractionUniforms(
        paneRect: const Rect.fromLTWH(16, 700, 408, 62),
        paneSize: const Size(408, 62),
        devicePixelRatio: 3,
        radius: 30,
        refraction: refraction,
      );
      expect(values, hasLength(GlassRefractionShader.uniformCount));
      // Pane rect and shape.
      expect(values.sublist(0, 8), [48, 2100, 1224, 186, 90, 42, 30, 3]);
      // Second of four cells inside a 4 px inset: (408 - 8) / 4 = 100 wide.
      // Left edge: (16 + 4 + 100) * 3.
      expect(values.sublist(8, 12), [360, 2112, 300, 162]);
      expect(values.sublist(12, 16), [78, 24, 12, 0]);
    });

    test('carries an ancestor scale into lengths', () {
      final values = glassRefractionUniforms(
        paneRect: const Rect.fromLTWH(0, 0, 204, 31),
        paneSize: const Size(408, 62),
        devicePixelRatio: 2,
        radius: 30,
        refraction: refraction,
      );
      expect(values.sublist(4, 8), [30, 14, 10, 1]);
    });

    test('turns the lens off without a segment', () {
      final values = glassRefractionUniforms(
        paneRect: const Rect.fromLTWH(0, 0, 100, 50),
        paneSize: const Size(100, 50),
        devicePixelRatio: 1,
        radius: 10,
        refraction: const GlassRefraction(bevel: 4, depth: 2),
      );
      expect(values.sublist(8), List<double>.filled(8, 0));
    });

    test('segment outside the row has no cell', () {
      const segment = GlassRefractionSegment(
        index: 3,
        count: 3,
        inset: 4,
        radius: 1,
        bevel: 1,
        depth: 1,
      );
      expect(segment.rectIn(const Size(100, 50)), isNull);
    });
  });

  group('AdaptiveTabBar refraction', () {
    testWidgets('iOS asks for edge refraction with a lens on the selected tab',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(_tabBar());
      final refraction = _tabBarRefraction(tester);
      expect(refraction, isNotNull);
      expect(refraction!.depth, GlassTokens.tabBarRefractionDepth);
      expect(refraction.segment?.index, 1);
      expect(refraction.segment?.count, _destinations.length);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('macOS keeps the plain blur', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await tester.pumpWidget(_tabBar());
      expect(_tabBarRefraction(tester), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('unsupported renderer: one plain blur, no shader layer',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      GlassRefractionShader.debugSupportedOverride = false;
      await tester.pumpWidget(_tabBar());
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(GlassRefractionBackdrop), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('kill switch keeps the plain blur', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      GlassRefractionShader.debugSupportedOverride = true;
      GlassFlags.refractionEnabled = false;
      expect(GlassRefractionShader.supported, isFalse);
      await tester.pumpWidget(_tabBar());
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(GlassRefractionBackdrop), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Reduce Transparency: no backdrop layer at all',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      GlassRefractionShader.debugSupportedOverride = true;
      await tester.pumpWidget(_tabBar(reduceTransparency: true));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassRefractionBackdrop), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('supported renderer: one backdrop layer, blur until loaded',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      GlassRefractionShader.debugSupportedOverride = true;
      await tester.pumpWidget(_tabBar());
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(GlassRefractionBackdrop), findsOneWidget);
      final layers = tester.layers.whereType<BackdropFilterLayer>().toList();
      expect(layers, hasLength(1));
      // The test renderer has no shader filters, so the program never
      // reaches the layer here: it must be the plain blur.
      expect(layers.single.filter.toString(), contains('blur'));
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
