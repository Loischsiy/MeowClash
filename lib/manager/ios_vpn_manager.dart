import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:meowclash/plugins/ios.dart';
import 'package:meowclash/state.dart';

/// Reflects Settings/OS VPN changes without issuing another start/stop command.
class IOSVpnManager extends StatefulWidget {
  const IOSVpnManager({super.key, required this.child});
  final Widget child;

  @override
  State<IOSVpnManager> createState() => _IOSVpnManagerState();
}

class _IOSVpnManagerState extends State<IOSVpnManager> {
  @override
  void initState() {
    super.initState();
    iosVpn!.status.addListener(_sync);
  }

  void _sync() {
    final status = iosVpn!.status.value;
    globalState.startTime = status.isConnected ? status.startedAt : null;
    if (!globalState.isAppControllerReady) return;
    globalState.appController.updateRunTime();
    if (status.isConnected) {
      unawaited(globalState.startUpdateTasks());
    } else {
      globalState.stopUpdateTasks();
    }
  }

  @override
  void dispose() {
    iosVpn!.status.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
