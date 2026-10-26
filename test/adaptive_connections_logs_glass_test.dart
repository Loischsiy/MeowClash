import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/connection/connections.dart';
import 'package:meowclash/views/connection/item.dart';
import 'package:meowclash/views/connection/requests.dart';
import 'package:meowclash/views/logs.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'connections_logs_test_support.dart';
import 'settings_test_support.dart';

/// Darwin glass Requests / Connections / Logs: flat stream rows whose
/// extents match what they paint, no blur in the lists, tag filters, closing
/// connections, empty / loading states, accessibility fallbacks and scrolling
/// under the glass toolbar. Material is covered by the goldens in
/// `material_connections_logs_golden_test.dart`.

const _size = Size(400, 900);
const _darwin =
    TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.iOS});

/// The list's own scroll view: the stream lists are reversed (newest at the
/// bottom), and every [SelectableText] of a log row has a Scrollable too.
final _reverseList = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.up,
);

Finder _blurIn(Finder scrollable) =>
    find.descendant(of: scrollable, matching: find.byType(BackdropFilter));

/// Every built row is exactly as tall as its content plus the row padding:
/// the precomputed item extents come from the same styles the rows use.
void _expectRowsFitExtents(WidgetTester tester) {
  final rows = find.byType(GlassStreamRow);
  expect(rows, findsWidgets);
  for (final element in rows.evaluate()) {
    final row = element.renderObject! as RenderBox;
    final column = find.descendant(
      of: find.byWidget(element.widget),
      matching: find.byType(Column),
    );
    final content = tester.renderObject<RenderBox>(column.first);
    expect(
      row.size.height,
      moreOrLessEquals(GlassStreamRow.extentOf(content.size.height),
          epsilon: 0.5),
    );
  }
}

Iterable<Color> _tagFills(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(GlassTag),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration)
    .whereType<ShapeDecoration>()
    .map((decoration) => decoration.color)
    .whereType<Color>();

/// [page] in a real scaffold at [textScale], measured at the same scale the
/// way `ThemeManager` does it.
Widget _scaledHost(String title, Widget page, double textScale) =>
    settingsHost(Brightness.light, (context) {
      globalState.measure = Measure.of(context, textScale);
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: CommonScaffold(title: title, body: page),
      );
    });

Widget _underToolbarHost(String title, Widget page) => settingsHost(
      Brightness.light,
      (_) => CommonScaffold(title: title, body: page, scrollUnderToolbar: true),
    );

double _barBottom(WidgetTester tester) =>
    tester.getBottomLeft(find.byType(AdaptiveAppBar)).dy;

