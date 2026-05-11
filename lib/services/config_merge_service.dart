/// Service that controls how GUI (local) settings are merged with
/// external (profile) settings.
///
/// When [externalPriority] is `false` (default), local settings override
/// the profile — matching the original behaviour.
///
/// When [externalPriority] is `true`, the profile keeps its own values
/// and local settings are used only as a fallback for missing keys.
class ConfigMergeService {
  final bool externalPriority;

  const ConfigMergeService({required this.externalPriority});

  /// Applies [value] to [config] under [key].
  /// If [externalPriority] is enabled and the key already exists
  /// with a non-null value, the existing value is preserved.
  void apply(Map<String, dynamic> config, String key, dynamic value) {
    if (externalPriority &&
        config.containsKey(key) &&
        config[key] != null) {
      return;
    }
    config[key] = value;
  }

  /// Applies a section (nested map) to [config] under [key].
  /// If [externalPriority] is enabled and the section already exists
  /// and is non-empty, the existing section is preserved.
  void applySection(
    Map<String, dynamic> config,
    String key,
    Map<String, dynamic> value,
  ) {
    if (externalPriority &&
        config[key] is Map &&
        (config[key] as Map).isNotEmpty) {
      return;
    }
    config[key] = value;
  }

  /// Determines whether a GUI override flag (e.g. overrideDns) should be
  /// honoured. When [externalPriority] is `true`, GUI overrides are ignored
  /// unless the section is missing from the profile.
  bool shouldOverrideSection(Map<String, dynamic> config, String sectionKey) {
    if (!externalPriority) return true;
    // External priority: only override if section is absent or empty.
    final section = config[sectionKey];
    if (section == null) return true;
    if (section is Map && section.isEmpty) return true;
    if (section is List && section.isEmpty) return true;
    return false;
  }
}
