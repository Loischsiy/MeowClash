import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/sheet.dart';

Widget _app(SheetType type, {double top = 0, bool highContrast = false}) =>
    ProviderScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(top: top),
            viewPadding: EdgeInsets.only(top: top),
            highContrast: highContrast,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: AdaptiveSheetScaffold(
            type: type,
            title: 'Sheet',
            body: const SizedBox(height: 200),
          ),
        ),
      ),
    );

int _backdropLayers(WidgetTester tester) =>
    tester.layers.whereType<BackdropFilterLayer>().length;

/// macOS title bar inset (`WindowHeaderContainer`).
const _macTop = 28.0;

void main() {
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  for (final type in [SheetType.sideSheet, SheetType.bottomSheet]) {
    testWidgets('$type: Material branch has no glass', (tester) async {
      AdaptivePlatform.debugUseGlassOverride = false;
      await tester.pumpWidget(_app(type));
      expect(find.byType(GlassSurface), findsNothing);
    });

    testWidgets('$type: glass branch blurs exactly once', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(_app(type));
      // One blur on the sheet itself. The side sheet's close button is a
      // glass toolbar capsule, but over the sheet's blur it must not add a
      // second (nested) one.
      expect(
        find.byType(GlassSurface),
        findsNWidgets(type == SheetType.sideSheet ? 2 : 1),
      );
      expect(_backdropLayers(tester), 1);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  group('side sheet (Darwin): floating panel', () {
    Finder panel() => find.byType(GlassSurface).first;

    testWidgets('macOS: inset from every edge, every corner rounded',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(_app(SheetType.sideSheet, top: _macTop));
      const inset = GlassTokens.sideSheetInset;
      final size = tester.getSize(find.byType(Scaffold).first);
      expect(
        tester.getRect(panel()),
        Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
      );
      expect(
        tester.widget<GlassSurface>(panel()).borderRadius,
        BorderRadius.circular(GlassTokens.sideSheetRadiusMac),
      );
      expect(tester.widget<GlassSurface>(panel()).shadow, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('macOS: close button is a round toolbar capsule, '
        'still clear of the title bar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(_app(SheetType.sideSheet, top: _macTop));
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(CloseButton), findsOneWidget);
      final capsule = find.ancestor(
        of: find.byType(CloseButton),
        matching: find.byType(GlassToolbarGroup),
      );
      expect(capsule, findsOneWidget);
      final size = tester.getSize(find.byType(Scaffold).first);
      final rect = tester.getRect(capsule);
      expect(rect.width, GlassToolbarGroup.itemSize);
      // Same row as a page toolbar: title bar inset + half the bar.
      expect(rect.center.dy, _macTop + GlassTokens.toolbarHeightMac / 2);
      expect(
        rect.right,
        size.width - GlassTokens.sideSheetInset - GlassTokens.toolbarInsetMac,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iOS: larger corner radius', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(_app(SheetType.sideSheet));
      expect(
        tester.widget<GlassSurface>(panel()).borderRadius,
        BorderRadius.circular(GlassTokens.sideSheetRadiusIos),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Increase Contrast: opaque panel, no blur, still rounded',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(
        _app(SheetType.sideSheet, top: _macTop, highContrast: true),
      );
      expect(_backdropLayers(tester), 0);
      expect(
        tester.widget<GlassSurface>(panel()).borderRadius,
        BorderRadius.circular(GlassTokens.sideSheetRadiusMac),
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Material side sheet keeps its edge-to-edge AppBar',
        (tester) async {
      AdaptivePlatform.debugUseGlassOverride = false;
      await tester.pumpWidget(_app(SheetType.sideSheet));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(GlassToolbarGroup), findsNothing);
      expect(
        tester.getRect(find.byType(AppBar)).left,
        0,
      );
    });
  });

  // On phones `showExtend` pushes the sheet as an opaque full-screen page:
  // there is nothing behind it to blur, so glass would paint a flat grey tint.
  testWidgets('page: Darwin page is opaque, without glass', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AdaptivePlatform.debugUseGlassOverride = true;
    await tester.pumpWidget(_app(SheetType.page));
    expect(find.byType(GlassSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    final context = tester.element(find.text('Sheet'));
    final scaffold = tester.widget<Scaffold>(find
        .ancestor(of: find.text('Sheet'), matching: find.byType(Scaffold))
        .first);
    final background = scaffold.backgroundColor ??
        Theme.of(context).scaffoldBackgroundColor;
    expect(background.a, 1.0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('page: Material branch keeps its translucent surface',
      (tester) async {
    AdaptivePlatform.debugUseGlassOverride = false;
    await tester.pumpWidget(_app(SheetType.page));
    expect(find.byType(GlassSurface), findsNothing);
    final context = tester.element(find.text('Sheet'));
    final scaffold = tester.widget<Scaffold>(find
        .ancestor(of: find.text('Sheet'), matching: find.byType(Scaffold))
        .first);
    expect(
      scaffold.backgroundColor,
      Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
    );
  });
}
