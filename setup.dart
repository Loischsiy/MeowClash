// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

enum Target {
  windows,
  linux,
  android,
  macos,
  ios,
}

extension TargetExt on Target {
  String get os {
    if (this == Target.macos) {
      return "darwin";
    }
    return name;
  }

  bool get same {
    if (this == Target.android) {
      return true;
    }
    if (Platform.isWindows && this == Target.windows) {
      return true;
    }
    if (Platform.isLinux && this == Target.linux) {
      return true;
    }
    if (Platform.isMacOS && (this == Target.macos || this == Target.ios)) {
      return true;
    }
    return false;
  }

  String get dynamicLibExtensionName {
    final String extensionName;
    switch (this) {
      case Target.android || Target.linux:
        extensionName = ".so";
        break;
      case Target.windows:
        extensionName = ".dll";
        break;
      case Target.ios:
        extensionName = ".a";
        break;
      case Target.macos:
        extensionName = ".dylib";
        break;
    }
    return extensionName;
  }

  String get executableExtensionName {
    final String extensionName;
    switch (this) {
      case Target.windows:
        extensionName = ".exe";
        break;
      default:
        extensionName = "";
        break;
    }
    return extensionName;
  }
}

enum Mode { core, lib }

enum Arch { amd64, arm64, arm }

class BuildItem {
  Target target;
  Arch? arch;
  String? archName;

  BuildItem({
    required this.target,
    this.arch,
    this.archName,
  });

  @override
  String toString() =>
      'BuildLibItem{target: $target, arch: $arch, archName: $archName}';
}

class Build {
  static List<BuildItem> get buildItems => [
        BuildItem(
          target: Target.macos,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.macos,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm,
          archName: 'armeabi-v7a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm64,
          archName: 'arm64-v8a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.amd64,
          archName: 'x86_64',
        ),
        BuildItem(target: Target.ios, arch: Arch.arm64),
      ];

  static String get appName => "MeowClash";

  static String get coreName => "MeowClashCore";

  static String get libName => "libclash";

  static String get outDir => join(current, libName);

  static String get _coreDir => join(current, "core");

  static String get _servicesDir => join(current, "services", "helper");

  static String get distPath => join(current, "dist");

  static String _getCc(BuildItem buildItem) {
    final environment = Platform.environment;
    if (buildItem.target == Target.android) {
      final ndk = environment["ANDROID_NDK"];
      assert(ndk != null);
      final prebuiltDir =
          Directory(join(ndk!, "toolchains", "llvm", "prebuilt"));
      final prebuiltDirList = prebuiltDir.listSync();
      final map = {
        "armeabi-v7a": "armv7a-linux-androideabi21-clang",
        "arm64-v8a": "aarch64-linux-android21-clang",
        "x86": "i686-linux-android21-clang",
        "x86_64": "x86_64-linux-android21-clang"
      };
      return join(
        prebuiltDirList.first.path,
        "bin",
        map[buildItem.archName],
      );
    }
    return "gcc";
  }

  static get tags => "with_gvisor,cmfa";

  static Future<void> exec(
    List<String> executable, {
    String? name,
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = true,
  }) async {
    if (name != null) print("run $name");
    final process = await Process.start(
      executable[0],
      executable.sublist(1),
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    process.stdout.listen((data) {
      print(utf8.decode(data));
    });
    process.stderr.listen((data) {
      print(utf8.decode(data));
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(executable.first, executable.sublist(1),
          '${name ?? executable.first} failed', exitCode);
    }
  }

  static Future<String> calcSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw "File not exists";
    }
    final stream = file.openRead();
    return sha256.convert(await stream.reduce((a, b) => a + b)).toString();
  }

  /// Reads [core/constant/version.go] (single source of truth for mihomo version).
  static Future<String> extractCoreVersion() async {
    final versionFile = File(join("core", "constant", "version.go"));
    if (!await versionFile.exists()) {
      throw "core/constant/version.go file not found";
    }
    final content = await versionFile.readAsString();
    final match = RegExp(r'Version\s*=\s*"([^"]+)"').firstMatch(content);
    if (match == null) {
      throw "Could not extract Version from core/constant/version.go";
    }
    return match.group(1)!;
  }

