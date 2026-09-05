import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/async_polling_loop.dart';
import 'package:meowclash/widgets/navigation_page_view.dart';
import 'package:meowclash/widgets/visibility_polling.dart';

class _PollingPage extends StatefulWidget {
  const _PollingPage({required this.fetch, required this.publish});
  final Future<int> Function() fetch;
  final void Function(int) publish;
  @override
  State<_PollingPage> createState() => _PollingPageState();
}

class _PollingPageState extends State<_PollingPage>
    with VisibilityPollingMixin<_PollingPage> {
  @override
  Duration get pollingInterval => const Duration(seconds: 1);
  @override
  Future<void> poll(PollingToken token) async {
    final value = await widget.fetch();
    if (mounted && token.isCurrent) widget.publish(value);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets('cached navigation pages stop timers and resume immediately',
      (tester) async {
    final calls = [0, 0];
    Widget host(int selected) => MaterialApp(
          home: NavigationPageView(
            selectedIndex: selected,
            itemCount: 2,
            animate: false,
            itemKey: ValueKey.new,
            keepAlive: (_) => true,
            itemBuilder: (_, index) => _PollingPage(
              fetch: () async => ++calls[index],
              publish: (_) {},
            ),
          ),
        );
    await tester.pumpWidget(host(0));
    await tester.pump();
    expect(calls, [1, 0]);
    await tester.pumpWidget(host(1));
    await tester.pump();
    final hiddenCount = calls[0];
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(calls[0], hiddenCount);
    expect(calls[1], greaterThan(1));
    await tester.pumpWidget(host(0));
    await tester.pump();
    expect(calls[0], hiddenCount + 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('initially hidden widgets perform no polls', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: TickerMode(
      enabled: false,
      child: _PollingPage(fetch: () async => ++calls, publish: (_) {}),
    )));
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'disposal during an awaited response discards it and stops timers',
      (tester) async {
    var calls = 0;
    final published = <int>[];
    final blocked = Completer<int>();
    await tester.pumpWidget(MaterialApp(
        home: _PollingPage(
      fetch: () {
        calls++;
        return blocked.future;
      },
      publish: published.add,
    )));
    await tester.pumpWidget(const SizedBox());
    blocked.complete(42);
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 1);
    expect(published, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'backgrounding stops polling and resume discards the old response',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final requests = <Completer<int>>[];
    final published = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: _PollingPage(
      fetch: () {
        final request = Completer<int>();
        requests.add(request);
        return request.future;
      },
      publish: published.add,
    )));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(minutes: 5));
    expect(requests, hasLength(1));
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(requests, hasLength(1));
    requests.first.complete(1);
    await tester.pump();
    await tester.pump(Duration.zero);
    expect(published, isEmpty);
    expect(requests, hasLength(2));
    requests.last.complete(2);
    await tester.pump();
    expect(published, [2]);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
