import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/ip_details.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/services/ui_lifecycle.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/dashboard/dashboard.dart';
import 'package:meowclash/views/dashboard/widgets/ip_details_dialog.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'settings_test_support.dart';

/// Shared host and sample data of the Dashboard tests (Material goldens,
/// Darwin glass checks, performance). Nothing here touches the network or
/// the core: the network widgets read values set on their global notifiers,
/// and memory polling is frozen by hiding the window.

const _gib = 1024 * 1024 * 1024;
const _mib = 1024 * 1024;

/// First half of the widgets: charts, modes, subscription.
const dashboardWidgetsA = [
  DashboardWidget.networkSpeed,
  DashboardWidget.outboundModeV2,
  DashboardWidget.outboundMode,
  DashboardWidget.trafficUsage,
  DashboardWidget.announce,
  DashboardWidget.metainfo,
];

/// Second half: toggles, addresses, memory, media unlock. TUN / system proxy
/// are desktop-only and the VPN toggle Android-only (by the host OS of the
/// test run, `SupportPlatform.currentPlatform`), so the filter drops some.
const dashboardWidgetsB = [
  DashboardWidget.networkDetection,
  DashboardWidget.tunButton,
  DashboardWidget.vpnButton,
  DashboardWidget.systemProxyButton,
  DashboardWidget.intranetIp,
  DashboardWidget.memoryInfo,
  DashboardWidget.mediaUnlock,
];

/// Every widget; the small media unlock tile only fits its status texts in
/// the test font at the wide size.
const dashboardWidgetsAll = DashboardWidget.values;

/// A subscription profile with an announcement and a support link, so the
/// announce and metainfo widgets render. Expires 2027-01-01 (no countdown).
Profile sampleDashboardProfile() => Profile(
      id: 'sub',
      label: 'Subscription',
      url: 'https://test.invalid/sub',
      autoUpdateDuration: const Duration(days: 1),
      lastUpdateDate: DateTime(2026, 10, 1, 12),
      providerHeaders: const {
        'announce': 'Maintenance tonight 02:00–03:00 UTC. Nodes in Tokyo '
            'will reconnect automatically.',
        'support-url': 'https://test.invalid/support',
      },
      subscriptionInfo: const SubscriptionInfo(
        upload: 2 * _gib,
        download: 5 * _gib,
        total: 20 * _gib,
        expire: 1798804800,
      ),
    );

/// Deterministic traffic sample [i] of a gentle wave (bytes per second).
Traffic sampleTraffic(int i) => Traffic(
      up: (40 + 30 * ((i * 7) % 11)) * 1024,
      down: (300 + 120 * ((i * 5) % 13)) * 1024,
    );

FixedList<Traffic> sampleTraffics([int count = 30]) =>
    FixedList<Traffic>(30, list: List.generate(count, sampleTraffic));

const sampleIpInfo = IpInfo(ip: '203.0.113.42', countryCode: 'JP');

Future<IpDetails?> fakeIpDetails({
  required String ip,
  required String languageCode,
  CancelToken? cancelToken,
}) async =>
    IpDetails(
      ip: ip,
      countryCode: 'JP',
      region: 'Tokyo',
      city: 'Chiyoda',
      domain: 'example.net',
    );

/// Per test: [setUpSettingsScreen] + dashboard data. [started] puts a run
/// time on the clock (the start button reads "connected"), [profiles] empty
/// gives the "add profile" metainfo and hides the start button.
Future<void> setUpDashboardScreen(
  WidgetTester tester,
  Size size, {
  List<DashboardWidget> widgets = dashboardWidgetsA,
  bool started = false,
  List<Profile>? profiles,
}) async {
  await setUpSettingsScreen(tester, size);
  await initializeDateFormatting('en');
  // Frozen memory polling: no core calls, no timers left behind.
  uiLifecycle.updateWindowVisibility(visible: false);
  addTearDown(() => uiLifecycle.updateWindowVisibility(visible: null));
  globalState.config = globalState.config.copyWith(
    currentProfileId: 'sub',
    profiles: profiles ?? [sampleDashboardProfile()],
    appSetting: globalState.config.appSetting.copyWith(
      dashboardWidgets: widgets,
    ),
  );
  globalState.appState = globalState.appState.copyWith(
    pageLabel: PageLabel.dashboard,
    isInit: true,
    runTime: started ? (3 * 3600 + 25 * 60 + 7) * 1000 : null,
    localIp: '192.168.1.23',
    traffics: sampleTraffics(),
    totalTraffic: Traffic(up: 1536 * _mib, down: 7 * _gib),
  );
  detectionState.state.value = const NetworkDetectionState(
    isLoading: false,
    isTesting: false,
    ipInfo: sampleIpInfo,
  );
  mediaUnlockState.state.value = const MediaUnlockState(
    results: {
      MediaPlatform.reddit: MediaUnlockResult(
        platform: MediaPlatform.reddit,
        status: MediaUnlockStatus.unlocked,
        region: 'JP',
      ),
      MediaPlatform.gemini: MediaUnlockResult(
        platform: MediaPlatform.gemini,
        status: MediaUnlockStatus.blocked,
      ),
      MediaPlatform.cloudflare: MediaUnlockResult(
        platform: MediaPlatform.cloudflare,
        status: MediaUnlockStatus.unlocked,
        region: 'JP',
        colo: 'NRT',
      ),
    },
  );
}

