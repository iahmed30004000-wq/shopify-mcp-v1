// Shared drawing kit for the «مدار الصغار» design mock-ups.
// Everything here is plain strings (HTML/SVG) so the pages open in any browser, offline.
// Fonts come from the repo's own assets/fonts folder (relative file path).

const T = {
  night900: '#17143F', night800: '#221E5A', night700: '#2F2A78', night500: '#5650B0', night300: '#A9A5E6', night100: '#E6E4FA',
  sun700: '#A8680F', sun500: '#F5B431', sun300: '#FFD479', sun100: '#FFF0CC',
  teal800: '#0F5552', teal700: '#17706C', teal500: '#2FA59C', teal200: '#B6E6DF', teal100: '#E2F5F1',
  rose700: '#A93556', rose500: '#E26A89', rose300: '#F6A9BC', rose100: '#FCE3EA',
  paper: '#FFF8EA', sand: '#F7E9CF', sand2: '#EBD5A8',
  ink: '#26214F', ink2: '#5A5482',
  retry: '#F7A94B', retry100: '#FFEBD0', retry700: '#8A4B05',
};

const AD = '٠١٢٣٤٥٦٧٨٩';
const ad = (n) => String(n).replace(/\d/g, (d) => AD[d]);
const f = (n) => Math.round(n * 100) / 100;

// ---------- geometry ----------
function starPts(cx, cy, r, rot = 0, n = 8, k = 0.765) {
  const pts = [];
  for (let i = 0; i < n * 2; i++) {
    const a = (Math.PI / n) * i + (rot * Math.PI) / 180 - Math.PI / 2;
    const rr = i % 2 === 0 ? r : r * k;
    pts.push(`${f(cx + rr * Math.cos(a))},${f(cy + rr * Math.sin(a))}`);
  }
  return pts.join(' ');
}
const star8 = (cx, cy, r, attrs = '', rot = 0, k = 0.765) =>
  `<polygon points="${starPts(cx, cy, r, rot, 8, k)}" ${attrs}/>`;
const star5 = (cx, cy, r, attrs = '') =>
  `<polygon points="${starPts(cx, cy, r, 0, 5, 0.5)}" ${attrs}/>`;
const circle = (cx, cy, r, attrs = '') => `<circle cx="${f(cx)}" cy="${f(cy)}" r="${f(r)}" ${attrs}/>`;

// Khatam rosette: layered stars, the app's visual signature.
function rosette(cx, cy, r, c1, c2, c3 = c1, sw = 1.4) {
  return `<g>
    ${star8(cx, cy, r, `fill="${c1}" opacity=".95"`)}
    ${star8(cx, cy, r * 0.8, `fill="none" stroke="${c2}" stroke-width="${sw}"`, 22.5)}
    ${star8(cx, cy, r * 0.62, `fill="${c2}" opacity=".9"`, 0, 0.72)}
    ${circle(cx, cy, r * 0.3, `fill="${c3}"`)}
    ${star8(cx, cy, r * 0.22, `fill="${c2}"`, 22.5)}
  </g>`;
}

// Girih-style lattice tile (stars on a grid + a rotated star in each gap).
function tilePattern(id, stroke, sw = 1.2, size = 64, extra = '') {
  const corners = [[0, 0], [size, 0], [0, size], [size, size]]
    .map(([x, y]) => star8(x, y, size * 0.4, `fill="none" stroke="${stroke}" stroke-width="${sw}"`))
    .join('');
  const mid = star8(size / 2, size / 2, size * 0.27, `fill="none" stroke="${stroke}" stroke-width="${sw}"`, 22.5)
    + `<rect x="${size / 2 - size * 0.1}" y="${size / 2 - size * 0.1}" width="${size * 0.2}" height="${size * 0.2}" transform="rotate(45 ${size / 2} ${size / 2})" fill="none" stroke="${stroke}" stroke-width="${sw}"/>`;
  const edges = [[size / 2, 0], [0, size / 2], [size, size / 2], [size / 2, size]]
    .map(([x, y]) => star8(x, y, size * 0.09, `fill="${stroke}" opacity=".7"`, 22.5))
    .join('');
  return `<pattern id="${id}" width="${size}" height="${size}" patternUnits="userSpaceOnUse">${corners}${mid}${edges}${extra}</pattern>`;
}

