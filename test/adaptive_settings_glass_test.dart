import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/list.dart';

/// Darwin settings lists: the app-wide `ListItem` / `ListHeader` /
/// `generateSection` / `generateListView` render Apple grouped lists inside
/// a [GlassListScope] and stay Material everywhere else.
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

  Widget app(Widget body, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: brightness,
          ),
        ),
        home: Scaffold(body: body),
      );

  final hairlines = find.byWidgetPredicate(
    (widget) => widget is SizedBox && widget.height == GlassTokens.hairlineWidth,
  );

  group('Material', () {
    testWidgets('ListItem stays a ListTile with Material controls',
        (tester) async {
      await tester.pumpWidget(
        app(
          generateListView([
            ...generateSection(
              title: 'Section',
              items: [
                ListItem.switchItem(
                  title: const Text('Switch'),
                  delegate: SwitchDelegate(value: true, onChanged: (_) {}),
                ),
                ListItem<int>.radio(
                  title: const Text('Radio'),
                  delegate: RadioDelegate(
                    value: 1,
                    groupValue: 1,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ]),
        ),
      );
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(Radio<int>), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(GlassListSection), findsNothing);
      expect(find.byType(GlassListRow), findsNothing);
    }, variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }));
  });

  group('Darwin rows', () {
    testWidgets('outside a glass list a ListItem keeps the Material tile',
        (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          ListView(
            children: [
              ListItem.switchItem(
                title: const Text('Plain list'),
                delegate: SwitchDelegate(value: false, onChanged: (_) {}),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(GlassListRow), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('section: one card, header, hairlines, no Divider, no blur',
        (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          generateListView([
            ...generateSection(
              title: 'General',
              items: [
                for (var i = 0; i < 3; i++)
                  ListItem(
                    leading: const Icon(Icons.info_outline),
                    title: Text('Row $i'),
                    onTap: () {},
                  ),
              ],
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassListSection), findsOneWidget);
      expect(find.byType(GlassListRow), findsNWidgets(3));
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('General'), findsOneWidget);
      expect(hairlines, findsNWidgets(2));
      // Hairlines start at the row text, after the leading symbol.
      final rowText = tester.getTopLeft(find.text('Row 1')).dx;
      expect(tester.getTopLeft(hairlines.first).dx, closeTo(rowText, 0.01));
    }, variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }));

    testWidgets('rows inside wrapper widgets still inset the hairline',
        (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          generateListView([
            ...generateSection(
              items: const [_WrappedRow('A'), _WrappedRow('B')],
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      final rowText = tester.getTopLeft(find.text('B')).dx;
      expect(tester.getTopLeft(hairlines.first).dx, closeTo(rowText, 0.01));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('header + bare rows in generateListView form one section',
        (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          generateListView([
            const ListHeader(title: 'Header'),
            ListItem(title: const Text('One'), onTap: () {}),
            const Divider(),
            ListItem(title: const Text('Two'), onTap: () {}),
            const _WrappedRow('Alone'),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      // [Header, One, Two] and the wrapper on its own.
      expect(find.byType(GlassListSection), findsNWidgets(2));
      expect(find.byType(GlassSectionHeader), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(hairlines, findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('switch row: AdaptiveSwitch, a tap on the row toggles',
        (tester) async {
      useGlass();
      var value = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => app(
            generateListView([
              ListItem.switchItem(
                title: const Text('Switch'),
                delegate: SwitchDelegate(
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ]),
          ),
        ),
      );
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    }, variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }));

    testWidgets('radio and checkbox rows: a checkmark instead of a control',
        (tester) async {
      useGlass();
      int? picked;
      bool? checked;
      await tester.pumpWidget(
        app(
          generateListView([
            ...generateSection(
              items: [
                for (final i in [1, 2])
                  ListItem<int>.radio(
                    title: Text('Radio $i'),
                    delegate: RadioDelegate(
                      value: i,
                      groupValue: 1,
                      onChanged: (value) => picked = value,
                    ),
                  ),
                ListItem.checkbox(
                  title: const Text('Check'),
                  delegate: CheckboxDelegate(
                    value: true,
                    onChanged: (value) => checked = value,
                  ),
                ),
              ],
            ),
          ]),
        ),
      );
      expect(find.byType(Radio<int>), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      await tester.tap(find.text('Radio 2'));
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(picked, 2);
      expect(checked, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('open / next rows get a chevron', (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          generateListView([
            ...generateSection(
              items: [
                const ListItem.open(
                  title: Text('Open'),
                  delegate: OpenDelegate(
                    title: 'Open',
                    widget: SizedBox(),
                  ),
                ),
                const ListItem.next(
                  title: Text('Next'),
                  delegate: NextDelegate(
                    title: 'Next',
                    widget: SizedBox(),
                  ),
                ),
              ],
            ),
          ]),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('input row: the value moves to the trailing edge',
        (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          generateListView([
            ListItem.input(
              title: const Text('Test URL'),
              subtitle: const Text('https://example.com'),
              delegate: InputDelegate(
                title: 'Test URL',
                value: 'https://example.com',
                onChanged: (_) {},
              ),
            ),
          ]),
        ),
      );
      final row = tester.widget<GlassListRow>(find.byType(GlassListRow));
      expect(row.subtitle, isNull);
      expect(row.value, isNotNull);
      expect(find.text('https://example.com'), findsOneWidget);
      expect(
        tester.getTopRight(find.text('https://example.com')).dx,
        greaterThan(tester.getTopRight(find.text('Test URL')).dx),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    Widget optionsList(ValueChanged<String?> onChanged) => app(
          generateListView([
            ListItem<String>.options(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: const Text('English'),
              delegate: OptionsDelegate<String>(
                title: 'Language',
                options: const ['System', 'English', 'Русский'],
                textBuilder: (value) => value,
                value: 'English',
                onChanged: onChanged,
              ),
            ),
          ]),
        );

    testWidgets('options row on macOS: native NSMenu, current one checked',
        (tester) async {
      useGlass();
      Map<Object?, Object?>? args;
      messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
          (call) async {
        args = call.arguments as Map<Object?, Object?>;
        return 2;
      });
      String? picked;
      await tester.pumpWidget(optionsList((value) => picked = value));
      // The value is shown once, at the trailing edge, with the pop-up symbol.
      expect(find.text('English'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(picked, 'Русский');
      final items = (args!['items']! as List).cast<Map<Object?, Object?>>();
      expect([for (final item in items) item['checked']], [false, true, false]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('options row on iOS: glass menu, no dialog', (tester) async {
      useGlass();
      String? picked;
      await tester.pumpWidget(optionsList((value) => picked = value));
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(picked, 'System');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('trailing Material buttons become capsules', (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          generateListView([
            ListItem(
              title: const Text('Backup'),
              trailing: FilledButton(
                onPressed: () {},
                child: const Text('Sync'),
              ),
            ),
          ]),
        ),
      );
      final context = tester.element(find.text('Sync'));
      final style = Theme.of(context).filledButtonTheme.style!;
      expect(style.shape!.resolve({}), isA<StadiumBorder>());
      expect(style.elevation!.resolve({}), 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('destructive row: title in the system red', (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          GlassListView(
            children: [
              GlassListSection(
                children: [
                  GlassListRow(
                    title: const Text('Reset'),
                    destructive: true,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final text = tester.widget<RichText>(
        find.descendant(of: find.text('Reset'), matching: find.byType(RichText)),
      );
      expect(text.text.style?.color, CupertinoColors.systemRed.color);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('Fallbacks', () {
    testWidgets('kill switch: opaque section fill, still no blur',
        (tester) async {
      useGlass();
      GlassFlags.backdropBlurEnabled = false;
      await tester.pumpWidget(
        app(
          generateListView([
            for (var i = 0; i < 120; i++)
              ListItem(title: Text('Row $i'), onTap: () {}),
          ]),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      final fills = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(GlassListSection),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<ShapeDecoration>()
          .map((decoration) => decoration.color)
          .whereType<Color>();
      expect(fills, isNotEmpty);
      expect(fills.every((color) => color.a == 1), isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    Iterable<Color> sectionFills(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassListSection),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .map((decoration) => decoration.color)
        .whereType<Color>();

    testWidgets('Reduce Transparency: opaque section fill, back to glass after',
        (tester) async {
      useGlass();
      final accessibility = GlassAccessibilityController();
      addTearDown(accessibility.dispose);
      accessibility.value = const GlassAccessibility(reduceTransparency: true);
      await tester.pumpWidget(
        GlassAccessibilityScope(
          controller: accessibility,
          child: app(
            generateListView([
              const ListHeader(title: 'Group'),
              for (var i = 0; i < 3; i++)
                ListItem(title: Text('Row $i'), onTap: () {}),
            ]),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(sectionFills(tester), isNotEmpty);
      expect(sectionFills(tester).every((color) => color.a == 1), isTrue);

      accessibility.value = GlassAccessibility.fallback;
      await tester.pump();
      expect(sectionFills(tester).any((color) => color.a < 1), isTrue);
      expect(find.byType(BackdropFilter), findsNothing);
    }, variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }));

    testWidgets('a 120-row list scrolls to the end with no blur anywhere',
        (tester) async {
      useGlass();
      await tester.pumpWidget(
        app(
          generateListView([
            for (var i = 0; i < 120; i++)
              ListItem(
                leading: const Icon(Icons.info_outline),
                title: Text('Row $i'),
                onTap: () {},
              ),
          ]),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Row 119'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Row 119'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    }, variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }));
  });
}

/// A settings item as the pages write them: a widget that builds a
/// `ListItem` with a leading symbol.
class _WrappedRow extends StatelessWidget {
  const _WrappedRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => ListItem(
        leading: const Icon(Icons.info_outline),
        title: Text(label),
        onTap: () {},
      );
}
