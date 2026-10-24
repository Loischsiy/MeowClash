import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';

// The same ThemeData font arguments as lib/application.dart.
ThemeData _appTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: GlassTheme.fontFamily('NotoSans'),
      fontFamilyFallback: GlassTheme.fontFamilyFallback(
        const ['NotoSans', 'JetBrainsMono'],
      ),
    );

void main() {
  tearDown(() => AdaptivePlatform.debugUseGlassOverride = null);

  testWidgets('Darwin uses the system San Francisco, not NotoSans',
      (tester) async {
    AdaptivePlatform.debugUseGlassOverride = true;
    final body = _appTheme().textTheme.bodyMedium!;
    final system = Typography.material2021(platform: defaultTargetPlatform)
        .black
        .bodyMedium!;
    expect(body.fontFamily, isNot('NotoSans'));
    expect(body.fontFamily, system.fontFamily);
    // No bundled fallbacks in front of the system cascade.
    expect(body.fontFamilyFallback, system.fontFamilyFallback);
  }, variant: const TargetPlatformVariant({
    TargetPlatform.macOS,
    TargetPlatform.iOS,
  }));

  testWidgets('other platforms keep NotoSans', (tester) async {
    AdaptivePlatform.debugUseGlassOverride = false;
    final body = _appTheme().textTheme.bodyMedium!;
    expect(body.fontFamily, 'NotoSans');
    expect(body.fontFamilyFallback, const ['NotoSans', 'JetBrainsMono']);
  }, variant: const TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
  }));
}
