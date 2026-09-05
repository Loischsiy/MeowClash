import 'dart:async';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/app.g.dart';

@riverpod
class RealTunEnable extends _$RealTunEnable with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.realTunEnable;

  @override
  void onUpdate(bool value) {
    globalState.appState = globalState.appState.copyWith(
      realTunEnable: value,
    );
  }
}

@riverpod
class Logs extends _$Logs with AutoDisposeNotifierMixin {
  @override
  FixedList<Log> build() => globalState.appState.logs;

  void addLog(Log value) {
    state = state.copyWith()..add(value);
  }

  @override
  void onUpdate(FixedList<Log> value) {
    globalState.appState = globalState.appState.copyWith(
      logs: value,
    );
  }
}

@riverpod
class Requests extends _$Requests with AutoDisposeNotifierMixin {
  @override
  FixedList<Connection> build() => globalState.appState.requests;

  @override
  void onUpdate(FixedList<Connection> value) {
    globalState.appState = globalState.appState.copyWith(
      requests: value,
    );
  }

  void addRequest(Connection value) {
    state = state.copyWith()..add(value);
  }
}

@riverpod
class Providers extends _$Providers with AutoDisposeNotifierMixin {
  @override
  List<ExternalProvider> build() => globalState.appState.providers;

  @override
  void onUpdate(List<ExternalProvider> value) {
    globalState.appState = globalState.appState.copyWith(
      providers: value,
    );
  }

  void setProvider(ExternalProvider? provider) {
    if (provider == null) return;
    final index = state.indexWhere((item) => item.name == provider.name);
    if (index == -1) {
      state = List.from(state)..add(provider);
      return;
    }
    state = List.from(state)..[index] = provider;
  }
}

@riverpod
class Packages extends _$Packages with AutoDisposeNotifierMixin {
  @override
  List<Package> build() => globalState.appState.packages;

  @override
  void onUpdate(List<Package> value) {
    globalState.appState = globalState.appState.copyWith(
      packages: value,
    );
  }
}

@riverpod
class AppBrightness extends _$AppBrightness with AutoDisposeNotifierMixin {
  @override
  Brightness? build() => globalState.appState.brightness;

  @override
  void onUpdate(Brightness? value) {
    globalState.appState = globalState.appState.copyWith(
      brightness: value,
    );
  }

  void setState(Brightness? value) {
    state = value;
  }
}

@riverpod
class Traffics extends _$Traffics with AutoDisposeNotifierMixin {
  @override
  FixedList<Traffic> build() => globalState.appState.traffics;

  @override
  void onUpdate(FixedList<Traffic> value) {
    globalState.appState = globalState.appState.copyWith(
      traffics: value,
    );
  }

  void addTraffic(Traffic value) {
    state = state.copyWith()..add(value);
  }

  void clear() {
    state = state.copyWith()..clear();
  }
}

@riverpod
class TotalTraffic extends _$TotalTraffic with AutoDisposeNotifierMixin {
  @override
  Traffic build() => globalState.appState.totalTraffic;

  @override
  void onUpdate(Traffic value) {
    globalState.appState = globalState.appState.copyWith(
      totalTraffic: value,
    );
  }
}

@riverpod
class LocalIp extends _$LocalIp with AutoDisposeNotifierMixin {
  @override
  String? build() => globalState.appState.localIp;

  @override
  void onUpdate(String? value) {
    globalState.appState = globalState.appState.copyWith(
      localIp: value,
    );
  }

  @override
  set state(String? value) {
    super.state = value;
    globalState.appState = globalState.appState.copyWith(
      localIp: state,
    );
  }
}

@riverpod
class RunTime extends _$RunTime with AutoDisposeNotifierMixin {
  @override
  int? build() => globalState.appState.runTime;

  @override
  void onUpdate(int? value) {
    globalState.appState = globalState.appState.copyWith(
      runTime: value,
    );
  }

  bool get isStart => state != null;
}

@riverpod
class ViewSize extends _$ViewSize with AutoDisposeNotifierMixin {
  @override
  Size build() => globalState.appState.viewSize;

  @override
  void onUpdate(Size value) {
    globalState.appState = globalState.appState.copyWith(
      viewSize: value,
    );
  }

  ViewMode get viewMode => utils.getViewMode(state.width);

  bool get isMobileView => viewMode == ViewMode.mobile;
}

@riverpod
double viewWidth(Ref ref) => ref.watch(viewSizeProvider).width;

@riverpod
ViewMode viewMode(Ref ref) => utils.getViewMode(ref.watch(viewWidthProvider));