  /// Writes [lib/core_version.dart] so Flutter can show the same version without dart-define.
  static Future<void> syncCoreVersionDartFile() async {
    final v = await extractCoreVersion();
    final out = File(join(current, "lib", "core_version.dart"));
    await out.writeAsString(
      "// GENERATED by setup.dart from core/constant/version.go — do not edit by hand\n"
      "// ignore_for_file: constant_identifier_names\n"
      "\n"
      "/// Embedded mihomo version (see core/constant/version.go).\n"
      "const String kCoreVersionFromSource = '$v';\n",
    );
  }

  static Future<List<String>> buildCore({
    required Mode mode,
    required Target target,
    required String coreVersion,
    Arch? arch,
  }) async {
    if (target == Target.ios) {
      if (!Platform.isMacOS || arch != Arch.arm64) {
        throw ArgumentError(
            'iOS requires macOS, Xcode and --arch arm64 (device only)');
      }
      await exec(['bash', 'ios/build_core.sh'], name: 'build iOS core');
      return [join(outDir, 'ios', 'libclash.a')];
    }
    final isLib = mode == Mode.lib;

    final items = buildItems
        .where(
          (element) =>
              element.target == target &&
              (arch == null ? true : element.arch == arch),
        )
        .toList();

    final List<String> corePaths = [];

    final targetOutFilePath = join(outDir, target.name);
    // Android ABIs share one output tree. Remove stale ABIs when the selection
    // changes, otherwise a supposedly arm64-only APK may contain an old core.
    final targetOutDirectory = Directory(targetOutFilePath);
    if (target == Target.android && targetOutDirectory.existsSync()) {
      targetOutDirectory.deleteSync(recursive: true);
    }
    targetOutDirectory.createSync(recursive: true);

    for (final item in items) {
      final outFilePath = join(targetOutFilePath, item.archName);
      Directory(outFilePath).createSync(recursive: true);

      final fileName = isLib
          ? "$libName${item.target.dynamicLibExtensionName}"
          : "$coreName${item.target.executableExtensionName}";
      final realOutPath = join(outFilePath, fileName);
      corePaths.add(realOutPath);

      final Map<String, String> env = {};
      env["GOOS"] = item.target.os;
      if (item.arch != null) {
        env["GOARCH"] = item.arch!.name;
        if (item.arch == Arch.arm) {
          env["GOARM"] = "7";
        }
      }
      if (isLib) {
        env["CGO_ENABLED"] = "1";
        env["CC"] = _getCc(item);
        env["CGO_CFLAGS"] = "-O3";
      } else {
        env["CGO_ENABLED"] = "0";
      }

      final execLines = [
        "go",
        "build",
        "-ldflags=-w -s -X github.com/metacubex/mihomo/constant.Version=$coreVersion",
        "-tags=$tags",
        if (isLib) "-buildmode=c-shared",
        "-o",
        realOutPath,
      ];
      await exec(
        execLines,
        name: "build core",
        environment: env,
        workingDirectory: _coreDir,
      );
      if (isLib && item.archName != null) {
        await adjustLibOut(
          targetOutFilePath: targetOutFilePath,
          outFilePath: outFilePath,
          archName: item.archName!,
        );
      }
    }

    return corePaths;
  }

  static Future<void> adjustLibOut({
    required String targetOutFilePath,
    required String outFilePath,
    required String archName,
  }) async {
    final includesPath = join(targetOutFilePath, "includes");
    final realOutPath = join(includesPath, archName);
    await Directory(realOutPath).create(recursive: true);
    final targetOutFiles = Directory(outFilePath).listSync();
    final coreFiles = Directory(_coreDir).listSync();
    for (final file in [...targetOutFiles, ...coreFiles]) {
      if (!file.path.endsWith('.h')) {
        continue;
      }
      final targetFilePath = join(realOutPath, basename(file.path));
      final realFile = File(file.path);
      await realFile.copy(targetFilePath);
      if (coreFiles.contains(file)) {
        continue;
      }
      await realFile.delete();
    }
  }

