import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/path.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/views/profiles/override_profile.dart';

/// Shared fixtures of the profile editor tests
/// (`material_profile_editors_golden_test.dart`,
/// `adaptive_profile_editors_glass_test.dart`).

const editorProfileId = 'sub';

Profile editorProfile() => const Profile(
      id: editorProfileId,
      label: 'Subscription',
      url: 'https://test.invalid/sub',
      autoUpdateDuration: Duration(minutes: 1440),
    );

const editorScripts = ScriptProps(
  currentId: 'b',
  scripts: [
    Script(id: 'a', label: 'Rename nodes', content: ''),
    Script(id: 'b', label: 'Add DNS', content: ''),
  ],
);

const editorSnippet = ClashConfigSnippet(
  proxyGroups: [
    ProxyGroup(
      name: 'Proxy',
      type: GroupType.Selector,
      proxies: ['Tokyo', 'Frankfurt'],
    ),
    ProxyGroup(
      name: 'Auto',
      type: GroupType.URLTest,
      proxies: ['Tokyo', 'Frankfurt'],
    ),
  ],
  ruleProvider: [RuleProvider(name: 'ads')],
  subRules: [SubRule(name: 'streaming')],
);

OverrideData editorOverrideData({int rules = 3}) => OverrideData(
      enable: true,
      chains: const [
        ProxyChain(
          id: 'c1',
          name: 'Via Tokyo',
          hops: ['Tokyo', 'Frankfurt'],
        ),
        ProxyChain(id: 'c2', name: 'Draft', hops: ['Tokyo'], enable: false),
      ],
      rule: OverrideRule(
        addedRules: [
          for (var i = 0; i < rules; i++)
            Rule(id: 'r$i', value: 'DOMAIN-SUFFIX,example$i.com,Proxy'),
        ],
      ),
    );

/// [ProfileOverrideState] that starts from a fixed model instead of loading
/// the profile config from disk.
class FixedProfileOverrideState extends ProfileOverrideState {
  FixedProfileOverrideState(this.initial);

  final ProfileOverrideStateModel initial;

  @override
  ProfileOverrideStateModel build() => initial;
}

Override fixedOverrideState({
  OverrideData? data,
  Set<String> selected = const {},
}) =>
    profileOverrideStateProvider.overrideWith(
      () => FixedProfileOverrideState(
        ProfileOverrideStateModel(
          snippet: editorSnippet,
          overrideData: data ?? editorOverrideData(),
          selectedRules: selected,
        ),
      ),
    );

/// The sections of `OverrideProfileView` (switch, chains, rules) in the same
/// order and paddings as its `_buildContent`, without the disk loading.
class OverrideSections extends StatelessWidget {
  const OverrideSections({super.key, this.maxWidth = 296});

  final double maxWidth;

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: OverrideSwitch()),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: ChainTitle(profileId: editorProfileId),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: ChainContent(profileId: editorProfileId),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: RuleTitle(profileId: editorProfileId),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: RuleContent(maxWidth: maxWidth),
          ),
        ],
      );
}

/// Points `path_provider` at [dir] and writes the profile file of
/// [editorProfileId], so the edit view shows its file row.
Future<void> mockProfileFiles(Directory dir) async {
  final profiles = Directory('${dir.path}/profiles');
  await profiles.create(recursive: true);
  await File('${profiles.path}/$editorProfileId.yaml')
      .writeAsString('mixed-port: 7890\n');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );
  // Resolve the app directories here, outside any test's fake-async zone:
  // the first test to touch `appPath` would otherwise own its completers.
  await appPath.getProfilePath(editorProfileId);
}

/// The edit view reads the profile file with real I/O, so fake time alone
/// never delivers it. Waits until the file row (`size  ·  just now`) shows.
Future<void> waitForProfileFileRow(WidgetTester tester) async {
  final row = find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.contains('  ·  ') ?? false),
  );
  for (var i = 0; i < 100 && row.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(row, findsOneWidget);
  await tester.pumpAndSettle();
}
