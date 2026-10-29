import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/navigation_page_view.dart';

class _CountingPage extends StatefulWidget {
  const _CountingPage({required this.index, required this.onInit});
  final int index;
  final void Function(int) onInit;
  @override
  State<_CountingPage> createState() => _CountingPageState();
}

class _CountingPageState extends State<_CountingPage> {
  @override
  void initState() {
    super.initState();
    widget.onInit(widget.index);
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('page-${widget.index}'));
}

Widget _host(
  int index,
  NavigationPageTransition transition, {
  int count = 5,
  bool animate = true,
  bool disableAnimations = false,
  void Function(int)? onInit,
}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: NavigationPageView(
          selectedIndex: index,
          itemCount: count,
          animate: animate,
          transition: transition,
          keepAlive: (_) => true,
          itemKey: ValueKey.new,
          itemBuilder: (_, i) =>
              _CountingPage(index: i, onInit: onInit ?? (_) {}),
        ),
      ),
    );

double _page(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

double _opacity(WidgetTester tester, int index) => tester
    .widget<Opacity>(
      find
          .ancestor(of: find.text('page-$index'), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

Offset _center(WidgetTester tester, int index) =>
    tester.getCenter(find.text('page-$index'));

// Fractional translations land a hair off whole pixels.
Matcher _at(Offset expected) => within(distance: 0.01, from: expected);

void main() {
  testWidgets('sidebar fade through moves only the two pages it switches',
      (tester) async {
    final initialized = <int, int>{};
    void onInit(int n) =>
        initialized.update(n, (v) => v + 1, ifAbsent: () => 1);
    Widget host(int index) => _host(
          index,
          NavigationPageTransition.fadeThrough,
          onInit: onInit,
        );
    await tester.pumpWidget(host(0));
    final settled = _center(tester, 0);
    await tester.pumpWidget(host(4));
    await tester.pump(); // Run the post-frame switch before the clock moves.
    await tester.pump(const Duration(milliseconds: 60));
    expect(_page(tester), inExclusiveRange(3, 4));
    expect(_opacity(tester, 0), inExclusiveRange(0, 1));
    expect(_opacity(tester, 4), 0, reason: 'fade through: old page first');
    expect(_center(tester, 0), _at(settled), reason: 'no sideways scroll');
    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacity(tester, 0), 0);
    expect(_opacity(tester, 4), inExclusiveRange(0, 1));
    expect(_center(tester, 4), _at(settled));
    expect(
      tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.text('page-4'),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .entry(0, 0),
      inExclusiveRange(0.92, 1),
    );
    await tester.pumpAndSettle();
    expect(_page(tester), 4);
    expect(_opacity(tester, 4), 1);
    expect(_center(tester, 4), _at(settled));
    expect(initialized.keys, unorderedEquals([0, 4]),
        reason: 'pages in between are never built');

    await tester.pumpWidget(host(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_page(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_page(tester), 0);
    expect(_opacity(tester, 0), 1);
    expect(initialized, {0: 1, 4: 1}, reason: 'visited pages keep state');
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass sidebar slides along the sidebar and never fades',
      (tester) async {
    final initialized = <int, int>{};
    void onInit(int n) =>
        initialized.update(n, (v) => v + 1, ifAbsent: () => 1);
    Widget host(int index) => _host(
          index,
          NavigationPageTransition.verticalSlide,
          count: 4,
          onInit: onInit,
        );
    await tester.pumpWidget(host(0));
    final settled = _center(tester, 0);
    await tester.pumpWidget(host(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Down the sidebar: the old page leaves upwards, the new one rises.
    final leaving = _center(tester, 0);
    final arriving = _center(tester, 3);
    expect(leaving.dx, closeTo(settled.dx, 0.01));
    expect(arriving.dx, closeTo(settled.dx, 0.01));
    expect(leaving.dy, lessThan(settled.dy));
    expect(arriving.dy, greaterThan(settled.dy));
    expect(
      find.descendant(
        of: find.byType(NavigationPageView),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity || widget is FadeTransition,
        ),
      ),
      findsNothing,
      reason: 'an Opacity over a glass page flattens its blur',
    );
    await tester.pumpAndSettle();
    expect(_page(tester), 3);
    expect(_center(tester, 3), _at(settled));
    expect(initialized.keys, unorderedEquals([0, 3]));

    await tester.pumpWidget(host(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Up the sidebar: the new page comes down from above.
    expect(_center(tester, 1).dy, lessThan(settled.dy));
    expect(_center(tester, 3).dy, greaterThan(settled.dy));
    await tester.pumpAndSettle();
    expect(_page(tester), 1);
    expect(_center(tester, 1), _at(settled));
    expect(tester.takeException(), isNull);
  });

  for (final transition in [
    NavigationPageTransition.fadeThrough,
    NavigationPageTransition.verticalSlide,
  ]) {
    testWidgets('${transition.name}: reduce motion and the setting jump',
        (tester) async {
      await tester.pumpWidget(_host(0, transition, disableAnimations: true));
      await tester.pumpWidget(_host(3, transition, disableAnimations: true));
      await tester.pump();
      expect(_page(tester), 3);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_host(1, transition, animate: false));
      await tester.pump();
      expect(_page(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('page-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${transition.name}: interrupted switches settle safely',
        (tester) async {
      Widget host(int index, {int count = 6}) =>
          _host(index, transition, count: count);
      await tester.pumpWidget(host(0));
      final settled = _center(tester, 0);
      await tester.pumpWidget(host(5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(host(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(host(4));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_page(tester), 4, reason: 'every page is back in its own slot');
      expect(_center(tester, 4), _at(settled));
      await tester.pumpWidget(host(2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(host(4));
      await tester.pumpAndSettle();
      expect(_page(tester), 4);
      expect(_center(tester, 4), _at(settled));
      await tester.pumpWidget(host(99, count: 2));
      await tester.pumpAndSettle();
      expect(find.text('page-1'), findsOneWidget);
      expect(_center(tester, 1), _at(settled));
      await tester.pumpWidget(host(0, count: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
