import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

Widget _app(Widget child, {bool highContrast = false}) => MaterialApp(
      theme: GlassTheme.apply(ThemeData(useMaterial3: true)),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

int _backdropLayers(WidgetTester tester) =>
    tester.layers.whereType<BackdropFilterLayer>().length;

final _darwin = TargetPlatformVariant.only(TargetPlatform.macOS);
final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group('GlassToolbarGroup', () {
    testWidgets('one capsule, one blur, square buttons side by side',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(GlassToolbarGroup(children: [
        IconButton(onPressed: () => taps++, icon: const Icon(Icons.sync)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.functions)),
      ])));

      expect(find.byType(GlassSurface), findsOneWidget);
      expect(_backdropLayers(tester), 1);
      const size = GlassTokens.toolbarItemSizeMac;
      final capsule = tester.getSize(find.byType(GlassSurface));
      expect(capsule, const Size(size * 3, size));
      for (final button in tester.widgetList(find.byType(IconButton))) {
        expect(tester.getSize(find.byWidget(button)), const Size.square(size));
      }
      expect(
        tester.getSize(find.byIcon(Icons.sync)),
        const Size.square(GlassTokens.toolbarIconSizeMac),
      );

      await tester.tap(find.byIcon(Icons.sync));
      expect(taps, 1);
    }, variant: _darwin);

    testWidgets('iOS capsule is taller', (tester) async {
      await tester.pumpWidget(_app(GlassToolbarGroup(children: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.sync)),
      ])));
      expect(
        tester.getSize(find.byType(GlassSurface)),
        const Size.square(GlassTokens.toolbarItemSizeIos),
      );
    }, variant: _ios);

    testWidgets('hidden actions leave no empty glass', (tester) async {
      await tester.pumpWidget(_app(const GlassToolbarGroup(children: [
        SizedBox.shrink(),
        SizedBox.shrink(),
      ])));
      expect(tester.getSize(find.byType(GlassToolbarGroup)).width, 0);
      expect(_backdropLayers(tester), 0);
    }, variant: _darwin);

    testWidgets('opaque fallback paints no blur', (tester) async {
      await tester.pumpWidget(_app(
        GlassToolbarGroup(children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.sync)),
        ]),
        highContrast: true,
      ));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(_backdropLayers(tester), 0);
    }, variant: _darwin);

    testWidgets('selected uses the accent, disabled fades', (tester) async {
      await tester.pumpWidget(_app(GlassToolbarGroup(children: [
        IconButton(
          isSelected: true,
          onPressed: () {},
          icon: const Icon(Icons.link_off),
          selectedIcon: const Icon(Icons.link),
        ),
        const IconButton(onPressed: null, icon: Icon(Icons.edit)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.sync)),
      ])));
      final scheme = Theme.of(tester.element(find.byIcon(Icons.link))).colorScheme;
      Color? color(IconData icon) =>
          IconTheme.of(tester.element(find.byIcon(icon))).color;
      expect(color(Icons.link), scheme.primary);
      expect(color(Icons.sync), scheme.onSurface);
      expect(
        color(Icons.edit),
        scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity),
      );
    }, variant: _darwin);
  });

  group('GlassToolbarSearchField', () {
    testWidgets('types, clears, one blur', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      var clears = 0;
      await tester.pumpWidget(_app(SizedBox(
        width: 300,
        child: GlassToolbarSearchField(
          controller: controller,
          onChanged: changes.add,
          onClear: () => clears++,
          hintText: 'Search',
        ),
      )));

      expect(_backdropLayers(tester), 1);
      expect(
        tester.getSize(find.byType(GlassSurface)),
        const Size(300, GlassTokens.toolbarItemSizeMac),
      );
      expect(find.text('Search'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hk');
      expect(changes, ['hk']);
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      expect(clears, 1);
    }, variant: _darwin);
  });
}
