import 'package:meow_clash/common/common.dart';

/// Service responsible for reading/writing the "override local settings" flag
/// directly from SharedPreferences, avoiding the need to regenerate Freezed models.
class ConfigPriorityService {
  static const String _key = 'override_local_settings';

  Future<bool> getOverrideLocalSettings() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    return prefs?.getBool(_key) ?? false;
  }

  Future<void> setOverrideLocalSettings(bool value) async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    await prefs?.setBool(_key, value);
  }
}

final configPriorityService = ConfigPriorityService();
