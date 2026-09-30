#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>
#include "lib/cinema.glsl"

// ---------------------------------------------------------------------------
// curtain — MATERIAL shader for the stage curtains (velvet folds, sheen,
// footlight bounce, sway) and the scalloped valance. Draw as Paint.shader on
// canvas.drawRect(uRect) of each panel. Owner: STAGE agent (body). Uniform
// contract: architect (shader_uniforms.dart, CurtainUniforms).
//
// Uniforms (float indices):
//   0-3   uRect   vec4  panel rect in local px (x, y, w, h)
//   4-7   uColor  vec4  velvet base colour (straight rgb), a = opacity
//   8-11  uShade  vec4  fold shadow colour (rgb), a = sheen strength (0..1)
//   12-15 uFolds  vec4  x fold count, y sway phase rad, z gather (0 = hanging
//                       straight, 1 = fully tied back toward the outer edge),
//                       w panel side (-1 left, +1 right, 0 valance)
//   16-19 uLight  vec4  footlight colour (rgb), a = intensity (0..1)
//   20-23 uClock  vec4  x seconds, y boil frame, z seed, w unused (0)
// Output: premultiplied velvet; the valance's scallops cut to transparent.
//
// Side panels: x runs from the OUTER edge (screen side, 0) to the leading
// edge (1). When gathered, the leading edge is pulled back to the tie-back
// at TIE_Y (the stage's StageLayout.tieY) and flares out below it, giving
// the classic hourglass drape; the folds follow the silhouette. Fold valleys
// are inked (1–1.5 px) and re-ink on the 12 fps boil like a painted cel.
//
// Valance: festoon swags (uFolds.x swags across) with curved folds, a gilt
// braid at the top and a gold fringe hanging from each swag's hem (the
// braid and fringe take the footlight colour as their "gold").
// ---------------------------------------------------------------------------

uniform vec4 uRect;
uniform vec4 uColor;
uniform vec4 uShade;
uniform vec4 uFolds;
uniform vec4 uLight;
uniform vec4 uClock;

out vec4 fragColor;

const float TIE_Y = 0.58;

// Inner-edge pull of a gathered panel at height y (0 at the rod, the
// deepest at the tie, relaxing toward the hem).
float st_pull(float y) {
  float up = cn_sat(y / TIE_Y);
  float down = cn_sat((y - TIE_Y) / (1.0 - TIE_Y));
  return y < TIE_Y ? 0.54 * pow(up, 1.6) : 0.54 - 0.3 * sin(down * CN_PI * 0.5);
}

vec3 st_gold(vec3 light) {
  // Footlight colour → a metallic gold of the same hue.
  return mix(light * vec3(0.92, 0.74, 0.42), light, 0.35);
}

