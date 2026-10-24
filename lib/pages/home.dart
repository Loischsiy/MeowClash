import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/navigation_page_view.dart';
import 'package:meowclash/widgets/widgets.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => HomeBackScope(
        child: Consumer(
          builder: (_, ref, child) {
            final state = ref.watch(homeStateProvider);
            final viewMode = state.viewMode;
            final navigationItems = state.navigationItems;
            final pageLabel = state.pageLabel;
            final index = navigationItems.lastIndexWhere(
              (element) => element.label == pageLabel,
            );
            final currentIndex = index == -1 ? 0 : index;
            final navigationBar = CommonNavigationBar(
              viewMode: viewMode,
              navigationItems: navigationItems,
              currentIndex: currentIndex,
            );
            final bottomNavigationBar =
                viewMode == ViewMode.mobile ? navigationBar : null;
            final sideNavigationBar =
                viewMode != ViewMode.mobile ? navigationBar : null;
            return CommonScaffold(
              key: globalState.homeScaffoldKey,
              title: Intl.message(
                pageLabel.name,
              ),
              sideNavigationBar: sideNavigationBar,
              body: child!,
              bottomNavigationBar: bottomNavigationBar,
            );
          },
          child: _HomePageView(),
        ),
      );
}

class _HomePageView extends ConsumerWidget {
  const _HomePageView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(currentNavigationsStateProvider).value;
    final label = ref.watch(currentPageLabelProvider);
    final animate = ref.watch(appSettingProvider.select((s) => s.isAnimateToPage));
    final isMobile = ref.watch(isMobileViewProvider);
    return NavigationPageView(
      selectedIndex: items.indexWhere((item) => item.label == label),
      itemCount: items.length,
      animate: animate && isMobile,
      itemKey: (index) => ValueKey(items[index].label),
      keepAlive: (index) => items[index].keep,
      itemBuilder: (context, index) => items[index].view,
    );
  }
}

class CommonNavigationBar extends ConsumerWidget {
  final ViewMode viewMode;
  final List<NavigationItem> navigationItems;
  final int currentIndex;

  const CommonNavigationBar({
    super.key,
    required this.viewMode,
    required this.navigationItems,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context, ref) {
    final destinations = navigationItems
        .map(
          (e) => AdaptiveDestination(
            icon: e.icon,
            label: Intl.message(e.label.name),
          ),
        )
        .toList();
    void onSelected(int index) {
      globalState.appController.toPage(navigationItems[index].label);
    }

    if (viewMode == ViewMode.mobile) {
      return AdaptiveTabBar(
        destinations: destinations,
        selectedIndex: currentIndex,
        onSelected: onSelected,
      );
    }
    final showLabel = ref.watch(appSettingProvider).showLabel;
    return AdaptiveSidebar(
      destinations: destinations,
      selectedIndex: currentIndex,
      onSelected: onSelected,
      showLabel: showLabel,
      onToggleLabel: () {
        ref.read(appSettingProvider.notifier).updateState(
              (state) => state.copyWith(
                showLabel: !state.showLabel,
              ),
            );
      },
      title: appName,
      logo: const AssetImage("assets/images/icon.png"),
      showMaterialLogo: !Platform.isMacOS,
    );
  }
}

class HomeBackScope extends StatelessWidget {
  final Widget child;

  const HomeBackScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return CommonPopScope(
        onPop: () async {
          final canPop = Navigator.canPop(context);
          if (canPop) {
            Navigator.pop(context);
          } else {
            await globalState.appController.handleBackOrExit();
          }
          return false;
        },
        child: child,
      );
    }
    return child;
  }
}