// Simple repeated khatam dots, quieter than the lattice.
function dotPattern(id, color, size = 36) {
  return `<pattern id="${id}" width="${size}" height="${size}" patternUnits="userSpaceOnUse">
    ${star8(size / 2, size / 2, size * 0.14, `fill="${color}"`)}
    ${circle(0, 0, 1.4, `fill="${color}"`)}${circle(size, 0, 1.4, `fill="${color}"`)}${circle(0, size, 1.4, `fill="${color}"`)}${circle(size, size, 1.4, `fill="${color}"`)}
  </pattern>`;
}

// Deterministic tiny stars for night skies.
function starfield(n, w, h, seed = 7, color = '#FFF0CC', skip = [[0, 0, 360, 30]]) {
  let s = seed;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  let out = '';
  for (let i = 0; i < n; i++) {
    const x = rnd() * w, y = rnd() * h, r = 1 + rnd() * 2.2;
    if (skip.some(([a, b, c, d]) => x > a - 8 && x < c + 8 && y > b - 8 && y < d + 8)) continue;
    out += i % 4 === 0
      ? star8(x, y, r * 2.4, `fill="${color}" opacity="${f(0.5 + rnd() * 0.5)}"`)
      : circle(x, y, r * 0.7, `fill="${color}" opacity="${f(0.35 + rnd() * 0.5)}"`);
  }
  return out;
}

