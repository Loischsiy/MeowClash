import 'dart:async';
import 'dart:io';

import 'package:meowclash/common/common.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

/// Dedicated append-only log for the zapret2 auto-selection process, kept
/// separate from the app log so a (potentially long) strategy search is easy to
/// diagnose in isolation. Lives at `<homeDir>/zapret2/select.log`. Everything
/// is local; nothing is ever sent off-device.
class ZapretLogger {
  factory ZapretLogger() {
    _instance ??= ZapretLogger._internal();
    return _instance!;
  }

  ZapretLogger._internal();
  static ZapretLogger? _instance;

  IOSink? _sink;

  /// Resolves the directory that holds `select.log`. Defaults to the app data
  /// directory; overridable so tests (where path_provider is unavailable) can
  /// point it at a temp dir without ever touching [appPath].
  Future<String> Function()? directoryResolver;

  Future<String> logFilePath() async {
    final base = directoryResolver != null
        ? await directoryResolver!()
        : join(await appPath.homeDirPath, "zapret2");
    final dir = Directory(base);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return join(dir.path, "select.log");
  }

  Future<void> _ensureSink() async {
    if (_sink != null) return;
    final path = await logFilePath();
    _sink = File(path).openWrite(mode: FileMode.append);
  }

  /// Appends [message] to the select log and mirrors it to the common app log
  /// (prefixed) so live diagnostics still surface in the normal log view.
  ///
  /// The file write is fire-and-forget with a timeout: diagnostics must never
  /// block or hang the selection flow (e.g. in unit tests where the app data
  /// directory is unavailable, resolving the path would otherwise never
  /// complete).
  Future<void> log(String message) async {
    final timestamp =
        DateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(DateTime.now());
    final line = "[$timestamp] $message";
    commonPrint.log("[zapret2] $message");
    unawaited(_appendToFile(line));
  }

  Future<void> _appendToFile(String line) async {
    try {
      await _ensureSink().timeout(const Duration(seconds: 2));
      _sink?.writeln(line);
      await _sink?.flush();
    } catch (_) {
      // Never let diagnostics writing break the selection flow.
    }
  }

  Future<void> dispose() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
  }
}

final zapretLogger = ZapretLogger();
