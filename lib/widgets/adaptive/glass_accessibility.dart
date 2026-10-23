import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'adaptive_platform.dart';

/// System settings that change how the Darwin glass chrome renders.
@immutable
class GlassAccessibility {
  const GlassAccessibility({
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.accentColor,
  });

  factory GlassAccessibility.fromMap(Map<Object?, Object?> map) {
    final accent = map['accentColor'];
    return GlassAccessibility(
      // Increase Contrast makes Apple's own glass opaque too.
      reduceTransparency: map['reduceTransparency'] == true ||
          map['increaseContrast'] == true,
      reduceMotion: map['reduceMotion'] == true,
      accentColor: accent is int ? Color(accent) : null,
    );
  }

  static const fallback = GlassAccessibility();

  /// macOS `accessibilityDisplayShouldReduceTransparency`, iOS
  /// `UIAccessibility.isReduceTransparencyEnabled`, or Increase Contrast on
  /// either OS. Glass falls back to opaque surfaces when set.
  final bool reduceTransparency;

  /// macOS `accessibilityDisplayShouldReduceMotion`, iOS
  /// `UIAccessibility.isReduceMotionEnabled`. Animated glass transitions are
  /// disabled when set.
  final bool reduceMotion;

  /// The system accent (macOS `NSColor.controlAccentColor`). `null` means the
  /// system leaves the choice to the app (macOS "Multicolor", or iOS, which has
  /// no user accent for third-party apps).
  final Color? accentColor;

  /// Whether glass surfaces should skip `BackdropFilter` and paint opaque.
  bool get opaque => reduceTransparency || !GlassFlags.backdropBlurEnabled;

  GlassAccessibility copyWith({
    bool? reduceTransparency,
    bool? reduceMotion,
  }) =>
      GlassAccessibility(
        reduceTransparency: reduceTransparency ?? this.reduceTransparency,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        accentColor: accentColor,
      );

  /// Reads the nearest [GlassAccessibilityScope], merged with Flutter's own
  /// accessibility features: "Increase Contrast" also makes glass opaque, as
  /// it does in Apple's apps, and `disableAnimations` implies reduced motion.
  static GlassAccessibility of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_GlassAccessibilityInherited>();
    final base = scope?.notifier?.value ?? fallback;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!highContrast && !disableAnimations) return base;
    return base.copyWith(
      reduceTransparency: base.reduceTransparency || highContrast,
      reduceMotion: base.reduceMotion || disableAnimations,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassAccessibility &&
      other.reduceTransparency == reduceTransparency &&
      other.reduceMotion == reduceMotion &&
      other.accentColor == accentColor;

  @override
  int get hashCode => Object.hash(reduceTransparency, reduceMotion, accentColor);

  @override
  String toString() => 'GlassAccessibility(reduceTransparency: '
      '$reduceTransparency, reduceMotion: $reduceMotion, accent: $accentColor)';
}

/// Mirrors the native accessibility/appearance state over
/// `meowclash/glass_accessibility`.
///
/// The native side answers `snapshot` with a map and pushes `changed` with the
/// same map whenever the user flips a setting. Off Darwin, or with an older
/// native runner, the controller keeps [GlassAccessibility.fallback].
class GlassAccessibilityController extends ValueNotifier<GlassAccessibility> {
  GlassAccessibilityController() : super(GlassAccessibility.fallback);

  static const channel = MethodChannel('meowclash/glass_accessibility');

  bool _started = false;

  Future<void> start() async {
    if (_started || !AdaptivePlatform.useGlass) return;
    _started = true;
    // Listen before asking for the snapshot so a change made during startup
    // cannot be lost.
    channel.setMethodCallHandler(_handle);
    try {
      final map = await channel.invokeMapMethod<Object?, Object?>('snapshot');
      if (map != null && _started) value = GlassAccessibility.fromMap(map);
    } on MissingPluginException {
      // Hot reload onto an older runner: keep the fallback.
    } on PlatformException {
      // Native side failed to read the settings: keep the fallback.
    }
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method == 'changed' && call.arguments is Map) {
      value = GlassAccessibility.fromMap(call.arguments as Map);
    }
    return null;
  }

  @override
  void dispose() {
    if (_started) channel.setMethodCallHandler(null);
    _started = false;
    super.dispose();
  }
}

/// Provides [GlassAccessibility] to the subtree. Place it above `MaterialApp`
/// so the Darwin theme can use the system accent.
class GlassAccessibilityScope extends StatefulWidget {
  const GlassAccessibilityScope({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;

  /// Injected in tests; otherwise the scope owns and starts its own.
  final GlassAccessibilityController? controller;

  @override
  State<GlassAccessibilityScope> createState() =>
      _GlassAccessibilityScopeState();
}

class _GlassAccessibilityScopeState extends State<GlassAccessibilityScope> {
  late final GlassAccessibilityController _controller;
  late final bool _owned;

  @override
  void initState() {
    super.initState();
    _owned = widget.controller == null;
    _controller = widget.controller ?? GlassAccessibilityController();
    if (_owned) unawaited(_controller.start());
  }

  @override
  void dispose() {
    if (_owned) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GlassAccessibilityInherited(
        notifier: _controller,
        child: widget.child,
      );
}

class _GlassAccessibilityInherited
    extends InheritedNotifier<GlassAccessibilityController> {
  const _GlassAccessibilityInherited({
    required super.notifier,
    required super.child,
  });
}
