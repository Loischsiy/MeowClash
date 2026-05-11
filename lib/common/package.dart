import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua =>
      ['Clash.Meta/ClashMetaForAndroid/5.0'].join(' ');
}
