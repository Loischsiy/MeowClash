import 'package:flutter/painting.dart';

/// A budget for decoded, reusable images, not a limit on total app/GPU memory.
/// Live images still displayed by widgets are deliberately left alone.
const uiImageCacheBytes = 32 * 1024 * 1024;
const uiImageCacheEntries = 128;

void configureUiImageCache(ImageCache cache) {
  cache
    ..maximumSizeBytes = uiImageCacheBytes
    ..maximumSize = uiImageCacheEntries;
}

/// Drop only reusable/pending cache entries when the UI is fully hidden.
/// Do not clearLiveImages: doing so can duplicate images still on screen.
void releaseUnusedUiImages(ImageCache cache) {
  cache.clear();
}
