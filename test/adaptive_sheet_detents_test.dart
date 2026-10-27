import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/sheet.dart';

/// iPhone glass bottom sheet with medium/large detents
/// (`SheetProps.expandable` → GlassSheetDetents), opened the way `showSheet`
/// opens it on Darwin.
void main() {
  const screen = Size(400, 800);
  const items = 40;

  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  Widget app({GlassAccessibility accessibility = GlassAccessibility.fallback}) =>
      ProviderScope(
        child: GlassAccessibilityScope(
          controller: GlassAccessibilityController()..value = accessibility,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => GlassSheetDetents(
                        child: SafeArea(
                          child: AdaptiveSheetScaffold(
                            type: SheetType.bottomSheet,
                            title: 'Add',
                            body: SingleChildScrollView(
                              child: Column(
                                children: [
                                  for (var i = 0; i < items; i++)
                                    SizedBox(
                                      height: 60,
                                      child: Text('Item $i'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> open(
    WidgetTester tester, {
    GlassAccessibility accessibility = GlassAccessibility.fallback,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AdaptivePlatform.debugUseGlassOverride = true;
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(accessibility: accessibility));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  double sheetHeight(WidgetTester tester) =>
      tester.getSize(find.byType(GlassSurface).first).height;

  Finder grabber() => find
      .descendant(
        of: find.byType(GlassSheetDragArea),
        matching: find.byType(GestureDetector),
      )
      .last;

  testWidgets('opens at the medium detent', (tester) async {
    await open(tester);
    expect(
      sheetHeight(tester),
      moreOrLessEquals(screen.height * GlassTokens.sheetMediumDetent),
    );
    expect(find.byType(GlassSheetDragArea), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('dragging the header up opens the whole screen',
      (tester) async {
    await open(tester);
    await tester.drag(find.text('Add'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(sheetHeight(tester), moreOrLessEquals(screen.height));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a small header drag settles back on the nearest detent',
      (tester) async {
    await open(tester);
    await tester.timedDrag(
      find.text('Add'),
      const Offset(0, -40),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(
      sheetHeight(tester),
      moreOrLessEquals(screen.height * GlassTokens.sheetMediumDetent),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('scrolling the content up expands the sheet first',
      (tester) async {
    await open(tester);
    await tester.drag(find.text('Item 1'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(sheetHeight(tester), moreOrLessEquals(screen.height));
    // The list itself has not scrolled away yet.
    expect(find.text('Item 0'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('tapping the grabber toggles medium and large', (tester) async {
    await open(tester);
    await tester.tap(grabber());
    await tester.pumpAndSettle();
    expect(sheetHeight(tester), moreOrLessEquals(screen.height));
    await tester.tap(grabber());
    await tester.pumpAndSettle();
    expect(
      sheetHeight(tester),
      moreOrLessEquals(screen.height * GlassTokens.sheetMediumDetent),
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('dragging the header down closes the sheet', (tester) async {
    await open(tester);
    await tester.drag(find.text('Add'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(GlassSheetDetents), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Reduce Motion: the grabber jumps to the detent',
      (tester) async {
    await open(
      tester,
      accessibility: const GlassAccessibility(reduceMotion: true),
    );
    await tester.tap(grabber());
    await tester.pump();
    expect(sheetHeight(tester), moreOrLessEquals(screen.height));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a plain glass sheet keeps its header without detents',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AdaptivePlatform.debugUseGlassOverride = true;
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveSheetScaffold(
              type: SheetType.bottomSheet,
              title: 'Sheet',
              body: SizedBox(height: 200),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GlassSheetDetents), findsNothing);
    // No drag handler without detents: the stock sheet drag still applies.
    expect(
      find.descendant(
        of: find.byType(GlassSheetDragArea),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Material sheet has no drag area', (tester) async {
    AdaptivePlatform.debugUseGlassOverride = false;
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveSheetScaffold(
              type: SheetType.bottomSheet,
              title: 'Sheet',
              body: SizedBox(height: 200),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GlassSheetDragArea), findsNothing);
  });
}
