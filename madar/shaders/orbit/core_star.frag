#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

// ---------------------------------------------------------------------------
// Core star — the luminous heart of the astrolabe that represents the user.
// A brilliant white-gold photosphere (limb darkened, softly granulated), a
// chromosphere rim, animated corona streamers and filaments (fbm in polar
// coordinates, flowing outward), arching prominences at the limb, a layered
// bloom halo and subtle 8-point diffraction spikes (the Rub el Hizb: four long
// + four short rays, two overlapping squares).
//
// Uniforms (after common.glsl; sampler 0 = uNoise, the shared noise texture):
//   uSize     canvas size (px) — unused, kept for API symmetry.
//   uCenter   star centre (px, local canvas).
//   uRadius   photosphere radius (px).  Draw rect: centre ± uRadius × 4.
//   uTime     seconds.
//   uBalance  0..1 overall life balance. 1 = brilliant warm white-gold, calm,
//             crisp spikes; 0 = dimmer, redder, turbulent corona, big
//             restless prominences, a few dark spots, flickering.
//   uPulse    0..1 celebration flare (brightness surge, longer spikes and a
//             shock ring racing outward as the pulse decays).
//   uColorA   core tint (straight sRGB), e.g. #FFE7A3.
//   uColorB   corona tint (straight sRGB), e.g. #F2C14E.
// Output is premultiplied with alpha = coverage of the disc plus max(rgb)
// of the glow, i.e. the glow composites like "screen" under srcOver (the
// same convention as compositeDiscHalo in common.glsl).
// Balance reads: the white-hot centre is kept modest so the outer third of a
// balanced star stays visibly gold, and an ailing star's diffraction spikes
// shrink and soften (0.35× at balance 0) instead of staying long and crisp.
// Round 2: never a blown-out white disc – a warm-white core (#FFF4DC)
// darkening to an orange limb with visible, slowly boiling granulation,
// exposed below clipping; fine corona filaments; the bloom is capped at
// ~2 radii so it stays inside the hub's window (the countdown engraved on
// the hub ring is never washed out).
// ---------------------------------------------------------------------------

uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uRadius;
uniform float uTime;
uniform float uBalance;
uniform float uPulse;
uniform vec4 uColorA;
uniform vec4 uColorB;

out vec4 fragColor;

const float CS_EXTENT = 4.0;   // draw rect half-size in star radii

float cs_sq(float x) { return x * x; }

// Warm temperature ramp, t 0 (deep ember red) … 1 (white-gold), linear light.
vec3 cs_temp(float t) {
  vec3 c = mix(vec3(0.85, 0.12, 0.03), vec3(1.0, 0.42, 0.1), smoothstep(0.0, 0.35, t));
  c = mix(c, vec3(1.0, 0.72, 0.34), smoothstep(0.3, 0.7, t));
  c = mix(c, vec3(1.0, 0.93, 0.8), smoothstep(0.65, 1.0, t));
  return c;
}

