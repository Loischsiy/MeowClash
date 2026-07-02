import 'dart:async';

import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/config.dart';
import 'package:meowclash/services/zapret/zapret.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/zapret.g.dart';

/// Owns the single [Zapret2Service] instance for the app. Kept alive (not
/// auto-disposed) because the engine session outlives any one widget subtree.
@Riverpod(keepAlive: true)
Zapret2Service zapret2Service(Ref ref) {
  final service = Zapret2Service();
  ref.onDispose(service.dispose);
  return service;
}

/// Reactive mirror of the service's [Zapret2Status] for the UI. Seeds from the
/// current status and then follows the service's broadcast stream, so progress
/// during a (possibly long) auto-selection is shown live.
@riverpod
class Zapret2Runtime extends _$Zapret2Runtime {
  @override
  Zapret2Status build() {
    final service = ref.watch(zapret2ServiceProvider);
    final sub = service.statusStream.listen((status) {
      state = status;
    });
    ref.onDispose(sub.cancel);
    return service.status;
  }

  Zapret2Service get _service => ref.read(zapret2ServiceProvider);

  Zapret2Props get _props => ref.read(zapret2SettingProvider);

  /// Turns the mode on and persists the enable flag. Selection/progress is
  /// reflected through [build]'s stream subscription.
  Future<Zapret2Status> enable() async {
    ref
        .read(zapret2SettingProvider.notifier)
        .updateState((s) => s.copyWith(enable: true));
    return _service.enable(props: _props);
  }

  /// Turns the mode off and persists the flag.
  Future<void> disable() async {
    ref
        .read(zapret2SettingProvider.notifier)
        .updateState((s) => s.copyWith(enable: false));
    await _service.disable();
  }

  /// Re-runs selection from scratch (drops the cache). Leaves the enable flag
  /// as-is; used by the "Перепроверить/сбросить" button.
  Future<Zapret2Status> rescan() => _service.rescan(props: _props);

  Future<Zapret2Availability> checkAvailability() =>
      _service.checkAvailability();
}
