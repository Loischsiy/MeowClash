// Explicit transitions make the teardown/restoration checks easier to follow.
// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/ui_lifecycle.dart';
import 'package:meowclash/widgets/navigation_page_view.dart';
import 'package:meowclash/widgets/suspendable_ui.dart';

class _Page extends StatefulWidget {
  const _Page({
    required this.index,
    required this.onInit,
    required this.onDispose,
    required this.onTick,
  });

  final int index;
  final void Function(int) onInit;
  final void Function(int) onDispose;
  final VoidCallback onTick;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    widget.onInit(widget.index);
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(widget.onTick)
      ..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    widget.onDispose(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('page-${widget.index}');
}

void main() {
  testWidgets(
      'unloads all cached pages, keeps navigator and restores selection',
      (tester) async {
    final controller = UiLifecycleController();
    final navigator = GlobalKey<NavigatorState>();
    final created = <int>[];
    final disposed = <int>[];
    var ticks = 0;
    var unloads = 0;
    Widget host(int selected) => MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => UiActivityScope(
            controller: controller,
            child: child!,
          ),
          home: SuspendableUi(
            controller: controller,
            onUnload: () {
              expect(disposed.toSet(), {0, 1});
              unloads++;
            },
            builder: (_) => NavigationPageView(
              selectedIndex: selected,
              itemCount: 2,
              animate: false,
              itemKey: ValueKey.new,
              keepAlive: (_) => true,
              itemBuilder: (_, index) => _Page(
                index: index,
                onInit: created.add,
                onDispose: disposed.add,
                onTick: () => ticks++,
              ),
            ),
          ),
        );
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final navigatorState = navigator.currentState;
    expect(created, [0, 1]);
    controller.updateWindowVisibility(visible: false);
    await tester.pump();
    final hiddenTicks = ticks;
    await tester.pump(const Duration(seconds: 2));
    expect(disposed, isEmpty);
    expect(ticks, hiddenTicks);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(disposed.toSet(), {0, 1});
    expect(unloads, 1);
    expect(find.byType(NavigationPageView), findsNothing);
    expect(navigator.currentState, same(navigatorState));
    await tester.pump(const Duration(minutes: 5));
    expect(ticks, hiddenTicks);
    controller.updateWindowVisibility(visible: true);
    await tester.pump();
    expect(find.text('page-1'), findsOneWidget);
    expect(created, [0, 1, 1], reason: 'only the selected page is rebuilt');
    expect(navigator.currentState, same(navigatorState));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('brief minimization preserves the same page instance',
      (tester) async {
    final controller = UiLifecycleController();
    var created = 0;
    var disposed = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => UiActivityScope(
        controller: controller,
        child: child!,
      ),
      home: SuspendableUi(
        controller: controller,
        builder: (_) => _Page(
          index: 0,
          onInit: (_) => created++,
          onDispose: (_) => disposed++,
          onTick: () {},
        ),
      ),
    ));
    controller.updateWindowVisibility(visible: false);
    await tester.pump(const Duration(seconds: 2));
    controller.updateWindowVisibility(visible: true);
    await tester.pump(const Duration(seconds: 5));
    expect(created, 1);
    expect(disposed, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  for (final dialog in [false, true]) {
    testWidgets(
        'preserves unsaved ${dialog ? 'dialog' : 'editor'} and its owner',
        (tester) async {
      final controller = UiLifecycleController();
      final navigator = GlobalKey<NavigatorState>();
      var disposed = 0;
      var ticks = 0;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => UiActivityScope(
          controller: controller,
          child: child!,
        ),
        home: SuspendableUi(
          controller: controller,
          builder: (_) => Scaffold(
            body: _Page(
              index: 0,
              onInit: (_) {},
              onDispose: (_) => disposed++,
              onTick: () => ticks++,
            ),
          ),
        ),
      ));
      const input = TextField();
      if (dialog) {
        // ignore: unawaited_futures
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: input),
        );
      } else {
        // ignore: unawaited_futures
        navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: input),
        ));
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField), 'unsaved draft');
      controller.updateWindowVisibility(visible: false);
      await tester.pump();
      final hiddenTicks = ticks;
      await tester.pump(const Duration(minutes: 5));
      expect(controller.isSuspended, isTrue);
      expect(disposed, 0, reason: 'a route may await a result in this owner');
      expect(ticks, hiddenTicks);
      controller.updateWindowVisibility(visible: true);
      await tester.pump();
      expect(find.text('unsaved draft'), findsOneWidget);
      expect(disposed, 0);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      controller.updateWindowVisibility(visible: false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(disposed, 1, reason: 'unloading resumes when editing is finished');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('in-flight operations defer unloading without restarting tickers',
      (tester) async {
    final controller = UiLifecycleController();
    var disposed = 0;
    var ticks = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => UiActivityScope(
        controller: controller,
        child: child!,
      ),
      home: SuspendableUi(
        controller: controller,
        builder: (_) => _Page(
          index: 0,
          onInit: (_) {},
          onDispose: (_) => disposed++,
          onTick: () => ticks++,
        ),
      ),
    ));
    final first = controller.keepAlive();
    final second = controller.keepAlive();
    controller.updateWindowVisibility(visible: false);
    await tester.pump();
    final hiddenTicks = ticks;
    await tester.pump(const Duration(minutes: 5));
    expect(disposed, 0);
    expect(ticks, hiddenTicks);
    first();
    first(); // Releases are idempotent.
    await tester.pump();
    expect(disposed, 0, reason: 'the second operation still owns the UI');
    second();
    await tester.pump();
    expect(disposed, 1);
    expect(controller.hasKeepAlive, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline editing guard preserves UI until editing is finished',
      (tester) async {
    final controller = UiLifecycleController();
    var disposed = 0;
    Widget host({required bool editing}) => MaterialApp(
          builder: (_, child) => UiActivityScope(
            controller: controller,
            child: child!,
          ),
          home: SuspendableUi(
            controller: controller,
            canUnload: !editing,
            builder: (_) => _Page(
              index: 0,
              onInit: (_) {},
              onDispose: (_) => disposed++,
              onTick: () {},
            ),
          ),
        );
    await tester.pumpWidget(host(editing: true));
    controller.updateWindowVisibility(visible: false);
    await tester.pump(const Duration(seconds: 3));
    expect(disposed, 0);
    await tester.pumpWidget(host(editing: false));
    expect(disposed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('starts suspended without creating pages and can open later',
      (tester) async {
    final controller = UiLifecycleController();
    controller.updateWindowVisibility(visible: false);
    await tester.pump(const Duration(seconds: 3));
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => UiActivityScope(
        controller: controller,
        child: child!,
      ),
      home: SuspendableUi(
        controller: controller,
        builder: (_) {
          builds++;
          return const Text('restored');
        },
      ),
    ));
    expect(builds, 0);
    controller.updateWindowVisibility(visible: true);
    await tester.pump();
    expect(find.text('restored'), findsOneWidget);
    expect(builds, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
