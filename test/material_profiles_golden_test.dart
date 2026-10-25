import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/profiles/profiles.dart';
import 'package:meowclash/widgets/sheet.dart';

import 'performance_test_support.dart';

/// Pixel baseline of the Material "Profiles" screen that Android, Linux and
/// Windows must keep after the Darwin glass work on that screen. The images
/// were generated on `main` before the glass profiles screen landed and must
/// still match. Regenerate only for an intended Material change:
/// `flutter test --update-goldens test/material_profiles_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mobile = Size(400, 720);
  const desktop = Size(800, 520);
  const gib = 1024 * 1024 * 1024;
  // 2027-01-01 12:00 UTC: the same calendar day in every time zone.
  const expire = 1798804800;

  List<Profile> profiles() {
    // Relative "updated" labels are computed from now, so keep the offset
    // far from a unit boundary to make the text stable ("3 days ago").
    final updated = DateTime.now().subtract(const Duration(days: 3, hours: 6));
    return [
      Profile(
        id: 'file',
        label: 'Local file',
        autoUpdateDuration: const Duration(days: 1),
        lastUpdateDate: updated,
      ),
      Profile(
        id: 'half',
        label: 'Subscription 50%',
        url: 'https://test.invalid/half',
        autoUpdateDuration: const Duration(days: 1),
        lastUpdateDate: updated,
        subscriptionInfo: const SubscriptionInfo(
          upload: 2 * gib,
          download: 3 * gib,
          total: 10 * gib,
          expire: expire,
        ),
      ),
      Profile(
        id: 'almost',
        label: 'Subscription 95%',
        url: 'https://test.invalid/almost',
        autoUpdateDuration: const Duration(days: 1),
        lastUpdateDate: updated,
        subscriptionInfo: const SubscriptionInfo(
          upload: 1 * gib,
          download: 18 * gib,
          total: 20 * gib,
          expire: expire,
        ),
      ),
      Profile(
        id: 'unlimited',
        label: 'Unlimited',
        url: 'https://test.invalid/unlimited',
        autoUpdateDuration: const Duration(days: 1),
        lastUpdateDate: updated,
        subscriptionInfo: const SubscriptionInfo(download: 4 * gib),
      ),
      Profile(
        id: 'updating',
        label: 'Updating',
        url: 'https://test.invalid/updating',
        autoUpdateDuration: const Duration(days: 1),
        lastUpdateDate: updated,
        isUpdating: true,
      ),
    ];
  }

  Future<void> setUp(
    WidgetTester tester, {
    required Size size,
    List<Profile>? override,
  }) async {
    await AppLocalizations.load(const Locale('en'));
    await initializeDateFormatting('en');
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    globalState.config = globalState.config.copyWith(
      currentProfileId: 'half',
      profiles: override ?? profiles(),
    );
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(Brightness brightness, Widget child) => ProviderScope(
        overrides: [backgroundUrlProvider.overrideWith((ref) => null)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
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
              return child;
            }),
          ),
        ),
      );

  // The updating profile shows an indeterminate spinner, so the screen never
  // settles: pump a fixed timeline instead to keep the frame deterministic.
  Future<void> pumpScreen(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> expectScreen(WidgetTester tester, String name) => expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_profiles_$name.png'),
      );

  Widget sortSheetOpener() => Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showSheet<void>(
              context: context,
              builder: (_, type) => ReorderableProfilesSheet(
                type: type,
                profiles: globalState.config.profiles,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('list, mobile, $b', (tester) async {
      await setUp(tester, size: mobile);
      await pumpScreen(tester, host(brightness, const ProfilesView()));
      await expectScreen(tester, 'list_mobile_$b');
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('list, desktop, $b', (tester) async {
      await setUp(tester, size: desktop);
      await pumpScreen(tester, host(brightness, const ProfilesView()));
      await expectScreen(tester, 'list_desktop_$b');
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('empty, $b', (tester) async {
      await setUp(tester, size: mobile, override: const []);
      await pumpScreen(tester, host(brightness, const ProfilesView()));
      await expectScreen(tester, 'empty_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('sort sheet, $b', (tester) async {
      await setUp(
        tester,
        size: mobile,
        override: profiles().where((p) => !p.isUpdating).toList(),
      );
      await tester.pumpWidget(host(brightness, sortSheetOpener()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await expectScreen(tester, 'sort_sheet_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
