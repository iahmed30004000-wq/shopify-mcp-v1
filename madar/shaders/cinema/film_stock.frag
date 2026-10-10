#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"
#include "lib/film.glsl"

// ---------------------------------------------------------------------------
// film_stock — the era film look of the Film Reel Engine (1920s–1970s; the
// 1980s use vhs.frag). Owner: FX agent (body AND uniform contract – the
// layout lives in lib/features/cinema/engine/fx/film_stock_shader.dart,
// FilmStockUniforms, and is checked by test/features/cinema/fx/). It is a
// superset of film_grade.frag (floats 0-35 mean the same) plus the per-era
// print looks and the reel events driven by FilmEvents on the Dart side.
//
// Pipeline (one pass): gate (weave, shake, frame slip, splice offset, 12 fps
// line boil) → sample → optics (soft focus, halation, bloom) → stock (tone
// curve, three-strip dyes, faded dyes, duotone) → print (halftone screen,
// pen hatching, venetian-blind light) → exposure (flicker, hot spot,
// vignette, aperture) → grain → wear (dust, scratches, hair, blotch, splice,
// cue mark, frame line) → flash / fade.
//
// Uniforms (float indices for setFloat):
//   0-3   uRect   vec4  destination rect, canvas-local px (x, y, w, h)
//   4-7   uClock  vec4  x seconds, y film frame, z boil frame, w seed
//   8-11  uInk    vec4  rgb ink (duotone dark end), a quality (0 low power,
//                       1 balanced, 2 full)
//   12-15 uPaper  vec4  rgb paper (duotone light end), a age (blotchy
//                       density of an old print, 0..1)
//   16-19 uTint   vec4  rgb toning colour, a strength
//   20-23 uTone   vec4  saturation, contrast, brightness, posterize levels
//   24-27 uGrain  vec4  grain, grain size px, flicker, vignette
//   28-31 uWear   vec4  gate weave px, dust, scratches, halation
//   32-35 uEvent  vec4  flash, shake, fade, damage
//   36-39 uPrint  vec4  halftone amount, halftone cell px, hatch amount,
//                       hatch spacing px
//   40-43 uInkFx  vec4  screen angle rad, line boil px, soft focus, toe
//                       (black crush, 0..1)
//   44-47 uLight  vec4  venetian blinds amount, angle rad, slat period px,
//                       drift phase
//   48-51 uDye    vec4  three-strip amount, dye fade (cyan loss), black
//                       lift, bloom
//   52-55 uGate   vec4  aperture corner radius px, lamp hot spot, colour
//                       grain (0 mono .. 1 per dye layer), frame-line
//                       visibility under weave
//   56-59 uSplice vec4  splice (0..1 this frame), splice y px, frame slip
//                       px (vertical misframe), blotch (0..1 this frame)
//   60-63 uCue    vec4  cue mark strength (0 hidden), centre x, y px, radius px
//   64-67 uHair   vec4  hair in the gate strength, x px, y px, angle rad
//   sampler 0 uFrame     the rendered frame (opaque).
// Output: opaque, premultiplied.
// Budget: ≤ 10 texture fetches/pixel at full quality (1 frame + 8 glow +
// 1 dye registration for Technicolor; 1 + 4 soft-focus / edge taps for the
// silent, 1930s and noir stocks),
// 1 in low power. Branches only on uniforms (and the per-cell dust test).
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
uniform vec4 uPrint;
uniform vec4 uInkFx;
uniform vec4 uLight;
uniform vec4 uDye;
uniform vec4 uGate;
uniform vec4 uSplice;
uniform vec4 uCue;
uniform vec4 uHair;
uniform sampler2D uFrame;

out vec4 fragColor;

vec3 sampleFrame(vec2 uv) {
  return texture(uFrame, cn_frame_uv(clamp(uv, vec2(0.0), vec2(1.0)))).rgb;
}

