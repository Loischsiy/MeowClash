import 'dart:io';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/process_backend.dart';

/// Windows backend: runs the upstream `winws.exe` (zapret2 winws2 engine) which
/// installs a WinDivert packet hook. WinDivert requires an elevated process to
/// load its signed driver — that's the same privilege the app already requests
/// for TUN mode. See README for the antivirus disclaimer (WinDivert is a
/// legitimate packet-filter driver and may trip heuristic AV).
class WindowsZapret2Backend extends ProcessZapret2Backend {
  WindowsZapret2Backend({super.resolver});

  @override
  SupportPlatform get platform => SupportPlatform.Windows;

  @override
  String get binaryName => "winws.exe";

  @override
  bool get requiresElevation => true;

  @override
  Future<bool> hasPrivileges() async {
    // `net session` succeeds only from an elevated context. Cheap and avoids a
    // native call; used purely to give the user a precise "run as admin" hint.
    try {
      final result = await Process.run("net", ["session"]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  List<String> buildArgs({
    required Zapret2Strategy strategy,
    required List<Zapret2Target> targets,
  }) {
    // winws filters by port/host; we scope to the target hosts and the standard
    // HTTPS/QUIC ports, then apply the strategy's desync flags verbatim.
    final hostList = targets.map((t) => t.host).join(",");
    return [
      "--wf-tcp=443",
      "--wf-udp=443",
      if (hostList.isNotEmpty) "--hostlist-domains=$hostList",
      ...strategy.args,
    ];
  }
}
