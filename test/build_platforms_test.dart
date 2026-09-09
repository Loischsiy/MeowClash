import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../setup.dart' as setup;

void main() {
  test('ARM64 and x64 remain available on desktop', () {
    for (final target in [
      setup.Target.windows,
      setup.Target.linux,
      setup.Target.macos
    ]) {
      final arches = setup.Build.buildItems
          .where((item) => item.target == target)
          .map((item) => item.arch)
          .toSet();
      expect(arches, {setup.Arch.amd64, setup.Arch.arm64});
    }
  });

  test('Android cores cover all requested Flutter ABIs', () {
    final items = setup.Build.buildItems
        .where((item) => item.target == setup.Target.android);
    expect(items.map((item) => item.archName).toSet(),
        {'armeabi-v7a', 'arm64-v8a', 'x86_64'});
  });

  test('iOS is an arm64-only archive, not a desktop executable', () {
    final items = setup.Build.buildItems
        .where((item) => item.target == setup.Target.ios)
        .toList();
    expect(items, hasLength(1));
    expect(items.single.arch, setup.Arch.arm64);
    expect(setup.Target.ios.os, 'ios');
    expect(setup.Target.ios.dynamicLibExtensionName, '.a');
  });

  test('Windows installer is restricted to the packaged architecture', () {
    const config = 'script_template: inno_setup.iss\napp_name: MeowClash\n';
    final arm64Config =
        setup.Build.patchWindowsMakeConfig(config, setup.Arch.arm64);
    expect(arm64Config, startsWith('script_template: inno_setup.iss'));
    expect(arm64Config, contains('architectures_allowed: arm64'));
    expect(arm64Config, contains('architectures_install_in_64bit_mode: arm64'));

    final amd64Config =
        setup.Build.patchWindowsMakeConfig(arm64Config, setup.Arch.amd64);
    expect(amd64Config, contains('architectures_allowed: x64'));
    expect(amd64Config, contains('architectures_install_in_64bit_mode: x64'));
    expect(amd64Config, isNot(contains('arm64')));
    expect('architectures_allowed:'.allMatches(amd64Config), hasLength(1));
  });

  test('Inno Setup template only uses substituted placeholders', () {
    final template =
        File('windows/packaging/exe/inno_setup.iss').readAsStringSync();
    expect(
        template, contains('ArchitecturesAllowed={{ARCHITECTURES_ALLOWED}}'));
    expect(
        template,
        contains(
            'ArchitecturesInstallIn64BitMode={{ARCHITECTURES_INSTALL_IN_64BIT_MODE}}'));
    expect(template, isNot(contains('{{ARCH}}')));
  });
}
