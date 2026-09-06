import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/image_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decoded image cache has explicit byte and entry budgets', () {
    final cache = ImageCache();
    configureUiImageCache(cache);
    expect(cache.maximumSizeBytes, 32 * 1024 * 1024);
    expect(cache.maximumSize, 128);
  });

  test('background trim drops reusable entries but keeps live images tracked',
      () async {
    final cache = ImageCache();
    configureUiImageCache(cache);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    picture.dispose();
    final stream = cache.putIfAbsent(
        'visible-icon',
        () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image))))!;
    final listener = ImageStreamListener((info, _) => info.dispose());
    stream.addListener(listener);
    await Future<void>.delayed(Duration.zero);
    expect(cache.currentSize, 1);
    expect(cache.liveImageCount, 1);
    releaseUnusedUiImages(cache);
    expect(cache.currentSize, 0);
    expect(cache.currentSizeBytes, 0);
    expect(cache.liveImageCount, 1);
    stream.removeListener(listener);
    cache.clearLiveImages();
  });
}
