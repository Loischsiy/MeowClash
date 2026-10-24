#version 460 core

// Edge refraction of the iOS glass tab bar (lib/widgets/adaptive/glass_refraction.dart).
//
// Runs as the outer half of ImageFilter.compose(outer: shader, inner: blur)
// inside one BackdropFilter, so uTexture already holds the blurred backdrop.
// In that mode FlutterFragCoord() and the texture are in physical screen
// pixels. The shader only moves where each pixel reads from: tint, rim and
// shadow are painted by GlassSurface in Flutter.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Set by the engine: size of the bound texture.
uniform vec2 uSize;
// The glass pane in physical px: left, top, width, height.
uniform vec4 uRect;
// Corner radius, bevel width, depth and color parting, all in physical px.
uniform vec4 uShape;
// An optional inner lens (the selected tab), as uRect.
uniform vec4 uLensRect;
// As uShape; a depth of 0 turns the lens off.
uniform vec4 uLensShape;
uniform sampler2D uTexture;

out vec4 fragColor;

// Signed distance to a rounded box centered at the origin; negative inside.
float boxDistance(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Outward normal of the same box.
vec2 boxNormal(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  vec2 n = (q.x > 0.0 && q.y > 0.0)
      ? normalize(q)
      : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
  return n * vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
}

// Where a bevel of circular profile sends a pixel: flat a bevel in from the
// rim, steepening toward it, so the outermost band reads from further inside
// and shows the backdrop squeezed against the edge. `rise` is 0 on the flat
// face and 1 at the rim.
vec2 bevelShift(vec2 point, vec4 rect, vec4 shape, out float rise) {
  rise = 0.0;
  vec2 halfSize = rect.zw * 0.5;
  if (halfSize.x <= 0.0 || halfSize.y <= 0.0 || shape.z <= 0.0) {
    return vec2(0.0);
  }
  vec2 p = point - (rect.xy + halfSize);
  float radius = clamp(shape.x, 0.0, min(halfSize.x, halfSize.y));
  float inset = -boxDistance(p, halfSize, radius);
  float bevel = max(min(shape.y, min(halfSize.x, halfSize.y)), 1e-3);
  if (inset <= 0.0 || inset >= bevel) {
    return vec2(0.0);
  }
  rise = 1.0 - inset / bevel;
  float depth = shape.z * (1.0 - sqrt(1.0 - rise * rise));
  return -boxNormal(p, halfSize, radius) * depth;
}

vec4 sampleAt(vec2 pixel) {
  vec2 uv = clamp(pixel, vec2(0.5), uSize - 0.5) / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv);
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  float rise;
  vec2 shift = bevelShift(point, uRect, uShape, rise);
  float parting = uShape.w;
  if (uLensShape.z > 0.0) {
    float lensRise;
    vec2 lensShift = bevelShift(point, uLensRect, uLensShape, lensRise);
    if (lensRise > rise) {
      parting = uLensShape.w;
      rise = lensRise;
    }
    shift += lensShift;
  }
  if (rise <= 0.0) {
    fragColor = sampleAt(point);
    return;
  }
  vec4 color = sampleAt(point + shift);
  float shiftLength = length(shift);
  if (parting > 0.0 && shiftLength > 1e-3) {
    // Red and blue part slightly along the normal near the rim, as thick
    // glass disperses light.
    vec2 part = shift / shiftLength * parting * rise;
    color.r = sampleAt(point + shift + part).r;
    color.b = sampleAt(point + shift - part).b;
  }
  fragColor = color;
}
