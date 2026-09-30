#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"
#include "lib/film.glsl"

// ---------------------------------------------------------------------------
// film_grade — the Film Reel Engine's ONE full-frame post pass (1920s–1970s
// eras; the 1980s use vhs.frag). Owner: FX agent (body). Uniform contract:
// architect (lib/features/cinema/engine/core/shader_uniforms.dart,
// FilmGradeUniforms) – change both together or not at all.
//
// ReelFilmFx (engine/fx/) grades with film_stock.frag, a superset of this
// layout with the per-era print looks; this pass is the contract-level
// fallback (same film wear from lib/film.glsl, no print stylisation).
//
// Draw: the whole game frame is recorded, rasterised (Picture.toImageSync at
// physical resolution × FilmFx.resolutionScale) and bound as uFrame; the
// shader is then used as Paint.shader on canvas.drawRect(uRect).
//
// Pipeline (single pass): gate weave + shake → sample → era grade (duotone
// ink/paper for monochrome eras, saturation, tint, contrast, brightness,
// posterize) → halation → flicker → vignette → grain → dust → scratches →
// hit flash → fade to black.
//
// Uniforms (float indices for setFloat):
//   0-3   uRect   vec4  destination rect in the canvas' local px (x, y, w, h)
//   4-7   uClock  vec4  x seconds since scene start, y film frame index
//                       (time quantised to FilmGrade.projectionFps), z boil
//                       frame (FilmClock.boilFrame), w per-scene seed
//   8-11  uInk    vec4  ink colour (straight rgb, a = 1): the duotone's dark end
//   12-15 uPaper  vec4  paper colour (straight rgb, a = 1): the duotone's light end
//   16-19 uTint   vec4  toning colour (rgb) and strength (a, 0..1)
//   20-23 uTone   vec4  x saturation (0 = pure duotone, 1 = source colours),
//                       y contrast (1 = neutral), z brightness offset (0 =
//                       neutral), w posterize levels (0 = off)
//   24-27 uGrain  vec4  x grain amount (0..1), y grain size px, z flicker
//                       (0..1), w vignette (0..1)
//   28-31 uWear   vec4  x gate weave amplitude px, y dust (0..1), z scratches
//                       (0..1), w halation (0..1, glow bleeding from brights)
//   32-35 uEvent  vec4  x flash (0..1, to paper), y shake (0..1), z fade to
//                       ink/black (0..1), w damage (0..1, extra dust+scratches)
//   sampler 0 uFrame     the rendered frame (opaque).
// Output: opaque, premultiplied.
// Budget: ≤ 6 texture fetches/pixel (1 + 4 halation taps + 1 spare);
// everything else ALU. Keep branches on uniforms only.
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uClock;
uniform vec4 uInk;
uniform vec4 uPaper;
uniform vec4 uTint;
uniform vec4 uTone;
uniform vec4 uGrain;
uniform vec4 uWear;
uniform vec4 uEvent;
uniform sampler2D uFrame;

out vec4 fragColor;

vec3 sampleFrame(vec2 uv) {
  return texture(uFrame, cn_frame_uv(clamp(uv, vec2(0.0), vec2(1.0)))).rgb;
}

void main() {
  vec2 size = max(uRect.zw, vec2(1.0));
  vec2 p0 = FlutterFragCoord().xy - uRect.xy;
  float t = uClock.x;
  float ff = uClock.y;
  float seed = uClock.w;

  // Gate weave + projector shake.
  vec2 weave = fm_weave(ff, t, seed) * uWear.x;
  weave += (cn_hash22(vec2(ff * 1.7, 3.1 + seed)) - 0.5) * uEvent.y * 16.0;
  vec2 p = p0 - weave;
  vec2 uv = p / size;
  vec3 c = sampleFrame(uv);

  // Halation: brights bleed a warm glow (4 taps, only when enabled).
  if (uWear.w > 0.001) {
    vec2 o = vec2(3.0) / size;
    vec3 h = sampleFrame(uv + vec2(o.x, o.y)) + sampleFrame(uv + vec2(-o.x, o.y)) +
             sampleFrame(uv + vec2(o.x, -o.y)) + sampleFrame(uv - o);
    h *= 0.25;
    c += h * smoothstep(0.6, 1.0, cn_luma(h)) * uWear.w * vec3(1.0, 0.55, 0.35) * 0.7;
  }

  // Tone curve first, then the stock: duotone for monochrome, saturation
  // around grey for colour.
  c = (c - 0.5) * uTone.y + 0.5 + uTone.z;
  if (uTone.w > 0.5) c = floor(c * uTone.w + 0.5) / uTone.w;
  float l = cn_sat(cn_luma(c));
  vec3 duo = mix(uInk.rgb, uPaper.rgb, l);
  vec3 satc = mix(vec3(l), c, max(uTone.x, 0.0));
  c = mix(duo, satc, cn_sat(uTone.x));
  c = mix(c, c * uTint.rgb * 1.2, uTint.a);

  // Exposure: flicker and vignette.
  vec2 q = p0 / size - 0.5;
  c *= 1.0 + fm_flicker(q, ff, t, seed) * uGrain.z;
  c = mix(c, uInk.rgb * 0.5, fm_vignette(p0, size, uGrain.w, 0.0, t) * 0.92);

  // Grain, strongest in the mid-tones.
  float lum = cn_luma(c);
  float body = 0.35 + 0.65 * (1.0 - abs(lum - 0.45) * 1.3);
  c += fm_grain(p0, max(uGrain.y, 0.75), ff, seed, 1.0) * uGrain.x * 0.1 * body;

  // Dust and travelling scratches (plus reel damage).
  float dust = cn_sat(uWear.y + uEvent.w * 0.6);
  if (dust > 0.001) {
    vec2 d = fm_dustLayer(p, 44.0, dust * 0.2, ff, seed);
    c = mix(c, mix(mix(uInk.rgb, c, 0.25), mix(uPaper.rgb, vec3(1.0), 0.4), d.y), d.x * 0.9);
  }
  float scr = cn_sat(uWear.z + uEvent.w * 0.5);
  if (scr > 0.001) {
    vec2 s = fm_scratches(p, size, scr, ff, seed);
    c = mix(c, mix(mix(uPaper.rgb, vec3(1.0), 0.35), uInk.rgb, s.y), s.x * 0.75);
  }

  c = mix(c, mix(uPaper.rgb, vec3(1.0), 0.3), cn_sat(uEvent.x));
  c = mix(c, uInk.rgb * 0.3, cn_sat(uEvent.z));
  fragColor = vec4(cn_sat3(c), 1.0);
}
