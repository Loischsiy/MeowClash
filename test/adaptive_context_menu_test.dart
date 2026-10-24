import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/models/common.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/popup.dart';

final _calls = <String>[];

List<PopupMenuItemData> _items() => [
      PopupMenuItemData(
        icon: Icons.edit_outlined,
        label: 'Edit',
        onPressed: () => _calls.add('edit'),
      ),
      const PopupMenuItemData(
        icon: Icons.undo,
        label: 'Undo',
        onPressed: null,
      ),
      PopupMenuItemData(
        icon: Icons.delete_outlined,
        label: 'Delete',
        type: PopupMenuItemType.danger,
        onPressed: () => _calls.add('delete'),
      ),
    ];

Widget _app({bool disableAnimations = false}) => MaterialApp(
      // Above the Navigator, so the popup route sees it too.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: CommonPopupBox(
            targetBuilder: (open) => IconButton(
              onPressed: () => open(),
              icon: const Icon(Icons.more_vert),
            ),
            popup: CommonPopupMenu(items: _items()),
          ),
        ),
      ),
    );

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

void _useGlass(TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  AdaptivePlatform.debugUseGlassOverride = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger;

  setUp(_calls.clear);

  tearDown(() {
    messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel, null);
    AdaptivePlatform.debugUseGlassOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Material: unchanged Card menu, native channel unused',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var nativeCalls = 0;
    messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
        (call) async {
      nativeCalls++;
      return 0;
    });
    await tester.pumpWidget(_app());
    await _openMenu(tester);
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(GlassSurface), findsNothing);
    expect(find.byType(GlassMenuTransition), findsNothing);
    expect(nativeCalls, 0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: glass menu with exactly one blur, red delete row',
      (tester) async {
    _useGlass(TargetPlatform.iOS);
    await tester.pumpWidget(_app());
    await _openMenu(tester);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    // No Opacity stacked over the menu's BackdropFilter.
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    final delete = tester.widget<Text>(find.text('Delete'));
    expect(delete.style?.color, CupertinoColors.systemRed.color);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(_calls, ['delete']);
    expect(find.byType(GlassSurface), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: disabled row ignores taps and keeps the menu open',
      (tester) async {
    _useGlass(TargetPlatform.iOS);
    await tester.pumpWidget(_app());
    await _openMenu(tester);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(_calls, isEmpty);
    expect(find.byType(GlassSurface), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: Reduce Motion opens the menu without scaling',
      (tester) async {
    _useGlass(TargetPlatform.iOS);
    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GlassMenuTransition),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS: NSMenu via channel, chosen index runs the item',
      (tester) async {
    _useGlass(TargetPlatform.macOS);
    MethodCall? received;
    messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
        (call) async {
      received = call;
      return 2;
    });
    await tester.pumpWidget(_app());
    await _openMenu(tester);

    expect(received?.method, 'show');
    final args = received!.arguments as Map<Object?, Object?>;
    final button = tester.getRect(find.byType(IconButton));
    expect(args['x'], button.left);
    expect(args['y'], button.bottom + GlassTokens.menuAnchorGap);
    final items = (args['items']! as List).cast<Map<Object?, Object?>>();
    expect(items.map((i) => i['title']), ['Edit', 'Undo', 'Delete']);
    expect(items.map((i) => i['symbol']), ['pencil', 'arrow.uturn.backward', 'trash']);
    expect(items.map((i) => i['enabled']), [true, false, true]);
    expect(items.map((i) => i['destructive']), [false, false, true]);

    expect(_calls, ['delete']);
    // The OS drew the menu; Flutter pushed nothing.
    expect(find.byType(GlassSurface), findsNothing);
    expect(find.byType(Card), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS: dismissed NSMenu runs nothing', (tester) async {
    _useGlass(TargetPlatform.macOS);
    messenger.setMockMethodCallHandler(
        AdaptiveContextMenu.channel, (call) async => -1);
    await tester.pumpWidget(_app());
    await _openMenu(tester);
    expect(_calls, isEmpty);
    expect(find.byType(GlassSurface), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final error in <Exception>[
    MissingPluginException(),
    PlatformException(code: 'INVALID_ARGS'),
  ]) {
    testWidgets(
        'macOS: ${error.runtimeType} falls back to the glass Flutter menu',
        (tester) async {
      _useGlass(TargetPlatform.macOS);
      messenger.setMockMethodCallHandler(
          AdaptiveContextMenu.channel, (call) async => throw error);
      await tester.pumpWidget(_app());
      await _openMenu(tester);
      expect(find.byType(GlassSurface), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(_calls, ['edit']);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  test('SF Symbols: known icons map, unknown and null do not', () {
    expect(AdaptiveContextMenu.sfSymbolFor(Icons.delete_outlined), 'trash');
    expect(AdaptiveContextMenu.sfSymbolFor(Icons.tune), 'slider.horizontal.3');
    expect(AdaptiveContextMenu.sfSymbolFor(Icons.abc), isNull);
    expect(AdaptiveContextMenu.sfSymbolFor(null), isNull);
  });
}
