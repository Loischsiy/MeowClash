import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/clash/clash.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/backend.dart';

class MacosZapret2Backend extends Zapret2Backend {
  @override
  SupportPlatform get platform => SupportPlatform.MacOS;

  @override
  Future<Zapret2Availability> checkAvailability() async =>
      const Zapret2Availability.available();

  @override
  Future<Zapret2Session> start({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  }) async {
    final ok = await clashCore.zapret2Apply({
      'strategy': strategy.id,
      'args': strategy.args,
      'hosts': targets.map((target) => target.host).toList(),
    });
    if (!ok) {
      throw const Zapret2BackendException(
        Zapret2UnavailableReason.missingNativeSupport,
        "core stream backend rejected strategy",
      );
    }
    return _MacosZapret2Session(strategy);
  }
}

class _MacosZapret2Session implements Zapret2Session {
  const _MacosZapret2Session(this.strategy);

  @override
  final Zapret2Strategy strategy;

  @override
  Future<void> stop() => clashCore.zapret2Clear();
}
