import 'dart:math' as math;

import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';

class LogsView extends ConsumerStatefulWidget {
  const LogsView({super.key});

  @override
  ConsumerState<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends ConsumerState<LogsView> with PageMixin {
  final _logsStateNotifier = ValueNotifier<LogsState>(
    const LogsState(loading: true),
  );
  late ScrollController _scrollController;

  double _currentMaxWidth = 0;
  final _tag = CacheTag.logs;
  bool _isLoad = false;

  List<Log> _logs = [];
  int _logsVersion = 0;

  @override
  void initState() {
    super.initState();
    final position = globalState.cacheScrollPosition[_tag] ?? -1;
    _scrollController = ScrollController(
      initialScrollOffset: position > 0 ? position : double.maxFinite,
    );
    final logs = globalState.appState.logs;
    _logs = logs.list;
    _logsVersion = logs.version;
    _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
      logs: _logs,
    );
    ref.listenManual(
      isCurrentPageProvider(
        PageLabel.logs,
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
    // Only the version per core message: no list copy or comparison.
    ref.listenManual(
      logsProvider.select((state) => state.version),
      (prev, next) {
        if (prev != next) {
          updateLogsThrottler();
        }
      },
    );
  }

  @override
  List<Widget> get actions => [
        IconButton(
          onPressed: _handleExport,
          icon: const Icon(
            Icons.file_download_outlined,
          ),
        ),
      ];

  @override
  Null Function(String value) get onSearch => (value) {
        _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
          query: value,
        );
      };

  @override
  Null Function(List<String> keywords) get onKeywordsUpdate => (keywords) {
        _logsStateNotifier.value =
            _logsStateNotifier.value.copyWith(keywords: keywords);
      };

  @override
  void dispose() {
    _logsStateNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final commonScaffoldState = context.commonScaffoldState;
    final res = await commonScaffoldState?.loadingRun<bool>(
      () async => globalState.appController.exportLogs(),
      title: appLocalizations.exportLogs,
    );
    if (res != true) return;
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(text: appLocalizations.exportSuccess),
    );
  }

  double _getItemHeight(Log log) {
    if (AdaptivePlatform.useGlass) {
      // Darwin rows: measured with the styles and tokens they paint with;
      // [_currentMaxWidth] is the full list width there.
      return _GlassLogItem.extentOf(
        log,
        width: _currentMaxWidth,
        textTheme: context.textTheme,
      );
    }
    final measure = globalState.measure;
    final bodySmallHeight = measure.bodySmallHeight;
    final bodyMediumHeight = measure.bodyMediumHeight;
    final height = globalState.measure
        .computeTextSize(
          Text(
            log.payload,
            style: context.textTheme.bodyLarge,
          ),
          maxWidth: _currentMaxWidth,
        )
        .height;
    return height + bodySmallHeight + 8 + bodyMediumHeight + 40 + 8;
  }

  void updateLogsThrottler() {
    throttler.call(FunctionTag.logs, () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        // One snapshot per throttled update.
        final logs = ref.read(logsProvider);
        if (logs.version == _logsVersion) {
          return;
        }
        _logsVersion = logs.version;
        _logs = logs.list;
        _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
          logs: _logs,
        );
      });
      // A post-frame callback does not schedule a frame: an idle screen
      // would hold the update until something else draws.
      WidgetsBinding.instance.ensureVisualUpdate();
    }, duration: commonDuration);
  }

  void _preLoad() {
    if (_isLoad == true) {
      return;
    }
    _isLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final isMobileView = ref.read(isMobileViewProvider);
      if (isMobileView) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      final parts = _logs.batch(10);
      globalState.cacheHeightMap[_tag] ??= FixedMap(
        _logs.length,
      );
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        await Future(
          () {
            for (final log in part) {
              globalState.cacheHeightMap[_tag]?.updateCacheValue(
                log.payload,
                () => _getItemHeight(log),
              );
            }
          },
        );
      }
      _logsStateNotifier.value = _logsStateNotifier.value.copyWith(
        loading: false,
      );
    });
  }

  Widget _buildGlass(LogsState state, List<Log> logs) {
    // Scrolls under the glass toolbar (`scrollUnderToolbar` in home.dart).
    // In the reverse list the top padding lies past the oldest row, at the
    // visual top.
    final topInset = AdaptiveAppBar.topInset(context);
    final Widget content;
    if (state.loading) {
      content = Padding(
        padding: EdgeInsets.only(top: topInset),
        child: const Center(child: AdaptiveActivityIndicator()),
      );
    } else if (logs.isEmpty) {
      content = Padding(
        padding: EdgeInsets.only(top: topInset),
        child: AdaptiveEmptyState(
          label: appLocalizations.nullTip(appLocalizations.logs),
          icon: Icons.article_outlined,
        ),
      );
    } else {
      content = Align(
        alignment: Alignment.topCenter,
        child: AdaptiveScrollbar(
          controller: _scrollController,
          child: ScrollToEndBox(
            controller: _scrollController,
            tag: _tag,
            dataSource: logs,
            child: CacheItemExtentListView(
              tag: _tag,
              reverse: true,
              shrinkWrap: true,
              physics: const NextClampingScrollPhysics(),
              controller: _scrollController,
              padding: EdgeInsets.only(top: topInset),
              itemExtentBuilder: (index) => _getItemHeight(logs[index]),
              itemBuilder: (context, index) {
                final log = logs[index];
                return _GlassLogItem(
                  key: Key(log.dateTime),
                  log: log,
                  onClick: (value) {
                    context.commonScaffoldState?.addKeyword(value);
                  },
                );
              },
              itemCount: logs.length,
              keyBuilder: (index) => logs[index].payload,
            ),
          ),
        ),
      );
    }
    return FadeBox(child: content);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) {
          _currentMaxWidth = AdaptivePlatform.useGlass
              ? constraints.maxWidth
              : constraints.maxWidth - 40;
          return ValueListenableBuilder<LogsState>(
            valueListenable: _logsStateNotifier,
            builder: (_, state, __) {
              _preLoad();
              final logs = state.list;
              if (AdaptivePlatform.useGlass) {
                return _buildGlass(state, logs);
              }
              final items = logs
                  .map<Widget>(
                    (log) => LogItem(
                      key: Key(log.dateTime),
                      log: log,
                      onClick: (value) {
                        context.commonScaffoldState?.addKeyword(value);
                      },
                    ),
                  )
                  .separated(
                    const Divider(
                      height: 0,
                    ),
                  )
                  .toList();
              final content = logs.isEmpty
                  ? NullStatus(
                      label: appLocalizations.nullTip(
                        appLocalizations.logs,
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: CommonScrollBar(
                        controller: _scrollController,
                        child: ScrollToEndBox(
                          controller: _scrollController,
                          tag: _tag,
                          dataSource: logs,
                          child: CacheItemExtentListView(
                            tag: _tag,
                            reverse: true,
                            shrinkWrap: true,
                            physics: const NextClampingScrollPhysics(),
                            controller: _scrollController,
                            itemBuilder: (_, index) => items[index],
                            itemExtentBuilder: (index) {
                              if (index.isOdd) {
                                return 0;
                              }
                              return _getItemHeight(logs[index ~/ 2]);
                            },
                            itemCount: items.length,
                            keyBuilder: (index) {
                              if (index.isOdd) {
                                return "divider";
                              }
                              return logs[index ~/ 2].payload;
                            },
                          ),
                        ),
                      ),
                    );
              return FadeBox(
                child: state.loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : content,
              );
            },
          );
        },
      );
}

