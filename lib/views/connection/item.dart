import 'dart:io';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/plugins/app.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionItem extends ConsumerWidget {

  const ConnectionItem({
    super.key,
    required this.connection,
    this.onClickKeyword,
    this.trailing,
    this.onClose,
    this.showTraffic = false,
  });
  final Connection connection;
  final Function(String)? onClickKeyword;
  final Widget? trailing;

  Future<ImageProvider?> _getPackageIcon(Connection connection) async => await app?.getPackageIcon(connection.metadata.process);

  /// Darwin: closes the connection (✕ on macOS, swipe on iOS, context menu).
  /// Material rows close through [trailing] instead.
  final VoidCallback? onClose;

  /// Darwin: ↑/↓ traffic at the trailing edge (live connections).
  final bool showTraffic;

  /// Item extent of the Darwin row of [connection] in a list [width] wide,
  /// from the same styles and tokens [_GlassConnectionItem] paints with.
  /// For rows without trailing content (requests).
  static double glassExtent(
    Connection connection, {
    required double width,
    required TextTheme textTheme,
  }) {
    final measure = globalState.measure;
    final contentWidth = GlassStreamRow.contentWidth(width);
    final title = measure.computeTextSize(
      Text(connection.desc, style: GlassTextStyles.listRowTitle(textTheme)),
      maxWidth: contentWidth,
    );
    var height = title.height +
        GlassTokens.streamRowLineGap +
        measure.heightOf(GlassTextStyles.listRowSubtitle(textTheme));
    final chains = connection.chains;
    if (chains.isNotEmpty) {
      final tagStyle = GlassTextStyles.tag(textTheme);
      final padding = defaultTargetPlatform == TargetPlatform.macOS
          ? GlassTokens.tagPaddingMac
          : GlassTokens.tagPaddingIos;
      var lines = 1;
      var lineWidth = 0.0;
      for (final chain in chains) {
        final textWidth =
            measure.computeTextSize(Text(chain, style: tagStyle)).width;
        final tagWidth = (textWidth + 2 * padding).clamp(0.0, contentWidth);
        if (lineWidth == 0) {
          lineWidth = tagWidth;
        } else if (lineWidth + GlassTokens.tagGap + tagWidth <= contentWidth) {
          lineWidth += GlassTokens.tagGap + tagWidth;
        } else {
          lines++;
          lineWidth = tagWidth;
        }
      }
      height += GlassStreamRow.tagGap +
          lines * GlassTag.heightOf() +
          (lines - 1) * GlassTokens.tagGap;
    }
    return GlassStreamRow.extentOf(height);
  }

  static String _getSourceText(Connection connection) {
    final metadata = connection.metadata;
    if (metadata.process.isEmpty) {
      return connection.start.lastUpdateTimeDesc;
    }
    return "${metadata.process} · ${connection.start.lastUpdateTimeDesc}";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AdaptivePlatform.useGlass) {
      return _GlassConnectionItem(
        connection: connection,
        onClickKeyword: onClickKeyword,
        onClose: onClose,
        showTraffic: showTraffic,
      );
    }
    final value = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always &&
            Platform.isAndroid,
      ),
    );
    final title = Text(
      connection.desc,
      style: context.textTheme.bodyLarge,
    );
    final subTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 8,
        ),
        Text(
          _getSourceText(connection),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(
          height: 8,
        ),
        Wrap(
          runSpacing: 6,
          spacing: 6,
          children: [
            for (final chain in connection.chains)
              CommonChip(
                label: chain,
                onPressed: () {
                  if (onClickKeyword == null) return;
                  onClickKeyword!(chain);
                },
              ),
          ],
        ),
      ],
    );
    return CommonPopupBox(
      targetBuilder: (open) =>
          // openPopup(Offset offset) {
          //   open(
          //     offset: offset.translate(
          //       0,
          //       0,
          //     ),
          //   );
          // }

          InkWell(
          child: GestureDetector(
            // onLongPressStart: (details) {
            //   if (!system.isDesktop) {
            //     return;
            //   }
            //   openPopup(details.localPosition);
            // },
            // onSecondaryTapDown: (details) {
            //   if (!system.isDesktop) {
            //     return;
            //   }
            //   openPopup(details.localPosition);
            // },
            child: ListItem(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              tileTitleAlignment: ListTileTitleAlignment.titleHeight,
              leading: value
                  ? GestureDetector(
                      onTap: () {
                        if (onClickKeyword == null) return;
                        final process = connection.metadata.process;
                        if (process.isEmpty) return;
                        onClickKeyword!(process);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 48,
                        height: 48,
                        child: FutureBuilder<ImageProvider?>(
                          future: _getPackageIcon(connection),
                          builder: (_, snapshot) {
                            if (!snapshot.hasData && snapshot.data == null) {
                              return Container();
                            } else {
                              return Image(
                                image: snapshot.data!,
                                gaplessPlayback: true,
                                width: 48,
                                height: 48,
                              );
                            }
                          },
                        ),
                      ),
                    )
                  : null,
              title: title,
              subtitle: subTitle,
              trailing: trailing,
            ),
          ),
          onTap: () {},
        ),
      popup: CommonPopupMenu(
        minWidth: 160,
        items: [
          PopupMenuItemData(
            label: "编辑规则",
            onPressed: () {
              // _handleShowEditExtendPage(context);
            },
          ),
          PopupMenuItemData(
            label: "设置直连",
            onPressed: () {},
          ),
          PopupMenuItemData(
            label: "一键屏蔽",
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Darwin row: a flat [GlassStreamRow] (no card, no blur) with the host, the
/// process and time, the proxy chain as [GlassTag]s (tap = keyword filter)
/// and, for live connections, ↑/↓ traffic and close.
///
/// Close: ✕ at the trailing edge on macOS, swipe to the leading edge on iOS;
/// right click (macOS, native `NSMenu`) or long press (iOS, glass menu)
/// opens Copy Host / Filter by Process / Close Connection.
class _GlassConnectionItem extends StatelessWidget {
  const _GlassConnectionItem({
    required this.connection,
    required this.onClickKeyword,
    required this.onClose,
    required this.showTraffic,
  });

  final Connection connection;
  final Function(String)? onClickKeyword;
  final VoidCallback? onClose;
  final bool showTraffic;

  String get _host {
    final metadata = connection.metadata;
    return metadata.host.isNotEmpty ? metadata.host : metadata.destinationIP;
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final host = _host;
    final process = connection.metadata.process;
    final onKeyword = onClickKeyword;
    final entries = [
      AdaptiveMenuEntry(
        label: appLocalizations.copyHost,
        icon: Icons.content_copy_outlined,
        onPressed: host.isEmpty
            ? null
            : () => Clipboard.setData(ClipboardData(text: host)),
      ),
      AdaptiveMenuEntry(
        label: appLocalizations.filterByProcess,
        icon: Icons.filter_alt_outlined,
        onPressed: process.isEmpty || onKeyword == null
            ? null
            : () => onKeyword(process),
      ),
      if (onClose != null)
        AdaptiveMenuEntry(
          label: appLocalizations.closeConnection,
          icon: Icons.close_rounded,
          destructive: true,
          onPressed: onClose,
        ),
    ];
    final anchor = Rect.fromLTWH(position.dx, position.dy, 0, 0);
    final shown = await AdaptiveContextMenu.showNative(
      anchor: anchor,
      entries: entries,
    );
    if (shown || !context.mounted) return;
    await AdaptiveContextMenu.showGlass(
      context: context,
      anchor: anchor,
      entries: entries,
    );
  }

  Widget? _buildTrailing(BuildContext context, TextTheme textTheme) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final upload = connection.upload;
    final download = connection.download;
    final traffic = showTraffic && (upload != null || download != null);
    final close = onClose != null && AdaptivePlatform.isMacOSGlass;
    if (!traffic && !close) return null;
    final metric = GlassTextStyles.streamMetric(textTheme).copyWith(
      color: secondary,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (traffic)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '↑ ${TrafficValue(value: upload?.toInt()).show}',
                style: metric,
                maxLines: 1,
              ),
              Text(
                '↓ ${TrafficValue(value: download?.toInt()).show}',
                style: metric,
                maxLines: 1,
              ),
            ],
          ),
        if (traffic && close)
          const SizedBox(width: GlassTokens.streamRowTrailingGap),
        if (close)
          GlassIconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
            size: GlassTokens.streamRowCloseSizeMac,
            iconSize: GlassTokens.streamRowCloseIconSizeMac,
            tooltip: appLocalizations.closeConnection,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final secondary = theme.colorScheme.onSurfaceVariant;
    final onKeyword = onClickKeyword;
    final chains = connection.chains;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          connection.desc,
          style: GlassTextStyles.listRowTitle(textTheme),
        ),
        const SizedBox(height: GlassTokens.streamRowLineGap),
        Text(
          ConnectionItem._getSourceText(connection),
          style: GlassTextStyles.listRowSubtitle(textTheme).copyWith(
            color: secondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (chains.isNotEmpty) ...[
          SizedBox(height: GlassStreamRow.tagGap),
          Wrap(
            spacing: GlassTokens.tagGap,
            runSpacing: GlassTokens.tagGap,
            children: [
              for (final chain in chains)
                GlassTag(
                  label: chain,
                  onPressed: onKeyword == null ? null : () => onKeyword(chain),
                ),
            ],
          ),
        ],
      ],
    );
    final trailing = _buildTrailing(context, textTheme);
    final onClose = this.onClose;
    return GlassStreamRow(
      onContextMenu: (position) => _showMenu(context, position),
      swipeAction: onClose == null
          ? null
          : GlassSwipeAction(
              label: MaterialLocalizations.of(context).closeButtonLabel,
              onPressed: onClose,
            ),
      child: trailing == null
          ? content
          : Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: GlassTokens.streamRowTrailingGap),
                trailing,
              ],
            ),
    );
  }
}
