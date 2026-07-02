import 'dart:io';

import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/services/zapret/process_backend.dart';

/// Linux backend: runs the upstream `nfqws` engine, which attaches to an
/// NFQUEUE. That requires CAP_NET_ADMIN (root or a file capability), so the
/// backend reports [missingPrivileges] when neither is present. The nftables/
/// iptables redirect that feeds the queue is set up by nfqws' own helper flags.
class LinuxZapret2Backend extends ProcessZapret2Backend {
  LinuxZapret2Backend({super.resolver});

  @override
  SupportPlatform get platform => SupportPlatform.Linux;

  @override
  String get binaryName => "nfqws";

  @override
  bool get requiresElevation => true;

  @override
  Future<bool> hasPrivileges() async {
    // Effective root is sufficient. A file-capability (cap_net_admin+ep) on the
    // binary would also work but is checked at start time by nfqws itself.
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
    return [
      "--qnum=200",
      "--filter-tcp=443",
      "--filter-udp=443",
      if (hostList.isNotEmpty) "--hostlist-domains=$hostList",
      ...strategy.args,
    ];
  }
}