class LogItem extends StatelessWidget {
  const LogItem({
    super.key,
    required this.log,
    this.onClick,
  });
  final Log log;
  final Function(String)? onClick;

  @override
  Widget build(BuildContext context) => ListItem(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        title: SelectableText(
          log.payload,
          style: context.textTheme.bodyLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              log.dateTime,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Container(
              alignment: Alignment.centerLeft,
              child: CommonChip(
                onPressed: () {
                  if (onClick == null) return;
                  onClick!(log.logLevel.name);
                },
                label: log.logLevel.name,
              ),
            ),
          ],
        ),
      );
}

/// Darwin log row (Console.app): the line in SF Mono, selectable, over a
/// colored level capsule (tap = filter by level) and the time.
class _GlassLogItem extends StatelessWidget {
  const _GlassLogItem({
    super.key,
    required this.log,
    required this.onClick,
  });

  final Log log;
  final ValueChanged<String>? onClick;

  /// Item extent of the row of [log] in a list [width] wide, from the same
  /// styles and tokens [build] paints with.
  static double extentOf(
    Log log, {
    required double width,
    required TextTheme textTheme,
  }) {
    final measure = globalState.measure;
    final payloadWidth = GlassStreamRow.contentWidth(width) -
        GlassTokens.selectableCaretReserve;
    final payload = measure.computeTextSize(
      Text(log.payload, style: GlassTextStyles.logPayload(textTheme)),
      maxWidth: payloadWidth,
    );
    final meta = math.max(
      GlassTag.heightOf(),
      measure.heightOf(GlassTextStyles.streamMetric(textTheme)),
    );
    return GlassStreamRow.extentOf(
      payload.height + GlassStreamRow.tagGap + meta,
    );
  }

  /// Level capsule color: system colors by severity, the accent for the
  /// app's own messages.
  static Color levelColor(LogLevel level, ColorScheme scheme) {
    final brightness = scheme.brightness;
    return switch (level) {
      LogLevel.debug || LogLevel.silent => GlassTokens.systemGray(brightness),
      LogLevel.info => GlassTokens.systemBlue(brightness),
      LogLevel.warning => GlassTokens.systemOrange(brightness),
      LogLevel.error => GlassTokens.systemRed(brightness),
      LogLevel.app => scheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final level = log.logLevel;
    final onClick = this.onClick;
    return GlassStreamRow(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            log.payload,
            style: GlassTextStyles.logPayload(textTheme),
          ),
          SizedBox(height: GlassStreamRow.tagGap),
          Row(
            children: [
              GlassTag(
                label: level.name,
                color: levelColor(level, scheme),
                onPressed: onClick == null ? null : () => onClick(level.name),
              ),
              const SizedBox(width: GlassTokens.streamRowTrailingGap),
              Flexible(
                child: Text(
                  log.dateTime,
                  style: GlassTextStyles.streamMetric(textTheme).copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
