#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// film_grade — the Film Reel Engine's ONE full-frame post pass (1920s–1970s
// eras; the 1980s use vhs.frag). Owner: FX agent (body). Uniform contract:
// architect (lib/features/cinema/engine/core/shader_uniforms.dart,
// FilmGradeUniforms) – change both together or not at all.
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
  vec2 p = FlutterFragCoord().xy - uRect.xy;
  float ff = uClock.y;
  float seed = uClock.w;

  // Gate weave: the print hops a little every film frame and drifts slowly.
  vec2 hop = cn_hash22(vec2(ff, seed + 1.3)) - 0.5;
  vec2 drift = vec2(sin(uClock.x * 1.7 + seed), sin(uClock.x * 2.3 + 1.1)) * 0.35;
  vec2 weave = (hop * vec2(0.6, 1.0) + drift) * uWear.x;
  weave += (cn_hash22(vec2(ff * 1.7, 3.1 + seed)) - 0.5) * uEvent.y * 14.0;
  vec2 uv = (p - weave) / size;
  vec3 c = sampleFrame(uv);

  // Halation: brights bleed a soft warm glow (4 taps, only when enabled).
  if (uWear.w > 0.001) {
    vec2 o = vec2(3.0) / size;
    vec3 h = sampleFrame(uv + vec2(o.x, o.y)) + sampleFrame(uv + vec2(-o.x, o.y)) +
             sampleFrame(uv + vec2(o.x, -o.y)) + sampleFrame(uv - o);
    h *= 0.25;
    float hb = smoothstep(0.6, 1.0, cn_luma(h));
    c += h * hb * uWear.w * vec3(1.0, 0.82, 0.62) * 0.6;
  }

  // Era grade: duotone for monochrome stock, then colour back by saturation.
  float l = cn_luma(c);
  vec3 duo = mix(uInk.rgb, uPaper.rgb, l);
  c = mix(duo, c, uTone.x);
  c = mix(c, c * uTint.rgb * 1.25, uTint.a);
  c = (c - 0.5) * uTone.y + 0.5 + uTone.z;
  if (uTone.w > 0.5) {
    c = floor(c * uTone.w + 0.5) / uTone.w;
  }

  // Projector flicker: exposure jitters per film frame.
  float flick = (cn_hash11(ff * 7.13 + seed) - 0.5) * 0.22 + sin(uClock.x * 31.0) * 0.03;
  c *= 1.0 + flick * uGrain.z;

  // Vignette (aspect-corrected, slightly uneven like an old lens).
  vec2 q = (p / size - 0.5) * vec2(size.x / size.y, 1.0);
  float vig = smoothstep(0.35, 1.05, length(q * vec2(1.25, 0.9)));
  c *= 1.0 - uGrain.w * vig;

  // Grain: new pattern every film frame, strongest in the mid-tones.
  float gs = max(uGrain.y, 1.0);
  float g = cn_hash12(floor(p / gs) + vec2(ff * 17.13, ff * 5.71) + seed) - 0.5;
  float mid = 1.0 - abs(cn_luma(c) - 0.5) * 1.2;
  c += g * uGrain.x * 0.32 * mid;

  // Dust: sparse specks (dark on the print, bright where the negative was hit).
  float dust = cn_sat(uWear.y + uEvent.w * 0.6);
  if (dust > 0.001) {
    vec2 cell = floor(p / 48.0);
    vec2 r = cn_hash22(cell + ff * 3.7 + seed);
    float present = step(1.0 - dust * 0.18, cn_hash12(cell * 1.31 + ff));
    vec2 centre = (cell + r) * 48.0;
    float rad = 0.8 + r.x * 2.4;
    float speck = 1.0 - cn_edge(rad, length(p - centre), 0.9);
    float bright = step(0.7, r.y);
    c = mix(c, mix(uInk.rgb * 0.6, uPaper.rgb, bright), speck * present * 0.85);
  }

  // Scratches: a few thin vertical lines that jump between film frames.
  float scr = cn_sat(uWear.z + uEvent.w * 0.5);
  if (scr > 0.001) {
    for (int k = 0; k < 3; k++) {
      float fk = float(k);
      float on = step(1.0 - scr * 0.6, cn_hash11(ff * 1.91 + fk * 13.7 + seed));
      float x = cn_hash11(floor(ff / 3.0) * 4.3 + fk * 7.1) * size.x;
      x += sin(p.y * 0.01 + fk) * 2.0;
      float line = 1.0 - cn_edge(0.6, abs(p.x - x), 0.6);
      float breakup = step(0.35, cn_noise(vec2(p.y * 0.02, fk * 5.0 + ff)));
      c = mix(c, uPaper.rgb * 1.05, line * on * breakup * 0.55);
    }
  }

  c = mix(c, uPaper.rgb, cn_sat(uEvent.x));
  c = mix(c, uInk.rgb * 0.35, cn_sat(uEvent.z));
  fragColor = vec4(cn_sat3(c), 1.0);
}
