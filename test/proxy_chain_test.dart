import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/models/profile.dart';

/// Unit tests for the proxy-chain feature.
///
/// Covers the [ProxyChain] model (defaults, id generation, JSON round-trip)
/// and [OverrideDataExt.buildRunningChainConfig], which clones exit hops into
/// proxy nodes carrying `dialer-proxy` and wraps them in `select` groups,
/// injected at runtime (see GlobalState.patchRawConfig).
void main() {
  group('ProxyChain', () {
    test('create() generates an id and sensible defaults', () {
      final chain = ProxyChain.create(name: 'My Chain');
      expect(chain.id, isNotEmpty);
      expect(chain.name, 'My Chain');
      expect(chain.hops, isEmpty);
      expect(chain.enable, isTrue);
    });

    test('create() produces unique ids', () {
      final a = ProxyChain.create();
      final b = ProxyChain.create();
      expect(a.id, isNot(equals(b.id)));
    });

    test('JSON round-trip preserves all fields', () {
      const chain = ProxyChain(
        id: 'abc',
        name: 'Relay',
        hops: ['Entry', 'Exit'],
        enable: false,
      );
      final restored = ProxyChain.fromJson(chain.toJson());
      expect(restored, chain);
    });
  });

  group('OverrideData chains', () {
    test('defaults to an empty chain list', () {
      const data = OverrideData();
      expect(data.chains, isEmpty);
      expect(data.enabledChains, isEmpty);
      final built = data.buildRunningChainConfig((_) => null);
      expect(built.proxies, isEmpty);
      expect(built.proxyGroups, isEmpty);
    });

    test('enabledChains keeps only enabled chains with >= 2 hops', () {
      const data = OverrideData(
        chains: [
          ProxyChain(id: '1', name: 'ok', hops: ['A', 'B']),
          ProxyChain(id: '2', name: 'disabled', hops: ['A', 'B'], enable: false),
          ProxyChain(id: '3', name: 'tooShort', hops: ['A']),
          ProxyChain(id: '4', name: 'empty', hops: []),
        ],
      );
      expect(data.enabledChains.map((c) => c.name), ['ok']);
    });

    test('buildRunningChainConfig clones exit hops with dialer-proxy', () {
      const data = OverrideData(
        chains: [
          // Entry is a group (resolver returns null for it, which is fine
          // since the entry is never cloned); exit is a concrete node.
          ProxyChain(id: '1', name: 'Chain1', hops: ['Auto', 'Exit']),
          // Three-hop chain: every hop after the entry must be a concrete node.
          ProxyChain(id: '2', name: 'Chain2', hops: ['A', 'B', 'C']),
          ProxyChain(id: '3', name: 'Off', hops: ['A', 'B'], enable: false),
        ],
      );
      // Resolver: concrete inline nodes by name; 'Auto' is a group (null).
      final defs = <String, Map<String, dynamic>>{
        'Exit': {'name': 'Exit', 'type': 'ss', 'server': 'exit.example'},
        'A': {'name': 'A', 'type': 'ss', 'server': 'a.example'},
        'B': {'name': 'B', 'type': 'ss', 'server': 'b.example'},
        'C': {'name': 'C', 'type': 'ss', 'server': 'c.example'},
      };
      final built = data.buildRunningChainConfig((name) => defs[name]);

      // Cloned nodes: Chain1 -> 1 (Exit); Chain2 -> 2 (B, C).
      expect(built.proxies.length, 3);
      // Chain1: the exit node is cloned and dials through the entry group.
      expect(built.proxies[0], {
        'name': 'Chain1 \u00b7 2',
        'type': 'ss',
        'server': 'exit.example',
        'dialer-proxy': 'Auto',
      });
      // Chain2: middle hop B dials through entry A...
      expect(built.proxies[1], {
        'name': 'Chain2 \u00b7 2',
        'type': 'ss',
        'server': 'b.example',
        'dialer-proxy': 'A',
      });
      // ...and exit hop C dials through the cloned middle node.
      expect(built.proxies[2], {
        'name': 'Chain2 \u00b7 3',
        'type': 'ss',
        'server': 'c.example',
        'dialer-proxy': 'Chain2 \u00b7 2',
      });

      // One select group per enabled chain, pointing at its exit clone.
      expect(built.proxyGroups.length, 2);
      expect(built.proxyGroups[0], {
        'name': 'Chain1',
        'type': 'select',
        'proxies': ['Chain1 \u00b7 2'],
      });
      expect(built.proxyGroups[1], {
        'name': 'Chain2',
        'type': 'select',
        'proxies': ['Chain2 \u00b7 3'],
      });
    });

    test('buildRunningChainConfig skips a chain with a non-node exit', () {
      const data = OverrideData(
        chains: [
          // Exit 'NL' is a group (resolver returns null) -> chain can't be
          // built because the exit can't carry dialer-proxy.
          ProxyChain(id: '1', name: 'Bad', hops: ['Auto', 'NL']),
          ProxyChain(id: '2', name: 'Good', hops: ['Auto', 'Exit']),
        ],
      );
      final defs = <String, Map<String, dynamic>>{
        'Exit': {'name': 'Exit', 'type': 'ss', 'server': 'exit.example'},
      };
      final built = data.buildRunningChainConfig((name) => defs[name]);
      expect(built.proxyGroups.map((g) => g['name']), ['Good']);
      expect(built.proxies.map((p) => p['name']), ['Good \u00b7 2']);
    });

    test('withChainSelectorMatch repoints the final MATCH', () {
      final rules = withChainSelectorMatch(
        ['DOMAIN-SUFFIX,cn,DIRECT', 'MATCH,Proxy'],
        'PROXY-CHAINS',
      );
      // Specific rules untouched; only the final MATCH target is rewritten.
      expect(rules, ['DOMAIN-SUFFIX,cn,DIRECT', 'MATCH,PROXY-CHAINS']);
    });

    test('withChainSelectorMatch appends MATCH when absent', () {
      final rules = withChainSelectorMatch(
        ['DOMAIN-SUFFIX,cn,DIRECT'],
        'PROXY-CHAINS',
      );
      expect(rules, ['DOMAIN-SUFFIX,cn,DIRECT', 'MATCH,PROXY-CHAINS']);
    });

    test('OverrideData JSON round-trip preserves chains', () {
      const data = OverrideData(
        enable: true,
        chains: [
          ProxyChain(id: '1', name: 'Chain1', hops: ['Entry', 'Exit']),
        ],
      );
      // Round-trip through an actual JSON string, mirroring how profiles are
      // persisted by the app. A direct fromJson(toJson()) fails here because
      // freezed's default toJson (explicitToJson: false) leaves the nested
      // OverrideRule as an object instead of a Map until it passes through
      // jsonEncode.
      final restored = OverrideData.fromJson(
        json.decode(json.encode(data)) as Map<String, dynamic>,
      );
      expect(restored.enable, isTrue);
      expect(restored.chains.length, 1);
      expect(restored.chains.first.name, 'Chain1');
      expect(restored.chains.first.hops, ['Entry', 'Exit']);
    });
  });
}
