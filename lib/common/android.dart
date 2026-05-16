import 'dart:io';

import 'package:meowclash/plugins/app.dart';
import 'package:meowclash/state.dart';

class Android {
  Future<void> init() async {
    app?.onExit = () async {
      await globalState.appController.savePreferences();
    };
  }
}

final android = Platform.isAndroid ? Android() : null;