void main() {
  vec2 p = FlutterFragCoord().xy - uRect.xy;
  vec2 size = max(uRect.zw, vec2(1.0));
  vec2 uv = p / size;
  float side = uFolds.w;
  float folds = max(uFolds.x, 1.0);
  float sheen = cn_sat(uShade.a);
  vec3 velvet = uColor.rgb;
  vec3 deep = uShade.rgb;
  float boil = floor(uClock.y);
  float seed = uClock.z;
  float li = cn_sat(uLight.a);

  if (abs(side) < 0.5) {
    // ------------------------------------------------------------ valance --
    float pel = 0.17;                 // braid band
    float sx = uv.x * folds;
    float cell = floor(sx);
    float fx = fract(sx);
    float arcB = 0.66 + 0.2 * sin(fx * CN_PI);    // swag hem (fraction of h)
    float fringe = 0.13;
    float y = uv.y;
    vec3 gold = st_gold(uLight.rgb);
    if (y < pel) {
      // Twisted gilt braid.
      float tw = sin((p.x + p.y * 1.3) / 2.6);
      vec3 c = gold * (0.62 + 0.38 * smoothstep(-0.2, 0.9, tw));
      float rim = smoothstep(pel - 1.6 / size.y, pel, y) + (1.0 - smoothstep(0.0, 1.6 / size.y, y));
      c = mix(c, deep * 0.25, cn_sat(rim));
      fragColor = vec4(cn_sat3(c), 1.0) * uColor.a;
      return;
    }
    if (y > arcB) {
      // Fringe: fine threads, each a little longer or shorter.
      float thread = floor(p.x / 1.7);
      float len = fringe * (0.72 + 0.28 * cn_hash11(thread + seed * 7.0));
      float d = (y - arcB) / len;
      float gap = abs(fract(p.x / 1.7) - 0.5);
      float a = (1.0 - smoothstep(0.85, 1.0, d)) * (1.0 - smoothstep(0.28, 0.5, gap));
      // Tassel knots at the swag joins.
      float join = min(fx, 1.0 - fx) * size.x / folds;
      a = max(a, (1.0 - smoothstep(3.0, 4.5, join)) * (1.0 - smoothstep(1.4, 1.7, (y - arcB) / fringe)));
      vec3 c = gold * (0.55 + 0.45 * cn_hash11(thread * 1.7)) * (1.0 - 0.45 * d);
      fragColor = vec4(cn_sat3(c), 1.0) * a * uColor.a;
      return;
    }
    // Swag body: folds follow the swag's curve and bunch at its ends.
    float v = (y - pel) / max(arcB - pel, 0.05);
    float ph = v * 3.4 * CN_TAU + 0.6 + (cn_noise(vec2(cell * 3.1 + seed, v * 2.0)) - 0.5) * 0.8;
    float crest = 0.5 + 0.5 * sin(ph);
    float ends = sin(fx * CN_PI);
    vec3 c = mix(deep, velvet, 0.3 + 0.7 * pow(crest, 0.8));
    float flank = smoothstep(0.62, 1.0, 0.5 + 0.5 * sin(ph + 0.9));
    c += sheen * 0.4 * pow(flank, 3.0) * (velvet * 0.6 + 0.22);
    c *= 0.55 + 0.45 * pow(ends, 0.6);
    // Inked valleys and the swag's hem line.
    float q = mod(ph + CN_PI * 0.5, CN_TAU);
    float dv = min(q, CN_TAU - q) / (3.4 * CN_TAU / max((arcB - pel) * size.y, 1.0));
    c = mix(c, deep * 0.3, (1.0 - smoothstep(0.4, 1.2, dv)) * 0.7 * ends);
    float hem = (arcB - y) * size.y;
    c = mix(c, deep * 0.2, 1.0 - smoothstep(0.8, 2.0, hem));
    // Swag joins: a dark crease.
    float join = min(fx, 1.0 - fx) * size.x / folds;
    c = mix(c, deep * 0.25, (1.0 - smoothstep(0.6, 2.2, join)) * 0.9);
    c += uLight.rgb * li * 0.06;
    float pile = cn_noise(p * vec2(0.8, 0.3) + seed);
    c *= 0.94 + 0.1 * pile;
    fragColor = vec4(cn_sat3(c), 1.0) * uColor.a;
    return;
  }

  // -------------------------------------------------------------- side panel --
  float x = side < 0.0 ? uv.x : 1.0 - uv.x;       // 0 outer … 1 leading edge
  float y = uv.y;
  float g = cn_sat(uFolds.z);
  float e = 1.0 - g * st_pull(y);                  // leading edge at this height
  float aa = 0.8 / size.x;
  float alpha = 1.0 - smoothstep(e - aa, e + aa, x);
  if (alpha <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  float u = cn_sat(x / max(e, 0.05));             // across the visible cloth
  float tieZone = exp(-pow((y - TIE_Y) / 0.13, 2.0)) * g;
  // Folds fan out below the tie and gather above it; they sway with the
  // ripple phase and wander a little so no two are alike.
  float fan = pow(u, 1.0 + 0.5 * tieZone);
  float ripple = sin(y * 4.6 + uFolds.y) * 0.03 * (1.0 - 0.8 * g) + sin(y * 10.0 - uFolds.y * 1.6) * 0.01;
  float wander = (cn_noise(vec2(fan * folds * 0.8, seed)) - 0.5) * 1.1
    + (cn_noise(vec2(fan * folds * 0.45 + 3.0, y * 1.6 + seed)) - 0.5) * 0.9;
  float jitter = (cn_hash11(boil * 3.7 + floor(fan * folds) + seed) - 0.5) * 0.12;
  float ph = (fan + ripple) * folds * CN_TAU + wander + jitter;
  float crest = 0.5 + 0.5 * sin(ph);
  vec3 c = mix(deep, velvet, pow(crest, 0.85));
  // Velvet sheen on the flank facing the stage.
  float flank = smoothstep(0.6, 1.0, 0.5 + 0.5 * sin(ph + 0.9));
  c += sheen * 0.5 * pow(flank, 3.0) * (velvet * 0.55 + 0.25);
  // Inked valleys (~1.2 px), fading up into the valance's shadow.
  float q = mod(ph + CN_PI * 0.5, CN_TAU);
  float dph = folds * CN_TAU / max(size.x * e, 1.0) * (1.0 + 0.5 * tieZone);
  float dpx = min(q, CN_TAU - q) / dph;
  float ink = (1.0 - smoothstep(0.35, 1.15, dpx)) * smoothstep(0.03, 0.2, y);
  c = mix(c, deep * 0.3, ink * 0.75);
  // Bunching at the tie-back.
  c *= 1.0 - 0.3 * tieZone * (1.0 - crest);
  // Depth: darker toward the proscenium and under the valance.
  c *= 0.62 + 0.38 * smoothstep(0.0, 0.4, u);
  c *= 0.5 + 0.5 * smoothstep(0.0, 0.16, y);
  // Footlight bounce on the hem and a lit leading edge.
  float glow = exp(-(1.0 - y) * 6.0) * li;
  c += uLight.rgb * glow * (0.3 + 0.5 * crest);
  float edgePx = (e - x) * size.x;
  c += uLight.rgb * li * 0.22 * (1.0 - smoothstep(1.5, 7.0, edgePx)) * (0.4 + 0.6 * y);
  // Outline of the leading edge.
  c = mix(c, deep * 0.2, 1.0 - smoothstep(0.7, 1.9, edgePx));
  // Velvet pile.
  float pile = cn_noise(p * vec2(1.1, 0.28) + seed * 13.0);
  c *= 0.93 + 0.12 * pile;
  fragColor = vec4(cn_sat3(c), 1.0) * alpha * uColor.a;
}
