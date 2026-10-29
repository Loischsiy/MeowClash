import 'constant.dart';
import 'iterable.dart';

/// Log and request buffer. Used at start-up and after a profile switch, so
/// both keep the same [maxLength] capacity.
FixedList<T> createEventBuffer<T>() => FixedList<T>(maxLength);

class FixedList<T> {

  FixedList(this.maxLength, {List<T>? list})
      : _list = (list ?? [])..truncate(maxLength);
  final int maxLength;
  final List<T> _list;

  void add(T item) {
    _list.add(item);
    _list.truncate(maxLength);
  }

  void clear() {
    _list.clear();
  }

  List<T> get list => List.unmodifiable(_list);

  int get length => _list.length;

  T operator [](int index) => _list[index];

  FixedList<T> copyWith() => FixedList(
      maxLength,
      list: _list,
    );
}

class FixedMap<K, V> {

  FixedMap(this.maxLength, {Map<K, V>? map}) {
    _map = map ?? {};
  }
  int maxLength;
  late Map<K, V> _map;

  V? updateCacheValue(K key, V Function() callback) {
    final realValue = _map.updateCacheValue(
      key,
      callback,
    );
    _evictOldest();
    return realValue;
  }

  void clear() {
    _map.clear();
  }

  void updateMaxLength(int size) {
    maxLength = size;
    _evictOldest();
  }

  void updateMap(Map<K, V> map) {
    // Copy only when trimming, so the caller's map is never mutated here.
    _map = map.length > maxLength ? Map.of(map) : map;
    _evictOldest();
  }

  // Insertion-ordered map: the first key is the oldest entry.
  void _evictOldest() {
    while (_map.length > maxLength) {
      _map.remove(_map.keys.first);
    }
  }

  V? get(K key) => _map[key];

  bool containsKey(K key) => _map.containsKey(key);

  int get length => _map.length;

  Map<K, V> get map => Map.unmodifiable(_map);
}
