import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/controller.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';

const _defaultProfile = Profile(
  id: 'default-subscription',
  label: 'Default Subscription',
  url: 'https://example.com/subscription.yaml',
  autoUpdateDuration: Duration(days: 1),
);

const _otherProfile = Profile(
  id: 'other-subscription',
  label: 'Other Subscription',
  autoUpdateDuration: Duration(days: 1),
);

// Exercise the real save/selection logic without starting the proxy core.
class _RecordingAppController extends AppController {
  _RecordingAppController(super.context, super.ref);

  final appliedConfigs = <Config>[];
  final silentApplications = <bool>[];

  @override
  void applyProfileDebounce({bool silence = false}) {
    appliedConfigs.add(globalState.config);
    silentApplications.add(silence);
  }
}

Future<({_RecordingAppController controller, WidgetRef ref})> _mountController(
  WidgetTester tester, {
  String? currentProfileId,
  List<Profile> profiles = const [_defaultProfile],
}) async {
  globalState.config = Config(
    themeProps: defaultThemeProps,
    profiles: profiles,
    currentProfileId: currentProfileId,
  );
  _RecordingAppController? controller;
  late WidgetRef testRef;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, child) {
            testRef = ref;
            ref
              ..watch(profilesProvider)
              ..watch(currentProfileIdProvider);
            controller ??= _RecordingAppController(context, ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return (controller: controller!, ref: testRef);
}

void main() {
  testWidgets('saving the default subscription selects it on first launch',
      (tester) async {
    final harness = await _mountController(tester);
    final savedProfile = _defaultProfile.copyWith(
      providerHeaders: {
        'meowclash-password': 'test-password',
        'meowclash-password-iterations': '1000',
      },
    );
    expect(harness.ref.read(currentProfileIdProvider), isNull);

    // EditProfileView uses this path when Save is pressed without a URL change.
    harness.controller.setProfileAndAutoApply(savedProfile);

    expect(harness.ref.read(currentProfileIdProvider), savedProfile.id);
    expect(harness.ref.read(profilesProvider), [savedProfile]);
    expect(globalState.config.currentProfileId, savedProfile.id);
    expect(harness.controller.silentApplications, [true]);
    expect(
        harness.controller.appliedConfigs.single.currentProfile, savedProfile);
  });

  testWidgets('saving an inactive subscription preserves the current selection',
      (tester) async {
    final harness = await _mountController(
      tester,
      currentProfileId: _otherProfile.id,
      profiles: [_defaultProfile, _otherProfile],
    );
    final savedProfile =
        _defaultProfile.copyWith(label: 'Updated subscription');

    harness.controller.setProfileAndAutoApply(savedProfile);

    expect(harness.ref.read(currentProfileIdProvider), _otherProfile.id);
    expect(harness.ref.read(profilesProvider), [savedProfile, _otherProfile]);
    expect(globalState.config.currentProfileId, _otherProfile.id);
    expect(harness.controller.appliedConfigs, isEmpty);
  });

  testWidgets('saving the selected subscription still reapplies its changes',
      (tester) async {
    final harness = await _mountController(
      tester,
      currentProfileId: _defaultProfile.id,
    );
    final savedProfile =
        _defaultProfile.copyWith(label: 'Updated subscription');

    harness.controller.setProfileAndAutoApply(savedProfile);

    expect(harness.ref.read(currentProfileIdProvider), savedProfile.id);
    expect(harness.ref.read(profilesProvider), [savedProfile]);
    expect(harness.controller.silentApplications, [true]);
    expect(
        harness.controller.appliedConfigs.single.currentProfile, savedProfile);
  });

  testWidgets('passive profile updates do not select a subscription',
      (tester) async {
    final harness = await _mountController(tester);

    harness.controller.setProfile(_defaultProfile.copyWith(isUpdating: true));

    expect(harness.ref.read(currentProfileIdProvider), isNull);
    expect(harness.controller.appliedConfigs, isEmpty);
  });
}
