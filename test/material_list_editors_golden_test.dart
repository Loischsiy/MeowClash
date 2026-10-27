import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/widgets.dart' show ListInputPage, MapInputPage;

import 'settings_test_support.dart';

/// Pixel baseline of the Material list editors (`ListInputPage`,
/// `MapInputPage`: the DNS / network / general lists and the proxies icon
/// map) that Android, Linux and Windows must keep after the Darwin glass
/// editors. The images were generated on `main` before the glass editors
/// landed and must still match. Regenerate only for an intended Material
/// change: `flutter test --update-goldens test/material_list_editors_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(400, 400);

  setUpAll(() => setUpSettingsEnvironment('material_list_editors'));

  final screens = <String, WidgetBuilder>{
    'list': (_) => ListInputPage(
          title: 'Nameserver',
          items: const ['https://doh.pub/dns-query', '8.8.8.8', 'tls://1.1.1.1'],
          titleBuilder: Text.new,
          onChange: (_) {},
        ),
    'list_empty': (_) => ListInputPage(
          title: 'Nameserver',
          items: const [],
          titleBuilder: Text.new,
          onChange: (_) {},
        ),
    'map': (_) => MapInputPage(
          title: 'Hosts',
          map: const {'example.com': '127.0.0.1', 'router.lan': '10.0.0.1'},
          titleBuilder: (e) => Text(e.key),
          subtitleBuilder: (e) => Text(e.value),
          onChange: (_) {},
        ),
  };

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  for (final brightness in Brightness.values) {
    final b = brightness.name;
    for (final MapEntry(key: name, value: builder) in screens.entries) {
      testWidgets('$name, $b', (tester) async {
        await setUpSettingsScreen(tester, size);
        await tester.pumpWidget(settingsHost(brightness, builder));
        await pumpSettingsFrames(tester);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/material_list_editors_${name}_$b.png'),
        );
      }, variant: android);
    }
  }
}
