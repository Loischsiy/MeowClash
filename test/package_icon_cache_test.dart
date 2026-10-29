import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/plugins/app.dart';
import 'package:meowclash/services/image_memory.dart';

/// Android connection rows ask [App.getPackageIcon] for the process icon on
/// every build (lib/views/connection/item.dart). One package must keep one
/// provider: a new [MemoryImage] is a new image cache key, so each row build
/// was a full decode and a single icon filled the cache. Cache entries and
/// bytes are printed for before/after comparison.

const _channel = MethodChannel('app');

Future<String> _pngBase64(int size) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return base64Encode(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // App is a singleton, so every test uses its own package names.
  final app = App();
  var calls = 0;
  Future<String?> Function(String packageName) answer = (_) async => null;

  setUp(() {
    calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method != 'getPackageIcon') return null;
      calls++;
      final arguments = call.arguments as Map;
      return answer(arguments['packageName'] as String);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('one provider and one channel call per package', () async {
    final icon = await _pngBase64(4);
    answer = (_) async => icon;
    final first = await app.getPackageIcon('com.example.one');
    expect(first, isNotNull);
    for (var build = 1; build < 200; build++) {
      expect(await app.getPackageIcon('com.example.one'), same(first));
    }
    expect(calls, 1);

    final other = await app.getPackageIcon('com.example.two');
    expect(other, isNotNull);
    expect(other, isNot(same(first)));
    expect(calls, 2);
  });

  test('builds that load at the same time share one provider', () async {
    final icon = await _pngBase64(4);
    answer = (_) async => icon;
    final results = await Future.wait([
      app.getPackageIcon('com.example.parallel'),
      app.getPackageIcon('com.example.parallel'),
    ]);
    expect(results.first, isNotNull);
    expect(results.last, same(results.first));
  });

  test('an empty or failed load is not cached and is retried', () async {
    final icon = await _pngBase64(4);
    answer = (_) async => null;
    expect(await app.getPackageIcon('com.example.retry'), isNull);
    answer = (_) async => throw PlatformException(code: 'error');
    await expectLater(
      app.getPackageIcon('com.example.retry'),
      throwsA(isA<PlatformException>()),
    );
    answer = (_) async => icon;
    expect(await app.getPackageIcon('com.example.retry'), isNotNull);
    expect(calls, 3);
  });

  testWidgets('row builds keep one image cache entry per icon', (tester) async {
    configureUiImageCache(imageCache);
    imageCache
      ..clear()
      ..clearLiveImages();
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final icon = (await tester.runAsync(() => _pngBase64(324)))!;
    answer = (_) async => icon;
    const builds = 200;
    for (var build = 0; build < builds; build++) {
      await tester.runAsync(() async {
        final provider = await app.getPackageIcon('com.example.cache');
        // The row decodes at 48 dp; 3.0 is a common phone pixel ratio.
        await precacheImage(
          ResizeImage.resizeIfNeeded(144, null, provider!),
          context,
        );
      });
    }
    // ignore: avoid_print
    print('324 px icon, $builds row builds: '
        'image cache entries ${imageCache.currentSize}, '
        'bytes ${imageCache.currentSizeBytes}, channel calls $calls');
    expect(imageCache.currentSize, 1);
    expect(imageCache.currentSizeBytes, 144 * 144 * 4);
    imageCache.clear();
  });
}
