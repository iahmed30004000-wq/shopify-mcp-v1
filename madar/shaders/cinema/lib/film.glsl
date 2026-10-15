// ---------------------------------------------------------------------------
// Madar Cinema film-stock library – the projector, the print and its wear.
// Owner: FX agent. Included by film_stock.frag and film_grade.frag AFTER
// lib/cinema.glsl. ALU only (never samples), same SkSL rules as cinema.glsl.
//
// Units: px are the logical px of the destination rect; `ff` is the film
// frame index (FilmClock.filmFrame) – everything that belongs to the print
// (grain, dust, flicker, weave) changes once per film frame, never per
// display frame, so the look is identical at 60 and 120 Hz.
// ---------------------------------------------------------------------------
#ifndef MADAR_FILM_GLSL
#define MADAR_FILM_GLSL

// --- the projector -----------------------------------------------------------

// Gate weave in px for amplitude 1: the print hops a little every film frame
// (worn sprocket holes), now and then a bigger registration jump, and sways
// slowly sideways as the loop breathes.
vec2 fm_weave(float ff, float t, float seed) {
  vec2 hop = cn_hash22(vec2(ff * 0.7071 + 3.1, seed + 1.3)) - 0.5;
  float jump = step(0.9, cn_hash11(ff * 1.37 + seed * 2.1));
  vec2 sway = vec2(sin(t * 1.31 + seed) * 0.55 + sin(t * 0.43 + 2.0) * 0.35, sin(t * 2.07 + 1.1) * 0.22);
  return hop * vec2(0.5, 1.0) * (1.0 + jump * 1.8) + sway;
}

// Exposure flicker for film frame ff (0 = steady): a per-frame density
// jitter plus a slower pulse (an uneven shutter), and a gradient that makes
// one side of the frame breathe differently from the other. q = p/size - .5.
float fm_flicker(vec2 q, float ff, float t, float seed) {
  float frame = cn_hash11(ff * 7.13 + seed) - 0.5;
  float slow = sin(t * 5.3 + seed) * 0.35 + sin(t * 1.7) * 0.25;
  vec2 dir = cn_hash22(vec2(ff * 0.37, seed + 5.0)) - 0.5;
  float side = dot(q, dir) * 0.9;
  return frame * 0.24 + slow * 0.06 + side * frame * 0.5;
}

// --- the print -----------------------------------------------------------------

// Film grain, zero mean, roughly -1..1: organic clumps (two octaves of value
// noise at the grain size) that re-roll every film frame. `fine` > 0.5 adds
// the second octave (off in low-power mode).
float fm_grain(vec2 p, float size, float ff, float seed, float fine) {
  vec2 o = cn_hash22(vec2(ff + 0.5, seed + 0.25)) * 997.0;
  float g = cn_noise(p / size + o) - 0.5;
  if (fine > 0.5) {
    g = g * 0.7 + (cn_noise(p / (size * 0.47) + o.yx * 1.31 + 7.0) - 0.5) * 0.6;
  }
  return g * 3.2;
}

// Dust on the print: one layer of cells, each maybe holding a speck or a
// fibre for exactly one film frame (real print dirt never stays put).
// Returns (coverage 0..1, bright 0/1): dirt on the print is dark, dirt that
// was on the negative prints light.
vec2 fm_dustLayer(vec2 p, float cellPx, float amount, float ff, float seed) {
  vec2 cell = floor(p / cellPx);
  vec2 local = p - cell * cellPx;
  float h = cn_hash12(cell * 1.31 + vec2(ff * 7.17 + seed, ff * 0.61));
  // Most cells are clean this frame: skip the shape (coherent per cell).
  if (h > amount) return vec2(0.0);
  vec2 r = cn_hash22(cell + vec2(ff * 3.71 + seed, ff * 1.3 + 2.0));
  vec2 d = local - (0.22 + 0.56 * r) * cellPx;
  float kind = fract(h * 57.3);
  // irregular speck
  float rad = 0.6 + r.x * r.y * 3.4 + step(0.93, fract(h * 31.1)) * 2.5;
  float ang = atan(d.y, d.x + 0.0001);
  rad *= 0.7 + 0.6 * cn_noise(vec2(ang * 1.7 + r.x * 20.0, h * 40.0));
  float speck = 1.0 - smoothstep(rad - 0.55, rad + 0.55, length(d));
  // bent fibre / hair fragment
  vec2 fq = cn_rotate(d, r.y * CN_TAU);
  float len = 5.0 + r.x * 15.0;
  float bend = (fract(h * 11.7) - 0.5) * 14.0;
  float fy = fq.y - bend * (fq.x * fq.x) / (len * len);
  float fibre = (1.0 - smoothstep(0.3, 0.9, abs(fy))) * (1.0 - smoothstep(len * 0.75, len, abs(fq.x)));
  float m = mix(speck, fibre, step(0.74, kind));
  m *= step(h, amount);
  return vec2(m, step(0.7, fract(h * 13.1 + r.x)));
}

