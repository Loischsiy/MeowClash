import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/backend.dart';
import 'package:meowclash/services/zapret/binary_resolver.dart';
import 'package:meowclash/services/zapret/zapret_logger.dart';

/// A [Zapret2Session] wrapping a spawned native engine process. Mirrors the
/// process-management shape of `lib/clash/service.dart`: line-split stdout/
/// stderr into the select log, and kill on stop.
class ProcessZapret2Session implements Zapret2Session {
  ProcessZapret2Session(this._process, this.strategy) {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.isNotEmpty) zapretLogger.log("[engine stdout] $line");
    });
    _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.isNotEmpty) zapretLogger.log("[engine stderr] $line");
    });
  }

  final Process _process;

  @override
  final Zapret2Strategy strategy;

  @override
  Future<void> stop() async {
    _process.kill();
    // Give the OS a moment to release the packet hook (WinDivert handle / nfq
    // binding) before the next strategy tries to grab it.
    await _process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  }
}

/// Shared base for backends that run the upstream engine as a child process.
/// Concrete subclasses supply the binary name and translate a strategy's
/// generic flags into that engine's actual argument vector.
abstract class ProcessZapret2Backend extends Zapret2Backend {
  ProcessZapret2Backend({ZapretBinaryResolver? resolver})
      : _resolver = resolver ?? zapretBinaryResolver;

  final ZapretBinaryResolver _resolver;

  /// Engine executable file name (e.g. `winws.exe`, `nfqws`).
  String get binaryName;

  /// Whether the engine requires elevated privileges to install its packet
  /// hook. Checked in [checkAvailability] so the UI can prompt appropriately.
  bool get requiresElevation;

  Future<bool> hasPrivileges();

  /// Builds the full argument vector for [strategy]/[targets]. Subclasses
  /// prepend/append engine-specific filtering flags around the strategy args.
  List<String> buildArgs({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
  });

  @override
  Future<Zapret2Availability> checkAvailability() async {
    final path = await _resolver.resolve(binaryName);
    if (path == null) {
      return Zapret2Availability.unavailable(
        Zapret2UnavailableReason.missingBinary,
        detail: "$binaryName not bundled",
      );
    }
    if (requiresElevation && !await hasPrivileges()) {
      return const Zapret2Availability.unavailable(
        Zapret2UnavailableReason.missingPrivileges,
      );
    }
    return const Zapret2Availability.available();
  }

  @override
  Future<Zapret2Session> start({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
    String? customEnginePath,
  }) async {
    final path =
        await _resolver.resolve(binaryName, customPath: customEnginePath);
    if (path == null) {
      throw const Zapret2BackendException(
        Zapret2UnavailableReason.missingBinary,
        "engine binary not found",
      );
    }
    if (requiresElevation && !await hasPrivileges()) {
      throw const Zapret2BackendException(
        Zapret2UnavailableReason.missingPrivileges,
        "engine requires elevated privileges",
      );
    }
    final args = buildArgs(strategy: strategy, targets: targets);
    await zapretLogger.log("starting $binaryName ${args.join(' ')}");
    try {
      final process = await Process.start(path, args);
      // A crash-on-start (bad WinDivert driver, missing caps) exits almost
      // immediately; surface that as a start failure rather than a false start.
      final earlyExit = await Future.any([
        process.exitCode.then<int?>((c) => c),
        Future<int?>.delayed(const Duration(milliseconds: 400), () => null),
      ]);
      if (earlyExit != null) {
        throw Zapret2BackendException(
          Zapret2UnavailableReason.missingPrivileges,
          "$binaryName exited immediately with code $earlyExit",
        );
      }
      return ProcessZapret2Session(process, strategy);
    } on ProcessException catch (e) {
      throw Zapret2BackendException(
        Zapret2UnavailableReason.missingBinary,
        "failed to spawn $binaryName: ${e.message}",
      );
    }
  }
}
