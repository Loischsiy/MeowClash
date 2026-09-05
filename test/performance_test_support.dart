import 'package:flutter/material.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';

void initializePerformanceState(
    {List<Group> groups = const [], DelayMap delays = const {}}) {
  globalState.appState = AppState(
    version: 1,
    viewSize: const Size(800, 600),
    groups: groups,
    delayMap: delays,
    requests: FixedList<Connection>(10),
    logs: FixedList<Log>(10),
    traffics: FixedList<Traffic>(10),
    totalTraffic: Traffic(),
  );
  globalState.config = const Config(themeProps: defaultThemeProps);
}
