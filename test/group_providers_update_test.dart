import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/views/proxies/common.dart';

ExternalProvider _provider(
  String name, {
  String type = 'Proxy',
  String vehicleType = 'HTTP',
}) =>
    ExternalProvider(
      name: name,
      type: type,
      count: 1,
      vehicleType: vehicleType,
      updateAt: DateTime.utc(2026),
    );

Proxy _node(String name, [String? providerName]) => Proxy(
      name: name,
      type: 'Vless',
      providerName: providerName,
    );

void main() {
  group('groupUpdatableProviders', () {
    test('returns each HTTP provider of the group once, in member order', () {
      final group = Group(
        type: GroupType.URLTest,
        name: 'hidden-auto',
        hidden: true,
        all: [
          _node('b-1', 'sub-b'),
          _node('a-1', 'sub-a'),
          _node('b-2', 'sub-b'),
          _node('manual'),
          _node('empty', ''),
        ],
      );
      final result = groupUpdatableProviders(group, [
        _provider('sub-a'),
        _provider('sub-b'),
        _provider('unrelated'),
      ]);
      expect(result.map((provider) => provider.name), ['sub-b', 'sub-a']);
    });

    test('skips file providers, unknown providers and rule providers', () {
      final group = Group(
        type: GroupType.Selector,
        name: 'hidden-select',
        all: [
          _node('f-1', 'local'),
          _node('u-1', 'missing'),
          _node('s-1', 'shared'),
        ],
      );
      final result = groupUpdatableProviders(group, [
        _provider('local', vehicleType: 'File'),
        _provider('shared', type: 'Rule'),
      ]);
      expect(result, isEmpty);
    });

    test('prefers the proxy provider when a rule provider shares its name', () {
      final group = Group(
        type: GroupType.Selector,
        name: 'hidden-select',
        all: [_node('s-1', 'shared')],
      );
      final result = groupUpdatableProviders(group, [
        _provider('shared'),
        _provider('shared', type: 'Rule'),
      ]);
      expect(result.single.type, 'Proxy');
    });

    test('a group without provider nodes has nothing to update', () {
      final group = Group(
        type: GroupType.Selector,
        name: 'manual',
        all: [_node('a'), _node('b')],
      );
      expect(groupUpdatableProviders(group, [_provider('sub')]), isEmpty);
    });
  });
}
