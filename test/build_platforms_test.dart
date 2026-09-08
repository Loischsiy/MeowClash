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
}