  static buildHelper(Target target, String token, {Arch? arch}) async {
    final List<String> buildArgs = [
      "cargo",
      "build",
      "--release",
      "--features",
      "windows-service",
    ];

    // Add target for cross-compilation
    if (target == Target.windows) {
      buildArgs.addAll([
        '--target',
        arch == Arch.arm64
            ? 'aarch64-pc-windows-msvc'
            : 'x86_64-pc-windows-msvc'
      ]);
    }

    await exec(
      buildArgs,
      environment: {
        "TOKEN": token,
      },
      name: "build helper",
      workingDirectory: _servicesDir,
    );

    // Determine output path based on architecture
    final String releasePath;
    if (target == Target.windows) {
      releasePath = join(
          _servicesDir,
          'target',
          arch == Arch.arm64
              ? 'aarch64-pc-windows-msvc'
              : 'x86_64-pc-windows-msvc',
          'release');
    } else {
      releasePath = join(_servicesDir, "target", "release");
    }

    final outPath = join(
      releasePath,
      "helper${target.executableExtensionName}",
    );
    final targetPath = join(
      outDir,
      target.name,
      "MeowClashHelperService${target.executableExtensionName}",
    );
    await File(outPath).copy(targetPath);
  }

  static List<String> getExecutable(String command) => command.split(" ");

  static getDistributor() async {
    final distributorDir = join(
      current,
      "plugins",
      "flutter_distributor",
      "packages",
      "flutter_distributor",
    );

    await exec(
      name: "clean distributor",
      Build.getExecutable("flutter clean"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "upgrade distributor",
      Build.getExecutable("flutter pub upgrade"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "get distributor",
      Build.getExecutable("dart pub global activate -s path $distributorDir"),
    );
  }

  static copyFile(String sourceFilePath, String destinationFilePath) {
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw "SourceFilePath not exists";
    }
    final destinationFile = File(destinationFilePath);
    final destinationDirectory = destinationFile.parent;
    if (!destinationDirectory.existsSync()) {
      destinationDirectory.createSync(recursive: true);
    }
    try {
      sourceFile.copySync(destinationFilePath);
      print("File copied successfully!");
    } catch (e) {
      print("Failed to copy file: $e");
    }
  }
}

class BuildCommand extends Command {
  Target target;

  BuildCommand({
    required this.target,
  }) {
    if (target == Target.android || target == Target.linux) {
      argParser.addOption(
        "arch",
        valueHelp: arches.map((e) => e.name).join(','),
        help: 'The $name build desc',
      );
    } else {
      argParser.addOption(
        "arch",
        help: 'The $name build archName',
      );
    }
    argParser.addOption(
      "out",
      valueHelp: [
        if (target.same) "app",
        "core",
      ].join(','),
      help: 'The $name build arch',
    );
    argParser.addOption(
      "env",
      valueHelp: [
        "pre",
        "stable",
      ].join(','),
      help: 'The $name build env',
    );
    // Android builds always create both split and universal APKs
    // No additional flags needed
  }

  @override
  String get description => "build $name application";

  @override
  String get name => target.name;

  List<Arch> get arches => Build.buildItems
      .where((element) => element.target == target && element.arch != null)
      .map((e) => e.arch!)
      .toList();

