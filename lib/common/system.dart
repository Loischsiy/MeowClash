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
      return result.exitCode == 0 &&
          result.stdout.toString().trim().isNotEmpty;
    } on ProcessException {
      return false;
    }
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (Platform.isAndroid) {
      return AuthorizeCode.error;
    }

    if (Platform.isMacOS) {
      return AuthorizeCode.none;
    }

    final corePath = await appPath.resolvedCorePath;
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
      const capabilities = 'cap_net_admin,cap_net_raw+ep';
      if (await _hasExecutable('pkexec')) {
        final result = await Process.run(
          'pkexec',
          ['setcap', capabilities, corePath],
        );
        if (result.exitCode == 0) {
          return AuthorizeCode.success;
        }
        commonPrint.log(
          'authorizeCore: pkexec setcap failed (exit ${result.exitCode}): '
          '${result.stderr}',
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
      if (await _hasExecutable('setcap')) {
        if (await runAsRoot(['setcap', capabilities, corePath]) == 0) {
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
    final currentServiceNameLineSplits =
        currentServiceNameLine.trim().split(' ');
    if (currentServiceNameLineSplits.length < 2) {
      return null;
    }
    return currentServiceNameLineSplits[1];
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
    List<String>? nextDns;
    if (restore) {
      nextDns = originDns;
    } else {
      final originDns = await system.getMacOSOriginDns();
      if (originDns == null) {
        return;
      }
      const needAddDns = "1.1.1.1"; // Cloudflare DNS
      if (originDns.contains(needAddDns)) {
        return;
      }
      nextDns = List.from(originDns)..add(needAddDns);
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
