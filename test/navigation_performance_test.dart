import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/navigation_page_view.dart';

class _TickerPage extends StatefulWidget {
  const _TickerPage(
      {required this.index, required this.onInit, required this.onTick});
  final int index;
  final void Function(int) onInit;
  final void Function(int) onTick;
  @override
  State<_TickerPage> createState() => _TickerPageState();
}

class _TickerPageState extends State<_TickerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    widget.onInit(widget.index);
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() => widget.onTick(widget.index))
          ..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('page-${widget.index}'));
}

void main() {
  testWidgets(
      'far navigation builds no intermediate pages and stops hidden tickers',
      (tester) async {
    final initialized = <int, int>{};
    final ticks = <int, int>{};
    Widget host(int index) => MaterialApp(
            home: Scaffold(
                body: NavigationPageView(
          selectedIndex: index,
          itemCount: 5,
          keepAlive: (_) => true,
          itemKey: ValueKey.new,
          itemBuilder: (_, i) => _TickerPage(
            index: i,
            onInit: (n) =>
                initialized.update(n, (v) => v + 1, ifAbsent: () => 1),
            onTick: (n) => ticks.update(n, (v) => v + 1, ifAbsent: () => 1),
          ),
        )));
    await tester.pumpWidget(host(0));
    await tester.pump(const Duration(milliseconds: 30));
    expect(initialized.keys, [0]);
    await tester.pumpWidget(host(4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(initialized.keys.toSet(), {0, 4});
    final oldTicks = ticks[0];
    final activeTicks = ticks[4]!;
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks[0], oldTicks);
    expect(ticks[4], greaterThan(activeTicks));
    await tester.pumpWidget(host(0));
    await tester.pump();
    expect(initialized[0], 1, reason: 'visited pages retain their state');
    expect(find.text('page-0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'adjacent transitions animate and rapid navigation/disposal is safe',
      (tester) async {
    Widget host(int index, {int count = 4}) => MaterialApp(
            home: Scaffold(
                body: NavigationPageView(
          selectedIndex: index,
          itemCount: count,
          keepAlive: (_) => true,
          itemKey: ValueKey.new,
          itemBuilder: (_, i) => Center(child: Text('page-$i')),
        )));
    await tester.pumpWidget(host(-1));
    expect(find.text('page-0'), findsOneWidget);
    await tester.pumpWidget(host(1));
    await tester.pump(); // Start the ticker before advancing its clock.
    await tester.pump(const Duration(milliseconds: 40));
    final position =
        tester.widget<PageView>(find.byType(PageView)).controller!.page!;
    expect(position, greaterThan(0));
    expect(position, lessThan(1));
    await tester.pumpWidget(host(3));
    await tester.pump();
    await tester.pumpWidget(host(1));
    await tester.pumpAndSettle();
    expect(find.text('page-1'), findsOneWidget);
    await tester.pumpWidget(host(99, count: 2));
    await tester.pumpAndSettle();
    expect(find.text('page-1'), findsOneWidget);
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty navigation can become populated safely', (tester) async {
    Widget host(int count) => MaterialApp(
            home: NavigationPageView(
          selectedIndex: 3,
          itemCount: count,
          keepAlive: (_) => true,
          itemKey: ValueKey.new,
          itemBuilder: (_, i) => Text('page-$i'),
        ));
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(4));
    await tester.pumpAndSettle();
    expect(find.text('page-3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
