import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/scaffold.dart';

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

/// macOS title bar inset (`WindowHeaderContainer`) / iOS status bar.
const _macTop = 28.0;
const _iosTop = 47.0;

var _syncTaps = 0;

List<Widget> _pageActions() => [
      IconButton(onPressed: () => _syncTaps++, icon: const Icon(Icons.sync)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
    ];

Future<GlobalKey<CommonScaffoldState>> _pumpScaffold(
  WidgetTester tester, {
  double top = _macTop,
  bool highContrast = false,
  Widget body = const SizedBox.expand(),
  bool scrollUnderToolbar = false,
}) async {
  await AppLocalizations.load(const Locale('en'));
  final key = GlobalKey<CommonScaffoldState>();
  final padding = EdgeInsets.only(top: top);
  await tester.pumpWidget(ProviderScope(
    overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
    child: MaterialApp(
      theme: GlassTheme.apply(ThemeData(useMaterial3: true)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: padding,
          viewPadding: padding,
          highContrast: highContrast,
        ),
        child: child!,
      ),
      // Search / edit mode blocks system back through the app controller.
      home: Consumer(builder: (context, ref, _) {
        globalState.appController = AppController(context, ref);
        return CommonScaffold(
          key: key,
          title: 'Profiles',
          actions: _pageActions(),
          scrollUnderToolbar: scrollUnderToolbar,
          body: body,
        );
      }),
    ),
  ));
  return key;
}

void _enableSearch(GlobalKey<CommonScaffoldState> key, List<String> queries) {
  key.currentState!.updateSearchState(
    (_) => AppBarSearchState(onSearch: queries.add),
  );
}

/// A page that opts into scrolling under the toolbar the way `ToolsView`
/// does: its own top padding is [AdaptiveAppBar.topInset].
Widget _insetList() => Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.only(top: AdaptiveAppBar.topInset(context)),
        children: [
          for (var i = 0; i < 30; i++)
            SizedBox(height: 50, child: Text('Row $i')),
        ],
      ),
    );

Finder _fade() => find.descendant(
      of: find.byType(AdaptiveAppBar),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      ),
    );

