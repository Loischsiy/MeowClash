import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/measure.dart';
import 'package:meowclash/common/theme.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/pages/home.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/popup.dart';
import 'package:meowclash/widgets/scaffold.dart';
import 'package:meowclash/widgets/sheet.dart';

import 'performance_test_support.dart';

/// Pixel baseline of the Material screens chrome (app bar + navigation,
/// bottom / side sheet, popup menu) that Android, Linux and Windows must keep
/// after the Darwin glass work. The images were generated on the commit
/// before the glass chrome landed (fd102ce) and must still match.
/// Regenerate only for an intended Material change:
/// `flutter test --update-goldens test/material_chrome_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const items = [
    NavigationItem(
      icon: Icon(Icons.space_dashboard),
      label: PageLabel.dashboard,
      view: SizedBox(),
    ),
    NavigationItem(
      icon: Icon(Icons.folder),
      label: PageLabel.profiles,
      view: SizedBox(),
    ),
    NavigationItem(
      icon: Icon(Icons.construction),
      label: PageLabel.tools,
      view: SizedBox(),
    ),
  ];

  const mobile = Size(400, 640);
  const desktop = Size(800, 480);

  Future<void> setUpView(WidgetTester tester, Size size) async {
    await AppLocalizations.load(const Locale('en'));
    initializePerformanceState();
    globalState.appState = globalState.appState.copyWith(viewSize: size);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host(Brightness brightness, Widget Function(BuildContext) home) =>
      ProviderScope(
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
          home: Builder(builder: (context) {
            globalState.measure = Measure.of(context, 1);
            globalState.theme = CommonTheme.of(context, 1);
            return home(context);
          }),
        ),
      );

  Widget scaffold({required bool isMobile}) {
    final navigation = CommonNavigationBar(
      viewMode: isMobile ? ViewMode.mobile : ViewMode.desktop,
      navigationItems: items,
      currentIndex: 1,
    );
    return CommonScaffold(
      title: 'Profiles',
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.sync)),
      ],
      body: const Center(child: Text('Body')),
      bottomNavigationBar: isMobile ? navigation : null,
      sideNavigationBar: isMobile ? null : navigation,
    );
  }

  Widget sheetOpener() => Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showSheet<void>(
                context: context,
                builder: (_, type) => AdaptiveSheetScaffold(
                  type: type,
                  title: 'Sheet',
                  body: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(title: Text('First')),
                      ListTile(title: Text('Second')),
                    ],
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

  Future<void> expectScreen(WidgetTester tester, String name) =>
      expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/material_$name.png'),
      );

  for (final brightness in Brightness.values) {
    final b = brightness.name;

    testWidgets('mobile scaffold, $b', (tester) async {
      await setUpView(tester, mobile);
      await tester.pumpWidget(
        host(brightness, (_) => scaffold(isMobile: true)),
      );
      await tester.pumpAndSettle();
      await expectScreen(tester, 'scaffold_mobile_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('desktop scaffold, $b', (tester) async {
      await setUpView(tester, desktop);
      await tester.pumpWidget(
        host(brightness, (_) => scaffold(isMobile: false)),
      );
      await tester.pumpAndSettle();
      await expectScreen(tester, 'scaffold_desktop_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('bottom sheet, $b', (tester) async {
      await setUpView(tester, mobile);
      await tester.pumpWidget(host(brightness, (_) => sheetOpener()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await expectScreen(tester, 'bottom_sheet_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('side sheet, $b', (tester) async {
      await setUpView(tester, desktop);
      await tester.pumpWidget(host(brightness, (_) => sheetOpener()));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await expectScreen(tester, 'side_sheet_$b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('popup menu, $b', (tester) async {
      await setUpView(tester, mobile);
      await tester.pumpWidget(host(
        brightness,
        (_) => Scaffold(
          body: Center(
            child: CommonPopupMenu(
              items: [
                PopupMenuItemData(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onPressed: () {},
                ),
                PopupMenuItemData(
                  icon: Icons.sync_alt_sharp,
                  label: 'Sync',
                  onPressed: () {},
                ),
                const PopupMenuItemData(
                  icon: Icons.delete_outlined,
                  label: 'Delete',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(CommonPopupMenu),
        matchesGoldenFile('goldens/material_popup_menu_$b.png'),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
