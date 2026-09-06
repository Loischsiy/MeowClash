import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('service profile scripts run without initializing UI AppState',
      () async {
    globalState
      ..isService = true
      ..config = const Config(
        themeProps: defaultThemeProps,
        scriptProps: ScriptProps(
          currentId: 'fixture',
          scripts: [
            Script(
              id: 'fixture',
              label: 'Headless fixture',
              content: '''
                function main(config) {
                  config['proxy-providers']['scripted'] = {
                    type: 'http',
                    url: 'https://example.invalid/scripted',
                    path: '/fixture/scripted',
                    interval: 1200
                  };
                  return config;
                }
              ''',
            ),
          ],
        ),
      );
    addTearDown(() {
      globalState.isService = false;
    });
    expect(globalState.isAppControllerReady, isFalse);
    // Deliberately never construct AppState, a UI, or a native VPN/core.
    final result = await globalState.handleEvaluate(<String, dynamic>{});
    expect((result['proxy-providers'] as Map)['scripted']['interval'], 1200);
  }, skip: !Platform.isMacOS);
}
