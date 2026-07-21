import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  String ua({String? coreVersion}) => [
        "MeowClash X/v$version",
        if (coreVersion != null && coreVersion.isNotEmpty) "core/$coreVersion",
        "Platform/${Platform.operatingSystem}",
      ].join(" ");
}
