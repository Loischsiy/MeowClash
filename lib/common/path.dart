import 'dart:async';
import 'dart:io';

import 'package:meowclash/common/common.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class AppPath {

  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  AppPath._internal() {
    appDirPath = join(dirname(Platform.resolvedExecutable));
    getApplicationSupportDirectory().then((value) {
      dataDir.complete(value);
    });
    getTemporaryDirectory().then((value) {
      tempDir.complete(value);
    });
    getDownloadsDirectory().then((value) {
      downloadDir.complete(value);
    });
  }
  static AppPath? _instance;
  Completer<Directory> dataDir = Completer();
  Completer<Directory> downloadDir = Completer();
  Completer<Directory> tempDir = Completer();
  late String appDirPath;

  String get executableExtension => Platform.isWindows ? ".exe" : "";

  bool get isNixPackage => Platform.environment['MEOWCLASH_NIX_PACKAGE'] == '1';

  String get executableDirPath {
    final currentExecutablePath = Platform.resolvedExecutable;
    return dirname(currentExecutablePath);
  }

  String get corePath {
    final nixCorePath = Platform.environment['MEOWCLASH_CORE_PATH'];
    if (!Platform.isWindows && nixCorePath != null && nixCorePath.isNotEmpty) {
      return nixCorePath;
    }
    if (Platform.isMacOS) {
      // Core is stored in Application Support/com.meowclash.app/cores/ (copied by Swift code on launch)
      // Permissions are set automatically in Swift
      final home = Platform.environment['HOME'] ?? '';
      return '$home/Library/Application Support/com.meowclash.app/cores/MeowClashCore';
    }
    return join(executableDirPath, "MeowClashCore$executableExtension");
  }

  Future<String> get resolvedCorePath async {
    final resolved = await _resolveCorePath();
    // On Linux the app frequently runs from a read-only AppImage mount, where
    // the core binary can never be granted the privileges TUN needs
    // (setcap/setuid fail with "Read-only file system"). Stage the core in a
    // writable per-user directory and run it from there. Nix packages and an
    // explicit MEOWCLASH_CORE_PATH override are left untouched.
    if (Platform.isLinux &&
        !isNixPackage &&
        (Platform.environment['MEOWCLASH_CORE_PATH'] ?? '').isEmpty) {
      return _ensureWritableLinuxCore(resolved);
    }
    return resolved;
  }

  Future<String> _resolveCorePath() async {
    final path = corePath;
    if (isAbsolute(path) || path.contains(separator)) {
      return path;
    }
    final result = await Process.run(
      'sh',
      ['-c', r'command -v -- "$1"', 'resolve-core', path],
    );
    if (result.exitCode == 0) {
      final output = result.stdout.toString().trim();
      if (output.isNotEmpty) {
        return output;
      }
    }
    return path;
  }

  /// Copies the bundled Linux core into a writable directory so it can be
  /// granted privileges. Returns the staged path, or [sourcePath] on failure.
  Future<String> _ensureWritableLinuxCore(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return sourcePath;
      }
      final dataDirPath = await homeDirPath;
      final coresDir = Directory(join(dataDirPath, 'cores'));
      if (!await coresDir.exists()) {
        await coresDir.create(recursive: true);
      }
      final destPath = join(coresDir.path, 'MeowClashCore');
      final dest = File(destPath);
      // Re-copy only when the bundled core changed (e.g. after an app update),
      // so that previously granted capabilities on the staged copy persist.
      final needsCopy = !await dest.exists() ||
          await source.length() != await dest.length() ||
          (await source.lastModified()).isAfter(await dest.lastModified());
      if (needsCopy) {
        await source.copy(destPath);
        await Process.run('chmod', ['+x', destPath]);
      }
      return destPath;
    } catch (error) {
      commonPrint.log('AppPath: failed to stage writable Linux core: $error');
      return sourcePath;
    }
  }

  String get helperPath => join(executableDirPath, "$appHelperService$executableExtension");

  Future<String> get downloadDirPath async {
    final directory = await downloadDir.future;
    return directory.path;
  }

  Future<String> get homeDirPath async {
    final directory = await dataDir.future;
    return directory.path;
  }

  Future<String> get lockFilePath async {
    final directory = await dataDir.future;
    return join(directory.path, "MeowClash.lock");
  }

  Future<String> get sharedPreferencesPath async {
    final directory = await dataDir.future;
    return join(directory.path, "shared_preferences.json");
  }

  Future<String> get profilesPath async {
    final directory = await dataDir.future;
    return join(directory.path, profilesDirectoryName);
  }

  Future<String> getProfilePath(String id) async {
    final directory = await profilesPath;
    return join(directory, "$id.yaml");
  }

  Future<String> getProvidersDirPath(String id) async {
    final directory = await profilesPath;
    return join(
      directory,
      "providers",
      id,
    );
  }

  Future<String> getProvidersFilePath(
    String id,
    String type,
    String url,
  ) async {
    final directory = await profilesPath;
    return join(
      directory,
      "providers",
      id,
      type,
      url.toMd5(),
    );
  }

  Future<String> get tempPath async {
    final directory = await tempDir.future;
    return directory.path;
  }
}

final appPath = AppPath();
