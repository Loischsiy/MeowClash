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

  /// Whether the app is running from an AppImage bundle. The AppImage runtime
  /// exports APPIMAGE (the absolute path to the .AppImage file) and APPDIR
  /// (the read-only mount point) into the environment, so either being present
  /// is a reliable signal.
  bool get isAppImage =>
      (Platform.environment['APPIMAGE'] ?? '').isNotEmpty ||
      (Platform.environment['APPDIR'] ?? '').isNotEmpty;

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
    // Only the AppImage build runs from a read-only mount where the core binary
    // can never be granted the privileges TUN needs (setcap/setuid fail with
    // "Read-only file system"). For that build we stage the core in a writable
    // per-user directory and run it from there. Every other Linux build
    // (portable, .deb/.rpm, Nix) can grant rights to the core in place, so
    // staging is intentionally skipped for them — otherwise a stale staged copy
    // left over in the per-user data dir from a previous install would shadow a
    // freshly installed build's core and the core would fail to start. Nix
    // packages and an explicit MEOWCLASH_CORE_PATH override are also untouched.
    if (Platform.isLinux &&
        isAppImage &&
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
  ///
  /// The staged copy lives in the per-user data directory and therefore
  /// survives reinstalling the app. We must re-stage whenever a different build
  /// is installed, otherwise the old staged core keeps running against a new
  /// app build and the core fails to start. Inside an AppImage the squashfs
  /// mtime of the bundled core is frequently normalized to a constant, so a
  /// plain size+mtime comparison can miss a new beta build. We instead store a
  /// signature next to the staged copy that also folds in the identity of the
  /// .AppImage file itself (its on-disk size and mtime), which always changes
  /// on every (re)install. When the signature is unchanged we keep the staged
  /// copy as-is so previously granted capabilities persist.
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
      final marker = File(join(coresDir.path, '.core-source'));

      final signature = await _coreSourceSignature(source);
      final storedSignature =
          await marker.exists() ? (await marker.readAsString()).trim() : '';

      final needsCopy = !await dest.exists() || signature != storedSignature;
      if (needsCopy) {
        await source.copy(destPath);
        await Process.run('chmod', ['+x', destPath]);
        try {
          await marker.writeAsString(signature);
        } catch (_) {
          // A missing/unwritable marker just forces a re-copy next launch.
        }
      }
      return destPath;
    } catch (error) {
      commonPrint.log('AppPath: failed to stage writable Linux core: $error');
      return sourcePath;
    }
  }

  /// Builds a signature that changes whenever a different build's core is
  /// bundled, so the staged copy is refreshed after an update or reinstall.
  Future<String> _coreSourceSignature(File source) async {
    final parts = <String>[];
    try {
      parts.add('len:${await source.length()}');
      parts.add(
        'mtime:${(await source.lastModified()).millisecondsSinceEpoch}',
      );
    } catch (_) {
      // Ignore: the AppImage signature below is the reliable discriminator.
    }
    final appImagePath = Platform.environment['APPIMAGE'] ?? '';
    if (appImagePath.isNotEmpty) {
      parts.add('app:$appImagePath');
      try {
        final appImage = File(appImagePath);
        if (await appImage.exists()) {
          parts.add('applen:${await appImage.length()}');
          parts.add(
            'appmtime:${(await appImage.lastModified()).millisecondsSinceEpoch}',
          );
        }
      } catch (_) {
        // The path alone still contributes some uniqueness.
      }
    }
    return parts.join('|');
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
