import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A damped spring sampled over a fixed [duration], the curve behind SwiftUI's
/// `.spring(response:dampingFraction:)` and UIKit's spring animations.
///
/// [response] is the period of the undamped spring in seconds and
/// [dampingFraction] its damping ratio (1 = critically damped, below 1 a small
/// overshoot). [duration] must be the length of the animation the curve drives
/// so the spring is evaluated in real time; choose it long enough for the
/// spring to settle (the curve snaps to exactly 1 at the end).
class GlassSpringCurve extends Curve {
  const GlassSpringCurve({
    required this.response,
    required this.dampingFraction,
    required this.duration,
  })  : assert(response > 0, 'response must be positive'),
        assert(dampingFraction > 0, 'dampingFraction must be positive');

  final double response;
  final double dampingFraction;
  final Duration duration;

  @override
  double transformInternal(double t) {
    final seconds =
        t * duration.inMicroseconds / Duration.microsecondsPerSecond;
    final omega = 2 * math.pi / response;
    final zeta = dampingFraction;
    if (zeta >= 1) {
      return 1 - math.exp(-omega * seconds) * (1 + omega * seconds);
    }
    final omegaD = omega * math.sqrt(1 - zeta * zeta);
    return 1 -
        math.exp(-zeta * omega * seconds) *
            (math.cos(omegaD * seconds) +
                zeta * omega / omegaD * math.sin(omegaD * seconds));
  }

  @override
  String toString() => 'GlassSpringCurve(response: $response, '
      'dampingFraction: $dampingFraction, duration: $duration)';
}