// ---------- icons (48 x 48 box). a = main colour, b = soft colour, c = accent ----------
const ICONS = {
  quran: `<path d="M24 13C18 8.5 10 8.5 5 11.5V38C10 35 18 35 24 39.5C30 35 38 35 43 38V11.5C38 8.5 30 8.5 24 13Z" fill="var(--b)" stroke="var(--a)" stroke-width="3" stroke-linejoin="round"/>
    <path d="M24 13V39" stroke="var(--a)" stroke-width="2.5"/>${star8(14.5, 23, 5.5, 'fill="var(--c)"')}${star8(33.5, 23, 5.5, 'fill="var(--c)"')}`,
  prayer: `<path d="M8 43V23C8 12 15 7 24 3C33 7 40 12 40 23V43Z" fill="var(--a)"/>
    <path d="M14 43V25C14 17.5 18.5 13 24 10.5C29.5 13 34 17.5 34 25V43Z" fill="var(--b)"/>
    ${star8(24, 27, 6.5, 'fill="var(--c)"')}${circle(24, 27, 2, 'fill="var(--a)"')}`,
  stories: `<rect x="10" y="8" width="28" height="32" fill="var(--b)"/>
    <rect x="5" y="5" width="38" height="8" rx="4" fill="var(--a)"/><rect x="5" y="35" width="38" height="8" rx="4" fill="var(--a)"/>
    <path d="M15 20H33M15 26H33M15 31H25" stroke="var(--a)" stroke-width="3" stroke-linecap="round"/>${star8(35, 28, 4.5, 'fill="var(--c)"')}`,
  manners: `<path d="M24 41C6 29 9 12 19.5 13.2C22.5 13.6 24 17 24 17C24 17 25.5 13.6 28.5 13.2C39 12 42 29 24 41Z" fill="var(--a)"/>
    ${star8(24, 26, 8, 'fill="var(--b)"')}${circle(24, 26, 2.6, 'fill="var(--a)"')}`,
  letters: `<rect x="5" y="5" width="38" height="38" rx="12" fill="var(--b)" stroke="var(--a)" stroke-width="3"/>
    <text x="24" y="35.5" text-anchor="middle" font-family="Reem" font-weight="700" font-size="30" fill="var(--a)">أ</text>`,
  maths: `<circle cx="24" cy="24" r="20" fill="var(--b)" stroke="var(--a)" stroke-width="3"/>
    <path d="M12.5 12.5l8 8m0-8l-8 8" stroke="var(--a)" stroke-width="3.2" stroke-linecap="round"/>
    <path d="M28 35h8" stroke="var(--a)" stroke-width="3.2" stroke-linecap="round"/>${circle(32, 29.5, 1.9, 'fill="var(--a)"')}${circle(32, 40.5, 1.9, 'fill="var(--a)"')}
    <path d="M27 14h10M32 9v10" stroke="var(--c)" stroke-width="3.2" stroke-linecap="round"/>`,
  colour: `<path d="M24 5C13 5 4 13.5 4 24C4 34.5 12.5 43 22 43C26.5 43 27.5 39.5 25.5 36.5C23.5 33.5 25.5 30 30 30H35.5C40.5 30 44 27 44 22C44 12.5 35.5 5 24 5Z" fill="var(--b)" stroke="var(--a)" stroke-width="3" stroke-linejoin="round"/>
    ${circle(14, 24, 3.6, `fill="${T.rose500}"`)}${circle(19, 14, 3.6, `fill="${T.sun500}"`)}${circle(30, 13, 3.6, `fill="${T.teal500}"`)}${circle(37, 21, 3.6, `fill="${T.night500}"`)}`,
  games: `<rect x="4" y="12" width="40" height="24" rx="12" fill="var(--b)" stroke="var(--a)" stroke-width="3"/>
    <path d="M15 19v10M10 24h10" stroke="var(--a)" stroke-width="3.4" stroke-linecap="round"/>${circle(32, 21.5, 2.8, 'fill="var(--c)"')}${circle(37.5, 27, 2.8, 'fill="var(--a)"')}`,
  rewards: `<path d="M24 2.5V7" stroke="var(--a)" stroke-width="3" stroke-linecap="round"/>
    <rect x="16.5" y="6.5" width="15" height="5.5" rx="2.5" fill="var(--a)"/>
    <path d="M14.5 12.5H33.5L37 23L33 36.5H15L11 23Z" fill="var(--b)" stroke="var(--a)" stroke-width="3" stroke-linejoin="round"/>
    <rect x="15.5" y="36" width="17" height="6" rx="2.5" fill="var(--a)"/>
    <path d="M24 18.5C28.5 23 28.5 27.5 24 31.5C19.5 27.5 19.5 23 24 18.5Z" fill="var(--c)"/>`,
  adhkar: (() => {
    let beads = '';
    for (let i = 0; i < 11; i++) {
      const a = (i / 11) * Math.PI * 2 - Math.PI / 2;
      beads += circle(24 + 15 * Math.cos(a), 20 + 15 * Math.sin(a), 3.6, i % 5 === 0 ? 'fill="var(--c)"' : 'fill="var(--a)"');
    }
    return `${beads}<path d="M24 36V43" stroke="var(--a)" stroke-width="2.6" stroke-linecap="round"/>${star8(24, 40.5, 4, 'fill="var(--c)"')}`;
  })(),
  lock: `<rect x="9" y="21" width="30" height="22" rx="7" fill="var(--a)"/><path d="M15 21V15C15 9.5 19 6 24 6C29 6 33 9.5 33 15V21" fill="none" stroke="var(--a)" stroke-width="4.5" stroke-linecap="round"/>${circle(24, 30, 3.6, 'fill="var(--b)"')}<path d="M24 31v6" stroke="var(--b)" stroke-width="3.2" stroke-linecap="round"/>`,
  finger: `<g fill="none" stroke="var(--a)" stroke-width="3.2" stroke-linecap="round"><path d="M10 20C10 11 16 6 24 6C32 6 38 11 38 20"/><path d="M16 42C14 36 14 30 14 24C14 19 18 15.5 24 15.5C30 15.5 34 19 34 24C34 30 34 34 36 39"/><path d="M22 43C21 38 20 33 20 25C20 22.5 22 21 24 21C26 21 28 22.5 28 25C28 32 29.5 36 30.5 39"/><path d="M24 27V32"/></g>`,
  back: `<path d="M17 9L31 24L17 39" fill="none" stroke="var(--a)" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>`,
  next: `<path d="M31 9L17 24L31 39" fill="none" stroke="var(--a)" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>`,
  home: `<path d="M6 23L24 7L42 23" fill="none" stroke="var(--a)" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M11 21V40H20V29H28V40H37V21L24 10Z" fill="var(--a)"/>`,
  play: `<path d="M14 7.5C14 6 15.6 5.1 16.9 5.9L40 22C41.2 22.9 41.2 25.1 40 26L16.9 42.1C15.6 42.9 14 42 14 40.5Z" fill="var(--a)"/>`,
  pause: `<rect x="11" y="8" width="9" height="32" rx="4" fill="var(--a)"/><rect x="28" y="8" width="9" height="32" rx="4" fill="var(--a)"/>`,
  mic: `<rect x="16" y="4" width="16" height="26" rx="8" fill="var(--a)"/><path d="M9 22C9 31 15 36.5 24 36.5C33 36.5 39 31 39 22" fill="none" stroke="var(--a)" stroke-width="4" stroke-linecap="round"/><path d="M24 37V44M17 44H31" stroke="var(--a)" stroke-width="4" stroke-linecap="round"/>`,
  trash: `<path d="M8 12H40" stroke="var(--a)" stroke-width="4" stroke-linecap="round"/><path d="M18 12V8H30V12" fill="none" stroke="var(--a)" stroke-width="4" stroke-linejoin="round"/><path d="M12 17L14 41C14 42 15 43 16 43H32C33 43 34 42 34 41L36 17Z" fill="var(--a)"/><path d="M20 23V37M28 23V37" stroke="var(--b)" stroke-width="3" stroke-linecap="round"/>`,
  redo: `<path d="M38 24C38 32.5 31.5 39 23 39C14.5 39 8 32.5 8 24C8 15.5 14.5 9 23 9C27 9 30.5 10.5 33 13" fill="none" stroke="var(--a)" stroke-width="5" stroke-linecap="round"/><path d="M34 4V15H23" fill="none" stroke="var(--a)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>`,
  speaker: `<path d="M6 19H14L24 10V38L14 29H6Z" fill="var(--a)" stroke="var(--a)" stroke-width="3" stroke-linejoin="round"/><path d="M31 17C34.5 20.5 34.5 27.5 31 31M36 11.5C42 18 42 30 36 36.5" fill="none" stroke="var(--a)" stroke-width="3.6" stroke-linecap="round"/>`,
  check: `<path d="M9 25L20 36L39 12" fill="none" stroke="var(--a)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>`,
  hourglass: `<path d="M12 5H36M12 43H36" stroke="var(--a)" stroke-width="4.5" stroke-linecap="round"/><path d="M15 5C15 17 24 19 24 24C24 29 15 31 15 43H33C33 31 24 29 24 24C24 19 33 17 33 5Z" fill="var(--b)" stroke="var(--a)" stroke-width="3" stroke-linejoin="round"/><path d="M19 38C21 33 27 33 29 38Z" fill="var(--a)"/>`,
  moon: `<path d="M33 6C22 8 14 16 14 27C14 35 19 41 27 42.5C16 45 4 36 4 24C4 12 15 3 27 4C29.5 4.2 31.5 5 33 6Z" fill="var(--a)" transform="translate(5 0)"/>${star8(37, 12, 4.5, 'fill="var(--c)"')}`,
  drop: `<path d="M24 4C32 14 38 21 38 29C38 37 32 43 24 43C16 43 10 37 10 29C10 21 16 14 24 4Z" fill="var(--a)"/><path d="M17 30C17 34 19.5 36.5 23 37" fill="none" stroke="var(--b)" stroke-width="3" stroke-linecap="round"/>`,
  plus: `<path d="M24 8V40M8 24H40" stroke="var(--a)" stroke-width="7" stroke-linecap="round"/>`,
  image: `<rect x="5" y="8" width="38" height="32" rx="7" fill="var(--b)" stroke="var(--a)" stroke-width="3.2"/>${circle(16, 19, 4, 'fill="var(--c)"')}<path d="M6 36L17 26L25 33L32 25L42 35" fill="none" stroke="var(--a)" stroke-width="3.2" stroke-linejoin="round" stroke-linecap="round"/>`,
  eraser: `<path d="M8 33L25 10C26 8.5 28.5 8.3 30 9.6L38 16C39.5 17.2 39.8 19.5 38.5 21L25 38H14Z" fill="var(--b)" stroke="var(--a)" stroke-width="3.2" stroke-linejoin="round"/><path d="M14 38H42" stroke="var(--a)" stroke-width="3.2" stroke-linecap="round"/>`,
  backspace: `<path d="M17 9H40C41.7 9 43 10.3 43 12V36C43 37.7 41.7 39 40 39H17L5 24Z" fill="var(--a)"/><path d="M24 18L35 30M35 18L24 30" stroke="var(--b)" stroke-width="3.6" stroke-linecap="round"/>`,
  undo: `<path d="M10 24C10 14.5 17 8.5 26 8.5C35 8.5 41 15 41 23.5C41 32 35 38.5 26 38.5H16" fill="none" stroke="var(--a)" stroke-width="5" stroke-linecap="round" transform="translate(51 0) scale(-1 1)"/><path d="M13 3L5 11L13 19" fill="none" stroke="var(--a)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" transform="translate(48 0) scale(-1 1)"/>`,
  sparkle: `<path d="M24 3C25.5 15 33 22.5 45 24C33 25.5 25.5 33 24 45C22.5 33 15 25.5 3 24C15 22.5 22.5 15 24 3Z" fill="var(--a)"/>`,
  shield: `<path d="M24 4L40 10V23C40 33 33 40 24 44C15 40 8 33 8 23V10Z" fill="var(--a)"/><path d="M16 24L22 30L33 18" fill="none" stroke="var(--b)" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/>`,
  cross: `<path d="M12 12L36 36M36 12L12 36" stroke="var(--a)" stroke-width="6" stroke-linecap="round"/>`,
  star: `${star8(24, 24, 22, 'fill="var(--a)"')}${star8(24, 24, 11, 'fill="var(--b)"', 22.5, 0.72)}`,
  bird: `<path d="M5 28C10 18 20 13 28 17C31 11 38 10 43 13C40 15 39 17 40 19C43 26 36 38 22 38C15 38 8 35 5 28Z" fill="var(--a)"/><path d="M30 24C26 24 21 27 19 31C25 32 31 30 33 25Z" fill="var(--b)"/>${circle(36, 16, 1.7, 'fill="var(--b)"')}`,
  bulb: `<path d="M24 5C15.5 5 10 11 10 18C10 23.5 13 26.5 15.5 29.5C17 31.5 17.5 33 17.5 35H30.5C30.5 33 31 31.5 32.5 29.5C35 26.5 38 23.5 38 18C38 11 32.5 5 24 5Z" fill="var(--a)"/><rect x="18" y="37.5" width="12" height="4.5" rx="2.2" fill="var(--b)"/>`,
};