// Technicolor-style dye transfer: each dye is printed from its own
// separation record with little cross-talk, so hues come out pure; the key
// (silver) record deepens the blacks; highlights warm, shadows cool.
vec3 threeStrip(vec3 c) {
  vec3 sep = c * 1.32 - (c.gbr + c.brg) * 0.16;
  float l = cn_luma(c);
  // Print shoulder: brights roll off like dye, not like a clipped sensor.
  sep = cn_sat3(sep);
  sep = mix(sep, 1.0 - (1.0 - sep) * (1.0 - sep), 0.18);
  sep = mix(sep, sep * sep * (3.0 - 2.0 * sep), 0.35);
  sep *= mix(0.78, 1.0, smoothstep(0.0, 0.45, l));
  // Warm, creamy highlights that keep their blue skies; cool deep shadows.
  vec3 warm = sep * vec3(1.04, 1.0, 0.96) + vec3(0.0, 0.0, 0.03) * sep.b;
  vec3 cool = sep * vec3(0.93, 0.98, 1.07);
  return mix(cool, warm, smoothstep(0.25, 0.85, l));
}

// Faded chromogenic print: the cyan dye goes first (reds and magentas take
// over), yellow a little; blacks turn to warm milky brown.
vec3 fadedPrint(vec3 c, float fade, float lift, vec3 liftCol) {
  vec3 dens = 1.0 - c;
  dens *= vec3(1.0 - 0.5 * fade, 1.0 - 0.1 * fade, 1.0 - 0.32 * fade);
  c = 1.0 - dens;
  return liftCol * lift + c * (1.0 - lift);
}

// Print tone curve: contrast/brightness around mid-grey, then a toe that
// crushes the blacks (noir) – applied before the stock maps tones to dyes.
vec3 toneCurve(vec3 c) {
  c = (c - 0.5) * uTone.y + 0.5 + uTone.z;
  float toe = uInkFx.w;
  if (toe > 0.001) {
    vec3 s = cn_sat3(c);
    c = mix(c, s * s * (3.0 - 2.0 * s), toe);
    c = mix(c, c * smoothstep(0.02, 0.3, c), toe * 0.6);
  }
  return c;
}

// 1930s print screen: an AM halftone of the mid and shadow tones. Returns
// ink coverage 0..1 for tone l.
float halftoneScreen(vec2 p, float l, float cell, float angle) {
  float d = 1.0 - smoothstep(0.1, 0.8, l);
  d = d * d * (3.0 - 2.0 * d);
  vec2 q = cn_rotate(p, angle) / max(cell, 1.5);
  float spot = 0.5 + 0.25 * (cos(CN_TAU * q.x) + cos(CN_TAU * q.y));
  float w = 1.1 / max(cell, 1.5);
  return smoothstep(1.0 - d - w, 1.0 - d + w, spot) * step(0.02, d);
}

// Pen hatching of the shadows (engraving / noir). Returns ink coverage.
// Every stroke is its own pen line: it wanders a little (re-inked on the
// boil frame), presses harder or lighter along its length and lifts off now
// and then, so the shadow reads as a hand's work, not a screen-door mesh.
float hatchLayer(vec2 p, float angle, float spacing, float width, float boil) {
  vec2 q = cn_rotate(p, angle);
  float lane = floor(q.y / spacing);
  float wob = (cn_noise(vec2(q.x * 0.02 + lane * 3.7, boil * 3.1 + angle * 5.0)) - 0.5) * spacing * 0.45;
  float y = q.y + wob + (cn_hash11(lane * 1.31 + angle) - 0.5) * spacing * 0.3;
  float row = floor(y / spacing);
  float d = abs(fract(y / spacing) - 0.5) * spacing;
  float press = 0.55 + 0.9 * cn_noise(vec2(q.x * 0.03 + row * 1.7, row * 0.31 + angle));
  float lift = smoothstep(0.2, 0.32, cn_noise(vec2(q.x * 0.012 + row * 5.3, angle * 2.0 + floor(boil * 0.5) * 0.7)));
  float w = width * press * 0.5;
  return (1.0 - smoothstep(w, w + 0.7, d)) * lift;
}

