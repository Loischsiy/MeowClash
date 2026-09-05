import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'card.dart';
import 'common.dart';

class ProxiesListView extends ConsumerStatefulWidget {
  const ProxiesListView({super.key});

  @override
  ConsumerState<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends ConsumerState<ProxiesListView> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(proxiesListSelectorStateProvider);
    ref.watch(themeSettingProvider.select((state) => state.textScale));
    if (state.groupNames.isEmpty) {
      return NullStatus(
          label: appLocalizations.nullTip(appLocalizations.proxies));
    }
    return CommonScrollBar(
      controller: _controller,
      child: ScrollConfiguration(
        behavior: HiddenBarScrollBehavior(),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: CustomScrollView(
            key: const PageStorageKey('proxies-list'),
            controller: _controller,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    for (final name in state.groupNames)
                      _ProxyGroupSliver(
                        key: ValueKey(name),
                        groupName: name,
                        columns: state.columns,
                        cardType: state.proxyCardType,
                        query: state.query,
                        sortType: state.proxiesSortType,
                        sortNum: state.sortNum,
                        expanded: state.currentUnfoldSet.contains(name),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProxyGroupSliver extends ConsumerStatefulWidget {
  const _ProxyGroupSliver({
    super.key,
    required this.groupName,
    required this.columns,
    required this.cardType,
    required this.query,
    required this.sortType,
    required this.sortNum,
    required this.expanded,
  });

  final String groupName;
  final int columns;
  final ProxyCardType cardType;
  final String query;
  final ProxiesSortType sortType;
  final num sortNum;
  final bool expanded;

  @override
  ConsumerState<_ProxyGroupSliver> createState() => _ProxyGroupSliverState();
}

class _ProxyGroupSliverState extends ConsumerState<_ProxyGroupSliver> {
  Group? _cachedGroup;
  String? _cachedQuery;
  ProxiesSortType? _cachedSortType;
  num? _cachedSortNum;
  List<Proxy> _proxies = const [];

  List<Proxy> _sortedProxies(Group group) {
    if (!identical(_cachedGroup, group) ||
        _cachedQuery != widget.query ||
        _cachedSortType != widget.sortType ||
        _cachedSortNum != widget.sortNum) {
      _cachedGroup = group;
      _cachedQuery = widget.query;
      _cachedSortType = widget.sortType;
      _cachedSortNum = widget.sortNum;
      final filtered = widget.query.isEmpty
          ? group.all
          : group.all
              .where((p) => p.name.toLowerCase().contains(widget.query))
              .toList();
      _proxies =
          globalState.appController.getSortProxies(filtered, group.testUrl);
    }
    return _proxies;
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(proxyGroupsByNameProvider.select(
      (groups) => groups[widget.groupName],
    ));
    if (group == null) return const SliverToBoxAdapter();
    final proxies = widget.expanded ? _sortedProxies(group) : const <Proxy>[];
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: ProxyGroupCard(group: group, expanded: widget.expanded),
        ),
        if (widget.expanded)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.columns,
                mainAxisSpacing:
                    widget.cardType == ProxyCardType.oneline ? 4 : 8,
                crossAxisSpacing: 8,
                mainAxisExtent: getItemHeight(widget.cardType),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final proxy = proxies[index];
                  return ProxyCard(
                    key: ValueKey('${group.name}.${proxy.name}'),
                    groupName: group.name,
                    testUrl: group.testUrl,
                    proxy: proxy,
                    groupType: group.type,
                    type: widget.cardType,
                  );
                },
                childCount: proxies.length,
                // Offscreen cards should not keep hundreds of spinners and
                // provider subscriptions alive after scrolling through them.
                addAutomaticKeepAlives: false,
              ),
            ),
          ),
      ],
    );
  }
}

class ProxyGroupCard extends StatefulWidget {
  const ProxyGroupCard({
    super.key,
    required this.group,
    required this.expanded,
  });
  final Group group;
  final bool expanded;

  @override
  State<ProxyGroupCard> createState() => _ProxyGroupCardState();
}

class _ProxyGroupCardState extends State<ProxyGroupCard> {
  bool isLock = false;

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  bool get isExpand => widget.expanded;

  void _toggleExpansion(Set<String> currentUnfoldSet) {
    final appController = globalState.appController;
    final unfoldSet = Set<String>.from(currentUnfoldSet);

    if (currentUnfoldSet.contains(groupName)) {
      unfoldSet.remove(groupName);
    } else {
      unfoldSet.add(groupName);
    }
    appController.updateCurrentUnfoldSet(unfoldSet);
  }

  Future<void> _delayTest() async {
    if (isLock) return;
    setState(() => isLock = true);
    try {
      await delayTest(widget.group.all, widget.group.testUrl);
    } finally {
      if (mounted) setState(() => isLock = false);
    }
  }

  Widget _buildIcon() => Consumer(
        builder: (_, ref, child) {
          final iconStyle = ref.watch(
            proxiesStyleSettingProvider.select(
              (state) => state.iconStyle,
            ),
          );
          final icon = ref.watch(proxiesStyleSettingProvider.select((state) {
            final iconMapEntryList = state.iconMap.entries.toList();
            final index = iconMapEntryList.indexWhere((item) {
              try {
                return RegExp(item.key).hasMatch(groupName);
              } catch (_) {
                return false;
              }
            });
            if (index != -1) {
              return iconMapEntryList[index].value;
            }
            return this.icon;
          }));
          return switch (iconStyle) {
            ProxiesIconStyle.icon => Container(
                margin: const EdgeInsets.only(
                  right: 16,
                ),
                child: LayoutBuilder(
                  builder: (_, constraints) => CommonTargetIcon(
                    src: icon,
                    size: 38,
                  ),
                ),
              ),
            ProxiesIconStyle.none => Container(),
          };
        },
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Consumer(
      builder: (_, ref, __) {
        final unfoldSet = ref.watch(unfoldSetProvider);
        return RepaintBoundary(
          child: GestureDetector(
            onTap: () => _toggleExpansion(unfoldSet),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.opacity80,
                borderRadius: BorderRadius.circular(16.0),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        _buildIcon(),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupName,
                                style: context.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                flex: 1,
                                child: Consumer(
                                  builder: (_, ref, __) {
                                    final proxyName = ref
                                        .watch(getSelectedProxyNameProvider(
                                            groupName))
                                        .getSafeValue("");
                                    if (proxyName.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return EmojiText(
                                      overflow: TextOverflow.ellipsis,
                                      proxyName,
                                      style: context
                                          .textTheme.labelMedium?.toLight,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: isLock ? null : _delayTest,
                        visualDensity: VisualDensity.standard,
                        icon: const Icon(Icons.network_ping),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: () => _toggleExpansion(unfoldSet),
                        icon: CommonExpandIcon(expand: isExpand),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
