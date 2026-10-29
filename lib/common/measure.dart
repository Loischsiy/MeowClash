import 'package:meowclash/common/common.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Measure {

  Measure.of(this.context, double textScaleFactor)
      : _measureMap = {},
        _styleHeights = {},
        _textScaler = TextScaler.linear(
          textScaleFactor,
        );
  final TextScaler _textScaler;
  final BuildContext context;
  final Map<String, double> _measureMap;
  final Map<TextStyle, double> _styleHeights;

  /// Height of one line of [style], cached per style.
  double heightOf(TextStyle style) => _styleHeights.putIfAbsent(
        style,
        () => computeTextSize(Text("X", style: style)).height,
      );

  Size computeTextSize(
    Text text, {
    double maxWidth = double.infinity,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text.data,
        style: text.style,
      ),
      maxLines: text.maxLines,
      textScaler: _textScaler,
      textDirection: text.textDirection ?? TextDirection.ltr,
    );
    try {
      textPainter.layout(
        maxWidth: maxWidth,
      );
      return textPainter.size;
    } finally {
      // Free the native paragraph now, not at a later GC finalizer.
      textPainter.dispose();
    }
  }

  double get bodyMediumHeight => _measureMap.updateCacheValue(
        "bodyMediumHeight",
        () => computeTextSize(
          Text(
            "X",
            style: context.textTheme.bodyMedium,
          ),
        ).height,
      )!;

  double get bodyLargeHeight => _measureMap.updateCacheValue(
        "bodyLargeHeight",
        () => computeTextSize(
          Text(
            "X",
            style: context.textTheme.bodyLarge,
          ),
        ).height,
      )!;

  double get bodySmallHeight => _measureMap.updateCacheValue(
        "bodySmallHeight",
        () => computeTextSize(
          Text(
            "X",
            style: context.textTheme.bodySmall,
          ),
        ).height,
      )!;

  double get labelSmallHeight => _measureMap.updateCacheValue(
        "labelSmallHeight",
        () => computeTextSize(
          Text(
            "X",
            style: context.textTheme.labelSmall,
          ),
        ).height,
      )!;

  double get labelMediumHeight => _measureMap.updateCacheValue(
        "labelMediumHeight",
        () => computeTextSize(
          Text(
            "X",
            style: context.textTheme.labelMedium,
          ),
        ).height,
      )!;

  double get titleLargeHeight => _measureMap.updateCacheValue(
        "titleLargeHeight",
        () => computeTextSize(
          Text(
            "X",
            style: context.textTheme.titleLarge,
          ),
        ).height,
      )!;

  double get titleMediumHeight => _measureMap.updateCacheValue(
        "titleMediumHeight",
        () => computeTextSize(
          Text(
            "X",
            style: context.textTheme.titleMedium,
          ),
        ).height,
      )!;
}
