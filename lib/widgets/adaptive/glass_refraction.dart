import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'adaptive_platform.dart';

/// A lens over one cell of a pane split into equal columns, such as the
/// selected tab of the tab bar. Lengths are logical px.
@immutable
class GlassRefractionSegment {
  const GlassRefractionSegment({
    required this.index,
    required this.count,
    required this.inset,
    required this.radius,
    required this.bevel,
    required this.depth,
    this.dispersion = 0,
  });

  final int index;
  final int count;

  /// Padding between the pane edge and its cells.
  final double inset;
  final double radius;
  final double bevel;
  final double depth;
  final double dispersion;

  /// The cell in the pane's local coordinates, or null when there is none.
  Rect? rectIn(Size size) {
    if (count <= 0 || index < 0 || index >= count) return null;
    final inner = (Offset.zero & size).deflate(inset);
    if (inner.width <= 0 || inner.height <= 0) return null;
    final width = inner.width / count;
    return Rect.fromLTWH(
      inner.left + width * index,
      inner.top,
      width,
      inner.height,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassRefractionSegment &&
      other.index == index &&
      other.count == count &&
      other.inset == inset &&
      other.radius == radius &&
      other.bevel == bevel &&
      other.depth == depth &&
      other.dispersion == dispersion;

  @override
  int get hashCode =>
      Object.hash(index, count, inset, radius, bevel, depth, dispersion);
}

/// Edge refraction of a glass pane (`shaders/glass_refraction.frag`): a
/// bevel of circular profile along the rim, so the backdrop looks squeezed
/// against the edge as through thick glass. Lengths are logical px.
@immutable
class GlassRefraction {
  const GlassRefraction({
    required this.bevel,
    required this.depth,
    this.dispersion = 0,
    this.segment,
  });

  /// How far in from the rim the bevel reaches.
  final double bevel;

  /// How far in the outermost band reads from.
  final double depth;

  /// How far red and blue part at the rim.
  final double dispersion;

  /// An optional inner lens, e.g. the selected tab.
  final GlassRefractionSegment? segment;

  @override
  bool operator ==(Object other) =>
      other is GlassRefraction &&
      other.bevel == bevel &&
      other.depth == depth &&
      other.dispersion == dispersion &&
      other.segment == segment;

  @override
  int get hashCode => Object.hash(bevel, depth, dispersion, segment);
}

/// Loads the refraction shader once and tells whether it can run.
abstract final class GlassRefractionShader {
  static const String asset = 'shaders/glass_refraction.frag';

  /// Floats the shader declares; the first two (`uSize`) belong to the engine.
  static const int floatCount = 2 + uniformCount;

  /// Floats written by [glassRefractionUniforms].
  static const int uniformCount = 16;

  /// Forces [supported] in tests; `null` asks the renderer.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Shader image filters need Impeller (iOS default); Skia, the test
  /// renderer and the kill switch keep the plain blur.
  static bool get supported =>
      GlassFlags.refractionEnabled &&
      (debugSupportedOverride ?? ui.ImageFilter.isShaderFilterSupported);

  static final ValueNotifier<ui.FragmentProgram?> _program =
      ValueNotifier<ui.FragmentProgram?>(null);
  static Future<void>? _loading;

  /// The program, null until it has loaded (and for good if loading failed).
  /// Reading it starts the load.
  static ValueListenable<ui.FragmentProgram?> get program {
    _loading ??= _load();
    return _program;
  }

  static Future<void> _load() async {
    try {
      _program.value = await ui.FragmentProgram.fromAsset(asset);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'adaptive glass',
        context: ErrorDescription('while loading $asset'),
      ));
    }
  }
}

/// Uniforms of `glass_refraction.frag` after the engine's `uSize`, in
/// physical px: pane rect, pane shape, lens rect, lens shape.
///
/// [paneRect] is the pane in global logical coordinates and [paneSize] its
/// local size; their ratio carries any scale of the ancestors.
@visibleForTesting
List<double> glassRefractionUniforms({
  required Rect paneRect,
  required Size paneSize,
  required double devicePixelRatio,
  required double radius,
  required GlassRefraction refraction,
}) {
  final scaleX = paneSize.width > 0 ? paneRect.width / paneSize.width : 1.0;
  final scaleY = paneSize.height > 0 ? paneRect.height / paneSize.height : 1.0;
  final scale = devicePixelRatio * math.min(scaleX, scaleY);
  final dpr = devicePixelRatio;
  final values = <double>[
    paneRect.left * dpr,
    paneRect.top * dpr,
    paneRect.width * dpr,
    paneRect.height * dpr,
    radius * scale,
    refraction.bevel * scale,
    refraction.depth * scale,
    refraction.dispersion * scale,
  ];
  final segment = refraction.segment;
  final cell = segment?.rectIn(paneSize);
  if (segment == null || cell == null) {
    values.addAll(List<double>.filled(8, 0));
  } else {
    values.addAll([
      (paneRect.left + cell.left * scaleX) * dpr,
      (paneRect.top + cell.top * scaleY) * dpr,
      cell.width * scaleX * dpr,
      cell.height * scaleY * dpr,
      segment.radius * scale,
      segment.bevel * scale,
      segment.depth * scale,
      segment.dispersion * scale,
    ]);
  }
  assert(
    values.length == GlassRefractionShader.uniformCount,
    'glass_refraction.frag expects ${GlassRefractionShader.uniformCount} '
    'uniforms after uSize',
  );
  return values;
}

