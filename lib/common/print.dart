import 'package:meowclash/common/file_logger.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';
import 'package:flutter/cupertino.dart';

class CommonPrint {

  factory CommonPrint() {
    _instance ??= CommonPrint._internal();
    return _instance!;
  }

  CommonPrint._internal();
  static CommonPrint? _instance;

  void log(String? text) {
    final payload = "[MeowClash] $text";
    debugPrint(payload);
    
    // Write to file log
    fileLogger.log(payload);
    
    if (!globalState.isInit) {
      return;
    }
    globalState.appController.addLog(
      Log.app(payload),
    );
  }
}

final commonPrint = CommonPrint();
