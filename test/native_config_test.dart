import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/clash/native_config.dart';

class _TrackingAllocator implements Allocator {
  final live = <int>{};
  int frees = 0;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    final pointer = malloc.allocate<T>(byteCount, alignment: alignment);
    live.add(pointer.address);
    return pointer;
  }

  @override
  void free(Pointer pointer) {
    expect(live.remove(pointer.address), isTrue,
        reason: 'wrong owner/double free');
    frees++;
    malloc.free(pointer);
  }
}

void main() {
  for (final source in ['{"name":"Кот","proxies":[]}', '', '{broken', '[]']) {
    test('native config frees both allocations for $source', () {
      final input = _TrackingAllocator();
      final output = _TrackingAllocator();
      Map<String, dynamic> read() => readNativeConfig(
            '/profile/Кот.yaml',
            allocator: input,
            getConfig: (path) {
              expect(path.cast<Utf8>().toDartString(), '/profile/Кот.yaml');
              return source.toNativeUtf8(allocator: output).cast<Char>();
            },
            freeCString: output.free,
          );
      if (source == '{broken') {
        expect(read, throwsFormatException);
      } else if (source == '[]') {
        expect(read, throwsA(isA<TypeError>()));
      } else {
        expect(read(), source.isEmpty ? isEmpty : containsPair('name', 'Кот'));
      }
      expect(input.live, isEmpty);
      expect(output.live, isEmpty);
      expect(input.frees, 1);
      expect(output.frees, 1);
    });
  }

  test('null core string does not call the core deallocator', () {
    final input = _TrackingAllocator();
    expect(
        readNativeConfig('missing',
            allocator: input,
            getConfig: (_) => nullptr,
            freeCString: (_) => fail('free(nullptr)')),
        isEmpty);
    expect(input.live, isEmpty);
    expect(input.frees, 1);
  });

  test('input is released when native invocation throws', () {
    final input = _TrackingAllocator();
    expect(
        () => readNativeConfig('profile',
            allocator: input,
            getConfig: (_) => throw StateError('native failure'),
            freeCString: (_) => fail('no returned allocation')),
        throwsStateError);
    expect(input.live, isEmpty);
    expect(input.frees, 1);
  });

  test('invalid UTF-8 still releases the returned buffer', () {
    final input = _TrackingAllocator();
    final output = _TrackingAllocator();
    expect(
        () => readNativeConfig('profile', allocator: input, getConfig: (_) {
              final pointer = output.allocate<Uint8>(2);
              pointer[0] = 255;
              pointer[1] = 0;
              return pointer.cast<Char>();
            }, freeCString: output.free),
        throwsFormatException);
    expect(input.live, isEmpty);
    expect(output.live, isEmpty);
  });
}