/// One `BackdropFilterLayer` that blurs the backdrop and then refracts it
/// along the rim: `ImageFilter.compose(outer: shader, inner: blur)`.
///
/// Used by `GlassSurface` only when [GlassRefractionShader.supported]; with
/// no [program] yet it is the same plain blur. The pane's screen position is
/// read when it paints, so an ancestor that only moves the composited layer
/// (a route transition) leaves the lens offset until the next paint.
class GlassRefractionBackdrop extends SingleChildRenderObjectWidget {
  const GlassRefractionBackdrop({
    super.key,
    required this.program,
    required this.sigma,
    required this.radius,
    required this.refraction,
    required this.devicePixelRatio,
    super.child,
  });

  final ui.FragmentProgram? program;
  final double sigma;
  final double radius;
  final GlassRefraction refraction;
  final double devicePixelRatio;

  @override
  RenderGlassRefraction createRenderObject(BuildContext context) =>
      RenderGlassRefraction(
        program: program,
        sigma: sigma,
        radius: radius,
        refraction: refraction,
        devicePixelRatio: devicePixelRatio,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassRefraction renderObject,
  ) {
    renderObject
      ..program = program
      ..sigma = sigma
      ..radius = radius
      ..refraction = refraction
      ..devicePixelRatio = devicePixelRatio;
  }
}

class RenderGlassRefraction extends RenderProxyBox {
  RenderGlassRefraction({
    required ui.FragmentProgram? program,
    required double sigma,
    required double radius,
    required GlassRefraction refraction,
    required double devicePixelRatio,
  })  : _program = program,
        _sigma = sigma,
        _radius = radius,
        _refraction = refraction,
        _devicePixelRatio = devicePixelRatio;

  ui.FragmentProgram? get program => _program;
  ui.FragmentProgram? _program;
  set program(ui.FragmentProgram? value) {
    if (identical(value, _program)) return;
    _program = value;
    _invalidate();
  }

  double get sigma => _sigma;
  double _sigma;
  set sigma(double value) {
    if (value == _sigma) return;
    _sigma = value;
    _invalidate();
  }

  double get radius => _radius;
  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    _invalidate();
  }

  GlassRefraction get refraction => _refraction;
  GlassRefraction _refraction;
  set refraction(GlassRefraction value) {
    if (value == _refraction) return;
    _refraction = value;
    _invalidate();
  }

  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _invalidate();
  }

  ui.ImageFilter? _filter;
  List<double>? _uniforms;
  // Set once the renderer rejected the shader filter: plain blur from then on.
  bool _shaderFailed = false;

  void _invalidate() {
    _filter = null;
    _uniforms = null;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final backdrop = (layer ?? BackdropFilterLayer())
      ..filter = _resolveFilter();
    layer = backdrop;
    context.pushLayer(backdrop, super.paint, offset);
  }

  ui.ImageFilter _blur() => ui.ImageFilter.blur(
        sigmaX: _sigma,
        sigmaY: _sigma,
        tileMode: TileMode.clamp,
      );

  ui.ImageFilter _resolveFilter() {
    final program = _program;
    if (program == null || _shaderFailed || size.isEmpty) {
      return _filter ??= _blur();
    }
    final uniforms = glassRefractionUniforms(
      paneRect: MatrixUtils.transformRect(
        getTransformTo(null),
        Offset.zero & size,
      ),
      paneSize: size,
      devicePixelRatio: _devicePixelRatio,
      radius: _radius,
      refraction: _refraction,
    );
    final cached = _filter;
    if (cached != null && listEquals(uniforms, _uniforms)) return cached;
    _uniforms = uniforms;
    try {
      final shader = program.fragmentShader();
      for (var i = 0; i < uniforms.length; i++) {
        shader.setFloat(i + 2, uniforms[i]);
      }
      return _filter = ui.ImageFilter.compose(
        outer: ui.ImageFilter.shader(shader),
        inner: _blur(),
      );
    } catch (error, stack) {
      _shaderFailed = true;
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'adaptive glass',
        context: ErrorDescription('while building the refraction filter'),
      ));
      return _filter = _blur();
    }
  }
}
