import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/card.dart';
import 'package:meowclash/widgets/input.dart';
import 'package:meowclash/widgets/null_status.dart';

import 'settings_test_support.dart';

/// Darwin list editors (`ListInputPage` / `MapInputPage`: DNS, network and
/// general lists, the proxies icon map): one grouped section of
/// `GlassListRow`s in a `GlassReorderableSection`, tap to edit, trash to
/// remove, long press to reorder, never blurred. The Material editors are
/// pinned by `material_list_editors_golden_test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 800);
  const darwin = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  });

  setUpAll(() => setUpSettingsEnvironment('glass_list_editors'));
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  /// A list page that keeps its edits, like the Riverpod-backed callers.
  Widget listEditor(
    List<String> initial, {
    ValueChanged<List<String>>? changed,
  }) {
    var items = initial;
    return StatefulBuilder(
        builder: (_, setState) => ListInputPage(
          title: 'Nameserver',
          items: items,
          titleBuilder: Text.new,
          onChange: (next) {
            setState(() => items = next);
            changed?.call(next);
          },
        ),
      );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    GlassAccessibility accessibility = GlassAccessibility.fallback,
    Brightness brightness = Brightness.light,
  }) async {
    AdaptivePlatform.debugUseGlassOverride = true;
    await setUpSettingsScreen(tester, size);
    // A fresh tree: the accessibility scope reads its controller once.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(settingsHost(
      brightness,
      (_) => GlassAccessibilityScope(
        controller: GlassAccessibilityController()..value = accessibility,
        child: page,
      ),
    ));
    await pumpSettingsFrames(tester);
    expect(tester.takeException(), isNull);
  }

  Finder rowOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(GlassListRow));

  Iterable<String> titles(WidgetTester tester) => tester
      .widgetList<GlassListRow>(find.byType(GlassListRow))
      .map((row) => ((row.title as Text).data)!);

  testWidgets('rows in one grouped section, trash symbols, no Material cards',
      (tester) async {
    await pump(tester, listEditor(['a', 'b', 'c']));
    expect(find.byType(GlassReorderableSection), findsOneWidget);
    expect(find.byType(GlassListRow), findsNWidgets(3));
    expect(titles(tester), ['a', 'b', 'c']);
    expect(find.byType(CommonCard), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(
      find.descendant(
        of: find.byType(GlassListRow),
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
      findsNWidgets(3),
    );
    // Hairlines between the rows only.
    expect(
      find.descendant(
        of: find.byType(GlassReorderableSection),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == GlassTokens.hairlineWidth,
        ),
      ),
      findsNWidgets(2),
    );
    // Never blurred: the list scrolls.
    expect(
      find.descendant(
        of: find.byType(GlassReorderableSection),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  }, variant: darwin);

  testWidgets('the first row sits below the toolbar inset of the list',
      (tester) async {
    await pump(tester, listEditor(['a']));
    final top = tester.getTopLeft(find.byType(GlassListRow)).dy;
    expect(top, greaterThanOrEqualTo(GlassListSection.listPadding.top));
    final left = tester.getTopLeft(find.byType(GlassListRow)).dx;
    expect(left, GlassListSection.listPadding.left);
  }, variant: darwin);

  testWidgets('tap edits in the glass dialog, trash removes', (tester) async {
    List<String>? changed;
    await pump(
      tester,
      listEditor(['a', 'b'], changed: (next) => changed = next),
    );

    await tester.tap(rowOf('a'));
    await tester.pumpAndSettle();
    expect(find.byType(AddDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'z');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(changed, ['z', 'b']);

    await tester.tap(
      find.descendant(
        of: rowOf('z'),
        matching: find.byType(GlassIconButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(changed, ['b']);
    expect(titles(tester), ['b']);
  }, variant: darwin);

  testWidgets('the add button appends through the same dialog',
      (tester) async {
    List<String>? changed;
    await pump(tester, listEditor(['a'], changed: (next) => changed = next));
    await tester.tap(find.byType(AdaptiveFloatingButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'b');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(changed, ['a', 'b']);
    expect(titles(tester), ['a', 'b']);
  }, variant: darwin);

  testWidgets('empty: the glass placeholder', (tester) async {
    await pump(tester, listEditor([]));
    expect(find.byType(AdaptiveEmptyState), findsOneWidget);
    expect(find.byType(NullStatus), findsNothing);
    expect(find.byType(GlassReorderableSection), findsNothing);
  }, variant: darwin);

  // The largest scale among the transforms above [finder].
  double liftOf(WidgetTester tester, Finder finder) => tester
      .widgetList<Transform>(
        find.ancestor(of: finder, matching: find.byType(Transform)),
      )
      .map((t) => t.transform.getMaxScaleOnAxis())
      .fold(1, (a, b) => a > b ? a : b);

  testWidgets('long press lifts a row and drops it in a new place',
      (tester) async {
    for (final reduceMotion in [false, true]) {
      List<String>? changed;
      await pump(
        tester,
        listEditor(['a', 'b', 'c'], changed: (next) => changed = next),
        accessibility: GlassAccessibility(reduceMotion: reduceMotion),
      );
      final rowHeight = tester.getSize(rowOf('a')).height;
      final gesture = await tester.startGesture(tester.getCenter(rowOf('a')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(Offset(0, rowHeight * 0.6));
      await tester.pump();
      await gesture.moveBy(Offset(0, rowHeight * 0.6));
      await tester.pump(const Duration(milliseconds: 500));

      // The lifted copy is an opaque card with the floating shadow.
      final shadow = GlassTokens.floatingShadow(Brightness.light);
      final lifted = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            listEquals((w.decoration as ShapeDecoration).shadows, shadow),
      );
      expect(lifted, findsOneWidget);
      expect((tester.widget<DecoratedBox>(lifted).decoration as ShapeDecoration)
          .color
          ?.a, 1);
      final lift = liftOf(
        tester,
        find.descendant(of: lifted, matching: find.text('a')),
      );
      expect(
        lift,
        moreOrLessEquals(reduceMotion ? 1 : GlassTokens.listRowDragScale),
        reason: 'reduceMotion: $reduceMotion',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(changed, ['b', 'a', 'c'], reason: 'reduceMotion: $reduceMotion');
      expect(titles(tester), ['b', 'a', 'c']);
    }
  }, variant: darwin);

  testWidgets('a short tap does not start a drag', (tester) async {
    List<String>? changed;
    await pump(tester, listEditor(['a', 'b'], changed: (next) => changed = next));
    await tester.drag(rowOf('a'), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(changed, isNull);
  }, variant: darwin);

  testWidgets('Reduce Transparency: the section card is opaque',
      (tester) async {
    Color? fillOf(WidgetTester tester) => tester
        .widgetList<DecoratedSliver>(find.byType(DecoratedSliver))
        .map((s) => s.decoration)
        .whereType<ShapeDecoration>()
        .map((d) => d.color)
        .firstWhere((c) => c != null);

    await pump(tester, listEditor(['a']));
    expect(fillOf(tester)!.a, lessThan(1));

    await pump(
      tester,
      listEditor(['a']),
      accessibility: const GlassAccessibility(reduceTransparency: true),
    );
    expect(fillOf(tester)!.a, 1);
  }, variant: darwin);

  testWidgets('long lists build lazily and scroll to the end', (tester) async {
    final items = [for (var i = 0; i < 150; i++) 'host-$i.example'];
    await pump(tester, listEditor(items));
    expect(
      find.byType(GlassListRow).evaluate().length,
      lessThan(items.length ~/ 2),
    );
    await tester.scrollUntilVisible(
      find.text('host-149.example'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('host-149.example'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: darwin);

  testWidgets('map: subtitle values, the icon scaled to the row symbol',
      (tester) async {
    await pump(
      tester,
      MapInputPage(
        title: 'Icons',
        map: const {'^HK': 'https://example.com/hk.png', '^US': 'us'},
        titleBuilder: (e) => Text(e.key),
        subtitleBuilder: (e) => Text(e.value),
        leadingBuilder: (_) => const SizedBox.square(dimension: 42),
        onChange: (_) {},
      ),
    );
    expect(find.byType(GlassListRow), findsNWidgets(2));
    expect(find.text('us'), findsOneWidget);
    final leadingSize = defaultTargetPlatform == TargetPlatform.macOS
        ? GlassTokens.listRowLeadingSizeMac
        : GlassTokens.listRowLeadingSizeIos;
    final icon = tester.getSize(find.byType(FittedBox).first);
    expect(icon.width, lessThanOrEqualTo(leadingSize));
    // Hairlines start at the row text, after the symbol.
    final hairline = find.descendant(
      of: find.byType(GlassReorderableSection),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == GlassTokens.hairlineWidth,
      ),
    );
    expect(
      tester.getTopLeft(hairline).dx,
      greaterThan(GlassListSection.listPadding.left + leadingSize),
    );
  }, variant: darwin);

  testWidgets('Material keeps the reorderable cards', (tester) async {
    AdaptivePlatform.debugUseGlassOverride = false;
    await setUpSettingsScreen(tester, size);
    await tester.pumpWidget(
      settingsHost(Brightness.light, (_) => listEditor(['a', 'b'])),
    );
    await pumpSettingsFrames(tester);
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byType(CommonCard), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    expect(find.byType(GlassReorderableSection), findsNothing);
    expect(find.byType(GlassListRow), findsNothing);
  });
}
