import 'constant.dart';
import 'iterable.dart';

/// Log and request buffer. Used at start-up and after a profile switch, so
/// both keep the same [maxLength] capacity.
FixedList<T> createEventBuffer<T>() => FixedList<T>(maxLength);

/// Ring buffer that keeps the newest [maxLength] items, oldest first.
///
/// [copyWith] returns a new wrapper over the same storage: assigning it to a
/// Riverpod state notifies, and every wrapper sees the same items. [version]
/// changes on every [add] and [clear] and never repeats across buffers. Since
/// wrappers share it, watch it with `select((s) => s.version)` rather than
/// comparing two wrappers. [list] is an unmodifiable snapshot cached per
/// version.
class FixedList<T> {
  /// Copies the newest [maxLength] items of [list]; [list] is not kept.
  FixedList(this.maxLength, {List<T>? list})
      : assert(maxLength > 0, 'FixedList needs a positive maxLength'),
        _ring = _Ring<T>(maxLength, list);

  FixedList._(this.maxLength, this._ring);

  final int maxLength;
  final _Ring<T> _ring;

  void add(T item) => _ring.add(item);

  void clear() => _ring.clear();

  int get version => _ring.version;

  List<T> get list => _ring.snapshot;

  int get length => _ring.items.length;

  T operator [](int index) => _ring.at(index);

  FixedList<T> copyWith() => FixedList._(maxLength, _ring);
}

// Shared by every buffer, so a new buffer never reuses an old version.
int _versionClock = 0;

class _Ring<T> {
  _Ring(this.capacity, List<T>? initial)
      : items = initial == null
            ? <T>[]
            : List<T>.of(initial.skip(
                initial.length > capacity ? initial.length - capacity : 0,
              ));

  final int capacity;

  // Grows up to [capacity], then is overwritten in place from [head].
  final List<T> items;

  // Index of the oldest item once the ring is full, otherwise 0.
  int head = 0;

  int version = ++_versionClock;

  List<T>? _snapshot;

  void add(T item) {
    if (items.length < capacity) {
      items.add(item);
    } else if (items.isNotEmpty) {
      items[head] = item;
      head = head + 1 == items.length ? 0 : head + 1;
    }
    _changed();
  }

  void clear() {
    items.clear();
    head = 0;
    _changed();
  }

  void _changed() {
    version = ++_versionClock;
    _snapshot = null;
  }

  T at(int index) {
    IndexError.check(index, items.length, indexable: this, name: 'index');
    final i = head + index;
    return items[i < items.length ? i : i - items.length];
  }

  List<T> get snapshot => _snapshot ??= List<T>.unmodifiable(
        head == 0 ? items : items.skip(head).followedBy(items.take(head)),
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