  _getLinuxDependencies(Arch arch) async {
    await Build.exec(
      Build.getExecutable("sudo apt update -y"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y ninja-build libgtk-3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y libayatana-appindicator3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt-get install -y libkeybinder-3.0-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y locate"),
    );
    await Build.exec(
      ['sudo', 'apt', 'install', '-y', 'rpm', 'patchelf', 'cmake', 'g++'],
    );
    final downloadName = arch == Arch.amd64 ? 'x86_64' : 'aarch64';
    await Build.exec([
      'wget',
      '-O',
      'appimagetool',
      'https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-$downloadName.AppImage',
    ]);
    await Build.exec(['chmod', '+x', 'appimagetool']);
    await Build.exec(['sudo', 'mv', 'appimagetool', '/usr/local/bin/']);
  }

  _getMacosDependencies() async {
    await Build.exec(
      Build.getExecutable("npm install -g create-dmg"),
    );
  }

  _buildMacosApp({
    required Arch arch,
    required String env,
    required String coreVersion,
  }) async {
    await Build.exec(
      name: "flutter build macos",
      [
        "flutter",
        "build",
        "macos",
        "--release",
        "--dart-define=APP_ENV=$env",
        "--dart-define=CORE_VERSION=$coreVersion",
      ],
    );

    final pubspecFile = File(join(current, "pubspec.yaml"));
    final pubspecContent = pubspecFile.readAsStringSync();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(pubspecContent);
    final version = versionMatch?.group(1)?.split('+').first ?? "0.0.0";

    final appName = Build.appName;
    final appPath = join(current, "build", "macos", "Build", "Products",
        "Release", "$appName.app");

    final distDir = Directory(Build.distPath);
    if (!distDir.existsSync()) {
      distDir.createSync(recursive: true);
    }

    print("Creating DMG with create-dmg...");

    await Build.exec(
      name: "create-dmg",
      [
        "create-dmg",
        "--overwrite",
        "--no-code-sign",
        "--dmg-title",
        appName,
        appPath,
        Build.distPath,
      ],
    );

    final createdDmgName = "$appName $version.dmg";
    final createdDmgPath = join(Build.distPath, createdDmgName);
    final targetDmgName = "$appName-macos-${arch.name}.dmg";
    final targetDmgPath = join(Build.distPath, targetDmgName);

    final createdDmg = File(createdDmgPath);
    if (createdDmg.existsSync()) {
      final targetDmg = File(targetDmgPath);
      if (targetDmg.existsSync()) {
        targetDmg.deleteSync();
      }

      createdDmg.renameSync(targetDmgPath);
      print("✅ DMG created: $targetDmgPath");
    } else {
      throw "DMG file not created: $createdDmgPath";
    }
  }

  _buildDistributor({
    required Target target,
    required String targets,
    String args = '',
    required String env,
  }) async {
    await Build.getDistributor();
    await Build.exec(
      name: name,
      Build.getExecutable(
        "flutter_distributor package --skip-clean --platform ${target.name} --targets $targets --flutter-build-args=verbose$args --build-dart-define=APP_ENV=$env",
      ),
    );
  }

  void _renameWindowsOutputs(Arch arch) {
    final directory = Directory(Build.distPath);
    final files =
        directory.listSync(recursive: true).whereType<File>().toList();
    for (final file in files) {
      final suffix = extension(file.path).toLowerCase();
      if (suffix != '.exe' && suffix != '.zip') continue;
      final output = join(Build.distPath,
          'MeowClash-$_appVersion-windows-${arch.name}${suffix == ".exe" ? "-setup.exe" : ".zip"}');
      if (file.path == output) continue;
      if (File(output).existsSync())
        throw StateError('Duplicate Windows artifact: $output');
      file.renameSync(output);
      final oldHash = File('${file.path}.sha256');
      if (oldHash.existsSync()) oldHash.deleteSync();
    }
  }

  void _renameLinuxOutputs(Arch arch) {
    final distDir = Directory(Build.distPath);
    if (!distDir.existsSync()) return;

    final pubspecFile = File(join(current, "pubspec.yaml"));
    final pubspecContent = pubspecFile.readAsStringSync();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(pubspecContent);
    final pubspecVersion = versionMatch?.group(1)?.trim() ?? "0.0.0";
    final cleanVersion = pubspecVersion.split('+').first;

    final archName = arch == Arch.arm64 ? "arm64" : "amd64";

    final files = distDir.listSync(recursive: true);
    for (final entity in files) {
      if (entity is File) {
        final filePath = entity.path;
        final fileName = basename(filePath);
        if (fileName.startsWith("meowclash") && fileName.contains("linux")) {
          final ext =
              filePath.endsWith('.tar.gz') ? '.tar.gz' : extension(filePath);
          final targetFileName = "MeowClash-$cleanVersion-linux-$archName$ext";
          final targetPath = join(entity.parent.path, targetFileName);
          if (filePath != targetPath) {
            print("Renaming: $filePath -> $targetPath");
            final targetFile = File(targetPath);
            if (targetFile.existsSync()) {
              targetFile.deleteSync();
            }
            entity.renameSync(targetPath);
          }
        }
      }
    }
  }

  Future<void> _packageLinuxPortable(Arch arch) async {
    final bundleDir = _linuxBundleDir(arch);
    final targetPath = _linuxOutputPath(arch, "portable.tar.gz");
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }

    await Build.exec(
      ["tar", "-C", bundleDir.path, "-czf", targetPath, "."],
      name: "package linux portable",
      runInShell: false,
    );
  }

  Directory _linuxBundleDir(Arch arch) {
    final buildArchName = arch == Arch.arm64 ? "arm64" : "x64";
    final bundleDir = Directory(
      join(current, "build", "linux", buildArchName, "release", "bundle"),
    );

    if (!bundleDir.existsSync()) {
      throw "Linux bundle not found: ${bundleDir.path}";
    }

    return bundleDir;
  }

