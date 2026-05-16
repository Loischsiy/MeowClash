import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/plugins/tile.dart';
import 'package:meowclash/state.dart';
import 'package:flutter/material.dart';

class TileManager extends StatefulWidget {

  const TileManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  State<TileManager> createState() => _TileContainerState();
}

class _TileContainerState extends State<TileManager> with TileListener {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void onStart() {
    globalState.appController.updateStatus(true);
    super.onStart();
  }

  @override
  Future<void> onStop() async {
    globalState.appController.updateStatus(false);
    super.onStop();
  }

  @override
  void onChangeMode(String mode) {
    try {
      final modeEnum = Mode.values.byName(mode);
      globalState.appController.changeMode(modeEnum);
      // Reflect back to widget — updateClashConfigDebounce will push to core.
      tile?.updateMode(mode);
    } catch (_) {}
    super.onChangeMode(mode);
  }

  @override
  void initState() {
    super.initState();
    tile?.addListener(this);
    // Push current mode to native so widget picks up the right active button
    // when the main engine comes online.
    try {
      final current = globalState.config.patchClashConfig.mode.name;
      tile?.updateMode(current);
    } catch (_) {}
  }

  @override
  void dispose() {
    tile?.removeListener(this);
    super.dispose();
  }
}