function icon(name, size = 32, a = T.ink, b = T.paper, c = T.sun500, extra = '') {
  return `<svg class="ico" width="${size}" height="${size}" viewBox="0 0 48 48" style="--a:${a};--b:${b};--c:${c};${extra}" aria-hidden="true">${ICONS[name]}</svg>`;
}

// ---------- shared scenery ----------
function lantern(x, y, s = 1, lit = true, body = T.sun500, rim = T.night800, unlit = T.sand2) {
  return `<g transform="translate(${x} ${y}) scale(${s})">
    ${lit ? `<circle cx="0" cy="0" r="46" fill="url(#glowSun)"/>` : ''}
    <path d="M0 -34V-27" stroke="${rim}" stroke-width="3" stroke-linecap="round"/>
    <rect x="-9" y="-28" width="18" height="6" rx="3" fill="${rim}"/>
    <path d="M-9 -21H9L14 -4L9 18H-9L-14 -4Z" fill="${lit ? body : unlit}" stroke="${rim}" stroke-width="3" stroke-linejoin="round"/>
    <path d="M0 -21V18M-5 -21L-8 18M5 -21L8 18" stroke="${rim}" stroke-width="1.4" opacity=".4"/>
    <rect x="-10" y="17" width="20" height="7" rx="3" fill="${rim}"/>
    ${lit ? `<path d="M0 -10C6 -4 6 3 0 9C-6 3 -6 -4 0 -10Z" fill="#FFF8EA"/>` : ''}
  </g>`;
}
const drop = (x, y, s = 1, fill = T.teal500, op = 1) =>
  `<path transform="translate(${x} ${y}) scale(${s})" d="M0 -10C6 -2 8 3 8 6A8 8 0 0 1 -8 6C-8 3 -6 -2 0 -10Z" fill="${fill}" opacity="${op}"/>`;