  String _linuxOutputPath(Arch arch, String suffix) {
    final pubspecFile = File(join(current, "pubspec.yaml"));
    final pubspecContent = pubspecFile.readAsStringSync();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(pubspecContent);
    final pubspecVersion = versionMatch?.group(1)?.trim() ?? "0.0.0";
    final cleanVersion = pubspecVersion.split('+').first;
    final archName = arch == Arch.arm64 ? "arm64" : "amd64";
    final distDir = Directory(Build.distPath)..createSync(recursive: true);
    final separator = suffix.startsWith(".") ? "" : "-";
    return join(
      distDir.path,
      "MeowClash-$cleanVersion-linux-$archName$separator$suffix",
    );
  }

  Future<void> _packageLinuxAppImage(Arch arch) async {
    final bundleDir = _linuxBundleDir(arch);
    final appDir = Directory(join(current, "build", "linux", "AppDir"));
    if (appDir.existsSync()) {
      appDir.deleteSync(recursive: true);
    }
    appDir.createSync(recursive: true);

    await Build.exec(
      ["cp", "-a", "${bundleDir.path}/.", appDir.path],
      name: "prepare linux appimage",
      runInShell: false,
    );

    final appRun = File(join(appDir.path, "AppRun"));
    await appRun.writeAsString(
      "#!/bin/sh\n"
      "HERE=\"\$(dirname \"\$(readlink -f \"\$0\")\")\"\n"
      "export LD_LIBRARY_PATH=\"\$HERE/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\"\n"
      "unset APPIMAGE\n"
      "exec \"\$HERE/meowclash\" \"\$@\"\n",
    );
    await Build.exec(
      ["chmod", "+x", appRun.path],
      name: "chmod AppRun",
      runInShell: false,
    );

    await File(join(current, "assets", "images", "icon.png")).copy(
      join(appDir.path, "meowclash.png"),
    );
    await File(join(appDir.path, "meowclash.desktop")).writeAsString(
      "[Desktop Entry]\n"
      "Name=MeowClash\n"
      "Exec=meowclash\n"
      "Icon=meowclash\n"
      "Type=Application\n"
      "Categories=Network;\n",
    );

    final targetPath = _linuxOutputPath(arch, ".AppImage");
    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      targetFile.deleteSync();
    }

    await Build.exec(
      ['appimagetool', '--appimage-extract-and-run', appDir.path, targetPath],
      environment: {'ARCH': arch == Arch.arm64 ? 'aarch64' : 'x86_64'},
      name: "package linux appimage",
      runInShell: false,
    );
  }

  String get _appVersion => RegExp(r'^version:\s*(.+)$', multiLine: true)
      .firstMatch(File('pubspec.yaml').readAsStringSync())!
      .group(1)!
      .trim()
      .split('+')
      .first;

  Future<void> _buildAndroidApp(
      Arch? arch, String env, String coreVersion) async {
    const platforms = {
      Arch.arm: 'android-arm',
      Arch.arm64: 'android-arm64',
      Arch.amd64: 'android-x64',
    };
    final selected = arch == null ? platforms.keys.toList() : [arch];
    final arguments = [
      'flutter',
      'build',
      'apk',
      '--release',
      '--target-platform=${selected.map((a) => platforms[a]).join(",")}',
      '--dart-define=APP_ENV=$env',
      '--dart-define=CORE_VERSION=$coreVersion',
    ];
    Directory(Build.distPath).createSync(recursive: true);
    if (selected.length > 1) {
      await Build.exec(arguments, name: 'build universal APK');
      await File('build/app/outputs/flutter-apk/app-release.apk').copy(
          join(Build.distPath, 'MeowClash-$_appVersion-android-universal.apk'));
    }
    await Build.exec([...arguments, '--split-per-abi'], name: 'build ABI APKs');
    for (final a in selected) {
      final abi = Build.buildItems
          .firstWhere((item) => item.target == Target.android && item.arch == a)
          .archName!;
      await File('build/app/outputs/flutter-apk/app-$abi-release.apk').copy(
          join(Build.distPath, 'MeowClash-$_appVersion-android-$abi.apk'));
    }
  }