List<double> _visibleRowTops(WidgetTester tester) => [
      for (final e in find.byType(GlassStreamRow).hitTestable().evaluate())
        (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
    ]..sort();

List<Log> _longLogs() => [
      ...sampleLogs(12),
      Log(
        logLevel: LogLevel.error,
        payload: 'very long line ' * 30,
        dateTime: '2026-10-26 12:00:00',
      ),
      Log(
        logLevel: LogLevel.app,
        payload: 'x' * 300,
        dateTime: '2026-10-26 12:00:01',
      ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => setUpSettingsEnvironment('connections_logs_glass'));

  group('rows and extents', () {
    testWidgets('requests: rows fit their extents, no dividers, no blur',
        (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.requests, requests: sampleConnections(20));
      await tester.pumpWidget(
          streamHost(Brightness.light, 'Requests', const RequestsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      _expectRowsFitExtents(tester);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(GlassTag), findsWidgets);
      expect(_blurIn(_reverseList), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    testWidgets('logs: long payloads fit their extents, monospaced selectable',
        (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.logs, logs: _longLogs());
      await tester
          .pumpWidget(streamHost(Brightness.dark, 'Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      _expectRowsFitExtents(tester);
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(SelectableText), findsWidgets);
      final payload =
          tester.widget<SelectableText>(find.byType(SelectableText).first);
      expect(payload.style?.fontFamilyFallback, contains('Menlo'));
      expect(_blurIn(_reverseList), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    testWidgets('large text (1.5×): requests and logs still fit',
        (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.requests, requests: sampleConnections(12));
      await tester
          .pumpWidget(_scaledHost('Requests', const RequestsView(), 1.5));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      _expectRowsFitExtents(tester);
      await tester.pumpWidget(const SizedBox());

      await setUpStreamScreen(tester, _size,
          page: PageLabel.logs, logs: _longLogs());
      await tester.pumpWidget(_scaledHost('Logs', const LogsView(), 1.5));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      _expectRowsFitExtents(tester);
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    testWidgets('1000 logs: no blur and exact extents at both ends',
        (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.logs, logs: sampleLogs(1000));
      await tester
          .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(GlassStreamRow).evaluate().length, lessThan(80));
      expect(_blurIn(_reverseList), findsNothing);
      _expectRowsFitExtents(tester);

      final position = tester.state<ScrollableState>(_reverseList).position;
      for (final offset in [position.maxScrollExtent, 0.0]) {
        position.jumpTo(offset);
        await pumpSettingsFrames(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(GlassStreamRow).evaluate().length, lessThan(80));
        expect(_blurIn(_reverseList), findsNothing);
        _expectRowsFitExtents(tester);
      }
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);
  });

  group('tag filters', () {
    testWidgets('a chain tag becomes a removable filter', (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.requests, requests: sampleConnections(6));
      await tester.pumpWidget(
          streamHost(Brightness.light, 'Requests', const RequestsView()));
      await pumpSettingsFrames(tester);
      final tag = find.byType(GlassTag).hitTestable().first;
      final label = tester.widget<GlassTag>(tag).label;
      await tester.tap(tag);
      await pumpSettingsFrames(tester);
      final filter = find.byWidgetPredicate(
          (w) => w is GlassTag && w.large && w.label == label);
      expect(filter, findsOneWidget);
      expect(find.byType(CommonChip), findsNothing);

      await tester.tap(filter);
      await pumpSettingsFrames(tester);
      expect(find.byWidgetPredicate((w) => w is GlassTag && w.large),
          findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    testWidgets('a level tag filters the logs', (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.logs, logs: sampleLogs(20));
      await tester
          .pumpWidget(streamHost(Brightness.light, 'Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      final tag = find.byType(GlassTag).hitTestable().first;
      final label = tester.widget<GlassTag>(tag).label;
      await tester.tap(tag);
      await pumpSettingsFrames(tester);
      expect(
        find.byWidgetPredicate(
            (w) => w is GlassTag && w.large && w.label == label),
        findsOneWidget,
      );
      final levels = tester
          .widgetList<GlassTag>(
              find.byWidgetPredicate((w) => w is GlassTag && !w.large))
          .map((t) => t.label)
          .toSet();
      expect(levels, {label});
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);
  });

  group('closing a connection', () {
    late int closed;
    late List<String> keywords;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    Future<void> pumpItem(WidgetTester tester) async {
      closed = 0;
      keywords = [];
      await setUpSettingsScreen(tester, _size);
      await tester.pumpWidget(settingsHost(
        Brightness.light,
        (_) => ListView(
          children: [
            ConnectionItem(
              connection: sampleConnection(1),
              onClickKeyword: keywords.add,
              onClose: () => closed++,
              showTraffic: true,
            ),
          ],
        ),
      ));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
    }

    tearDown(() =>
        messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel, null));

    testWidgets('macOS: ✕ and the native right-click menu', (tester) async {
      await pumpItem(tester);
      expect(find.textContaining('↑'), findsOneWidget);
      expect(find.textContaining('↓'), findsOneWidget);
      await tester.tap(find.byType(GlassIconButton));
      await tester.pump();
      expect(closed, 1);

      final titles = <String>[];
      var pick = 1;
      messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
          (call) async {
        final items = (call.arguments as Map)['items'] as List;
        titles
          ..clear()
          ..addAll(items.map((item) => (item as Map)['title'] as String));
        return pick;
      });
      final row = tester.getTopLeft(find.byType(GlassStreamRow));
      await tester.tapAt(row + const Offset(24, 12), buttons: kSecondaryButton);
      await pumpSettingsFrames(tester);
      expect(titles, ['Copy Host', 'Filter by Process', 'Close Connection']);
      expect(keywords, ['Safari']);

      pick = 2;
      await tester.tapAt(row + const Offset(24, 12), buttons: kSecondaryButton);
      await pumpSettingsFrames(tester);
      expect(closed, 2);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('iOS: long swipe and the long-press menu', (tester) async {
      messenger.setMockMethodCallHandler(AdaptiveContextMenu.channel,
          (call) async => fail('iOS must not use the native NSMenu channel'));
      await pumpItem(tester);
      expect(find.byType(GlassIconButton), findsNothing);
      await tester.drag(find.byType(GlassStreamRow), const Offset(-360, 0));
      await pumpSettingsFrames(tester);
      expect(closed, 1);

      await tester.longPress(find.byType(GlassStreamRow));
      await pumpSettingsFrames(tester);
      expect(find.text('Close Connection'), findsOneWidget);
      await tester.tap(find.text('Close Connection'));
      await pumpSettingsFrames(tester);
      expect(closed, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('empty and loading', () {
    testWidgets('adaptive empty states, never a Material spinner',
        (tester) async {
      final pages = <(PageLabel, String, Widget)>[
        (PageLabel.requests, 'Requests', const RequestsView()),
        (
          PageLabel.connections,
          'Connections',
          ConnectionsView(loadConnections: () async => const []),
        ),
        (PageLabel.logs, 'Logs', const LogsView()),
      ];
      for (final (page, title, view) in pages) {
        await setUpStreamScreen(tester, _size, page: page);
        await tester.pumpWidget(streamHost(Brightness.dark, title, view));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byType(CircularProgressIndicator), findsNothing);
        }
        expect(tester.takeException(), isNull);
        expect(find.byType(AdaptiveEmptyState), findsOneWidget);
        expect(find.byType(NullStatus), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    }, variant: _darwin);
  });

  group('accessibility fallbacks', () {
    Future<void> pumpRequests(
      WidgetTester tester,
      GlassAccessibilityController accessibility,
    ) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.requests, requests: sampleConnections(8));
      await tester.pumpWidget(GlassAccessibilityScope(
        controller: accessibility,
        child: streamHost(Brightness.light, 'Requests', const RequestsView()),
      ));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
    }

    testWidgets('Reduce Transparency: opaque tags, glass again after',
        (tester) async {
      final accessibility = GlassAccessibilityController();
      addTearDown(accessibility.dispose);
      accessibility.value = const GlassAccessibility(reduceTransparency: true);
      await pumpRequests(tester, accessibility);
      expect(_tagFills(tester), isNotEmpty);
      expect(_tagFills(tester).every((color) => color.a == 1), isTrue);
      expect(_blurIn(_reverseList), findsNothing);

      accessibility.value = GlassAccessibility.fallback;
      await pumpSettingsFrames(tester);
      expect(_tagFills(tester).any((color) => color.a < 1), isTrue);
      expect(_blurIn(_reverseList), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    testWidgets('blur kill switch: opaque tags', (tester) async {
      GlassFlags.backdropBlurEnabled = false;
      addTearDown(() => GlassFlags.backdropBlurEnabled = true);
      final accessibility = GlassAccessibilityController();
      addTearDown(accessibility.dispose);
      accessibility.value = GlassAccessibility.fallback;
      await pumpRequests(tester, accessibility);
      expect(_tagFills(tester), isNotEmpty);
      expect(_tagFills(tester).every((color) => color.a == 1), isTrue);
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    for (final reduceMotion in [true, false]) {
      testWidgets(
          'new rows: ScrollToEndBox ${reduceMotion ? 'jumps (Reduce Motion)' : 'animates'}',
          (tester) async {
        globalState.cacheScrollPosition = {};
        final accessibility = GlassAccessibilityController();
        addTearDown(accessibility.dispose);
        accessibility.value = GlassAccessibility(reduceMotion: reduceMotion);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        Widget box(int count) => GlassAccessibilityScope(
              controller: accessibility,
              // No MaterialApp: its route caches the page, so a new
              // dataSource would never reach the box.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: ScrollToEndBox<int>(
                  controller: controller,
                  tag: CacheTag.rules,
                  dataSource: List.generate(count, (i) => i),
                  // A fresh list per count: a fixed-extent list whose
                  // visible rows did not change keeps its old extent.
                  child: ListView.builder(
                    key: ValueKey(count),
                    controller: controller,
                    itemCount: count,
                    itemExtent: 50,
                    itemBuilder: (_, i) => Text('row $i'),
                  ),
                ),
              ),
            );
        await tester.pumpWidget(box(30));
        await tester.pumpWidget(box(60));
        await tester.pump();
        final position = controller.position;
        if (reduceMotion) {
          // Already at the end on the first frame: no scroll animation (the
          // desktop scrollbar still fades in, so tickers are not idle).
          expect(position.pixels, position.maxScrollExtent);
        } else {
          expect(position.pixels, lessThan(position.maxScrollExtent));
          await tester.pumpAndSettle();
          expect(position.pixels, position.maxScrollExtent);
        }
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    }
  });

  group('scrolling under the glass toolbar', () {
    testWidgets('logs start below the bar and scroll under it', (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.logs, logs: sampleLogs(40));
      await tester.pumpWidget(_underToolbarHost('Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      final bar = _barBottom(tester);
      expect(tester.getTopLeft(find.byType(ListView)).dy, 0);
      expect(
          _visibleRowTops(tester).first, moreOrLessEquals(bar, epsilon: 0.5));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await pumpSettingsFrames(tester);
      expect(_visibleRowTops(tester).first, lessThan(bar));
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    testWidgets('pushed from More (iPhone): logs scroll under the bar',
        (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.logs, logs: sampleLogs(40));
      await tester.pumpWidget(settingsHost(
        Brightness.light,
        (_) => CommonScaffold.open(
          title: 'Logs',
          onBack: () {},
          actions: const [],
          scrollUnderToolbar: true,
          body: const SafeArea(top: false, child: LogsView()),
        ),
      ));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.byType(ListView)).dy, 0);
      expect(_visibleRowTops(tester).first,
          moreOrLessEquals(_barBottom(tester), epsilon: 0.5));
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);

    testWidgets('requests, connections and empty logs start below the bar',
        (tester) async {
      await setUpStreamScreen(tester, _size,
          page: PageLabel.requests, requests: sampleConnections(3));
      await tester
          .pumpWidget(_underToolbarHost('Requests', const RequestsView()));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      expect(_visibleRowTops(tester).first,
          moreOrLessEquals(_barBottom(tester), epsilon: 0.5));
      await tester.pumpWidget(const SizedBox());

      await setUpStreamScreen(tester, _size, page: PageLabel.connections);
      await tester.pumpWidget(_underToolbarHost(
        'Connections',
        ConnectionsView(loadConnections: () async => sampleConnections(30)),
      ));
      await pumpSettingsFrames(tester);
      expect(tester.takeException(), isNull);
      expect(_visibleRowTops(tester).first,
          moreOrLessEquals(_barBottom(tester), epsilon: 0.5));
      await tester.pumpWidget(const SizedBox());

      await setUpStreamScreen(tester, _size, page: PageLabel.logs);
      await tester.pumpWidget(_underToolbarHost('Logs', const LogsView()));
      await pumpSettingsFrames(tester);
      expect(tester.getRect(find.byType(AdaptiveEmptyState)).top,
          greaterThanOrEqualTo(_barBottom(tester) - 0.5));
      await tester.pumpWidget(const SizedBox());
    }, variant: _darwin);
  });
}
