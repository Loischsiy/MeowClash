import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_tokens.dart';

/// Continuous slider.
///
/// * iOS: `CupertinoSlider` in the accent.
/// * macOS: the thin AppKit track with a small white knob, no ink overlay.
/// * Everything else: Material `Slider`, unchanged.
///
/// Content, so never blurred.
class AdaptiveSlider extends StatelessWidget {
  const AdaptiveSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;

  /// `null` disables the slider.
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!AdaptivePlatform.useGlass) {
      return Slider(value: value, min: min, max: max, onChanged: onChanged);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return CupertinoSlider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        activeColor: scheme.primary,
      );
    }
    final track = scheme.onSurface.withValues(
      alpha: GlassTokens.sliderTrackOpacity(theme.brightness),
    );
    final disabled =
        scheme.onSurface.withValues(alpha: GlassTokens.disabledOpacity);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: GlassTokens.sliderTrackHeightMac,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: track,
        disabledActiveTrackColor: disabled,
        disabledInactiveTrackColor: track,
        thumbColor: CupertinoColors.white,
        disabledThumbColor: CupertinoColors.white,
        trackShape: const RoundedRectSliderTrackShape(),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: GlassTokens.sliderThumbRadiusMac,
          disabledThumbRadius: GlassTokens.sliderThumbRadiusMac,
          elevation: GlassTokens.sliderThumbElevationMac,
          pressedElevation: GlassTokens.sliderThumbElevationMac,
        ),
        overlayShape: SliderComponentShape.noOverlay,
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}
