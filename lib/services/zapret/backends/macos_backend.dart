import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/backend.dart';

class MacosZapret2Backend extends Zapret2Backend {
  @override
  SupportPlatform get platform => SupportPlatform.MacOS;

  // ponytail: no fake nfqws-darwin path; add NetworkExtension/utun when macOS ships.
  @override
  Future<Zapret2Availability> checkAvailability() async =>
      const Zapret2Availability.unavailable(
        Zapret2UnavailableReason.missingNativeSupport,
        detail: "local TUN backend is not built for macOS yet",
      );

  @override
  Future<Zapret2Session> start({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  }) async {
    throw const Zapret2BackendException(
      Zapret2UnavailableReason.missingNativeSupport,
      "local TUN backend is not built for macOS yet",
    );
  }
}