// Long scratches along the film. A scratch keeps its lane for many frames and
// wanders a little; its breaks travel with the film (each frame shows a new
// stretch of the scratched print). Returns (coverage, kind): kind 0 = base
// scratch (prints light), 1 = emulsion scratch (dark / dye-coloured).
vec2 fm_scratches(vec2 p, vec2 size, float amount, float ff, float seed) {
  float m = 0.0;
  float kind = 0.0;
  for (int k = 0; k < 4; k++) {
    float fk = float(k);
    float life = 28.0 + fk * 21.0;
    float epoch = floor((ff + fk * 97.0 + seed * 13.0) / life);
    float alive = step(cn_hash11(epoch * 3.17 + fk * 11.3 + seed), amount * 0.8);
    float x = cn_hash11(epoch * 7.31 + fk * 1.7 + seed) * size.x;
    x += sin(ff * 0.09 + fk * 2.0) * 3.0 + (cn_hash11(ff + fk * 3.3) - 0.5) * 0.9;
    x += sin(p.y * (0.004 + fk * 0.0021) + epoch) * (1.5 + fk);
    float w = 0.35 + cn_hash11(epoch + fk * 5.0) * 0.8;
    float line = (1.0 - smoothstep(w, w + 0.75, abs(p.x - x))) * alive;
    // Only the pixels on a scratch pay for its breaks.
    if (line > 0.0) {
      float run = cn_noise(vec2(fk * 7.0 + epoch * 1.3, (p.y + ff * size.y * 1.137) / 46.0));
      float on = smoothstep(0.3, 0.45, run);
      float flutter = 0.5 + 0.5 * cn_hash11(ff * 1.7 + fk);
      float mk = line * on * flutter;
      float kk = step(0.6, cn_hash11(epoch * 1.9 + fk));
      kind = mix(kind, kk, step(m, mk));
      m = max(m, mk);
    }
  }
  // One-frame "flash" scratches: short bright tears in random places.
  float fs = step(1.0 - amount * 0.35, cn_hash11(ff * 1.91 + seed));
  float fx = cn_hash11(ff * 4.3 + 1.0) * size.x;
  float fy0 = cn_hash11(ff * 2.9 + 2.0) * size.y;
  float flen = 60.0 + cn_hash11(ff * 8.1) * size.y * 0.5;
  float fline = (1.0 - smoothstep(0.4, 1.2, abs(p.x - fx - (p.y - fy0) * 0.02))) * step(fy0, p.y) * step(p.y, fy0 + flen);
  m = max(m, fline * fs * 0.85);
  return vec2(m, kind);
}

// Rounded projector aperture: 1 inside the gate, 0 in the dark corners.
float fm_gate(vec2 p, vec2 size, float radius, float soft) {
  vec2 h = size * 0.5;
  vec2 d = abs(p - h) - (h - vec2(radius));
  float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
  return 1.0 - smoothstep(-soft, soft * 0.5, dist);
}

// Uneven lens vignette that follows the frame's shape (tall phone screens
// darken along every edge, most in the rounded corners, not just in a
// landscape-sized ellipse); `age` adds the blotchy density of an old print.
float fm_vignette(vec2 p, vec2 size, float amount, float age, float t) {
  float m = min(size.x, size.y);
  vec2 e = min(p, size - p) / m;
  // Smooth minimum of the two edge distances rounds the corners.
  float k = 0.14;
  float h = clamp(0.5 + 0.5 * (e.y - e.x) / k, 0.0, 1.0);
  float ed = mix(e.y, e.x, h) - k * h * (1.0 - h);
  float v = 1.0 - smoothstep(-0.03, 0.34, ed);
  v *= v;
  vec2 q = (p / size - 0.5) * 2.0;
  v = max(v, smoothstep(0.7, 1.45, length(q)) * 0.55);
  if (age > 0.001) {
    // Two octaves are plenty at this scale (the mottle is large and slow).
    vec2 mq = p / 170.0 + vec2(floor(t * 0.7) * 1.7, 3.0);
    float n = cn_noise(mq) * 0.65 + cn_noise(mq * 2.3 + 5.1) * 0.35;
    v += (n - 0.5) * age * (0.3 + v);
  }
  return cn_sat(v * amount);
}

#endif // MADAR_FILM_GLSL
