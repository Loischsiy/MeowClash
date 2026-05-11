import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/models/models.dart';
import 'package:meow_clash/providers/providers.dart';
import 'package:meow_clash/state.dart';
import 'package:meow_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<int, FocusNode> _navFocusNodes = {};

  FocusNode _getNavFocusNode(int index) {
    return _navFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  @override
  void dispose() {
    for (final node in _navFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeBackScope(
      child: Material(
        color: context.colorScheme.surface,
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(navigationStateProvider);
            final isMobile = state.viewMode == ViewMode.mobile;
            final navigationItems = state.navigationItems;
            final currentIndex = state.currentIndex;
            final bottomNavigationBar = globalState.isAndroidTV
                ? _buildTVBottomNavBar(
                    context,
                    navigationItems: navigationItems,
                    currentIndex: currentIndex,
                  )
                : GoogleBottomNavBar(
                    navigationItems: navigationItems,
                    selectedIndex: currentIndex,
                    onTabChange: (index) {
                      globalState.appController.toPage(navigationItems[index].label);
                    },
                  );
            if (isMobile) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: globalState.appState.systemUiOverlayStyle.copyWith(
                  systemNavigationBarColor:
                      context.colorScheme.surfaceContainer,
                ),
                child: Column(
                  children: [
                    Flexible(
                      flex: 1,
                      child: MediaQuery.removePadding(
                        removeTop: false,
                        removeBottom: true,
                        removeLeft: true,
                        removeRight: true,
                        context: context,
                        child: child!,
                      ),
                    ),
                    MediaQuery.removePadding(
                      removeTop: true,
                      removeBottom: false,
                      removeLeft: true,
                      removeRight: true,
                      context: context,
                      child: bottomNavigationBar,
                    ),
                  ],
                ),
              );
            } else {
              return child!;
            }
          },
          child: Consumer(
            builder: (_, ref, _) {
              final navigationItems = ref
                  .watch(currentNavigationItemsStateProvider)
                  .value;
              final isMobile = ref.watch(isMobileViewProvider);
              return _HomePageView(
                navigationItems: navigationItems,
                pageBuilder: (_, index) {
                  final navigationItem = navigationItems[index];
                  final navigationView = navigationItem.builder(context);
                  return KeepScope(
                    key: ValueKey(navigationItem.label),
                    keep: navigationItem.keep,
                    child: isMobile
                        ? navigationView
                        : Navigator(
                            pages: [MaterialPage(child: navigationView)],
                            onDidRemovePage: (_) {},
                          ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTVBottomNavBar(
    BuildContext context, {
    required List<NavigationItem> navigationItems,
    required int currentIndex,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withValues(alpha: 0.15),
          ),
        ],
      ),
      child: SafeArea(
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;
              final focusNode = _getNavFocusNode(index);
              return FocusTraversalOrder(
                order: NumericFocusOrder(index.toDouble()),
                child: AnimatedBuilder(
                  animation: focusNode,
                  builder: (context, child) {
                    final isFocused = focusNode.hasFocus;
                    return InkWell(
                      focusNode: focusNode,
                      onTap: () {
                        globalState.appController.toPage(item.label);
                      },
                      onFocusChange: (hasFocus) {
                        if (hasFocus && !isSelected) {
                          globalState.appController.toPage(item.label);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colorScheme.secondaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isFocused
                              ? Border.all(
                                  color: context.colorScheme.primary,
                                  width: 2,
                                )
                              : Border.all(
                                  color: Colors.transparent,
                                  width: 2,
                                ),
                        ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconTheme(
                                data: IconThemeData(
                                  color: isSelected
                                      ? context.colorScheme.onSecondaryContainer
                                      : context.colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                child: item.icon,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getLocalizedLabel(item.label),
                                style: TextStyle(
                                  color: isSelected
                                      ? context.colorScheme.onSecondaryContainer
                                      : context.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _getLocalizedLabel(PageLabel label) {
    switch (label) {
      case PageLabel.dashboard:
        return appLocalizations.dashboard;
      case PageLabel.proxies:
        return appLocalizations.proxies;
      case PageLabel.profiles:
        return appLocalizations.profiles;
      case PageLabel.tools:
        return appLocalizations.tools;
      case PageLabel.logs:
        return appLocalizations.logs;
      case PageLabel.requests:
        return appLocalizations.requests;
      case PageLabel.resources:
        return appLocalizations.resources;
      case PageLabel.script:
        return appLocalizations.script;
      case PageLabel.connections:
        return appLocalizations.connections;
    }
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;
  late final ProviderSubscription<PageLabel> _pageLabelSubscription;

  @override
  initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
    _pageLabelSubscription = ref.listenManual(currentPageLabelProvider, (
      prev,
      next,
    ) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    return widget.navigationItems.indexWhere(
      (item) => item.label == globalState.appState.pageLabel,
    );
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }
    
    FocusManager.instance.primaryFocus?.unfocus();
    
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageLabelSubscription.close();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.navigationItems.length,
      itemBuilder: (context, index) {
        return widget.pageBuilder(context, index);
      },
    );
  }
}

class HomeBackScope extends ConsumerStatefulWidget {
  final Widget child;

  const HomeBackScope({super.key, required this.child});

  @override
  ConsumerState<HomeBackScope> createState() => _HomeBackScopeState();
}

class _HomeBackScopeState extends ConsumerState<HomeBackScope> {
  int? sdkInt;

  @override
  void initState() {
    super.initState();
    if (system.isAndroid) {
      system.version.then((value) {
        if (mounted) {
          setState(() {
            sdkInt = value;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (system.isAndroid) {
      if (sdkInt == null) {
        return widget.child;
      }

      final backBlock = ref.watch(backBlockProvider);
      final currentPage = ref.watch(currentPageLabelProvider);
      final rootPageLabels = ref.watch(
        currentNavigationItemsStateProvider.select(
          (state) => state.value.map((item) => item.label).toSet(),
        ),
      );
      final isCurrentRootPage = rootPageLabels.contains(currentPage);

      if (sdkInt! >= 31) {
        return PopScope(
          canPop: !backBlock && isCurrentRootPage,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || backBlock) return;
            if (!isCurrentRootPage) {
              globalState.appController.toPage(PageLabel.dashboard);
            }
          },
          child: widget.child,
        );
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || backBlock) return;
          if (!isCurrentRootPage) {
            globalState.appController.toPage(PageLabel.dashboard);
            return;
          }
          final canPop = Navigator.canPop(context);
          if (canPop) {
            Navigator.pop(context);
          } else {
            await globalState.appController.handleBackOrExit();
          }
        },
        child: widget.child,
      );
    }
    return widget.child;
  }
}
