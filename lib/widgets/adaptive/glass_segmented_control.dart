import 'package:flutter/material.dart';

import 'adaptive_platform.dart';
import 'glass_accessibility.dart';
import 'glass_text_styles.dart';
import 'glass_tokens.dart';

/// An Apple segmented control (Darwin only): a recessed capsule track and a
/// neutral raised thumb that slides to the chosen segment, as in System
/// Settings — the thumb never takes the accent or a per-value color.
///
/// No blur: it sits inside dashboard tiles that scroll. Reduce Motion makes
/// the thumb jump; labels scale down instead of overflowing at large text.
/// Material screens keep `CommonTabBar`.
class GlassSegmentedControl<T extends Object> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.segments,
    required this.groupValue,
    required this.onValueChanged,
    this.large = false,
  });

  /// Values in display order with their labels.
  final Map<T, String> segments;
  final T groupValue;
  final ValueChanged<T> onValueChanged;

  /// The taller variant that fills a dashboard tile.
  final bool large;

  double get _height {
    final mac = AdaptivePlatform.isMacOSGlass;
    if (large) {
      return mac
          ? GlassTokens.segmentedLargeHeightMac
          : GlassTokens.segmentedLargeHeightIos;
    }
    return mac
        ? GlassTokens.segmentedHeightMac
        : GlassTokens.segmentedHeightIos;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final reduceMotion = GlassAccessibility.of(context).reduceMotion;
    final values = segments.keys.toList(growable: false);
    final selectedIndex = values.indexOf(groupValue);
    final height = _height;
    const inset = GlassTokens.segmentedInset;
    final thumbHeight = height - inset * 2;
    final duration = GlassTokens.motion(
      GlassTokens.segmentedDuration,
      reduceMotion: reduceMotion,
    );

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: GlassTokens.segmentedTrack(brightness),
          shape: const StadiumBorder(),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth =
                (constraints.maxWidth - inset * 2) / values.length;
            return Stack(
              children: [
                if (selectedIndex >= 0)
                  AnimatedPositioned(
                    duration: duration,
                    curve: GlassTokens.segmentedCurve,
                    left: inset + segmentWidth * selectedIndex,
                    top: inset,
                    width: segmentWidth,
                    height: thumbHeight,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: GlassTokens.segmentedThumb(brightness),
                        shape: const StadiumBorder(),
                        shadows: GlassTokens.segmentedThumbShadow(brightness),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(inset),
                  child: Row(
                    children: [
                      for (final value in values)
                        Expanded(
                          child: _Segment(
                            label: segments[value]!,
                            selected: value == groupValue,
                            onTap: () {
                              if (value != groupValue) onValueChanged(value);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: FocusableActionDetector(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GlassTokens.segmentedInset * 2,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GlassTextStyles.segment(
                    theme.textTheme,
                    selected: selected,
                  ).copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
