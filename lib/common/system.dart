import 'dart:io';
import 'dart:io' as io;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/plugins/app.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/input.dart';
import 'package:flutter/services.dart';

class System {
  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  System._internal();
  static System? _instance;
  List<String>? originDns;

  /// Tracks whether elevation has been attempted in this process to prevent
  /// repeated UAC prompts when the helper service install does not produce
  /// a pingable helper (e.g. SHA token mismatch with the installed core).
  bool _hasAttemptedElevation = false;

  bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get isMobile => Platform.isAndroid || Platform.isIOS;

  Future<bool> get isAndroidTV async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.systemFeatures.contains('android.software.leanback');
  }

  Future<int> get version async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    return switch (Platform.operatingSystem) {
      "macos" => (deviceInfo as MacOsDeviceInfo).majorVersion,
      "android" => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      "windows" => (deviceInfo as WindowsDeviceInfo).majorVersion,
      String() => 0
    };
  }

  Future<bool> checkIsAdmin() async {
    final corePath = await appPath.resolvedCorePath;
    if (Platform.isWindows) {
      final result = await windows?.checkService();
      return result == WindowsHelperServiceStatus.running;
    } else if (Platform.isMacOS) {
      final result = await Process.run('stat', ['-f', '%Su:%Sg %Sp', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:admin') && output.contains('rws')) {
        return true;
      }
      return false;
    } else if (Platform.isLinux) {
      if (await _linuxCoreHasNetAdminCapability(corePath)) {
        return true;
      }
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:') && output.contains('rws')) {
        return true;
      }
      return false;
    }
    return true;
  }

  Future<bool> _linuxCoreHasNetAdminCapability(String corePath) async {
    if (!Platform.isLinux) {
      return false;
    }
    final ProcessResult result;
    try {
      result = await Process.run('getcap', [corePath]);
    } on ProcessException {
      return false;
    }
    final output = result.stdout.toString();
    return output.contains('cap_net_admin') &&
        (output.contains('=ep') || output.contains('+ep'));
  }

  /// Returns true if [name] is an executable found on PATH.
  Future<bool> _hasExecutable(String name) async {
    try {
      final result = await Process.run(
        'sh',
        ['-c', r'command -v -- "$1"', '_', name],
      );
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } on ProcessException {
      return false;
    }
  }

  /// Resolves [name] to an absolute executable path.
  ///
  /// This matters for privilege-elevation helpers: both `pkexec` and `sudo`
  /// run the target with a sanitized PATH that frequently omits `/usr/sbin`
  /// and `/sbin` (where `setcap` lives), and `pkexec` does not search PATH the
  /// way a shell does. Passing a bare name like `setcap` then fails with
  /// exit 127 ("No such file or directory") even though the tool is installed.
  /// We first try `command -v`, then fall back to well-known sbin/bin
  /// locations. Returns null if the executable cannot be found anywhere
  /// (e.g. a minimal distro shipped without libcap's setcap binary).
  Future<String?> _resolveExecutable(String name) async {
    try {
      final result = await Process.run(
        'sh',
        ['-c', r'command -v -- "$1"', '_', name],
      );
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.startsWith('/')) {
          return path;
        }
      }
    } on ProcessException {
      // Ignore and try the well-known locations below.
    }
    const candidateDirs = [
      '/usr/sbin/',
      '/sbin/',
      '/usr/bin/',
      '/bin/',
      '/usr/local/sbin/',
      '/usr/local/bin/',
    ];
    for (final dir in candidateDirs) {
      final candidate = '$dir$name';
      if (await File(candidate).exists()) {
        return candidate;
      }
    }
    return null;
  }

  /// Ensures the Linux `/dev/net/tun` device exists by loading the kernel
  /// `tun` module when necessary.
  ///
  /// Granting cap_net_admin to the core is not enough for TUN: the core also
  /// has to open `/dev/net/tun`. If the `tun` module is not loaded that node
  /// is absent and the core reports "configure tun interface: no such file or
  /// directory" (ENOENT) — which is distinct from a missing capability
  /// (EPERM, "operation not permitted"). We load the module with a single
  /// graphical prompt (pkexec), and surface a clear, actionable message if it
  /// still cannot be loaded.
  Future<void> _ensureLinuxTunDevice() async {
    if (!Platform.isLinux) {
      return;
    }
    if (await File('/dev/net/tun').exists()) {
      return;
    }
    // modprobe lives in /usr/sbin or /sbin and needs root, so resolve its
    // absolute path for the same PATH-sanitization reason as setcap.
    final modprobePath = await _resolveExecutable('modprobe');
    if (modprobePath == null) {
      globalState.showNotifier(
        'TUN needs the kernel "tun" module but modprobe was not found. '
        'Run: sudo modprobe tun',
      );
      return;
    }
    if (await _hasExecutable('pkexec')) {
      final result = await Process.run('pkexec', [modprobePath, 'tun']);
      if (result.exitCode == 0 && await File('/dev/net/tun').exists()) {
        return;
      }
      commonPrint.log(
        'authorizeCore: pkexec modprobe tun failed '
        '(exit ${result.exitCode}): ${result.stderr}',
      );
    }
    if (await File('/dev/net/tun').exists()) {
      return;
    }
    globalState.showNotifier(
      'Could not load the "tun" kernel module automatically. '
      'Run "sudo modprobe tun" and add "tun" to /etc/modules-load.d/tun.conf '
      'to enable TUN mode.',
    );
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (Platform.isAndroid) {
      return AuthorizeCode.error;
    }

    if (Platform.isMacOS) {
      return AuthorizeCode.none;
    }

    final corePath = await appPath.resolvedCorePath;

    // TUN also needs the /dev/net/tun device node to exist. When the kernel
    // "tun" module is not loaded the core fails with
    //   "configure tun interface: no such file or directory" (ENOENT),
    // which is distinct from a missing capability (EPERM). This must run even
    // when the core is already authorized: a granted capability persists
    // across runs (it lives on the staged binary), yet the module can be
    // unloaded again after a reboot, leaving an already-"admin" core unable to
    // create the interface. Running this before the isAdmin short-circuit
    // guarantees the device is present whenever the user enables TUN.
    if (Platform.isLinux && !appPath.isNixPackage) {
      await _ensureLinuxTunDevice();
    }

    final isAdmin = await checkIsAdmin();
    if (isAdmin) {
      return AuthorizeCode.none;
    }

    if (Platform.isWindows) {
      // First, try to start existing service without UAC
      final startedWithoutUac = await windows?.tryStartExistingService();
      if (startedWithoutUac == true) {
        return AuthorizeCode.success;
      }

      // If a previous attempt in this session already failed to produce a
      // working helper, do not re-prompt for UAC — the user has no way to
      // resolve a SHA mismatch / bind failure at runtime and another prompt
      // only produces the infinite admin-prompt loop reported as a bug.
      if (_hasAttemptedElevation) {
        return AuthorizeCode.error;
      }
      _hasAttemptedElevation = true;

      // Service not installed or couldn't start - need to install with UAC
      final result = await windows?.installService();
      if (result == true) {
        return AuthorizeCode.success;
      }
      return AuthorizeCode.error;
    } else if (Platform.isLinux) {
      if (appPath.isNixPackage) {
        globalState.showNotifier(
          'TUN mode on NixOS requires programs.meowclash.tunMode.enable = true and a system rebuild.',
        );
        return AuthorizeCode.error;
      }
      // Preferred path: a graphical polkit prompt (pkexec) that grants only
      // the cap_net_admin capability the core needs for TUN. This never routes
      // the password through our app and avoids making the core setuid root.
      //
      // setcap must be addressed by ABSOLUTE PATH here. pkexec/sudo run with a
      // sanitized PATH that usually omits /usr/sbin, and pkexec does not search
      // PATH like a shell — so `pkexec setcap ...` fails with exit 127
      // ("Cannot run program setcap: No such file or directory") on many
      // distros even when libcap is installed. If setcap is missing entirely
      // we fall back to making the core setuid root, which needs no libcap.
      const capabilities = 'cap_net_admin,cap_net_raw+ep';
      final setcapPath = await _resolveExecutable('setcap');
      if (await _hasExecutable('pkexec')) {
        // 1) Least privilege: grant only cap_net_admin via setcap if present.
        if (setcapPath != null) {
          final result = await Process.run(
            'pkexec',
            [setcapPath, capabilities, corePath],
          );
          if (result.exitCode == 0) {
            return AuthorizeCode.success;
          }
          commonPrint.log(
            'authorizeCore: pkexec setcap failed (exit ${result.exitCode}): '
            '${result.stderr}',
          );
        } else {
          commonPrint.log(
            'authorizeCore: setcap not found, using pkexec setuid-root fallback',
          );
        }
        // 2) Fallback: make the core setuid root in a single graphical prompt.
        //    corePath is passed as a positional argument (\$1) and never
        //    interpolated into the script text, so there is no shell-injection
        //    surface even if the path contained spaces or metacharacters.
        final setuidResult = await Process.run(
          'pkexec',
          [
            'sh',
            '-c',
            r'chown -- root:root "$1" && chmod -- +sx "$1"',
            '_',
            corePath,
          ],
        );
        if (setuidResult.exitCode == 0) {
          return AuthorizeCode.success;
        }
        commonPrint.log(
          'authorizeCore: pkexec setuid fallback failed '
          '(exit ${setuidResult.exitCode}): ${setuidResult.stderr}',
        );
        // Fall through to the password-based fallback below.
      }

      // Fallback: ask for the password and use `sudo -S`, feeding the password
      // through stdin instead of interpolating it into a shell command string.
      // This removes the shell command-injection vector (a crafted password
      // could otherwise run arbitrary commands as root) and keeps the password
      // out of the process argument list (visible via `ps`). Arguments are
      // passed as a list, so corePath is never re-parsed by a shell and no
      // manual escaping is required.
      final password = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: appLocalizations.pleaseInputAdminPassword,
          value: '',
        ),
      );
      if (password == null || password.isEmpty) {
        return AuthorizeCode.error;
      }

      Future<int> runAsRoot(List<String> command) async {
        final process = await Process.start('sudo', ['-S', '-k', ...command]);
        process.stdin.writeln(password);
        await process.stdin.close();
        // Drain stdout/stderr so the child can't block on a full pipe buffer.
        await process.stdout.drain<void>();
        await process.stderr.drain<void>();
        return process.exitCode;
      }

      // Prefer least-privilege capabilities via sudo when setcap exists.
      // Use the absolute path resolved above for the same PATH-sanitization
      // reason as the pkexec branch.
      if (setcapPath != null) {
        if (await runAsRoot([setcapPath, capabilities, corePath]) == 0) {
          return AuthorizeCode.success;
        }
        commonPrint.log(
          'authorizeCore: sudo setcap failed, falling back to setuid root',
        );
      }

      // Legacy fallback: make the core binary setuid root.
      if (await runAsRoot(['chown', 'root:root', corePath]) != 0) {
        return AuthorizeCode.error;
      }
      if (await runAsRoot(['chmod', '+sx', corePath]) != 0) {
        return AuthorizeCode.error;
      }
      return AuthorizeCode.success;
    }
    return AuthorizeCode.error;
  }

  Future<String?> getMacOSDefaultServiceName() async {
    if (!Platform.isMacOS) {
      return null;
    }
    final result = await Process.run('route', ['-n', 'get', 'default']);
    final output = result.stdout.toString();
    final deviceLine = output
        .split('\n')
        .firstWhere((s) => s.contains('interface:'), orElse: () => "");
    final lineSplits = deviceLine.trim().split(' ');
    if (lineSplits.length != 2) {
      return null;
    }
    final device = lineSplits[1];
    final serviceResult = await Process.run(
      'networksetup',
      ['-listnetworkserviceorder'],
    );
    final serviceResultOutput = serviceResult.stdout.toString();
    final currentService = serviceResultOutput.split('\n\n').firstWhere(
          (s) => s.contains("Device: $device"),
          orElse: () => "",
        );
    if (currentService.isEmpty) {
      return null;
    }
    final currentServiceNameLine = currentService.split("\n").firstWhere(
        (line) => RegExp(r'^\(\d+\).*').hasMatch(line),
        orElse: () => "");
    // Strip the leading "(N) " index; the rest is the full service name, which
    // can contain spaces ("Thunderbolt Ethernet", "USB 10/100/1000 LAN"). The
    // old split(' ')[1] truncated multi-word names, silently breaking auto
    // system-DNS (and poisoning originDns with networksetup's error text) on
    // wired/USB adapters.
    final name =
        currentServiceNameLine.trim().replaceFirst(RegExp(r'^\(\d+\)\s*'), '');
    return name.isEmpty ? null : name;
  }

  Future<List<String>?> getMacOSOriginDns() async {
    if (!Platform.isMacOS) {
      return null;
    }
    final deviceServiceName = await getMacOSDefaultServiceName();
    if (deviceServiceName == null) {
      return null;
    }
    final result = await Process.run(
      'networksetup',
      ['-getdnsservers', deviceServiceName],
    );
    final output = result.stdout.toString().trim();
    if (output.startsWith("There aren't any DNS Servers set on")) {
      originDns = [];
    } else {
      originDns = output.split("\n");
    }
    return originDns;
  }

  Future<void> setMacOSDns(bool restore) async {
    if (!Platform.isMacOS) {
      return;
    }
    final serviceName = await getMacOSDefaultServiceName();
    if (serviceName == null) {
      return;
    }
    final prefs = await preferences.sharedPreferencesCompleter.future;
    const originKey = "macos_origin_dns";
    const needAddDns = "1.1.1.1"; // Cloudflare DNS
    List<String>? nextDns;
    if (restore) {
      // Prefer the persisted true origin over the in-memory snapshot (which is
      // lost on crash/restart), then clear it so the next session starts clean.
      nextDns = prefs?.getStringList(originKey) ?? originDns;
      await prefs?.remove(originKey);
    } else {
      final saved = prefs?.getStringList(originKey);
      final origin = saved ?? await system.getMacOSOriginDns();
      if (origin == null) {
        return;
      }
      // Persist the TRUE pre-injection DNS exactly once. Preferring a persisted
      // snapshot over the live read means a crash-polluted live value (already
      // carrying 1.1.1.1 from a prior unclean exit) can never become the
      // "origin" and get baked in permanently. A genuine 1.1.1.1 user keeps
      // their value because we never strip it from the saved snapshot.
      if (saved == null) {
        await prefs?.setStringList(originKey, origin);
      }
      nextDns = origin.contains(needAddDns)
          ? List<String>.from(origin)
          : (List<String>.from(origin)..add(needAddDns));
    }
    if (nextDns == null) {
      return;
    }
    await Process.run(
      'networksetup',
      [
        '-setdnsservers',
        serviceName,
        if (nextDns.isNotEmpty) ...nextDns,
        if (nextDns.isEmpty) "Empty",
      ],
    );
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
    await window?.hide();
  }

  Future<void> exit() async {
    commonPrint.log("System: Exiting application...");
    if (Platform.isAndroid) {
      commonPrint.log("System: Calling SystemNavigator.pop()");
      await SystemNavigator.pop();
      return;
    }
    // Desktop: terminate the whole process. Closing only the window is not
    // enough — if the platform intercepts the close (e.g. window_manager's
    // setPreventClose on Windows), the GUI process can survive after the core
    // has already been shut down. That leaves a "zombie": the interface keeps
    // working while the app has vanished from the task manager, and background
    // timers keep writing to the now-dead core socket (StreamSink is closed).
    // exit(0) guarantees the process is actually gone.
    commonPrint.log("System: Closing window...");
    try {
      await window?.close();
    } catch (e) {
      commonPrint.log("System: window.close() failed: $e");
    }
    commonPrint.log("System: Forcing process exit");
    io.exit(0);
  }
}

final system = System();