const DEFS = `
  <radialGradient id="glowSun"><stop offset="0" stop-color="#FFD479" stop-opacity=".95"/><stop offset=".45" stop-color="#FFD479" stop-opacity=".35"/><stop offset="1" stop-color="#FFD479" stop-opacity="0"/></radialGradient>
  <radialGradient id="glowTeal"><stop offset="0" stop-color="#B6E6DF" stop-opacity=".9"/><stop offset="1" stop-color="#B6E6DF" stop-opacity="0"/></radialGradient>
  <radialGradient id="glowRose"><stop offset="0" stop-color="#F6A9BC" stop-opacity=".8"/><stop offset="1" stop-color="#F6A9BC" stop-opacity="0"/></radialGradient>`;

// ---------- page shell ----------
const CSS = `
@font-face{font-family:'Plex';src:url('${'../../../assets/fonts/'}IBMPlexSansArabic-Regular.ttf');font-weight:400}
@font-face{font-family:'Plex';src:url('../../../assets/fonts/IBMPlexSansArabic-Medium.ttf');font-weight:500}
@font-face{font-family:'Plex';src:url('../../../assets/fonts/IBMPlexSansArabic-SemiBold.ttf');font-weight:600}
@font-face{font-family:'Plex';src:url('../../../assets/fonts/IBMPlexSansArabic-Bold.ttf');font-weight:700}
@font-face{font-family:'Reem';src:url('../../../assets/fonts/ReemKufi-Variable.ttf');font-weight:400 700}
@font-face{font-family:'Amiri';src:url('../../../assets/fonts/Amiri-Regular.ttf');font-weight:400}
@font-face{font-family:'Amiri';src:url('../../../assets/fonts/Amiri-Bold.ttf');font-weight:700}
@font-face{font-family:'AmiriQuran';src:url('../../../assets/fonts/AmiriQuran-Regular.ttf');font-weight:400}
:root{
${Object.entries(T).map(([k, v]) => `--${k}:${v};`).join('')}
}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:360px;height:780px;overflow:hidden;background:#000}
body{font-family:'Plex',sans-serif;color:var(--ink);direction:rtl;-webkit-font-smoothing:antialiased}
.phone{position:relative;width:360px;height:780px;overflow:hidden;background:var(--paper)}
.abs{position:absolute}
.fill{position:absolute;inset:0;width:100%;height:100%}
.status{position:absolute;top:0;left:0;right:0;height:28px;display:flex;align-items:center;justify-content:space-between;padding:0 16px;font-size:13px;font-weight:600;z-index:50}
.status .r{display:flex;gap:6px;align-items:center}
.h1{font-family:'Reem',serif;font-weight:700;font-size:32px;line-height:1.25;word-spacing:.18em}
.h2{font-family:'Reem',serif;font-weight:700;font-size:26px;line-height:1.3;word-spacing:.18em}
.h3{font-family:'Reem',serif;font-weight:600;font-size:22px;line-height:1.35;word-spacing:.16em}
.body{font-size:20px;line-height:1.6;font-weight:500}
.small{font-size:16px;line-height:1.5;font-weight:500}
.btn{display:flex;align-items:center;justify-content:center;gap:10px;min-height:64px;padding:0 28px;border-radius:32px;font-family:'Plex';font-weight:700;font-size:20px;border:0;box-shadow:0 5px 0 rgba(23,20,63,.22),0 14px 22px -10px rgba(23,20,63,.45)}
.btn.gold{background:linear-gradient(180deg,#FFD479,#F5B431);color:var(--night900)}
.btn.teal{background:linear-gradient(180deg,#2FA59C,#17706C);color:#fff}
.btn.rose{background:linear-gradient(180deg,#F6A9BC,#E26A89);color:var(--night900)}
.btn.night{background:linear-gradient(180deg,#3B3590,#221E5A);color:#fff}
.btn.paper{background:var(--paper);color:var(--ink);box-shadow:0 5px 0 rgba(23,20,63,.14),0 12px 20px -10px rgba(23,20,63,.35)}
.btn.ghost{background:transparent;color:inherit;box-shadow:none;border:2.5px solid currentColor}
.round{width:64px;height:64px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex:none}
.chip{display:inline-flex;align-items:center;gap:8px;height:40px;padding:0 16px;border-radius:20px;font-weight:700;font-size:16px}
.card{background:var(--paper);border-radius:28px;box-shadow:0 2px 0 rgba(255,255,255,.7) inset,0 14px 28px -14px rgba(38,33,79,.5)}
.ph{display:inline-block;direction:rtl;font-family:'Plex';font-weight:600;font-size:14px;color:var(--sun700);background:var(--sun100);border:1.5px dashed var(--sun700);border-radius:10px;padding:2px 10px}
.num{font-feature-settings:'tnum'}
.topbar{position:absolute;top:28px;left:0;right:0;height:80px;display:flex;align-items:center;justify-content:space-between;padding:0 16px;z-index:20}
.topbar .title{font-family:'Reem';font-weight:700;font-size:26px;text-align:center;flex:1;word-spacing:.18em}
`;

