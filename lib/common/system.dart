import 'dart:io';
import 'dart:io' as io;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/plugins/app.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/input.dart';
import 'package:flutter/services.dart';
import 'package:meowclash/widgets/dialog.dart';

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
    final corePath = appPath.corePath.replaceAll(' ', r'\\ ');
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
      final result = await Process.run('stat', ['-c', '%U:%G %A', corePath]);
      final output = result.stdout.trim();
      if (output.startsWith('root:') && output.contains('rws')) {
        return true;
      }
      // Also check capability based on path resolved from PATH, if available.
      // E.g. NixOS wrappers or generic Linux installations using setcap.
      final whichResult = await Process.run('which', [appPath.corePath], runInShell: true);
      if (whichResult.exitCode == 0) {
        final resolvedCorePath = whichResult.stdout.trim();
        final capResult = await Process.run('getcap', [resolvedCorePath]);
        final capOutput = capResult.stdout.trim();
        if (capOutput.contains('cap_net_admin')) {
          return true;
        }
      }
      return false;

    }
    return true;
  }

  Future<AuthorizeCode> authorizeCore() async {
    if (Platform.isAndroid) {
      return AuthorizeCode.error;
    }

    if (Platform.isMacOS) {
      return AuthorizeCode.none;
    }

    final corePath = appPath.corePath.replaceAll(' ', r'\\ ');
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
