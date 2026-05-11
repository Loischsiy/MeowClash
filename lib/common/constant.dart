import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:meow_clash/common/common.dart';
import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/models/models.dart';
import 'package:flutter/material.dart';

const appName = 'MeowClash';
const appHelperService = 'MeowClashHelperService';
const coreName = 'clash.meta';
const tunDeviceName = 'MeowClash';
const browserUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36';
const packageName = 'com.follow.clash';
final unixSocketPath = '/tmp/MeowClashSocket_${Random().nextInt(10000)}.sock';
const helperPort = 45678;
const maxTextScale = 1.4;
const minTextScale = 0.8;
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.ap,
  horizontal: 16.ap,
);

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 5000);
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const mmdbFileName = 'geoip.metadb';
const asnFileName = 'ASN.mmdb';
const geoIpFileName = 'GeoIP.dat';
const geoSiteFileName = 'GeoSite.dat';
final double kHeaderHeight = system.isDesktop
    ? !system.isMacOS
          ? 40
          : 28
    : 0;
const profilesDirectoryName = 'profiles';
const localhost = '127.0.0.1';
const clashConfigKey = 'clash_config';
const configKey = 'config';
const customSidebarIconKey = 'custom_sidebar_icon';
const customDashboardTitleKey = 'custom_dashboard_title';
const double dialogCommonWidth = 300;
const repository = 'appshubcc/MeowClash';
const defaultExternalController = '127.0.0.1:9090';
const maxMobileWidth = 600;
const maxLaptopWidth = 840;
const defaultTestUrl = 'https://g.cn/generate_204';

// Preset test URLs
const presetTestUrls = [
  'https://g.cn/generate_204',
  'https://www.gstatic.com/generate_204',
  'https://www.google.com/generate_204',
  'https://cp.cloudflare.com/generate_204',
  'https://www.apple.com/library/test/success.html',
];

// Preset NTP servers
const defaultNtpServer = 'ntp.aliyun.com';
const presetNtpServers = [
  'ntp.aliyun.com',
  'time.apple.com',
  'ntp.tencent.com',
  'time.windows.com',
  'time.cloudflare.com',
];

class CommonFilters {
  static final ImageFilter blur = ImageFilter.blur(
    sigmaX: 2,
    sigmaY: 2,
    tileMode: TileMode.mirror,
  );
}

final commonFilter = CommonFilters.blur;

const navigationItemListEquality = ListEquality<NavigationItem>();
const trackerInfoListEquality = ListEquality<TrackerInfo>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
};

const proxiesListStoreKey = PageStorageKey<String>('proxies_list');
const toolsStoreKey = PageStorageKey<String>('tools');
const profilesStoreKey = PageStorageKey<String>('profiles');

const defaultPrimaryColor = 0xFF00796B;

double getWidgetHeight(num lines) {
  return max(lines * 84 + (lines - 1) * 16, 0).ap;
}

const maxLength = 256;

final mainIsolate = 'MeowClashMainIsolate';

final serviceIsolate = 'MeowClashServiceIsolate';

const defaultPrimaryColors = [
  0xFF191919,
  0xFF1976D2,
  defaultPrimaryColor,
  0xFFE91E63,
  0xFF7B1FA2,
  0xFFD97706,
  0xFF455A64,
];

const scriptTemplate = '''
const main = (config) => {
  return config;
}''';
