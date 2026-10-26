import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/services/async_polling_loop.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/visibility_polling.dart';
import 'package:meowclash/widgets/widgets.dart';

import 'item.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  const ConnectionsView({super.key, this.loadConnections});

  final Future<List<Connection>> Function()? loadConnections;

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with PageMixin, VisibilityPollingMixin<ConnectionsView> {
  final _connectionsStateNotifier = ValueNotifier<ConnectionsState>(
    const ConnectionsState(),
  );
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  @override
  Duration get pollingInterval => const Duration(seconds: 1);

  @override
  List<Widget> get actions => [
        IconButton(
          onPressed: () async {
            clashCore.closeConnections();
            await polling.refresh();
          },
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ];

  @override
  Null Function(String value) get onSearch => (value) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(
          query: value,
        );
      };

  @override
  Null Function(List<String> keywords) get onKeywordsUpdate => (keywords) {
        _connectionsStateNotifier.value =
            _connectionsStateNotifier.value.copyWith(keywords: keywords);
      };

  @override
  Future<void> poll(PollingToken token) async {
    final connections =
        await (widget.loadConnections?.call() ?? clashCore.getConnections());
    if (!mounted || !token.isCurrent) return;
    _connectionsStateNotifier.value =
        _connectionsStateNotifier.value.copyWith(connections: connections);
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      isCurrentPageProvider(
        PageLabel.connections,
        handler: (pageLabel, viewMode) =>
            pageLabel == PageLabel.tools && viewMode == ViewMode.mobile,
      ),
      (prev, next) {
        if (prev != next && next == true) {
          initPageState();
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _handleBlockConnection(String id) async {
    clashCore.closeConnection(id);
    await polling.refresh();
  }

  /// Darwin: flat stream rows (hairlines inside the rows, no dividers), ↑/↓
  /// traffic, close by ✕ / swipe / context menu; no blur anywhere.
  Widget _buildGlassList(List<Connection> connections) => AdaptiveScrollbar(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final connection = connections[index];
            return ConnectionItem(
              key: Key(connection.id),
              connection: connection,
              showTraffic: true,
              onClickKeyword: (value) {
                context.commonScaffoldState?.addKeyword(value);
              },
              onClose: () {
                _handleBlockConnection(connection.id);
              },
            );
          },
        ),
      );

  @override
  void dispose() {
    _connectionsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ConnectionsState>(
        valueListenable: _connectionsStateNotifier,
        builder: (_, state, __) {
          final connections = state.list;
          if (connections.isEmpty) {
            return AdaptiveEmptyState(
              label: appLocalizations.nullTip(appLocalizations.connections),
              icon: Icons.cable_outlined,
            );
          }
          if (AdaptivePlatform.useGlass) {
            return _buildGlassList(connections);
          }
          return CommonScrollBar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              itemBuilder: (_, index) {
                final connection = connections[index];
                return ConnectionItem(
                  key: Key(connection.id),
                  connection: connection,
                  onClickKeyword: (value) {
                    context.commonScaffoldState?.addKeyword(value);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.block),
                    onPressed: () {
                      _handleBlockConnection(connection.id);
                    },
                  ),
                );
              },
              separatorBuilder: (context, index) => const Divider(
                height: 0,
              ),
              itemCount: connections.length,
            ),
          );
        },
      );
}