// Three pen layers at open angles (not a 90° mesh): the first lays the
// shadow, the second darkens it, the third fills the deepest pockets.
float hatchScreen(vec2 p, float l, float spacing, float angle, float boil) {
  float sp = max(spacing, 2.0);
  float d = 1.0 - smoothstep(0.06, 0.62, l);
  float a = hatchLayer(p, angle, sp, 0.45 + d * sp * 0.3, boil) * smoothstep(0.05, 0.14, d);
  a = max(a, hatchLayer(p, angle + 0.62, sp * 1.08, 0.3 + (d - 0.4) * sp * 0.36, boil) * smoothstep(0.4, 0.5, d));
  a = max(a, hatchLayer(p, angle - 0.58, sp * 0.8, 0.3 + (d - 0.72) * sp * 0.45, boil) * smoothstep(0.72, 0.8, d));
  return max(a, smoothstep(0.93, 1.0, d));
}

// Slatted light through venetian blinds, thrown across the set. 1 = in a lit
// slat, 0 = in a slat shadow or outside the window's throw.
vec2 blinds(vec2 p, vec2 size) {
  vec2 c = (p - size * vec2(0.66, 0.34)) / size.y;
  vec2 q = cn_rotate(c, uLight.y);
  float window = (1.0 - smoothstep(0.12, 0.3, abs(q.x))) * (1.0 - smoothstep(0.14, 0.3, abs(q.y)));
  float period = max(uLight.z, 8.0) / size.y;
  // Slats widen slightly away from the window (perspective of the throw).
  float v = (q.y + q.x * 0.1) / (period * (1.0 + q.x * 0.4)) + uLight.w;
  float slat = smoothstep(0.1, 0.24, abs(fract(v) - 0.5));
  return vec2(window, slat);
}

// Cigarette-burn cue mark: a round punch with a ragged scorched rim.
// Returns (dark, light) coverage.
vec2 cueMark(vec2 p, float ff) {
  vec2 d = p - uCue.yz;
  float r = max(uCue.w, 1.0);
  float ang = atan(d.y, d.x + 0.0001);
  float rag = (cn_noise(vec2(ang * 3.0 + 3.0, floor(ff) * 0.37)) - 0.5) * 0.16 * r;
  float dist = length(d) - r - rag;
  float disc = 1.0 - smoothstep(-0.8, 0.8, dist);
  float rim = (1.0 - smoothstep(0.0, 2.2, abs(dist + 1.2))) * 0.9;
  float core = (1.0 - smoothstep(-0.6, 0.6, length(d) - r * 0.42 - rag * 0.5)) * 0.35;
  return vec2(disc, max(rim, core)) * uCue.x;
}

// A hair caught in the gate: a curly fibre that twitches every film frame.
float gateHair(vec2 p, float ff) {
  vec2 d = cn_rotate(p - uHair.yz, -uHair.w);
  float len = 70.0;
  float tw = (cn_hash11(ff * 0.73) - 0.5) * 1.2;
  float y = sin(d.x * 0.09 + tw) * 6.0 + sin(d.x * 0.031 + 1.0) * 9.0 + d.x * d.x * 0.0022;
  float along = step(0.0, d.x) * (1.0 - smoothstep(len * 0.8, len, d.x));
  return (1.0 - smoothstep(0.35, 1.05, abs(d.y - y))) * along * uHair.x;
}

