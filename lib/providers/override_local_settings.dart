import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_clash/services/config_priority_service.dart';

/// Notifier that keeps the "Override Local Settings" flag in memory
/// and persists it via [ConfigPriorityService].
class OverrideLocalSettingsNotifier extends StateNotifier<bool> {
  OverrideLocalSettingsNotifier() : super(false) {
    _init();
  }

  final ConfigPriorityService _service = configPriorityService;

  Future<void> _init() async {
    final value = await _service.getOverrideLocalSettings();
    state = value;
  }

  Future<void> setValue(bool value) async {
    await _service.setOverrideLocalSettings(value);
    state = value;
  }
}

/// Provider for the "Override Local Settings" toggle.
/// When `true`, external (profile) configuration takes priority over GUI settings.
final overrideLocalSettingsProvider =
    StateNotifierProvider<OverrideLocalSettingsNotifier, bool>((ref) {
  return OverrideLocalSettingsNotifier();
});
