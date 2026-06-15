import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:meowclash/clash/interface.dart';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/core.dart';
import 'package:meowclash/state.dart';
import 'package:path/path.dart';

class ClashService extends ClashHandlerInterface {

  factory ClashService() {
    _instance ??= ClashService._internal();
    return _instance!;
  }

  ClashService._internal() {
    unawaited(_initServer());
    reStart();
  }
  static ClashService? _instance;

  Completer<ServerSocket> serverCompleter = Completer();

  Completer<Socket> socketCompleter = Completer();

  bool isStarting = false;

  Process? process;

  String? _unixSocketPath;

  bool _isShuttingDown = false;

  int _unexpectedExitCount = 0;

  DateTime? _lastUnexpectedExitTime;

  Future<void> _initServer() async {
    runZonedGuarded(() async {
      if (!Platform.isWindows) {
        final tempDirPath = await appPath.tempPath;
        _unixSocketPath = join(tempDirPath, "MeowClashSocket_${Random().nextInt(10000)}.sock");
      }
      final address = !Platform.isWindows
          ? InternetAddress(
              _unixSocketPath!,
              type: InternetAddressType.unix,
            )
          : InternetAddress(
              localhost,
              type: InternetAddressType.IPv4,
            );
      await _deleteSocketFile();
      final server = await ServerSocket.bind(
        address,
        0,
        shared: true,
      );
      serverCompleter.complete(server);
      await for (final socket in server) {
        await _destroySocket();
        socketCompleter.complete(socket);
        socket
            .transform(uint8ListToListIntConverter)
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (data) {
            handleResult(
              ActionResult.fromJson(
                json.decode(data.trim()),
              ),
            );
          },
        );
      }
    }, (error, stack) {
      commonPrint.log(error.toString());
      if (error is SocketException) {
        globalState.showNotifier(error.toString());
        // globalState.appController.restartCore();
      }
    });
  }

  @override
  Future<void> reStart() async {
    if (isStarting == true) {
      return;
    }
    isStarting = true;
    try {
      if (process != null) {
        await shutdown();
      }
      socketCompleter = Completer();
      final serverSocket = await serverCompleter.future;
      final arg = Platform.isWindows
          ? "${serverSocket.port}"
          : serverSocket.address.address;
      if (Platform.isWindows && await system.checkIsAdmin()) {
        final isSuccess = await request.startCoreByHelper(arg);
        if (isSuccess) {
          _isShuttingDown = false;
          return;
        }
      }

      final homeDirPath = await appPath.homeDirPath;
      final environment = Map<String, String>.from(Platform.environment);
      // Set SAFE_PATHS to prevent "path is not subpath of home directory" errors
      // This ensures the core can access provider files before SetHomeDir is called
      environment['SAFE_PATHS'] = homeDirPath;

      final corePath = await appPath.resolvedCorePath;
      commonPrint.log("ClashService: starting core at $corePath");
      _isShuttingDown = false;
      final nextProcess = await Process.start(
        corePath,
        [
          arg,
        ],
        environment: environment,
      );
      process = nextProcess;
      commonPrint.log("ClashService: core pid ${nextProcess.pid}");
      _watchProcess(nextProcess);
    } catch (error, stackTrace) {
      commonPrint.log("ClashService: failed to start core: $error");
      commonPrint.log(stackTrace.toString());
    } finally {
      isStarting = false;
    }
  }

  Duration _nextRestartDelay() {
    final now = DateTime.now();
    final lastExitTime = _lastUnexpectedExitTime;
    if (lastExitTime == null ||
        now.difference(lastExitTime) > const Duration(minutes: 1)) {
      _unexpectedExitCount = 0;
    }
    _lastUnexpectedExitTime = now;
    _unexpectedExitCount += 1;
    final delaySeconds = min(30, 1 << min(_unexpectedExitCount - 1, 5));
    return Duration(seconds: delaySeconds);
  }

  void _watchProcess(Process watchedProcess) {
    watchedProcess.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.isNotEmpty) {
        commonPrint.log("[core stdout] $line");
      }
    });
    watchedProcess.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.isNotEmpty) {
        commonPrint.log("[core stderr] $line");
      }
    });
    unawaited(watchedProcess.exitCode.then((exitCode) async {
      if (process != watchedProcess) {
        return;
      }
      commonPrint.log("ClashService: core exited with code $exitCode");
      process = null;
      await _destroySocket();
      if (_isShuttingDown) {
        return;
      }
      final restartDelay = _nextRestartDelay();
      commonPrint.log(
        "ClashService: restarting core after unexpected exit in "
        "${restartDelay.inSeconds}s",
      );
      await Future<void>.delayed(restartDelay);
      await reStart();
    }));
  }

  @override
  Future<bool> destroy() async {
    final server = await serverCompleter.future;
    await server.close();
    await _deleteSocketFile();
    return true;
  }

  @override
  Future<void> sendMessage(String message) async {
    final socket = await socketCompleter.future;
    try {
      socket.writeln(message);
    } on SocketException catch (e) {
      // The core forcibly dropped the connection (e.g. errno 10054 on
      // Windows when the core process restarts). Swallow it so it does not
      // surface as an unhandled zone error; callers such as updateGroups
      // already handle a missing response gracefully.
      commonPrint.log("sendMessage failed, socket unavailable: $e");
    } on StateError catch (e) {
      // The underlying StreamSink was already closed.
      commonPrint.log("sendMessage failed, socket closed: $e");
    }
  }

  Future<void> _deleteSocketFile() async {
    if (!Platform.isWindows && _unixSocketPath != null) {
      final file = File(_unixSocketPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _destroySocket() async {
    if (socketCompleter.isCompleted) {
      final lastSocket = await socketCompleter.future;
      await lastSocket.close();
      socketCompleter = Completer();
    }
  }

  @override
  Future<bool> shutdown() async {
    _isShuttingDown = true;
    if (Platform.isWindows) {
      await request.stopCoreByHelper();
    }
    await _destroySocket();
    process?.kill();
    process = null;
    return true;
  }

  @override
  Future<bool> preload() async {
    await serverCompleter.future;
    return true;
  }
}

final clashService = system.isDesktop ? ClashService() : null;
