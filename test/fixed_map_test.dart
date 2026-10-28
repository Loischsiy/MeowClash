import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/common.dart';

/// The pre-optimization eviction: rebuild the map from its truncated entry
/// list. [FixedMap] must keep exactly these keys in this order.
class _CopyingFixedMap {
  _CopyingFixedMap(this.maxLength);

  int maxLength;
  Map<String, int> _map = {};

  int? updateCacheValue(String key, int Function() callback) {
    final value = _map.updateCacheValue(key, callback);
    _adjust();
    return value;
  }

  void updateMaxLength(int size) {
    maxLength = size;
    _adjust();
  }

  void _adjust() {
    if (_map.length > maxLength) {
      _map = Map.fromEntries(_map.entries.toList()..truncate(maxLength));
    }
  }

  Map<String, int> get map => _map;
}

FixedMap<String, int> _filled(int maxLength, Iterable<String> keys) {
  final map = FixedMap<String, int>(maxLength);
  var i = 0;
  for (final key in keys) {
    map.updateCacheValue(key, () => i++);
  }
  return map;
}

void main() {
  test('evicts the oldest entries first', () {
    final map = _filled(3, ['a', 'b', 'c', 'd', 'e']);
    expect(map.length, 3);
    expect(map.map.keys, ['c', 'd', 'e']);
    expect(map.containsKey('a'), isFalse);
    expect(map.get('e'), 4);
  });

  test('a hit returns the cached value and does not refresh its age', () {
    final map = _filled(3, ['a', 'b', 'c']);
    var calls = 0;
    expect(map.updateCacheValue('a', () => ++calls), 0);
    expect(calls, 0);
    map.updateCacheValue('d', () => 9);
    // Insertion order, not LRU: "a" is still the oldest.
    expect(map.map.keys, ['b', 'c', 'd']);
  });

  test('the value of a new key is returned even when it overflows', () {
    final map = _filled(2, ['a', 'b']);
    expect(map.updateCacheValue('c', () => 7), 7);
    expect(map.map, {'b': 1, 'c': 7});
  });

  test('maxLength can shrink and grow', () {
    final map = _filled(5, ['a', 'b', 'c', 'd', 'e'])..updateMaxLength(2);
    expect(map.maxLength, 2);
    expect(map.map.keys, ['d', 'e']);

    map.updateMaxLength(4);
    expect(map.length, 2);
    map
      ..updateCacheValue('f', () => 5)
      ..updateCacheValue('g', () => 6);
    expect(map.map.keys, ['d', 'e', 'f', 'g']);
    map.updateCacheValue('h', () => 7);
    expect(map.map.keys, ['e', 'f', 'g', 'h']);
  });

  test('the same maxLength keeps every entry', () {
    final map = _filled(3, ['a', 'b', 'c']);
    for (var i = 0; i < 10; i++) {
      map.updateMaxLength(3);
    }
    expect(map.map.keys, ['a', 'b', 'c']);
  });

  test('maxLength 0 keeps nothing', () {
    final map = _filled(3, ['a', 'b', 'c'])..updateMaxLength(0);
    expect(map.length, 0);
  });

  test('clear', () {
    final map = _filled(3, ['a', 'b', 'c'])..clear();
    expect(map.length, 0);
    expect(map.containsKey('a'), isFalse);
    map.updateCacheValue('d', () => 1);
    expect(map.map, {'d': 1});
  });

  test('updateMap keeps the newest maxLength entries', () {
    final map = FixedMap<String, int>(2)
      ..updateMap({'a': 1, 'b': 2, 'c': 3});
    expect(map.map, {'b': 2, 'c': 3});
    map.updateCacheValue('d', () => 4);
    expect(map.map, {'c': 3, 'd': 4});
  });

  test('map is an unmodifiable snapshot', () {
    final map = _filled(3, ['a', 'b']);
    final snapshot = map.map;
    expect(() => snapshot['x'] = 1, throwsUnsupportedError);
    map.updateCacheValue('c', () => 2);
    expect(snapshot.keys, ['a', 'b']);
  });

  test('matches the copying eviction on random operations', () {
    final random = Random(42);
    final map = FixedMap<String, int>(8);
    final reference = _CopyingFixedMap(8);
    for (var i = 0; i < 5000; i++) {
      if (random.nextInt(10) == 0) {
        final size = 1 + random.nextInt(16);
        map.updateMaxLength(size);
        reference.updateMaxLength(size);
      } else {
        final key = 'k${random.nextInt(40)}';
        expect(
          map.updateCacheValue(key, () => i),
          reference.updateCacheValue(key, () => i),
        );
      }
      expect(map.map.entries.map((e) => (e.key, e.value)).toList(),
          reference.map.entries.map((e) => (e.key, e.value)).toList());
    }
  });
}
