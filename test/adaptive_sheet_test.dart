import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/sheet.dart';

Widget _app(SheetType type) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: AdaptiveSheetScaffold(
            type: type,
            title: 'Sheet',
            body: const SizedBox(height: 200),
          ),
        ),
      ),
    );

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
      // One GlassSurface on the sheet itself; the sheet's app bar must not
      // add a second (nested) blur.
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  }

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
