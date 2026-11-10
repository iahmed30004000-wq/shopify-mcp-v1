// ---------------------------------------------------------------------------
// Madar Cinema shader library – included by every shaders/cinema/*.frag.
// Owner: FX agent (others may #include it, never edit it).
//
// ALU only: no textures, so it never claims a sampler index (a post-process
// shader's sampler 0 is always its uFrame input).
//
// SkSL rules (widget-test screenshots + Skia fallback must compile):
//   * never pass a sampler2D as a function parameter (samplers are globals);
//   * no `saturate` builtin (use cn_sat), constant loop bounds only;
//   * no derivatives (fwidth/dFdx): anti-alias with px-sized uniforms;
//   * output is PREMULTIPLIED alpha.
// Declare the shader's own uniforms AFTER including this file.
// ---------------------------------------------------------------------------
#ifndef MADAR_CINEMA_GLSL
#define MADAR_CINEMA_GLSL

#define CN_PI 3.14159265359
#define CN_TAU 6.28318530718

float cn_sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 cn_sat3(vec3 x) { return clamp(x, 0.0, 1.0); }

float cn_luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// --- hashes (Dave Hoskins, sin-free) ---------------------------------------
float cn_hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}
float cn_hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
vec2 cn_hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

// --- value noise / fbm (ALU) -------------------------------------------------
float cn_noise(vec2 x) {
  vec2 i = floor(x);
  vec2 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  float a = cn_hash12(i);
  float b = cn_hash12(i + vec2(1.0, 0.0));
  float c = cn_hash12(i + vec2(0.0, 1.0));
  float d = cn_hash12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float cn_fbm(vec2 p) {
  float s = 0.0, a = 0.5;
  for (int i = 0; i < 4; i++) {
    s += a * cn_noise(p);
    p = p * 2.03 + vec2(17.1, 9.7);
    a *= 0.5;
  }
  return s / 0.9375;
}

// --- geometry ---------------------------------------------------------------
vec2 cn_rotate(vec2 p, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Smooth 0→1 edge `w` px wide around `edge` (px-space anti-aliasing).
float cn_edge(float edge, float d, float w) {
  return smoothstep(edge - w, edge + w, d);
}

// Ramp parameter for material shaders (halftone / crosshatch):
//   mode 0 – linear from `from` (t = 0) to `to` (t = 1);
//   mode 1 – radial around `from`, t = 1 at distance |to - from|.
float cn_ramp(vec2 p, vec2 from, vec2 to, float mode) {
  vec2 d = to - from;
  if (mode > 0.5) {
    return cn_sat(length(p - from) / max(length(d), 1e-3));
  }
  return cn_sat(dot(p - from, d) / max(dot(d, d), 1e-3));
}

// UV of the rendered frame (uFrame, from Picture.toImageSync) for a point in
// the destination rect. Impeller's OpenGLES backend stores render-target
// textures bottom-up (same as the ImageFilter input, see
// shaders/orbit/zoom_blur.frag) – verify on a GLES device; this is the ONE
// place to change if frames appear upside down there.
vec2 cn_frame_uv(vec2 uv) {
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

#endif // MADAR_CINEMA_GLSL
