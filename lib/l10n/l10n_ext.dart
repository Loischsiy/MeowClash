import 'package:meow_clash/l10n/l10n.dart';

extension AppLocalizationsExt on AppLocalizations {
  String get overrideLocalSettings {
    return Intl.message(
      'Override Local Settings',
      name: 'overrideLocalSettings',
      desc: '',
      args: [],
    );
  }

  String get overrideLocalSettingsDesc {
    return Intl.message(
      'External profile settings take priority over local GUI settings',
      name: 'overrideLocalSettingsDesc',
      desc: '',
      args: [],
    );
  }
}
