import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/proxies/common.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyCard extends StatelessWidget {

  const ProxyCard({
    super.key,
    required this.groupName,
    required this.testUrl,
    required this.proxy,
    required this.groupType,
    required this.type,
  });
  final String groupName;
  final Proxy proxy;
  final GroupType groupType;
  final ProxyCardType type;
  final String? testUrl;

  Measure get measure => globalState.measure;

  void _handleTestCurrentDelay() {
    proxyDelayTest(
      proxy,
      testUrl,
    );
  }

  bool _canDrillDown(Group? group) =>
      group?.hidden == true && group?.type == GroupType.URLTest;

  void _openProxyGroup(BuildContext context, Group group) {
    showExtend(
      context,
      props: const ExtendProps(maxWidth: 480),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: _ProxyGroupDrillDownView(groupName: group.name),
        title: group.name,
      ),
    );
  }

  Widget _buildDelayText() => SizedBox(
      height: measure.labelSmallHeight,
      child: Consumer(
        builder: (context, ref, __) {
          final delay = ref.watch(getDelayProvider(
            proxyName: proxy.name,
            testUrl: testUrl,
          ));
          return delay == 0 || delay == null
              ? SizedBox(
                  height: measure.labelSmallHeight,
                  width: measure.labelSmallHeight,
                  child: delay == 0
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                        )
                      : IconButton(
                          icon: const Icon(Icons.bolt),
                          iconSize: globalState.measure.labelSmallHeight,
                          padding: EdgeInsets.zero,
                          onPressed: _handleTestCurrentDelay,
                        ),
                )
              : GestureDetector(
                  onTap: _handleTestCurrentDelay,
                  child: Text(
                    delay > 0 ? '$delay ms' : "Timeout",
                    style: context.textTheme.labelSmall?.copyWith(
                      overflow: TextOverflow.ellipsis,
                      color: utils.getDelayColor(
                        delay,
                      ),
                    ),
                  ),
                );
        },
      ),
    );

  Widget _buildProxyNameText(BuildContext context) {
    if (type == ProxyCardType.oneline) {
      return Consumer(
        builder: (context, ref, child) {
          final isSelected = groupType.isComputedSelected &&
              ref.watch(getProxyNameProvider(groupName)) == proxy.name;

          return Padding(
            padding:
                isSelected ? const EdgeInsets.only(right: 32) : EdgeInsets.zero,
            child: child,
          );
        },
        child: SizedBox(
          height: measure.bodyMediumHeight * 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: EmojiText(
                  proxy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              _buildDelayText(),
            ],
          ),
        ),
      );
    } else if (type == ProxyCardType.min) {
      return SizedBox(
        height: measure.bodyMediumHeight * 1,
        child: EmojiText(
          proxy.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium,
        ),
      );
    } else {
      return SizedBox(
        height: measure.bodyMediumHeight * 2,
        child: EmojiText(
          proxy.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium,
        ),
      );
    }
  }

  Future<void> _changeProxy(WidgetRef ref) async {
    final isComputedSelected = groupType.isComputedSelected;
    final isSelector = groupType == GroupType.Selector;
    if (isComputedSelected || isSelector) {
      final currentProxyName = ref.read(getProxyNameProvider(groupName));
      final nextProxyName = switch (isComputedSelected) {
        true => currentProxyName == proxy.name ? "" : proxy.name,
        false => proxy.name,
      };
      final appController = globalState.appController;
      appController.updateCurrentSelectedMap(
        groupName,
        nextProxyName,
      );
      appController.changeProxyDebounce(groupName, nextProxyName);
      return;
    }
    globalState.showNotifier(
      appLocalizations.notSelectedTip,
    );
  }

  @override
  Widget build(BuildContext context) {
    final measure = globalState.measure;
    final delayText = _buildDelayText();
    final proxyNameText = _buildProxyNameText(context);
    return Stack(
      children: [
        Consumer(
          builder: (_, ref, child) {
            final selectedProxyName =
                ref.watch(getSelectedProxyNameProvider(groupName));
            final drillDownGroup = ref.watch(
              groupsProvider.select((state) {
                final group = state.getGroup(proxy.name);
                return _canDrillDown(group) ? group : null;
              }),
            );
            return CommonCard(
              key: key,
              onPressed: () {
                _changeProxy(ref);
              },
              onLongPress: drillDownGroup != null
                  ? () => _openProxyGroup(context, drillDownGroup)
                  : null,
              isSelected: selectedProxyName == proxy.name,
              child: child!,
            );
          },
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                proxyNameText,
                if (type != ProxyCardType.oneline) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  if (type == ProxyCardType.expand) ...[
                    SizedBox(
                      height: measure.bodySmallHeight,
                      child: _ProxyDesc(
                        proxy: proxy,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    delayText,
                  ] else
                    SizedBox(
                      height: measure.bodySmallHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 1,
                            child: _ProxyDesc(proxy: proxy),
                          ),
                          delayText,
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (groupType.isComputedSelected)
          Positioned(
            top: 0,
            right: 0,
            child: _ProxyComputedMark(
              groupName: groupName,
              proxy: proxy,
              cardType: type,
            ),
          )
      ],
    );
  }
}

class _ProxyGroupDrillDownView extends ConsumerStatefulWidget {
  const _ProxyGroupDrillDownView({required this.groupName});

  final String groupName;

  @override
  ConsumerState<_ProxyGroupDrillDownView> createState() =>
      _ProxyGroupDrillDownViewState();
}

class _ProxyGroupDrillDownViewState
    extends ConsumerState<_ProxyGroupDrillDownView> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(
      groupsProvider.select((state) => state.getGroup(widget.groupName)),
    );
    if (group == null) {
      return NullStatus(
        label: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }

    final proxiesStyle = ref.watch(proxiesStyleSettingProvider);
    ref.watch(sortNumProvider);
    final sortedProxies = globalState.appController.getSortProxies(
      group.all,
      group.testUrl,
    );
    if (sortedProxies.isEmpty) {
      return NullStatus(
        label: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = utils.getProxiesColumns(
          constraints.maxWidth,
          proxiesStyle.layout,
        );
        return CommonAutoHiddenScrollBar(
          controller: _controller,
          child: GridView.builder(
            controller: _controller,
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: getItemHeight(proxiesStyle.cardType),
            ),
            itemCount: sortedProxies.length,
            itemBuilder: (_, index) {
              final proxy = sortedProxies[index];
              return ProxyCard(
                testUrl: group.testUrl,
                groupType: group.type,
                type: proxiesStyle.cardType,
                key: ValueKey('${group.name}.${proxy.name}'),
                proxy: proxy,
                groupName: group.name,
              );
            },
          ),
        );
      },
    );
  }
}

class _ProxyDesc extends ConsumerWidget {

  const _ProxyDesc({
    required this.proxy,
  });
  final Proxy proxy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ref.watch(
      getProxyDescProvider(proxy),
    );
    return EmojiText(
      desc,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.textTheme.bodySmall?.color?.opacity80,
      ),
    );
  }
}

class _ProxyComputedMark extends ConsumerWidget {

  const _ProxyComputedMark({
    required this.groupName,
    required this.proxy,
    required this.cardType,
  });
  final String groupName;
  final Proxy proxy;
  final ProxyCardType cardType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxyName = ref.watch(
      getProxyNameProvider(groupName),
    );
    if (proxyName != proxy.name) {
      return const SizedBox();
    }

    final margin = cardType == ProxyCardType.oneline
        ? const EdgeInsets.fromLTRB(8, 4, 8, 8)
        : const EdgeInsets.all(8);

    return Container(
      alignment: Alignment.topRight,
      margin: margin,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.secondaryContainer,
        ),
        child: const SelectIcon(),
      ),
    );
  }
}
