import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';

/// Why a backend cannot run right now, surfaced to the UI verbatim (never a
/// silent failure — requirement #4/#5).
enum Zapret2UnavailableReason {
  /// The platform has no working backend yet (e.g. macOS/Android experimental).
  unsupportedPlatform,

  /// The engine binary (winws/nfqws) is not bundled or not found on disk.
  missingBinary,

  /// The engine needs elevated privileges we don't have (admin/root/VPN grant).
  missingPrivileges,

  /// A native seam the backend depends on is not built into this app yet.
  missingNativeSupport,
}

/// Result of probing whether a backend can operate on this device.
class Zapret2Availability {
  const Zapret2Availability.available()
      : isAvailable = true,
        reason = null,
        detail = null;

  const Zapret2Availability.unavailable(this.reason, {this.detail})
      : isAvailable = false;

  final bool isAvailable;
  final Zapret2UnavailableReason? reason;

  /// Human-readable, localizable-key-independent extra context for logs.
  final String? detail;
}

/// A running engine session for a specific strategy. Stopping it must fully
/// tear down the native process / packet hook so the next strategy (or a clean
/// "off" state) starts from scratch.
abstract class Zapret2Session {
  Zapret2Strategy get strategy;
  Future<void> stop();
}

/// Platform-abstracted DPI-bypass engine, following the repo's plugin pattern
/// (one interface, per-platform implementations). Desktop backends spawn the
/// upstream native process (winws/nfqws); Android/macOS route through native
/// seams. The [Zapret2StrategyTester] and [Zapret2AutoSelector] depend only on
/// this interface, so they are fully unit-testable with a mock backend.
abstract class Zapret2Backend {
  SupportPlatform get platform;

  /// Cheap, side-effect-free check used by the UI to decide whether to offer
  /// the mode and by the selector to fail fast with a clear message.
  Future<Zapret2Availability> checkAvailability();

  /// Starts the engine applying [strategy] against [targets]. Returns a live
  /// [Zapret2Session] on success; throws [Zapret2BackendException] on failure.
  /// The tester starts a session, probes the targets, then stops it.
  Future<Zapret2Session> start({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  });
}

/// Raised when a backend cannot start or apply a strategy. Carries a structured
/// [reason] so callers can show the right localized message.
class Zapret2BackendException implements Exception {
  const Zapret2BackendException(this.reason, this.message);

  final Zapret2UnavailableReason reason;
  final String message;

  @override
  String toString() => "Zapret2BackendException($reason): $message";
}