double? _fontSize(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style?.fontSize;

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

  group('CommonScaffold glass toolbar', () {
    setUp(() => _syncTaps = 0);

    testWidgets('macOS: see-through bar, compact title, one capsule + search',
        (tester) async {
      final key = await _pumpScaffold(tester);
      _enableSearch(key, []);
      await tester.pump();

      expect(find.byType(AppBar), findsNothing);
      expect(
        tester.getSize(find.byType(AdaptiveAppBar)).height,
        _macTop + GlassTokens.toolbarHeightMac,
      );
      // Title: 15 pt at the leading edge.
      expect(_fontSize(tester, 'Profiles'), GlassTokens.toolbarTitleSizeMac);
      expect(
        tester.getTopLeft(find.text('Profiles')).dx,
        GlassTokens.toolbarInsetMac,
      );
      // Three actions share one capsule, search has its own: two blurs, none
      // for the bar itself.
      expect(find.byType(GlassToolbarGroup), findsNWidgets(2));
      expect(_backdropLayers(tester), 2);
      final search = tester.getRect(find.byType(GlassToolbarGroup).last);
      expect(search.right, 800 - GlassTokens.toolbarInsetMac);
      expect(search.width, GlassTokens.toolbarItemSizeMac);
      expect(
        tester.getSize(find.byType(GlassToolbarGroup).first).width,
        GlassTokens.toolbarItemSizeMac * 3,
      );
      // Capsules sit centred in the toolbar row, below the title bar.
      expect(
        search.center.dy,
        _macTop + GlassTokens.toolbarHeightMac / 2,
      );

      await tester.tap(find.byIcon(Icons.sync));
      expect(_syncTaps, 1);
    }, variant: _darwin);

    testWidgets('search: glass field replaces title and actions',
        (tester) async {
      final key = await _pumpScaffold(tester);
      final queries = <String>[];
      _enableSearch(key, queries);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();
      expect(find.byType(GlassToolbarSearchField), findsOneWidget);
      expect(find.text('Profiles'), findsNothing);
      expect(find.byIcon(Icons.sync), findsNothing);
      // Back capsule + field.
      expect(_backdropLayers(tester), 2);

      await tester.enterText(find.byType(TextField), 'hk');
      expect(queries, ['hk']);
      // Clear empties the field first, then leaves search mode.
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pump();
      expect(queries.last, '');
      expect(find.byType(GlassToolbarSearchField), findsOneWidget);
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pump();
      expect(find.byType(GlassToolbarSearchField), findsNothing);
      expect(find.text('Profiles'), findsOneWidget);

      // The back capsule also leaves search mode.
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();
      await tester.tap(find.byType(BackButtonIcon));
      await tester.pump();
      expect(find.byType(GlassToolbarSearchField), findsNothing);
    }, variant: _darwin);

    testWidgets('iOS: 44 pt bar under the status bar, centred 17 pt title',
        (tester) async {
      await _pumpScaffold(tester, top: _iosTop);
      expect(
        tester.getSize(find.byType(AdaptiveAppBar)).height,
        _iosTop + GlassTokens.toolbarHeightIos,
      );
      expect(_fontSize(tester, 'Profiles'), GlassTokens.toolbarTitleSizeIos);
      expect(tester.getCenter(find.text('Profiles')).dx, 400);
      expect(_backdropLayers(tester), 1);
    }, variant: _ios);

    testWidgets('Reduce Transparency / Increase Contrast: no blur at all',
        (tester) async {
      final key = await _pumpScaffold(tester, highContrast: true);
      _enableSearch(key, []);
      await tester.pump();
      expect(find.byType(GlassToolbarGroup), findsNWidgets(2));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(_backdropLayers(tester), 0);
    }, variant: _darwin);

    testWidgets('pushed page gets a round back capsule', (tester) async {
      await _pumpScaffold(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const CommonScaffold(
          title: 'Providers',
          body: SizedBox.expand(),
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(BackButton),
          matching: find.byType(GlassToolbarGroup),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Providers'), findsNothing);
      expect(find.text('Profiles'), findsOneWidget);
    }, variant: _darwin);

    testWidgets('Material keeps its AppBar', (tester) async {
      await _pumpScaffold(tester, top: 0);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(GlassToolbar), findsNothing);
      expect(find.byType(GlassSurface), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('CommonScaffold scrollUnderToolbar', () {
    const macBar = _macTop + GlassTokens.toolbarHeightMac;
    setUp(() => _syncTaps = 0);

    testWidgets('macOS: body starts at the window top, content scrolls under',
        (tester) async {
      await _pumpScaffold(tester, body: _insetList(), scrollUnderToolbar: true);

      expect(tester.getRect(find.byType(ListView)).top, 0);
      // The first row starts right below the bar, not under it.
      expect(tester.getTopLeft(find.text('Row 0')).dy, macBar);
      expect(_fade(), findsOneWidget);
      // Still no blur for the bar itself: three actions in one capsule.
      expect(_backdropLayers(tester), 1);

      final row2 = tester.getTopLeft(find.text('Row 2')).dy;
      expect(row2, macBar + 100);
      await tester.drag(find.text('Row 5'), const Offset(0, -150));
      await tester.pump();
      // Row 2 now sits under the bar instead of being clipped at its edge.
      final scrolled = tester.getTopLeft(find.text('Row 2')).dy;
      expect(scrolled, lessThan(row2 - 100));
      expect(scrolled, lessThan(macBar));
      expect(scrolled, greaterThan(0));
      // Buttons above the scrolled content still take the taps.
      await tester.tap(find.byIcon(Icons.sync));
      expect(_syncTaps, 1);
    }, variant: _darwin);

    testWidgets('iOS: same under the status bar', (tester) async {
      await _pumpScaffold(
        tester,
        top: _iosTop,
        body: _insetList(),
        scrollUnderToolbar: true,
      );
      expect(tester.getRect(find.byType(ListView)).top, 0);
      expect(
        tester.getTopLeft(find.text('Row 0')).dy,
        _iosTop + GlassTokens.toolbarHeightIos,
      );
      expect(_fade(), findsOneWidget);
    }, variant: _ios);

    testWidgets('without the flag the page stays below the bar',
        (tester) async {
      await _pumpScaffold(tester, body: _insetList());
      expect(tester.getRect(find.byType(ListView)).top, macBar);
      expect(tester.getTopLeft(find.text('Row 0')).dy, macBar);
      expect(_fade(), findsNothing);
    }, variant: _darwin);

    testWidgets('keyword chips sit below the bar, the page adds no inset',
        (tester) async {
      final key = await _pumpScaffold(
        tester,
        body: _insetList(),
        scrollUnderToolbar: true,
      );
      key.currentState!.addKeyword('hk');
      await tester.pump();

      final chips = tester.getRect(find.byType(Wrap));
      expect(chips.top, macBar + 16);
      expect(
        tester.getTopLeft(find.text('Row 0')).dy,
        tester.getRect(find.byType(ListView)).top,
      );
      expect(tester.getRect(find.byType(ListView)).top, chips.bottom + 16);
    }, variant: _darwin);

    testWidgets('Material ignores the flag', (tester) async {
      await _pumpScaffold(
        tester,
        top: 0,
        body: _insetList(),
        scrollUnderToolbar: true,
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.getRect(find.byType(ListView)).top, kToolbarHeight);
      expect(tester.getTopLeft(find.text('Row 0')).dy, kToolbarHeight);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('AdaptiveAppBar', () {
    Widget bar({
      VoidCallback? onWindowDrag,
      VoidCallback? onTap,
      bool scrollEdge = false,
    }) =>
        MaterialApp(
          theme: GlassTheme.apply(ThemeData(useMaterial3: true)),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: AdaptiveAppBar(
                onWindowDrag: onWindowDrag,
                scrollEdge: scrollEdge,
                child: GlassToolbar(
                  title: const Text('Title'),
                  actions: [
                    IconButton(
                      onPressed: onTap,
                      icon: const Icon(Icons.sync),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    Finder gradient() => _fade();

    testWidgets('macOS: drag moves the window, taps reach the buttons',
        (tester) async {
      var drags = 0;
      var taps = 0;
      await tester.pumpWidget(bar(
        onWindowDrag: () => drags++,
        onTap: () => taps++,
      ));
      await tester.tap(find.byIcon(Icons.sync));
      expect(taps, 1);
      expect(drags, 0);
      await tester.drag(find.text('Title'), const Offset(40, 0));
      expect(drags, 1);
    }, variant: _darwin);

    testWidgets('scroll edge fades below the bar, no hairline',
        (tester) async {
      await tester.pumpWidget(bar(scrollEdge: true));
      expect(gradient(), findsOneWidget);
      expect(
        tester.getRect(gradient()).bottom,
        tester.getRect(find.byType(AdaptiveAppBar)).bottom +
            GlassTokens.toolbarFadeExtent,
      );
      // The fade never takes taps meant for the content below.
      expect(
        find.ancestor(of: gradient(), matching: find.byType(IgnorePointer)),
        findsWidgets,
      );

      await tester.pumpWidget(bar());
      expect(gradient(), findsNothing);
    }, variant: _darwin);

    testWidgets('capsule inside a blurring surface does not blur again',
        (tester) async {
      await tester.pumpWidget(_app(GlassSurface(
        child: GlassToolbarGroup(children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.sync)),
        ]),
      )));
      expect(find.byType(GlassSurface), findsNWidgets(2));
      expect(_backdropLayers(tester), 1);
    }, variant: _darwin);
  });
}
