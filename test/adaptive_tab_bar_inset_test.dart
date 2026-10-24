import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/scaffold.dart';

const _destinations = [
  AdaptiveDestination(icon: Icon(Icons.home), label: 'Home'),
  AdaptiveDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

const _bottomKey = Key('bottom-content');

Future<void> _pump(WidgetTester tester, {required double homeIndicator}) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(top: 47, bottom: homeIndicator),
              viewPadding: EdgeInsets.only(top: 47, bottom: homeIndicator),
            ),
            child: child!,
          ),
          home: CommonScaffold(
            title: 'Dashboard',
            body: const Column(
              children: [
                Spacer(),
                SizedBox(key: _bottomKey, height: 56, width: 200),
              ],
            ),
            bottomNavigationBar: AdaptiveTabBar(
              destinations: _destinations,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  tearDown(() {
    AdaptivePlatform.debugUseGlassOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  for (final homeIndicator in [34.0, 0.0]) {
    testWidgets('glass tab bar never covers page content '
        '(home indicator $homeIndicator)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AdaptivePlatform.debugUseGlassOverride = true;
      await _pump(tester, homeIndicator: homeIndicator);
      await tester.pump();

      final capsule = tester.getRect(find.byType(GlassSurface).last);
      final content = tester.getRect(find.byKey(_bottomKey));
      expect(content.bottom, lessThanOrEqualTo(capsule.top));

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        AdaptiveTabBar.bottomInset(tester.element(find.byType(AdaptiveTabBar))),
        screen.height - capsule.top,
      );
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('Material tab bar: no extra inset', (tester) async {
    AdaptivePlatform.debugUseGlassOverride = false;
    await _pump(tester, homeIndicator: 0);
    await tester.pump();
    final bar = tester.getRect(find.byType(NavigationBar));
    final content = tester.getRect(find.byKey(_bottomKey));
    expect(content.bottom, bar.top);
    expect(
      AdaptiveTabBar.bottomInset(tester.element(find.byType(AdaptiveTabBar))),
      0,
    );
  });
}
