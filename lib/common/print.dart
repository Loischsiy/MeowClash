import 'package:meow_clash/models/models.dart';
import 'package:meow_clash/state.dart';
import 'package:flutter/cupertino.dart';

class CommonPrint {
  static CommonPrint? _instance;

  CommonPrint._internal();

  factory CommonPrint() {
    _instance ??= CommonPrint._internal();
    return _instance!;
  }

  void log(String? text) {
    final payload = '[APP] $text';
    debugPrint(payload);
    if (!globalState.isInit) {
      return;
    }
    globalState.appController.addLog(Log.app(payload));
  }
}

final commonPrint = CommonPrint();