/// The dashboard inside a real [CommonScaffold] (toolbar actions come from
/// `PageMixin`). [tunFailure] is the TUN start error shown by the start
/// button status line.
Widget dashboardHost(
  Brightness brightness, {
  String? tunFailure,
  Widget? page,
}) {
  _lastTunFailure = tunFailure;
  return ProviderScope(
      overrides: [
        backgroundUrlProvider.overrideWith((ref) => null),
        if (tunFailure != null)
          tunStartFailureProvider.overrideWith((ref) => tunFailure),
      ],
      child: MaterialApp(
        navigatorKey: globalState.navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: brightness,
          ),
        ),
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            globalState.appController = AppController(context, ref);
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return CommonScaffold(
              title: 'Dashboard',
              body: page ?? const DashboardView(),
            );
          }),
        ),
      ),
    );
}

String? _lastTunFailure;

/// The start button animates forever (ambient), so never settle: pump a
/// fixed second of frames.
Future<void> pumpDashboard(WidgetTester tester, Widget host) async {
  await tester.pumpWidget(host);
  await pumpSettingsFrames(tester);
  expect(tester.takeException(), isNull);
}

/// Opens the IP details dialog the way the network detection card does,
/// with a fake loader.
Future<void> openIpDetailsDialog(WidgetTester tester) async {
  unawaited(globalState.showCommonDialog<void>(
    child: IpDetailsDialog(
      ipInfo: sampleIpInfo,
      loadDetails: fakeIpDetails,
      onRefresh: () {},
    ),
  ));
  await pumpSettingsFrames(tester);
}

/// Toggles edit mode with the toolbar action: the edit / save icons on
/// Material, the "Edit" / "Done" text button on Darwin glass.
Future<void> toggleDashboardEdit(WidgetTester tester) async {
  final edit = find.byIcon(Icons.edit);
  final save = find.byIcon(Icons.save);
  await tester.tap(edit.evaluate().isNotEmpty
      ? edit
      : save.evaluate().isNotEmpty
          ? save
          : find.byType(GlassToolbarTextButton));
  await pumpSettingsFrames(tester);
  await pumpShakeToRest(tester);
}

/// Edit mode wiggles every tile with a random amplitude, so a snapshot taken
/// mid-swing differs run to run. The swing passes zero once per half period;
/// pump in 1 ms steps until every tile of the grid is upright.
Future<void> pumpShakeToRest(WidgetTester tester) async {
  for (var i = 0; i < 480; i++) {
    if (_gridIsUpright(tester)) return;
    await tester.pump(const Duration(milliseconds: 1));
  }
  fail('the edit-mode wiggle never came to rest');
}

bool _gridIsUpright(WidgetTester tester) {
  final transforms = tester.widgetList<Transform>(find.descendant(
    of: find.byType(SuperGrid),
    matching: find.byType(Transform),
  ));
  return transforms.every((t) => t.transform.entry(1, 0).abs() < 1e-6);
}

/// Ends the test without live tickers or timers. The page goes first, while
/// the app controller is still alive (leaving edit mode releases the system
/// back block through it), then the app.
Future<void> tearDownDashboard(WidgetTester tester) async {
  await tester.pumpWidget(dashboardHost(
    Brightness.light,
    tunFailure: _lastTunFailure,
    page: const SizedBox.shrink(),
  ));
  await tester.pump();
  await tester.pumpWidget(const SizedBox.shrink());
  uiLifecycle.updateWindowVisibility(visible: null);
  await tester.pump(const Duration(seconds: 1));
}
