import 'dart:io';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/process_backend.dart';

/// macOS backend: runs a `nfqws-darwin` build that hooks the packet flow via a
/// BSD **pf divert-to** socket (upstream zapret2 does not ship a macOS binary,
/// so this is a custom build — see README "macOS: building nfqws-darwin").
///
/// Because there is no official upstream artifact, the binary is frequently
/// absent; [checkAvailability] then reports [missingBinary] and the UI shows an
/// explicit "build required" message rather than failing silently. When the
/// binary is present it needs root to program pf, hence [requiresElevation].
class MacosZapret2Backend extends ProcessZapret2Backend {
  MacosZapret2Backend({super.resolver});

  @override
  SupportPlatform get platform => SupportPlatform.MacOS;

  /// Distinct name so a Darwin pf-divert build never collides with the Linux
  /// NFQUEUE binary in a shared bundle.
  @override
  String get binaryName => "nfqws-darwin";

  @override
  bool get requiresElevation => true;

  @override
  Future<bool> hasPrivileges() async {
    try {
      final result = await Process.run("id", ["-u"]);
      final uid = int.tryParse(result.stdout.toString().trim());
      return uid == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  List<String> buildArgs({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
  }) {
    final hostList = targets.map((t) => t.host).join(",");
    // pf divert socket port; the pf anchor that redirects 443 to this divert
    // port is installed by the nfqws-darwin wrapper at start.
    return [
      "--daemon=0",
      "--divert-port=989",
      "--filter-tcp=443",
      "--filter-udp=443",
      if (hostList.isNotEmpty) "--hostlist-domains=$hostList",
      ...strategy.args,
    ];
  }
}
