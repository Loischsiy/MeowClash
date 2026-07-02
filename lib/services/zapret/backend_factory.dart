import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/services/zapret/backend.dart';
import 'package:meowclash/services/zapret/backends/android_backend.dart';
import 'package:meowclash/services/zapret/backends/linux_backend.dart';
import 'package:meowclash/services/zapret/backends/macos_backend.dart';
import 'package:meowclash/services/zapret/backends/windows_backend.dart';

/// Selects the correct [Zapret2Backend] for the running platform. Kept as a
/// standalone factory (not a switch scattered through the service) so tests can
/// substitute a mock backend for any [SupportPlatform].
Zapret2Backend createZapret2Backend([SupportPlatform? platform]) {
  final target = platform ?? SupportPlatform.currentPlatform;
  switch (target) {
    case SupportPlatform.Windows:
      return WindowsZapret2Backend();
    case SupportPlatform.Linux:
      return LinuxZapret2Backend();
    case SupportPlatform.MacOS:
      return MacosZapret2Backend();
    case SupportPlatform.Android:
      return AndroidZapret2Backend();
  }
}