@riverpod
bool isMobileView(Ref ref) => ref.watch(viewModeProvider) == ViewMode.mobile;

@riverpod
double viewHeight(Ref ref) => ref.watch(viewSizeProvider).height;

@riverpod
class Init extends _$Init with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.isInit;

  @override
  void onUpdate(bool value) {
    globalState.appState = globalState.appState.copyWith(
      isInit: value,
    );
  }
}

@riverpod
class CurrentPageLabel extends _$CurrentPageLabel
    with AutoDisposeNotifierMixin {
  @override
  PageLabel build() => globalState.appState.pageLabel;

  @override
  void onUpdate(PageLabel value) {
    globalState.appState = globalState.appState.copyWith(
      pageLabel: value,
    );
  }
}

@riverpod
class SortNum extends _$SortNum with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.sortNum;

  @override
  void onUpdate(int value) {
    globalState.appState = globalState.appState.copyWith(
      sortNum: value,
    );
  }

  int add() => state++;
}

@riverpod
class CheckIpNum extends _$CheckIpNum with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.checkIpNum;

  @override
  void onUpdate(int value) {
    globalState.appState = globalState.appState.copyWith(
      checkIpNum: value,
    );
  }

  int add() => state++;
}

@riverpod
class BackBlock extends _$BackBlock with AutoDisposeNotifierMixin {
  @override
  bool build() => globalState.appState.backBlock;

  @override
  void onUpdate(bool value) {
    globalState.appState = globalState.appState.copyWith(
      backBlock: value,
    );
  }
}

@riverpod
class Version extends _$Version with AutoDisposeNotifierMixin {
  @override
  int build() => globalState.appState.version;

  @override
  void onUpdate(int value) {
    globalState.appState = globalState.appState.copyWith(
      version: value,
    );
  }
}

@riverpod
class Groups extends _$Groups with AutoDisposeNotifierMixin {
  @override
  List<Group> build() => globalState.appState.groups;

  bool setGroups(List<Group> groups) {
    final previous = {for (final group in state) group.name: group};
    final next = [
      for (final group in groups)
        if (previous[group.name] == group) previous[group.name]! else group,
    ];
    if (listEquals(state, next)) return false;
    state = next;
    return true;
  }

  @override
  void onUpdate(List<Group> value) {
    globalState.appState = globalState.appState.copyWith(
      groups: value,
    );
  }
}

@riverpod
class DelayDataSource extends _$DelayDataSource with AutoDisposeNotifierMixin {
  static const updateInterval = Duration(milliseconds: 50);
  final _pending = <String, Map<String, int?>>{};
  Timer? _timer;
  KeepAliveLink? _pendingKeepAlive;

  @override
  DelayMap build() {
    ref.onDispose(() {
      _timer?.cancel();
      _pending.clear();
    });
    return globalState.appState.delayMap;
  }

  @override
  void onUpdate(DelayMap value) {
    globalState.appState = globalState.appState.copyWith(delayMap: value);
  }

  void setDelay(Delay delay) {
    final pending = _pending[delay.url];
    final previous = pending != null && pending.containsKey(delay.name)
        ? pending[delay.name]
        : state[delay.url]?[delay.name];
    if (previous == delay.value) return;
    (_pending[delay.url] ??= {})[delay.name] = delay.value;
    // A read-only consumer (e.g. a hidden page) must not lose pending updates
    // when the auto-dispose provider reaches the end of a frame.
    _pendingKeepAlive ??= ref.keepAlive();
    _timer ??= Timer(updateInterval, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isNotEmpty) {
      final next = Map<String, Map<String, int?>>.of(state);
      var changed = false;
      for (final entry in _pending.entries) {
        final previous = state[entry.key] ?? const <String, int?>{};
        final updates = Map<String, int?>.of(previous);
        var bucketChanged = false;
        for (final delay in entry.value.entries) {
          if (previous[delay.key] != delay.value) {
            updates[delay.key] = delay.value;
            bucketChanged = true;
          }
        }
        if (bucketChanged) {
          next[entry.key] = updates;
          changed = true;
        }
      }
      _pending.clear();
      if (changed) state = next;
    }
    _pendingKeepAlive?.close();
    _pendingKeepAlive = null;
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _pendingKeepAlive?.close();
    _pendingKeepAlive = null;
    state = {};
  }
}

@riverpod
class ProxiesQuery extends _$ProxiesQuery with AutoDisposeNotifierMixin {
  @override
  String build() => globalState.appState.proxiesQuery;

  @override
  void onUpdate(String value) {
    globalState.appState = globalState.appState.copyWith(
      proxiesQuery: value,
    );
  }
}
