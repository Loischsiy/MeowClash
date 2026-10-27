import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

// 1x1 transparent PNG: keeps the sidebar logo off the asset bundle.
final _logo = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

const _destinations = [
  AdaptiveDestination(icon: Icon(Icons.home), label: 'Home'),
  AdaptiveDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  group('AdaptiveTabBar', () {
    testWidgets('Material branch keeps NavigationBar', (tester) async {
      AdaptivePlatform.debugUseGlassOverride = false;
      await tester.pumpWidget(_app(AdaptiveTabBar(
        destinations: _destinations,
        selectedIndex: 0,
        onSelected: (_) {},
      )));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(GlassSurface), findsNothing);
      expect(AdaptiveTabBar.extendsBody, isFalse);
    });

    testWidgets('glass branch floats and selects', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      var selected = -1;
      await tester.pumpWidget(_app(AdaptiveTabBar(
        destinations: _destinations,
        selectedIndex: 0,
        onSelected: (i) => selected = i,
      )));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(AdaptiveTabBar.extendsBody, isTrue);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('AdaptiveSidebar', () {
    Widget sidebar({required bool showLabel, ValueChanged<int>? onSelected}) =>
        _app(Row(children: [
          AdaptiveSidebar(
            destinations: _destinations,
            selectedIndex: 0,
            onSelected: onSelected ?? (_) {},
            showLabel: showLabel,
            onToggleLabel: () {},
            title: 'MeowClash',
            logo: _logo,
          ),
          const Expanded(child: SizedBox()),
        ]));

    testWidgets('Material branch keeps NavigationRail', (tester) async {
      AdaptivePlatform.debugUseGlassOverride = false;
      await tester.pumpWidget(sidebar(showLabel: true));
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('macOS glass branch is a source list', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      var selected = -1;
      await tester.pumpWidget(
        sidebar(showLabel: true, onSelected: (i) => selected = i),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      // Native NSVisualEffectView backdrop: no Flutter blur in the sidebar.
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.tap(find.text('Settings'));
      expect(selected, 1);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('extended header lines up with the rows', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      await tester.pumpWidget(sidebar(showLabel: true));
      await tester.pumpAndSettle();
      final logo = tester.getRect(find.byType(CircleAvatar));
      final icon = tester.getRect(find.byIcon(Icons.home));
      expect(logo.center.dx, moreOrLessEquals(icon.center.dx));
      expect(
        tester.getTopLeft(find.text('MeowClash')).dx,
        moreOrLessEquals(tester.getTopLeft(find.text('Home')).dx),
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