  Future<void> _buildIosApp(String env, String coreVersion) async {
    await Build.exec([
      'flutter',
      'build',
      'ios',
      '--release',
      '--no-codesign',
      '--dart-define=APP_ENV=$env',
      '--dart-define=CORE_VERSION=$coreVersion',
    ], name: 'build unsigned iOS app');
    final staging = Directory(join(current, 'build', 'ios', 'unsigned'));
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    final payload = Directory(join(staging.path, 'Payload'))
      ..createSync(recursive: true);
    await Build.exec([
      'ditto',
      'build/ios/iphoneos/Runner.app',
      join(payload.path, 'MeowClash.app')
    ], name: 'stage iOS app');
    Directory(Build.distPath).createSync(recursive: true);
    final output =
        join(Build.distPath, 'MeowClash-$_appVersion-ios-arm64-unsigned.ipa');
    if (File(output).existsSync()) File(output).deleteSync();
    await Build.exec(
        ['ditto', '-c', '-k', '--keepParent', payload.path, output],
        name: 'package unsigned IPA');
    print(
        'Unsigned IPA: sign BOTH Runner and PacketTunnel with matching App Group entitlements before installing.');
  }

  Future<String?> get systemArch async {
    if (Platform.isWindows) {
      return Platform.environment["PROCESSOR_ARCHITECTURE"];
    } else if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('uname', ['-m']);
      return result.stdout.toString().trim();
    }
    return null;
  }

  @override
  Future<void> run() async {
    final mode =
        target == Target.android || target == Target.ios ? Mode.lib : Mode.core;
    final String out = argResults?["out"] ?? (target.same ? "app" : "core");
    final archName = argResults?["arch"];
    final env = argResults?["env"] ?? "pre";
    final currentArches =
        arches.where((element) => element.name == archName).toList();
    final arch = currentArches.isEmpty ? null : currentArches.first;

    if ((archName != null && arch == null) ||
        (arch == null && target != Target.android)) {
      throw UsageException(
          'Choose --arch ${arches.map((e) => e.name).join("|")}', usage);
    }
    if (out != 'core' && out != 'app') {
      throw UsageException('--out must be core or app', usage);
    }
    if (out == 'app' && !target.same) {
      throw UsageException(
          'Build ${target.name} apps on their native host', usage);
    }

    await Build.syncCoreVersionDartFile();
    final coreVersion = await Build.extractCoreVersion();

    final corePaths = await Build.buildCore(
      target: target,
      arch: arch,
      mode: mode,
      coreVersion: coreVersion,
    );

    if (out != "app") {
      return;
    }

    switch (target) {
      case Target.windows:
        final token = target != Target.android
            ? await Build.calcSha256(corePaths.first)
            : null;
        await Build.buildHelper(target, token!, arch: arch);
        await _buildDistributor(
          target: target,
          targets: "exe,zip",
          args:
              " --build-target-platform windows-${arch == Arch.arm64 ? 'arm64' : 'x64'} --build-dart-define=CORE_SHA256=$token --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );
        _renameWindowsOutputs(arch!);
        return;
      case Target.linux:
        final targetMap = {
          Arch.arm64: "linux-arm64",
          Arch.amd64: "linux-x64",
        };
        final targets = [
          "deb",
          "rpm",
        ].join(",");
        final defaultTarget = targetMap[arch];
        await _getLinuxDependencies(arch!);
        await _buildDistributor(
          target: target,
          targets: targets,
          args:
              " --build-target-platform $defaultTarget --build-dart-define=CORE_VERSION=$coreVersion",
          env: env,
        );
        await _packageLinuxPortable(arch);
        await _packageLinuxAppImage(arch);
        _renameLinuxOutputs(arch);
        return;
      case Target.android:
        await _buildAndroidApp(arch, env, coreVersion);
        return;
      case Target.ios:
        await _buildIosApp(env, coreVersion);
        return;
      case Target.macos:
        await _getMacosDependencies();
        await _buildMacosApp(
          arch: arch!,
          env: env,
          coreVersion: coreVersion,
        );
        return;
    }
  }
}

Future<void> main(List<String> args) async {
  final runner = CommandRunner("setup", "build Application");
  runner.addCommand(BuildCommand(target: Target.android));
  runner.addCommand(BuildCommand(target: Target.linux));
  runner.addCommand(BuildCommand(target: Target.windows));
  runner.addCommand(BuildCommand(target: Target.macos));
  runner.addCommand(BuildCommand(target: Target.ios));
  await runner.run(args);
}