// One diffraction ray along unit direction d: thin, tapering.
float cs_ray(vec2 p, vec2 d, float len, float w) {
  float along = dot(p, d);
  float perp = abs(p.x * d.y - p.y * d.x);
  float s = max(along, 0.0);
  float width = w * (1.0 + s * 0.35);
  float fall = exp(-s / len) * smoothstep(0.0, 0.6, along);
  return exp(-perp / width) * fall;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  vec2 dir = p / max(r, 1e-4);
  float bal = saturate(uBalance);
  float turb = 1.0 - bal;                         // 0 calm … 1 restless
  float t = uTime;
  float px = 1.0 / uRadius;

  vec3 tintA = toLinear(uColorA.rgb);
  vec3 tintB = toLinear(uColorB.rgb);
  // Temperature: balance drives the colour, the tints steer it.
  float temp = mix(0.2, 1.0, bal);
  vec3 hot = cs_temp(temp) * mix(vec3(1.0), tintA * 1.25, 0.5 * bal);
  vec3 coronaC = mix(cs_temp(temp * 0.8), tintB, mix(0.2, 0.55, bal));
  float flicker = 1.0 - turb * 0.14 * (0.5 + 0.5 * sin(t * 7.3 + sin(t * 3.1) * 2.0))
                      * noise2(vec2(t * 3.0, 4.2));
  float exposure = mix(0.5, 1.0, bal) * flicker * (1.0 + uPulse * 0.9);

  // ---------------- photosphere ----------------
  vec3 disc = vec3(0.0);
  if (r < 1.0 + 2.0 * px) {
    vec2 pd = p * min(1.0, 0.9995 / max(r, 1e-4));
    vec3 n = sphereNormal(pd);
    float mu = n.z;
    // Limb darkening + colour shift toward the cooler limb.
    float ld = 1.0 - 0.62 * (1.0 - mu) - 0.18 * cs_sq(1.0 - mu);
    vec3 q = rotY(t * 0.03) * n;
    float gran = fbm3lo(q * 9.0 + vec3(0.0, t * 0.08, t * 0.05));
    float gran2 = noise3(q * 23.0 - vec3(t * 0.12, 0.0, t * 0.1));
    float cells = (gran - 0.5) * 0.55 + (gran2 - 0.5) * 0.3;
    // Restless star: a few dark spots with warm penumbrae.
    float spotN = fbm3lo(q * 2.6 + vec3(7.1, t * 0.01, 3.3));
    float spots = smoothstep(0.66, 0.74, spotN) * turb;
    float pen = smoothstep(0.58, 0.68, spotN) * turb;
    // Warm white (#FFF4DC) at the centre, an orange limb; an ailing star
    // runs cooler and redder throughout.
    vec3 coreC = mix(cs_temp(temp * 0.9), vec3(1.0, 0.905, 0.71), bal) * mix(vec3(1.0), tintA * 1.1, 0.25);
    vec3 limbC = mix(vec3(0.9, 0.2, 0.04), vec3(1.0, 0.42, 0.1), bal);
    vec3 photo = mix(limbC, coreC, smoothstep(0.0, 0.9, mu));
    float bright = ld * (1.0 + cells * mix(0.55, 0.85, turb));
    bright *= 1.0 - pen * 0.35 - spots * 0.55;
    // Faculae: bright filigree near the limb.
    bright += smoothstep(0.62, 0.8, gran2) * (1.0 - mu) * 0.3;
    disc = photo * bright * mix(0.75, 1.0, bal) * exposure;
    // A gentle hot centre (never clipped white).
    disc += vec3(1.0, 0.93, 0.8) * pow(mu, 4.0) * 0.28 * bal * exposure;
    // An ailing star still smoulders: a deep ember glow from within.
    disc += vec3(1.0, 0.36, 0.08) * pow(mu, 1.5) * 0.45 * turb * exposure;
  }

  // ---------------- corona ----------------
  float rr = max(r, 1.0);
  float lr = log(rr);
  float speed = mix(1.0, 2.6, turb);
  // Domain-warped radial streamers: slow along the radius, fast along the angle.
  vec3 wq = vec3(dir * 1.6, lr * 1.2 - t * 0.05 * speed);
  float warp = fbm3lo(wq + vec3(3.1, 7.7, 0.0));
  vec2 wdir = normalize(dir + (warp - 0.5) * mix(0.25, 0.9, turb) * vec2(-dir.y, dir.x));
  float s1 = fbm3lo(vec3(wdir * 4.5, lr * 1.6 - t * 0.09 * speed));
  float s2 = noise3(vec3(wdir * 13.0 + 1.7, lr * 2.8 - t * 0.16 * speed));
  // Fine eclipse-like striations dominate a calm star; a restless one shows
  // coarse, whipping tendrils instead.
  float s3 = noise3(vec3(wdir * 30.0 + 4.1, lr * 1.3 - t * 0.04 * speed));
  float streamers = smoothstep(0.35, 0.95, s1) * 0.8 + smoothstep(0.45, 1.0, s2) * 0.55 * s1
                  + smoothstep(0.5, 0.95, s3) * 0.6 * bal * (0.4 + s1);
  float reach = mix(0.8, 1.35, turb) * (1.0 + uPulse * 0.6);
  float coronaFall = exp(-(rr - 1.0) / (0.36 * reach));
  float coronaI = coronaFall * (0.06 + streamers * mix(0.8, 1.9, turb));
  // Chromosphere: fine spicule fringe hugging the limb.
  float spic = noise3(vec3(dir * 38.0, lr * 22.0 - t * 1.2 * speed));
  float chromo = exp(-(rr - 1.0) / (0.035 + 0.03 * turb)) * (0.6 + 0.8 * spic);
  vec3 chromoC = mix(coronaC, vec3(1.0, 0.25, 0.12), 0.25 + 0.45 * turb);

  // ---------------- prominences (limb arcs) ----------------
  float prom = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec3 h = hash33(vec3(fi * 3.7 + 1.3, 5.1, 9.2 + fi));
    float ang = h.x * TAU + t * 0.015 * (h.y - 0.5) + fi * 2.1;
    vec2 base = vec2(cos(ang), sin(ang));
    float life = 0.5 + 0.5 * sin(t * (0.21 + h.z * 0.2) + fi * 2.3);   // rises and fades
    float a = mix(0.1, 0.22, h.y) * mix(0.8, 1.6, turb) * (0.7 + 0.5 * life);
    // Loop = circle centred just inside the limb; only its outer part shows.
    vec2 c = base * (1.0 - a * 0.35);
    float d = abs(length(p - c) - a);
    float along = noise2(vec2(atan(p.y - c.y, p.x - c.x) * 3.0 + fi * 11.0, t * 0.6));
    float w = (0.022 + 0.03 * along) * (1.0 + turb * 0.8);
    float feet = smoothstep(1.0, 1.06, r);            // anchored, fading into the limb
    prom += exp(-d * d / (w * w)) * feet * (0.35 + 0.9 * along) * life;
  }
  prom *= mix(0.2, 1.1, turb);

  // ---------------- bloom halo ----------------
  float dr = rr - 1.0;
  float bloom = exp(-dr / 0.08) * 0.4 + exp(-dr / 0.3) * 0.16;

  // ---------------- 8-point diffraction spikes ----------------
  float sLong = 1.15 * mix(0.7, 1.0, bal) * (1.0 + uPulse * 0.8);
  float sShort = sLong * 0.55;
  float w0 = max(0.012, 0.9 * px);
  float spikes = 0.0;
  spikes += cs_ray(p, vec2(1.0, 0.0), sLong, w0) + cs_ray(p, vec2(-1.0, 0.0), sLong, w0);
  spikes += cs_ray(p, vec2(0.0, 1.0), sLong, w0) + cs_ray(p, vec2(0.0, -1.0), sLong, w0);
  const float D = 0.70710678;
  spikes += (cs_ray(p, vec2(D, D), sShort, w0) + cs_ray(p, vec2(-D, D), sShort, w0)
           + cs_ray(p, vec2(D, -D), sShort, w0) + cs_ray(p, vec2(-D, -D), sShort, w0)) * 0.7;
  // Gentle shimmer running outward along the rays.
  spikes *= (0.8 + 0.2 * sin(r * 9.0 - t * 2.2)) * step(1.0, r);
  spikes *= mix(0.35, 1.0, bal);                  // an ailing star's spikes fade

  // ---------------- celebration shock ring ----------------
  // An 8-lobed rosette shock front (echoing the Rub el Hizb) with a soft wake.
  float ringR = 1.05 + (1.0 - uPulse) * 2.2;
  // Signed distance to an octagram (two squares) blended with a circle.
  vec2 ap = abs(p);
  vec2 ar = abs(vec2(p.x + p.y, p.x - p.y) * 0.70710678);
  float sq1 = max(ap.x, ap.y), sq2 = max(ar.x, ar.y);
  float octa = min(sq1, sq2) * 1.1;            // "radius" of the 8-point star
  float rosette = mix(r, octa, 0.45);
  float rw = 0.03 + 0.06 * (1.0 - uPulse);
  float ring = (exp(-cs_sq((rosette - ringR) / rw)) + exp(-max(ringR - rosette, 0.0) / (rw * 4.0)) * step(rosette, ringR) * 0.18)
             * uPulse * (1.0 - smoothstep(2.4, 3.6, ringR));

  vec3 glow = coronaC * coronaI * 1.7
            + chromoC * chromo * 2.0
            + mix(chromoC, vec3(1.0, 0.3, 0.12), 0.45) * prom * 3.0
            + mix(hot, coronaC, 0.6) * bloom * 1.5
            + mix(vec3(1.0, 0.95, 0.85), hot, 0.4) * spikes * 2.2
            + mix(coronaC, vec3(1.0, 0.9, 0.7), 0.5) * ring * 1.5;
  glow *= exposure * 0.8;
  // The bloom stays inside the hub's window (~2 radii).
  glow *= 1.0 - smoothstep(1.45, 2.1, r);

  float discA = discMask(p, uRadius);
  // Blend the glow in toward the limb so the disc edge meets the chromosphere
  // without a darker outline.
  vec3 discG = toGamma(tonemapACES(disc + glow * mix(0.05, 0.75, smoothstep(0.82, 1.0, r))));
  vec3 glowG = toGamma(tonemapACES(glow));
  float glowA = saturate(max(glowG.r, max(glowG.g, glowG.b)));
  vec3 pm = discG * discA + glowG * (1.0 - discA);
  float a = discA + glowA * (1.0 - discA);
  pm = dither(frag, pm) * step(0.002, a);
  fragColor = vec4(min(pm, vec3(a)), a);
}
