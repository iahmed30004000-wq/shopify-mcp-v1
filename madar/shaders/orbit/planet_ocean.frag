#version 460 core
#include <flutter/runtime_effect.glsl>
#include "lib/common.glsl"

uniform vec2 uSize;
uniform vec2 uCenter;
uniform float uRadius;
uniform float uTime;
uniform vec3 uLight;
uniform float uScore;
uniform float uPulse;
uniform vec3 uSpin;
uniform vec4 uColorA;
uniform vec4 uColorB;
uniform vec4 uColorC;
uniform float uDetail;
uniform float uSeed;
uniform vec4 uExtra;   // unused by the ocean world

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = (frag - uCenter) / uRadius;
  p.y = -p.y;
  float r = length(p);
  vec3 l = normalize(uLight);
  float th = thrive(uScore);
  float ng = neglect(uScore);
  vec3 atmoCol = toLinear(mix(uColorA.rgb, uColorB.rgb, 0.55));

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  if (r < 1.0) {
    vec3 n = sphereNormal(p);
    mat3 rot = rotY(uSpin.x + uTime * 0.02) * rotX(uSpin.y);
    vec3 q = rot * n + uSeed;

    float warp = fbm3lo(q * 1.5 + vec3(0.0, uTime * 0.008, 0.0));
    float h = fbm3(q * 2.1 + warp * 1.2);
    float land = smoothstep(0.64, 0.67, h);

    vec3 deep = toLinear(uColorC.rgb) * 0.55;
    vec3 shallow = toLinear(uColorA.rgb) * 0.8;
    vec3 water = mix(deep, shallow, smoothstep(0.38, 0.64, h));
    vec3 coast = toLinear(vec3(0.78, 0.72, 0.56));
    vec3 jungle = toLinear(vec3(0.16, 0.42, 0.26));
    vec3 ground = mix(coast, jungle, smoothstep(0.68, 0.74, h));
    vec3 albedo = mix(water, ground, land);

    // Bioluminescent currents: thin glowing filaments along warped flow lines.
    float flow = fbm3(q * 2.6 + vec3(uTime * 0.02, -uTime * 0.015, 0.0) + warp * 1.8);
    float band = abs(fract(flow * 7.0) - 0.5) * 2.0;
    float filament = smoothstep(0.86, 0.98, band);
    float beat = pow(0.5 + 0.5 * sin(uTime * mix(1.0, 3.2, uScore) - h * 9.0), 4.0);
    float bio = filament * (1.0 - land) * mix(0.15, 1.0, th) * (0.45 + 0.55 * beat);

    // Lighting.
    float ndl = dot(n, l);
    float diff = smoothstep(-0.08, 0.35, ndl) * saturate(ndl * 0.8 + 0.25);
    vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
    float spec = pow(saturate(dot(n, hv)), 70.0) * (1.0 - land) * 2.2 * smoothstep(0.0, 0.2, ndl);
    float fres = pow(1.0 - saturate(n.z), 5.0);

    vec3 lit = albedo * diff * 2.4 + vec3(1.0, 0.93, 0.8) * spec;

    // Clouds with soft shadows.
    vec3 cq = q * 3.2 + vec3(uTime * 0.012, 0.0, 0.0);
    float cl = smoothstep(0.58, 0.82, fbm3lo(cq));
    float clShadow = smoothstep(0.58, 0.82, fbm3lo(cq + l * 0.06));
    lit *= 1.0 - clShadow * 0.35;
    lit = mix(lit, vec3(0.95, 0.98, 1.0) * diff * 2.2, cl * 0.6);

    float night = 1.0 - smoothstep(-0.2, 0.12, ndl);
    vec3 glow = toLinear(uColorB.rgb) * bio * (0.5 + 2.2 * night);

    // Neglect: murky algae bloom, desaturation, dimming, dust haze.
    float murkMask = smoothstep(0.35, 0.7, warp) * ng;
    lit = mix(lit, toLinear(vec3(0.36, 0.33, 0.22)) * diff * 2.0, murkMask * 0.6);
    lit = desaturate(lit, ng * 0.6) * (1.0 - ng * 0.4);
    float dust = dustStorm(q, uTime) * ng;
    lit = mix(lit, toLinear(vec3(0.62, 0.52, 0.38)) * (diff * 1.8 + 0.02), dust * 0.55);
    glow *= 1.0 - ng * 0.9;

    col = lit + glow;
    col += atmosphere(p, n, l, atmoCol, mix(0.35, 0.9, th) * (1.0 - ng * 0.5), 0.2);
    col += toLinear(vec3(1.0, 0.25, 0.18)) * fres * ng * distressPulse(uTime) * 1.2;
    col += toLinear(uColorB.rgb) * uPulse * (0.3 + fres * 2.0);
  }
  // Halo (evaluated everywhere, composited under the disc – no limb seam).
  vec3 halo = atmosphere(p * max(1.0, r) / max(r, 1e-4), vec3(0.0, 0.0, 1.0), l, atmoCol, 0.0, 0.2);
  halo = atmosphere(p, vec3(0.0, 0.0, 1.0), l, atmoCol, mix(0.35, 0.9, th) * (1.0 - ng * 0.5), 0.2) * step(1.0, r)
       + atmoCol * mix(0.35, 0.9, th) * (1.0 - ng * 0.5) * 1.2 * (1.0 - step(1.0, r));
  halo += toLinear(vec3(1.0, 0.25, 0.18)) * ng * distressPulse(uTime) * 0.5 * (1.0 - smoothstep(1.0, 1.1, r));
  float haloA = saturate(max(halo.r, max(halo.g, halo.b)) * 2.5);
  float discA = discMask(p, uRadius);
  vec3 outCol = toGamma(tonemapACES(col));
  vec3 haloCol = toGamma(tonemapACES(halo));
  // premultiplied "disc over halo"
  vec3 pm = outCol * discA + haloCol * haloA * (1.0 - discA);
  float a = discA + haloA * (1.0 - discA);
  pm = dither(frag, pm);
  fragColor = vec4(pm, a);
}