void main() {
  vec2 size = max(uRect.zw, vec2(1.0));
  vec2 p0 = FlutterFragCoord().xy - uRect.xy;
  float t = uClock.x;
  // Wrapped so per-frame hashes keep full float precision in long sessions
  // (8192 film frames ≈ 6 min; the random wear never visibly repeats).
  float ff = mod(uClock.y, 8192.0);
  float bf = mod(uClock.z, 4096.0);
  float seed = uClock.w;
  float quality = uInk.a;
  float damage = uEvent.w;

  // --- gate --------------------------------------------------------------------
  vec2 weave = fm_weave(ff, t, seed) * uWear.x;
  weave += (cn_hash22(vec2(ff * 1.7, 3.1 + seed)) - 0.5) * uEvent.y * 16.0;
  vec2 p = p0 - weave;
  float lineBar = 0.0;
  if (abs(uSplice.z) > 0.01) {
    float barH = size.y * 0.07;
    float y = mod(p.y + uSplice.z, size.y + barH);
    lineBar = step(size.y, y);
    p.y = min(y, size.y);
  }
  if (uSplice.x > 0.001) {
    float below = step(uSplice.y, p.y);
    p.x += below * uSplice.x * 2.5;
  }
  if (uInkFx.y > 0.001 && quality > 0.5) {
    vec2 bq = p / 21.0 + vec2(bf * 3.71, bf * 1.93);
    p += (vec2(cn_noise(bq), cn_noise(bq + 17.3)) - 0.5) * 2.0 * uInkFx.y;
  }
  vec2 uv = p / size;
  vec3 c = sampleFrame(uv);

  // --- optics ------------------------------------------------------------------
  // `edge` marks line work and text (local contrast): the print screens stay
  // off it so small lettering and fine ink stay crisp.
  float edge = 0.0;
  if (quality > 0.5) {
    if (uInkFx.z > 0.001 || uPrint.x + uPrint.z > 0.001) {
      vec2 o = vec2(1.35) / size;
      vec3 b = sampleFrame(uv + vec2(o.x, 0.0)) + sampleFrame(uv - vec2(o.x, 0.0)) +
               sampleFrame(uv + vec2(0.0, o.y)) + sampleFrame(uv - vec2(0.0, o.y));
      b *= 0.25;
      edge = smoothstep(0.03, 0.12, abs(cn_luma(c) - cn_luma(b)));
      c = mix(c, b, cn_sat(uInkFx.z));
    }
    float glowAmt = uWear.w + uDye.w;
    if (glowAmt > 0.001) {
      float radius = mix(3.0, 9.0, uDye.w / glowAmt);
      vec2 o = vec2(radius) / size;
      vec2 a = o * 0.7071;
      vec2 b = o * 0.5;
      vec3 g = vec3(0.0);
      vec3 s = sampleFrame(uv + vec2(a.x, a.y));
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      s = sampleFrame(uv + vec2(-a.x, a.y));
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      s = sampleFrame(uv + vec2(a.x, -a.y));
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      s = sampleFrame(uv - a);
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      s = sampleFrame(uv + vec2(b.x, 0.0));
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      s = sampleFrame(uv - vec2(b.x, 0.0));
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      s = sampleFrame(uv + vec2(0.0, b.y));
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      s = sampleFrame(uv - vec2(0.0, b.y));
      g += s * smoothstep(0.6, 1.0, cn_luma(s));
      g *= 0.125;
      // Light spreads, it is not created: the halo is what the bright
      // neighbourhood throws beyond this pixel's own brights (a flat white
      // card stays white; the sun and the highlights glow into the sky).
      // Ink lines keep most of their bite (a thin dark stroke on a bright
      // card would otherwise wash out under the glow).
      float lc = cn_luma(c);
      vec3 own = c * smoothstep(0.6, 1.0, lc);
      vec3 halo = max(g - own, vec3(0.0)) * mix(0.45, 1.6, smoothstep(0.1, 0.6, lc)) + g * 0.1;
      c += halo * (uWear.w * vec3(1.0, 0.45, 0.25) * 0.85 + uDye.w * vec3(1.0, 0.92, 0.78) * 0.7);
    }
    if (uDye.x > 0.001) {
      // Dye-transfer registration: the cyan (red record) matrix sits a
      // fraction of a pixel off.
      float r = sampleFrame(uv + vec2(0.7, 0.3) / size).r;
      c.r = mix(c.r, r, 0.6 * uDye.x);
    }
  }

  // --- stock -------------------------------------------------------------------
  vec3 col = toneCurve(c);
  if (uDye.x > 0.001) col = mix(col, threeStrip(col), uDye.x);
  if (uDye.y + uDye.z > 0.001) {
    vec3 liftCol = mix(uInk.rgb, uPaper.rgb, 0.22) + vec3(0.07, 0.0, 0.03);
    col = fadedPrint(col, uDye.y, uDye.z, liftCol);
  }
  if (uTone.w > 0.5) col = floor(col * uTone.w + 0.5) / uTone.w;
  float l = cn_sat(cn_luma(col));

  // --- print ---------------------------------------------------------------------
  float ls = l;
  if (uPrint.x > 0.001) {
    float dots = halftoneScreen(p, l, uPrint.y, uInkFx.x);
    float band = smoothstep(0.03, 0.12, l) * (1.0 - smoothstep(0.72, 0.84, l));
    // The screen prints ink dots over a light wash of the tone itself.
    float wash = mix(l, 1.0, 0.55);
    ls = mix(ls, mix(wash, 0.0, dots), band * uPrint.x * (1.0 - edge));
  }
  if (uLight.x > 0.001) {
    vec2 bl = blinds(p, size);
    // Low-key room, a pool of slatted light from the window.
    float light = mix(0.62, 1.0, bl.x) * mix(1.0, mix(0.5, 1.16, bl.y), bl.x);
    // Beams in the cigarette haze: lit slats show even on black.
    float haze = bl.x * bl.y * 0.16 * (1.0 - ls);
    ls = mix(ls, cn_sat(ls * light + haze), uLight.x);
  }
  float hatchBand = 1.0 - smoothstep(0.3, 0.5, ls);
  if (uPrint.z > 0.001 && hatchBand > 0.0) {
    float h = hatchScreen(p, ls, uPrint.w, uInkFx.x + 0.3, bf);
    float band = hatchBand * (1.0 - edge);
    // Strokes of ink over a slightly lifted shadow: the tone survives,
    // the shadow reads as pen work.
    float hatched = mix(min(1.0, ls * 1.6 + 0.12), ls * 0.2, h);
    ls = mix(ls, hatched, band * uPrint.z);
  }
  // Colour stock follows the stylised tone; monochrome maps it to the dyes.
  vec3 grey = vec3(l);
  vec3 satc = mix(grey, col, max(uTone.x, 0.0)) * ((ls + 0.03) / (l + 0.03));
  vec3 duo = mix(uInk.rgb, uPaper.rgb, ls);
  c = mix(duo, satc, cn_sat(uTone.x));
  c = mix(c, c * uTint.rgb * 1.2, uTint.a);

  // --- exposure ------------------------------------------------------------------
  vec2 q = p0 / size - 0.5;
  c *= 1.0 + fm_flicker(q, ff, t, seed) * uGrain.z;
  c *= 1.0 + uGate.y * (0.16 - dot(q, q) * 0.9);
  float vig = fm_vignette(p0, size, uGrain.w, uPaper.a * step(0.5, quality), t);
  c = mix(c, uInk.rgb * 0.5, vig * 0.92);

  // --- grain -----------------------------------------------------------------------
  float lum = cn_luma(c);
  float body = 0.35 + 0.65 * (1.0 - abs(lum - 0.45) * 1.3);
  float gs = max(uGrain.y, 0.75);
  float amt = uGrain.x * 0.1 * body;
  float g = fm_grain(p0, gs, ff, seed, quality);
  if (uGate.z > 0.001 && quality > 0.5) {
    vec3 gc = vec3(g, fm_grain(p0 + 31.7, gs, ff, seed + 3.0, 0.0), fm_grain(p0 - 57.1, gs, ff, seed + 7.0, 0.0));
    c += mix(vec3(g), gc, uGate.z) * amt;
  } else {
    c += g * amt;
  }

  // --- wear ------------------------------------------------------------------------
  vec3 dustDark = mix(uInk.rgb, c, 0.25);
  vec3 dustLight = mix(uPaper.rgb, vec3(1.0), 0.4);
  float dust = cn_sat(uWear.y + damage * 0.6);
  if (dust > 0.001) {
    vec2 d1 = fm_dustLayer(p, 44.0, dust * 0.2, ff, seed);
    vec2 d2 = fm_dustLayer(p + 13.0, 97.0, dust * 0.14, ff + 71.0, seed + 5.0);
    float m = max(d1.x, d2.x);
    float bright = d1.x > d2.x ? d1.y : d2.y;
    c = mix(c, mix(dustDark, dustLight, bright), m * 0.9);
  }
  float scr = cn_sat(uWear.z + damage * 0.5);
  if (scr > 0.001) {
    vec2 s = fm_scratches(p, size, scr, ff, seed);
    vec3 emulsion = mix(uInk.rgb, vec3(0.25, 0.75, 0.45), cn_sat(uTone.x) * 0.8);
    vec3 base = mix(uPaper.rgb, vec3(1.0), 0.35);
    c = mix(c, mix(base, emulsion, s.y), s.x * 0.75);
  }
  if (uHair.x > 0.001) {
    c = mix(c, uInk.rgb * 0.8, gateHair(p0, ff) * 0.92);
  }
  if (uSplice.w > 0.001) {
    // Chemical stain / emulsion lift for one frame.
    vec2 bc = cn_hash22(vec2(ff, seed + 9.0)) * size;
    float blob = cn_fbm((p - bc) / 55.0 + ff * 0.37) - length((p - bc) / (size.y * 0.22));
    float stain = smoothstep(0.05, 0.14, blob) * uSplice.w;
    float light = step(0.5, cn_hash11(ff * 3.3 + seed));
    c = mix(c, mix(uInk.rgb * 0.7 + vec3(0.08, 0.03, 0.0), mix(uPaper.rgb, vec3(1.0), 0.5), light), stain * 0.75);
  }
  if (uSplice.x > 0.001) {
    float dy = p0.y - uSplice.y;
    float tape = (1.0 - smoothstep(0.6, 1.6, abs(dy))) * 0.9 + (1.0 - smoothstep(1.0, 6.0, abs(dy - 3.0))) * 0.25;
    c = mix(c, mix(uPaper.rgb, vec3(1.0), 0.5), tape * uSplice.x);
    c *= 1.0 + step(0.0, dy) * 0.07 * uSplice.x;
  }
  if (uCue.x > 0.001) {
    vec2 cm = cueMark(p0, ff);
    c = mix(c, uInk.rgb * 0.45, cm.x * 0.92);
    c = mix(c, mix(uPaper.rgb, vec3(1.0, 0.95, 0.85), 0.5), cm.y);
  }
  // Frame line: the black bar between frames (slips, or peeking under a big
  // weave at the top and bottom of the gate).
  float peek = uGate.w * (1.0 - smoothstep(-0.8, 0.4, p.y) + smoothstep(size.y - 0.4, size.y + 0.8, p.y));
  lineBar = max(lineBar, cn_sat(peek));
  c = mix(c, uInk.rgb * 0.25, lineBar);
  if (uGate.x > 0.5) c = mix(uInk.rgb * 0.2, c, fm_gate(p0, size, uGate.x, 2.0 + uGate.x * 0.2));

  // --- events ----------------------------------------------------------------------
  c = mix(c, mix(uPaper.rgb, vec3(1.0), 0.3), cn_sat(uEvent.x));
  c = mix(c, uInk.rgb * 0.3, cn_sat(uEvent.z));
  fragColor = vec4(cn_sat3(c), 1.0);
}
