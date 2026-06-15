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
    socketCompleter = Completer();
    if (process != null) {
      await shutdown();
    }
    final serverSocket = await serverCompleter.future;
    final arg = Platform.isWindows
        ? "${serverSocket.port}"
        : serverSocket.address.address;
    if (Platform.isWindows && await system.checkIsAdmin()) {
      final isSuccess = await request.startCoreByHelper(arg);
      if (isSuccess) {
        return;
      }
    }
    
    final homeDirPath = await appPath.homeDirPath;
    final environment = Map<String, String>.from(Platform.environment);
    // Set SAFE_PATHS to prevent "path is not subpath of home directory" errors
    // This ensures the core can access provider files before SetHomeDir is called
    environment['SAFE_PATHS'] = homeDirPath;
    
    final corePath = await appPath.resolvedCorePath;
    process = await Process.start(
      corePath,
      [
        arg,
      ],
      environment: environment,
    );
    process?.stdout.listen((_) {});
    process?.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error);
      }
    });
    isStarting = false;
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
