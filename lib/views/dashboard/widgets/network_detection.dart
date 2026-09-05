import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/views/dashboard/widgets/ip_details_dialog.dart';
import 'package:meowclash/widgets/widgets.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection> {
  bool _detailsOpen = false;

  void _refresh() {
    if (!mounted || detectionState.forceCheck()) return;
    final l10n = AppLocalizations.of(context);
    unawaited(globalState.showMessage(
      title: l10n.tip,
      message: TextSpan(text: l10n.tooFrequentOperation),
    ));
  }

  Future<void> _showDetails() async {
    if (_detailsOpen) return;
    _detailsOpen = true;
    try {
      await globalState.showCommonDialog<void>(
        child: ValueListenableBuilder<NetworkDetectionState>(
          valueListenable: detectionState.state,
          builder: (_, state, __) => IpDetailsDialog(
            ipInfo: state.ipInfo,
            isIpLoading: state.isLoading,
            loadDetails: request.getIpDetails,
            onRefresh: _refresh,
          ),
        ),
      );
    } finally {
      _detailsOpen = false;
    }
  }

  String _countryCodeToEmoji(String countryCode) {
    final code = countryCode.toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      return countryCode;
    }
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: ValueListenableBuilder<NetworkDetectionState>(
          valueListenable: detectionState.state,
          builder: (_, state, __) {
            final ipInfo = state.ipInfo;
            final isLoading = state.isLoading;
            return CommonCard(
              onPressed: _showDetails,
              onLongPress: _refresh,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: globalState.measure.titleMediumHeight + 16,
                    padding: baseInfoEdgeInsets.copyWith(
                      bottom: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        ipInfo != null
                            ? Text(
                                _countryCodeToEmoji(
                                  ipInfo.countryCode,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.toLight
                                    .copyWith(
                                      fontFamily: FontFamily.twEmoji.value,
                                    ),
                              )
                            : Icon(
                                Icons.network_check,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        const SizedBox(
                          width: 8,
                        ),
                        Flexible(
                          flex: 1,
                          child: TooltipText(
                            text: Text(
                              appLocalizations.networkDetection,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        AspectRatio(
                          aspectRatio: 1,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              globalState.showMessage(
                                title: appLocalizations.tip,
                                message: TextSpan(
                                  text: appLocalizations.detectionTip,
                                ),
                                cancelable: false,
                              );
                            },
                            icon: Icon(
                              size: 16.ap,
                              Icons.info_outline,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: baseInfoEdgeInsets.copyWith(
                        top: 0,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FadeThroughBox(
                          child: ipInfo != null
                              ? TooltipText(
                                  text: Text(
                                    ipInfo.ip,
                                    style: context.textTheme.bodyMedium?.toLight
                                        .adjustSize(1),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              : FadeThroughBox(
                                  child: isLoading == false && ipInfo == null
                                      ? Text(
                                          AppLocalizations.of(context)
                                              .ipDetailsUnavailable,
                                          style: context.textTheme.bodyMedium
                                              ?.copyWith(color: Colors.red)
                                              .adjustSize(1),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Container(
                                          padding: const EdgeInsets.all(2),
                                          child: const AspectRatio(
                                            aspectRatio: 1,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      );
}