const BATT = (c) => `<svg width="26" height="13" viewBox="0 0 26 13"><rect x=".7" y=".7" width="21" height="11.6" rx="3.2" fill="none" stroke="${c}" stroke-width="1.4"/><rect x="2.6" y="2.6" width="14" height="7.8" rx="1.6" fill="${c}"/><rect x="23" y="4" width="2.3" height="5" rx="1" fill="${c}"/></svg>`;
const status = (c = T.ink) => `<div class="status" style="color:${c}"><span class="num">٩:٤١</span><span class="r">${BATT(c)}</span></div>`;

function page({ title, body, bg = T.paper, css = '', statusColor = T.ink, defs = '' }) {
  return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>${title}</title>
<meta name="viewport" content="width=360, initial-scale=1">
<style>${CSS}${css}</style></head><body>
<div class="phone" style="background:${bg}">
<svg width="0" height="0" style="position:absolute"><defs>${DEFS}${defs}</defs></svg>
${status(statusColor)}
${body}
</div></body></html>`;
}

// Standard header for kids screens: home (round) on the start side, title, star count on the end side.
function kidsTop({ title, ink = T.ink, ring = T.night800, ringBg = T.paper, stars = '٢٤', showStars = true, homeIcon = 'home' }) {
  return `<div class="topbar">
    <div class="round" style="background:${ringBg};box-shadow:0 4px 0 rgba(23,20,63,.18)">${icon(homeIcon, 32, ring, ringBg, T.sun500)}</div>
    <div class="title" style="color:${ink}">${title}</div>
    ${showStars ? `<div class="chip" style="background:${T.night800};color:#fff;height:56px;border-radius:28px;padding:0 14px 0 16px;font-size:20px;gap:6px;border:1.5px solid rgba(255,248,234,.28)">${icon('star', 28, T.sun500, T.night800)}<span class="num">${stars}</span></div>` : '<div style="width:64px"></div>'}
  </div>`;
}

// Quran-style placeholder text row (never real verses). words = [{t, state}] state: done | now | next
function wordRow(words, size = 30) {
  return `<div style="display:flex;gap:10px 8px;flex-wrap:wrap;justify-content:center;direction:rtl">` +
    words.map((w) => {
      const st = w.state;
      const style = st === 'now'
        ? `background:linear-gradient(180deg,${T.sun300},${T.sun500});color:${T.night900};box-shadow:0 0 0 4px rgba(245,180,49,.28),0 8px 16px -6px rgba(168,104,15,.6);transform:translateY(-3px)`
        : st === 'done'
          ? `color:${T.teal700};background:${T.teal100}`
          : `color:${T.ink}`;
      return `<span style="font-family:'AmiriQuran';font-size:${size}px;line-height:1.55;padding:2px 12px;border-radius:16px;${style}">${w.t}</span>`;
    }).join('') + `</div>`;
}

module.exports = { T, f, ad, star8, star5, circle, rosette, tilePattern, dotPattern, starfield, icon, ICONS, lantern, drop, DEFS, page, kidsTop, wordRow, status, BATT, CSS };
