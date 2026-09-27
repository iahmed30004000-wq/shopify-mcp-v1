// ---------------------------------------------------------------------------
// Madar orbit shader library (included by every orbit shader).
//
// Noise comes from uNoise: a 256×256 RGBA texture generated in Dart
// (lib/features/orbit/render/noise_texture.dart). Its content is periodic with
// period 255 (row/column 255 duplicate 0) so linear filtering never shows a
// seam even though Flutter samplers clamp to edge. Channel layout follows the
// classic "two-slice" trick: G(x, y) = R(x - 37, y - 17), so one bilinear
// fetch yields the two z-slices needed for 3D value noise.
//
// SkSL compatibility (required for widget-test screenshots and Skia fallback):
// samplers can NOT be passed as function parameters, so the library owns the
// single global noise sampler below. Declare shader float uniforms AFTER the
// include; the noise sampler is always sampler index 0.
// ---------------------------------------------------------------------------

uniform sampler2D uNoise;

#define PI 3.14159265359
#define TAU 6.28318530718

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec3 saturate3(vec3 x) { return clamp(x, 0.0, 1.0); }

// --- hashes (ALU) ----------------------------------------------------------
float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}
vec3 hash33(vec3 p3) {
  p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// --- texture value noise ---------------------------------------------------
vec2 _noiseUv(vec2 cell) { return (mod(cell, 255.0) + 0.5) / 256.0; }

// 3D value noise in [0, 1].
float noise3(vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  vec2 cell = p.xy + vec2(37.0, 17.0) * p.z;
  vec2 rg = texture(uNoise, _noiseUv(cell) + f.xy / 256.0).yx;
  return mix(rg.x, rg.y, f.z);
}

// 2D value noise in [0, 1].
float noise2(vec2 x) {
  vec2 p = floor(x);
  vec2 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return texture(uNoise, _noiseUv(p) + f / 256.0).x;
}

// Fractal Brownian motion (octaves are compile-time constants for unrolling).
float fbm3(vec3 p) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 5; i++) {
    s += a * noise3(p);
    p = p * 2.03 + vec3(1.7, 9.2, 3.1);
    a *= 0.5;
  }
  return s / 0.96875;
}
float fbm3lo(vec3 p) {
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 3; i++) {
    s += a * noise3(p);
    p = p * 2.07 + vec3(4.3, 1.1, 7.7);
    a *= 0.5;
  }
  return s / 0.875;
}
// Ridged multifractal (mountain ridges, lava rivers, veins) in [0, 1].
float ridged3(vec3 p) {
  float a = 0.5, s = 0.0, w = 1.0;
  for (int i = 0; i < 4; i++) {
    float n = 1.0 - abs(noise3(p) * 2.0 - 1.0);
    n *= n * w;
    w = saturate(n * 2.0);
    s += n * a;
    p = p * 2.11 + vec3(2.9, 5.3, 1.3);
    a *= 0.5;
  }
  return saturate(s / 0.9375);
}

// 3D cellular noise: x = distance to nearest feature, y = to second nearest.
vec2 voronoi3(vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  float d1 = 8.0, d2 = 8.0;
  for (int k = -1; k <= 1; k++)
  for (int j = -1; j <= 1; j++)
  for (int i = -1; i <= 1; i++) {
    vec3 b = vec3(float(i), float(j), float(k));
    vec3 r = b - f + hash33(p + b);
    float d = dot(r, r);
    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
  }
  return sqrt(vec2(d1, d2));
}

// --- rotations -------------------------------------------------------------
mat3 rotY(float a) { float c = cos(a), s = sin(a); return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c); }
mat3 rotX(float a) { float c = cos(a), s = sin(a); return mat3(1.0, 0.0, 0.0, 0.0, c, s, 0.0, -s, c); }
mat3 rotZ(float a) { float c = cos(a), s = sin(a); return mat3(c, s, 0.0, -s, c, 0.0, 0.0, 0.0, 1.0); }

// --- colour ------------------------------------------------------------------
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 desaturate(vec3 c, float amount) { return mix(c, vec3(luma(c)), amount); }

// Narkowicz ACES filmic approximation (input linear, output display-ready).
vec3 tonemapACES(vec3 x) {
  const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
  return saturate3((x * (a * x + b)) / (x * (c * x + d) + e));
}
vec3 toLinear(vec3 c) { return pow(c, vec3(2.2)); }
vec3 toGamma(vec3 c) { return pow(max(c, 0.0), vec3(1.0 / 2.2)); }

// Tiny ordered dither to kill gradient banding on 8-bit targets.
vec3 dither(vec2 fragCoord, vec3 c) {
  float n = hash12(fragCoord) - 0.5;
  return c + n / 255.0;
}

// --- sphere impostor ---------------------------------------------------------
// Given the fragment position relative to the planet centre in units of the
// planet's screen radius (p, |p| <= 1 on the disc), returns the view-space
// normal of an orthographic sphere (z towards the viewer).
vec3 sphereNormal(vec2 p) {
  float z = sqrt(max(0.0, 1.0 - dot(p, p)));
  return vec3(p.x, p.y, z);
}

// Soft disc coverage with ~1.5px antialiasing; pxPerUnit = planet radius in px.
float discMask(vec2 p, float pxPerUnit) {
  float r = length(p);
  return saturate((1.0 - r) * pxPerUnit / 1.5 + 0.5);
}

// Rim-lit atmosphere: thickness grows toward the limb, brighter on the day side.
// p: position in planet radii (may exceed 1 for the halo), l: light dir (view space).
vec3 atmosphere(vec2 p, vec3 n, vec3 l, vec3 color, float density, float haloWidth) {
  float r = length(p);
  float inside = step(r, 1.0);
  float limb = pow(1.0 - saturate(n.z), 3.0) * inside;
  float halo = (1.0 - smoothstep(1.0, 1.0 + haloWidth, r)) * step(1.0, r);
  halo *= halo;
  vec2 lp = normalize(l.xy + 1e-4);
  float dayside = saturate(dot(normalize(p + 1e-4), lp) * 0.6 + 0.55);
  float sunward = saturate(dot(n, l) * 0.5 + 0.5);
  return color * density * (limb * sunward * 1.6 + halo * dayside * 1.2);
}

// --- living state -----------------------------------------------------------
// uScore in [0,1]: 0 neglected … 1 thriving.
float thrive(float score) { return smoothstep(0.55, 0.95, score); }
float neglect(float score) { return 1.0 - smoothstep(0.15, 0.55, score); }

// Swirling dust storm density over a surface point (object space).
float dustStorm(vec3 q, float t) {
  vec3 w = q * 2.2 + vec3(t * 0.05, 0.0, -t * 0.03);
  float d = fbm3lo(w + fbm3lo(w * 1.7 + t * 0.02) * 1.3);
  return smoothstep(0.35, 0.8, d);
}

// Faint crack network (cellular edges) – returns 0..1 crack intensity.
float cracks(vec3 q) {
  vec2 v = voronoi3(q * 4.0);
  return 1.0 - smoothstep(0.0, 0.05, v.y - v.x);
}

// Slow "distress" pulse for neglected worlds (period ~3.2 s).
float distressPulse(float t) { return 0.5 + 0.5 * sin(t * 1.96); }
