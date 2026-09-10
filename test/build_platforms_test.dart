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

  test('Build option probe ignores flags mentioned in prose', () {
    const help = '    --[no-]analyze-size    Whether to produce additional '
        'profile information for artifact output size. When building for '
        'Android, a single ABI must be specified at a time with the '
        '"--target-platform" flag.\n'
        '    --target=<path>    The main entry-point file.\n';
    expect(setup.Build.probeDeclaresOption(help, 'target-platform'), isFalse);
  });

  test('Build option probe reads the argument parser verdict', () {
    expect(
      setup.Build.probeDeclaresOption(
        'Could not find an option named "--target-platform".',
        'target-platform',
      ),
      isFalse,
    );
    expect(
      setup.Build.probeDeclaresOption(
        'Missing argument for "--target-platform".',
        'target-platform',
      ),
      isTrue,
    );
    expect(
      setup.Build.probeDeclaresOption(
        'Missing argument for "target-platform".',
        'target-platform',
      ),
      isTrue,
    );
    expect(
      setup.Build.probeDeclaresOption(
        '    --target-platform=<default>    The target platform.\n',
        'target-platform',
      ),
      isTrue,
    );
  });

  test('Windows host architecture is detected under x64 emulation', () {
    expect(setup.Build.hostArchFromEnvironment('ARM64'), setup.Arch.arm64);
    expect(setup.Build.hostArchFromEnvironment('arm64'), setup.Arch.arm64);
    expect(setup.Build.hostArchFromEnvironment('AMD64'), setup.Arch.amd64);
    expect(setup.Build.hostArchFromEnvironment(null), setup.Arch.amd64);
  });

  test('QuickJS keeps constant Math initializers on windows-arm64', () {
    // Every libm symbol whose address quickjs.c stores in js_math_funcs.
    const wrapped = <String>[
      'acos',
      'acosh',
      'asin',
      'asinh',
      'atan',
      'atan2',
      'atanh',
      'cbrt',
      'ceil',
      'cos',
      'cosh',
      'exp',
      'expm1',
      'fabs',
      'floor',
      'log',
      'log10',
      'log1p',
      'log2',
      'sin',
      'sinh',
      'sqrt',
      'tan',
      'tanh',
      'trunc',
    ];
    final shim = File('native/quickjs/msvc_arm64_math.h').readAsStringSync();
    expect(shim, contains('_M_ARM64'));
    for (final name in wrapped) {
      expect(shim, contains('#define $name meow_qjs_$name'),
          reason: 'quickjs.c takes the address of $name in its Math table');
    }
    expect(shim, contains('!defined(__cplusplus)'),
        reason: 'the shim is force-included target-wide, C++ must stay clean');
    final cmake = File('native/quickjs/CMakeLists.txt').readAsStringSync();
    // The Visual Studio generator behind `flutter build windows` drops
    // target-wide $<COMPILE_LANGUAGE:C> options, so that spelling silently
    // removed the force-include and arm64 kept failing with C2099.
    expect(cmake,
        isNot(contains(r'$<$<COMPILE_LANGUAGE:C>:/FImsvc_arm64_math.h>')));
    expect(
        cmake,
        contains(
            r'set_source_files_properties(${MEOW_QUICKJS_C_SOURCES} PROPERTIES'));
    expect(cmake, contains('COMPILE_OPTIONS "/FImsvc_arm64_math.h"'));
    expect(
        cmake,
        contains(
            'target_compile_options(meow_quickjs PRIVATE /FImsvc_arm64_math.h)'));
    expect(
        cmake,
        contains('target_include_directories(meow_quickjs PRIVATE '
            r'"${CMAKE_CURRENT_LIST_DIR}")'));
  });

  test('QuickJS resolves alloca on windows-arm64', () {
    // libregexp.c and quickjs.c call alloca() without including <malloc.h>.
    // MSVC only recognises the bare name as an intrinsic on x86/x64, so arm64
    // compiled cleanly and then failed with LNK2019/LNK2001 on `alloca` and
    // LNK1120 for quickjs_c_bridge.dll.
    final shim = File('native/quickjs/msvc_arm64_math.h').readAsStringSync();
    const guard = '#define MEOW_QUICKJS_MSVC_ARM64_MATH_H';
    final mathBlock = shim.indexOf('MEOW_QUICKJS_FORCE_MATH_SHIM');
    expect(mathBlock, greaterThan(0));
    final prelude =
        shim.substring(shim.indexOf(guard) + guard.length, mathBlock);
    expect(prelude, contains('#include <malloc.h>'));
    expect(prelude, contains('#define alloca _alloca'),
        reason: 'the mapping must cover every MSVC arch, not only ARM64');
    expect(prelude, contains('defined(_MSC_VER)'));
    expect(prelude, contains('!defined(__cplusplus)'),
        reason: 'the shim is force-included target-wide, C++ must stay clean');
  });
}
