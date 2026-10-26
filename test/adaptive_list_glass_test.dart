import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

/// Grouped-list primitives of the Darwin forms (switch, sections, rows,
/// content buttons) and the pop-up button with its checked menu: native
/// NSMenu on macOS, scrolling glass menu on iOS.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void useGlass() => AdaptivePlatform.debugUseGlassOverride = true;

  tearDown(() {
    messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel, null);
    AdaptivePlatform.debugUseGlassOverride = null;
    GlassFlags.backdropBlurEnabled = true;
  });

  Widget app(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: brightness,
          ),
        ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [child],
          ),
        ),
      );

  group('AdaptiveSwitch', () {
    testWidgets('Material: plain Switch', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        app(AdaptiveSwitch(value: true, onChanged: (_) {})),
      );
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('iOS: Cupertino switch in the accent, toggles', (tester) async {
      useGlass();
      var value = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            AdaptiveSwitch(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      final control = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      final context = tester.element(find.byType(CupertinoSwitch));
      expect(control.activeTrackColor, Theme.of(context).colorScheme.primary);
      expect(find.byType(FittedBox), findsNothing);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('macOS: scaled down to the AppKit switch', (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(Align(child: AdaptiveSwitch(value: true, onChanged: (_) {}))),
      );
      final size = tester.getSize(find.byType(FittedBox));
      expect(
        size.height,
        closeTo(
          GlassTokens.switchBoxHeightIos *
              GlassTokens.switchTrackHeightMac /
              GlassTokens.switchTrackHeightIos,
          0.01,
        ),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('GlassListSection', () {
    Widget section({int rows = 3}) => GlassListSection(
          header: 'Header',
          footer: 'Footer',
          children: [
            for (var i = 0; i < rows; i++)
              GlassListRow(
                leading: const Icon(Icons.link_rounded),
                title: Text('Row $i'),
                subtitle: const Text('Subtitle'),
                accessory: GlassRowAccessory.chevron,
                onTap: () {},
              ),
          ],
        );

    testWidgets('flat card, hairlines between rows, no blur', (tester) async {
      useGlass();
      await tester.pumpWidget(app(section()));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Footer'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      // Two hairlines for three rows, starting at the row text.
      final hairlines = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.height == GlassTokens.hairlineWidth,
      );
      expect(hairlines, findsNWidgets(2));
      final rowText = tester.getTopLeft(find.text('Row 1')).dx;
      expect(tester.getTopLeft(hairlines.first).dx, closeTo(rowText, 0.01));
      expect(
        tester.getSize(find.byType(GlassListRow).first).height,
        greaterThanOrEqualTo(GlassTokens.listRowMinHeightIos),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('rows react to taps; disabled rows do not', (tester) async {
      useGlass();
      final taps = <String>[];
      await tester.pumpWidget(
        app(
          GlassListSection(
            children: [
              GlassListRow(
                title: const Text('On'),
                onTap: () => taps.add('on'),
              ),
              GlassListRow(
                title: const Text('Off'),
                enabled: false,
                onTap: () => taps.add('off'),
              ),
              const GlassListRow(
                title: Text('Choice'),
                accessory: GlassRowAccessory.checkmark,
                selected: true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('On'));
      await tester.tap(find.text('Off'));
      expect(taps, ['on']);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        tester.getSize(find.byType(GlassListRow).first).height,
        GlassTokens.listRowMinHeightMac,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('opaque fill with the blur kill switch', (tester) async {
      useGlass();
      Color fill() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(GlassListSection),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is DecoratedBox &&
                      widget.decoration is ShapeDecoration &&
                      (widget.decoration as ShapeDecoration).color != null,
                ),
              )
              .first,
        );
        return (box.decoration as ShapeDecoration).color!;
      }

      await tester.pumpWidget(app(section(), brightness: Brightness.dark));
      expect(fill().a, lessThan(1));
      GlassFlags.backdropBlurEnabled = false;
      await tester
          .pumpWidget(app(section(rows: 2), brightness: Brightness.dark));
      expect(fill().a, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('GlassButton', () {
    testWidgets('busy shows a spinner and ignores taps', (tester) async {
      useGlass();
      var taps = 0;
      Widget button({required bool busy}) => app(
            Align(
              child: GlassButton(
                label: 'Decrypt',
                icon: Icons.lock_open_rounded,
                busy: busy,
                onPressed: () => taps++,
              ),
            ),
          );
      await tester.pumpWidget(button(busy: false));
      expect(
        tester.getSize(find.byType(GlassButton)).height,
        GlassTokens.buttonHeightIos,
      );
      await tester.tap(find.text('Decrypt'));
      expect(taps, 1);
      await tester.pumpWidget(button(busy: true));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
      await tester.tap(find.text('Decrypt'));
      expect(taps, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('GlassPopUpButton', () {
    Widget picker(List<String> options, ValueChanged<String> onChanged,
            {String? value, String? errorText}) =>
        app(
          GlassPopUpButton<String>(
            label: 'Target',
            value: value,
            options: options,
            textBuilder: (option) => option,
            onChanged: onChanged,
            errorText: errorText,
          ),
        );

    testWidgets(
        'macOS: native menu with the current item checked over the '
        'control', (tester) async {
      useGlass();
      Map<Object?, Object?>? args;
      messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
          (call) async {
        args = call.arguments as Map<Object?, Object?>;
        return 2;
      });
      String? picked;
      await tester.pumpWidget(
        picker(['DIRECT', 'Proxy', 'REJECT'], (v) => picked = v,
            value: 'Proxy'),
      );
      expect(find.text('Proxy'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
      await tester.tap(find.byType(GlassPopUpButton<String>));
      await tester.pumpAndSettle();
      expect(picked, 'REJECT');
      final items = (args!['items']! as List).cast<Map<Object?, Object?>>();
      expect([for (final item in items) item['checked']], [false, true, false]);
      expect(args!['positioning'], 1);
      final top = tester.getTopLeft(find.byType(GlassPopUpButton<String>)).dy;
      expect(args!['y'], top);
      // No Flutter menu on top of the native one.
      expect(find.byType(GlassSurface), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('macOS: glass menu when the native channel is missing',
        (tester) async {
      useGlass();
      messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
          (call) async => throw MissingPluginException());
      String? picked;
      await tester.pumpWidget(
        picker(['DIRECT', 'Proxy'], (v) => picked = v, value: 'DIRECT'),
      );
      await tester.tap(find.byType(GlassPopUpButton<String>));
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsOneWidget);
      await tester.tap(find.text('Proxy').last);
      await tester.pumpAndSettle();
      expect(picked, 'Proxy');
      expect(find.byType(GlassSurface), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets(
        'iOS: one blurred menu, checkmark, scrolls to the current '
        'value of a long list', (tester) async {
      useGlass();
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
          (call) async {
        nativeCalls++;
        return 0;
      });
      final options = [for (var i = 0; i < 200; i++) 'Node $i'];
      String? picked;
      await tester.pumpWidget(
        picker(options, (v) => picked = v, value: 'Node 150'),
      );
      await tester.tap(find.byType(GlassPopUpButton<String>));
      await tester.pumpAndSettle();
      expect(nativeCalls, 0);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      // The menu fits the screen and starts at the checked row.
      final menu = tester.getRect(find.byType(GlassSurface));
      final screen = tester.getRect(find.byType(Scaffold));
      expect(menu.bottom, lessThanOrEqualTo(screen.bottom));
      final check = find.descendant(
        of: find.byType(GlassSurface),
        matching: find.byIcon(Icons.check_rounded),
      );
      expect(check, findsOneWidget);
      final checkRect = tester.getRect(check);
      expect(menu.contains(checkRect.center), isTrue);
      await tester.tap(find.text('Node 151'));
      await tester.pumpAndSettle();
      expect(picked, 'Node 151');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('error text below the control', (tester) async {
      useGlass();
      await tester.pumpWidget(
        picker(const [], (_) {}, errorText: 'Required'),
      );
      expect(find.text('Required'), findsOneWidget);
      // No options: disabled, opens nothing.
      await tester.tap(find.byType(GlassPopUpButton<String>));
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('context menus without choices keep no checkmark column',
      (tester) async {
    useGlass();
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => AdaptiveContextMenu.showGlass(
              context: context,
              anchor: const Rect.fromLTWH(20, 100, 40, 40),
              entries: [
                AdaptiveMenuEntry(label: 'Edit', onPressed: () {}),
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(
      tester.getTopLeft(find.byType(GlassSurface)).dy,
      140 + GlassTokens.menuAnchorGap,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('native menu entries default to unchecked', () {
    expect(const AdaptiveMenuEntry(label: 'x').checked, isFalse);
  });
}
