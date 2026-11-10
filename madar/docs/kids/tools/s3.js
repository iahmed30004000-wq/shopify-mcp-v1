// Screens 07a, 07b, 08a, 08b
const L = require('./lib');
const { T, ad, star8, circle, rosette, tilePattern, starfield, icon, page, kidsTop } = L;

const seg = (items, activeIdx, tone = T.teal) => `<div class="abs" style="top:118px;left:16px;right:16px;height:64px;border-radius:32px;background:${tone.soft};display:flex;padding:6px;gap:6px">
  ${items.map((t, i) => `<div style="flex:1;border-radius:26px;${i === activeIdx ? `background:linear-gradient(180deg,${tone.a},${tone.b});color:#fff` : `color:${tone.ink}`};display:flex;align-items:center;justify-content:center;font-weight:700;font-size:19px">${t}</div>`).join('')}</div>`;

// ---------- 07a: Arabic letters ----------
function s07a() {
  const bg = `<svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p', T.sun500, 1, 64)}</defs><rect width="360" height="780" fill="url(#p)" opacity=".12"/></svg>`;
  const chip = (t, active) => `<div style="flex:none;width:64px;height:64px;border-radius:22px;display:flex;align-items:center;justify-content:center;font-family:'Amiri';font-weight:700;font-size:34px;${active ? `background:linear-gradient(180deg,${T.sun300},${T.sun500});color:${T.night900};box-shadow:0 5px 0 rgba(168,104,15,.45)` : `background:${T.paper};color:${T.ink};box-shadow:0 4px 0 rgba(38,33,79,.12)`}">${t}</div>`;
  const strip = `<div class="abs" style="top:116px;left:0;right:0;display:flex;gap:10px;padding:0 16px;direction:rtl;overflow:hidden">${['ط', 'ظ', 'ع', 'غ', 'ف'].map((t) => chip(t, t === 'ع')).join('')}</div>`;
  const form = (g, label, on) => `<div style="flex:1;text-align:center"><div style="height:78px;border-radius:20px;background:${on ? T.sun100 : '#fff'};border:2px solid ${on ? T.sun500 : T.sand2};display:flex;align-items:center;justify-content:center;font-family:'Amiri';font-weight:700;font-size:38px;line-height:2;color:${T.night800}">${g}</div><div style="font-size:14px;font-weight:600;margin-top:4px;color:${T.ink2};line-height:1.2">${label}</div></div>`;
  const big = `<div class="abs card" style="top:194px;left:16px;right:16px;height:252px;background:#FFFDF6;overflow:hidden">
    <svg class="fill" viewBox="0 0 328 252"><circle cx="86" cy="76" r="70" fill="${T.sun100}"/>${star8(86, 76, 66, `fill="none" stroke="${T.sun500}" stroke-width="1.6" stroke-dasharray="2 7" stroke-linecap="round"`)}</svg>
    <div style="position:absolute;top:0px;left:16px;width:140px;text-align:center;font-family:'Amiri';font-weight:700;font-size:100px;line-height:1.25;color:${T.night800}">ع</div>
    <div style="position:absolute;top:22px;right:20px;width:140px;text-align:right"><div class="h2" style="color:${T.night800}">حرف العين</div><div class="small" style="color:${T.ink2};margin-top:2px">المس وسمّع الحرف</div></div>
    <div class="round" style="position:absolute;top:82px;right:20px;background:${T.teal100};box-shadow:0 5px 0 rgba(15,85,82,.25)">${icon('speaker', 32, T.teal700)}</div>
    <div style="position:absolute;bottom:14px;left:14px;right:14px;display:flex;gap:8px">${form('ع', 'وحدها', 0)}${form('عـ', 'أول الكلمة', 1)}${form('ـعـ', 'وسط الكلمة', 0)}${form('ـع', 'آخر الكلمة', 0)}</div>
  </div>`;
  // grapes
  const grapes = (() => {
    const pts = [[0, 0], [-14, 0], [14, 0], [-7, 13], [7, 13], [0, 26], [-21, 13], [21, 13], [-14, 26], [14, 26], [0, 39]];
    return `<svg width="96" height="96" viewBox="-40 -30 80 82"><path d="M0 -14C0 -22 4 -26 10 -28" stroke="${T.night800}" stroke-width="3" fill="none" stroke-linecap="round"/><path d="M6 -24C14 -34 26 -30 28 -22C20 -18 12 -18 6 -24Z" fill="${T.teal500}"/>
      <g transform="translate(0 -8)">${pts.map(([x, y], i) => circle(x, y, 8.5, `fill="${i % 3 === 0 ? T.night500 : i % 3 === 1 ? '#6B63C8' : '#4A4399'}" stroke="${T.night800}" stroke-width="1"`) + circle(x - 3, y - 3, 2.2, 'fill="#fff" opacity=".6"')).join('')}</g></svg>`;
  })();
  const word = `<div class="abs card" style="top:458px;left:16px;right:16px;height:124px;background:#FFFDF6;display:flex;align-items:center;gap:16px;padding:0 20px">
    <div style="width:104px;height:104px;border-radius:50%;background:${T.night100};display:flex;align-items:center;justify-content:center">${grapes}</div>
    <div style="flex:1;font-family:'Amiri';font-weight:700;font-size:64px;color:${T.night800};line-height:1.3"><span style="color:${T.sun700}">ع</span>ِنَب</div>
    <div class="round" style="background:${T.teal100};box-shadow:0 5px 0 rgba(15,85,82,.25)">${icon('speaker', 32, T.teal700)}</div>
  </div>`;
  const acts = `<div class="abs" style="top:600px;left:16px;right:16px;display:flex;flex-direction:column;gap:12px">
    <div class="btn rose" style="width:100%">${icon('colour', 30, T.night900, T.rose100)} اكتب الحرف بإصبعك</div>
    <div style="display:flex;gap:12px"><div class="round" style="background:${T.paper};box-shadow:0 5px 0 rgba(38,33,79,.14)">${icon('back', 28, T.ink)}</div><div class="btn gold" style="flex:1">الحرف الجاي ${icon('next', 24, T.night900)}</div></div>
  </div>`;
  return page({ title: 'الحروف', body: bg + kidsTop({ title: 'الحروف' }) + strip + big + word + acts, bg: `linear-gradient(180deg,${T.sand},${T.paper})` });
}

// ---------- 07b: maths ----------
function s07b() {
  const bg = `<svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p', T.teal500, 1, 64)}</defs><rect width="360" height="780" fill="url(#p)" opacity=".10"/></svg>`;
  const tabs = seg(['الضرب', 'القسمة', 'الكسور'], 0, { soft: T.teal100, a: T.teal500, b: T.teal700, ink: T.teal800 });
  const cols = [T.teal500, T.sun500, T.rose500];
  const dots = `<svg width="196" height="110" viewBox="0 0 196 110">${[0, 1, 2].map((r) => [0, 1, 2, 3].map((c) => circle(26 + c * 48, 20 + r * 36, 14, `fill="${cols[r]}"`) + circle(21 + c * 48, 15 + r * 36, 4, 'fill="#fff" opacity=".55"')).join('')).join('')}</svg>`;
  const q = `<div class="abs card" style="top:196px;left:16px;right:16px;height:256px;background:#FFFDF6;text-align:center">
    <div style="margin-top:16px;font-family:'Reem';font-weight:700;font-size:64px;color:${T.night800};direction:ltr;unicode-bidi:bidi-override" class="num">${ad(3)} × ${ad(4)} = <span style="color:${T.rose500}">؟</span></div>
    <div style="display:flex;justify-content:center;margin-top:6px">${dots}</div>
    <div class="small" style="color:${T.ink2};margin-top:2px;font-size:15px">٣ صفوف، في كل صف ٤</div>
  </div>`;
  const ans = (t, state) => `<div style="flex:1;height:84px;border-radius:28px;display:flex;align-items:center;justify-content:center;font-family:'Reem';font-weight:700;font-size:40px;${state === 'sel' ? `background:linear-gradient(180deg,${T.sun300},${T.sun500});color:${T.night900};box-shadow:0 0 0 5px rgba(245,180,49,.35),0 6px 0 rgba(168,104,15,.5)` : `background:${T.paper};color:${T.night800};box-shadow:0 5px 0 rgba(38,33,79,.14)`}">${t}</div>`;
  const answers = `<div class="abs" style="top:468px;left:16px;right:16px;display:flex;gap:12px">${ans(ad(14), '')}${ans(ad(12), 'sel')}${ans(ad(9), '')}</div>`;
  // previews: division + fraction
  const share = `<svg width="120" height="64" viewBox="0 0 132 70">${[0, 1, 2].map((g) => `<rect x="${4 + g * 44}" y="6" width="38" height="58" rx="12" fill="${T.teal100}" stroke="${T.teal500}" stroke-width="2"/>` + [0, 1, 2, 3].map((i) => circle(15 + g * 44 + (i % 2) * 16, 22 + Math.floor(i / 2) * 22, 6, `fill="${cols[g]}"`)).join('')).join('')}</svg>`;
  const pie = `<svg width="60" height="60" viewBox="-35 -35 70 70">${[0, 1, 2, 3].map((i) => {
    const a0 = (i * 90 - 90) * Math.PI / 180, a1 = ((i + 1) * 90 - 90) * Math.PI / 180;
    return `<path d="M0 0L${32 * Math.cos(a0)} ${32 * Math.sin(a0)}A32 32 0 0 1 ${32 * Math.cos(a1)} ${32 * Math.sin(a1)}Z" fill="${i < 3 ? T.rose500 : '#fff'}" stroke="${T.night800}" stroke-width="2"/>`;
  }).join('')}</svg>`;
  const mini = (title, art, sub) => `<div style="flex:1;height:150px;border-radius:28px;background:${T.paper};box-shadow:0 5px 0 rgba(38,33,79,.12);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;text-align:center"><div style="font-family:'Reem';font-weight:700;font-size:30px;color:${T.night800};direction:ltr;unicode-bidi:bidi-override" class="num">${title}</div>${art}<div style="font-weight:700;font-size:16px;color:${T.ink2}">${sub}</div></div>`;
  const frac = `<div style="display:flex;flex-direction:column;align-items:center;line-height:1;font-family:'Reem';font-weight:700;font-size:26px"><span>${ad(3)}</span><span style="width:30px;height:3px;background:${T.night800};margin:3px 0;border-radius:2px"></span><span>${ad(4)}</span></div>`;
  const previews = `<div class="abs" style="top:566px;left:16px;right:16px"><div class="h3" style="color:${T.teal800};margin-bottom:6px">جرّب كمان</div>
    <div style="display:flex;gap:12px">${mini(`${ad(12)} ÷ ${ad(3)}`, share, 'قسمة')}${mini(frac, pie, 'كسور')}</div></div>`;
  return page({ title: 'الحساب', body: bg + kidsTop({ title: 'الحساب' }) + tabs + q + answers + previews, bg: `linear-gradient(180deg,${T.teal100},${T.paper} 60%)` });
}

// ---------- 08a: colouring gallery + import card ----------
function thumbMandala(i) {
  const cols = [T.rose500, T.teal500, T.sun500, T.night500];
  let s = '';
  for (let k = 0; k < 8; k++) {
    const a = (k * 45 - 90) * Math.PI / 180;
    const p = (r, d) => `${(r * Math.cos(a + d)).toFixed(1)},${(r * Math.sin(a + d)).toFixed(1)}`;
    s += `<polygon points="${p(12, 0)} ${p(30, 0.32)} ${p(52, 0)} ${p(30, -0.32)}" fill="${(k + i) % 3 === 0 ? cols[(k + i) % 4] : '#fff'}" stroke="${T.night800}" stroke-width="2"/>`;
  }
  return `<svg width="108" height="108" viewBox="-60 -60 120 120">${s}${circle(0, 0, 11, `fill="${T.sun300}" stroke="${T.night800}" stroke-width="2"`)}</svg>`;
}
function thumbLantern() {
  return `<svg width="108" height="108" viewBox="-50 -56 100 112"><g fill="#fff" stroke="${T.night800}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">
    <path d="M0 -50V-38"/><rect x="-14" y="-40" width="28" height="10" rx="4"/><path d="M-14 -28H14L22 0L14 30H-14L-22 0Z"/><path d="M0 -28V30M-9 -28L-12 30M9 -28L12 30" fill="none"/><rect x="-16" y="30" width="32" height="12" rx="4"/><path d="M-6 42V50M6 42V50"/></g></svg>`;
}
function thumbBird() {
  return `<svg width="108" height="108" viewBox="0 0 120 120"><g fill="#fff" stroke="${T.night800}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"><path d="M14 74C22 50 46 38 64 46C70 32 88 28 104 36C96 40 94 46 97 52C104 70 86 100 54 100C34 100 18 90 14 74Z"/><path d="M70 62C60 62 50 68 46 78C60 80 74 74 78 64Z"/><circle cx="88" cy="42" r="3" fill="${T.night800}"/><path d="M40 100L36 112M56 100L56 112"/></g></svg>`;
}
function s08a() {
  const bg = `<svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p', T.rose500, 1, 64)}</defs><rect width="360" height="780" fill="url(#p)" opacity=".10"/></svg>`;
  const th = (art, own, badge) => `<div style="flex:1;height:140px;border-radius:26px;background:#fff;box-shadow:0 5px 0 rgba(38,33,79,.14);display:flex;align-items:center;justify-content:center;position:relative">${art}${own ? `<div style="position:absolute;top:8px;right:8px;background:${T.teal100};color:${T.teal800};font-weight:700;font-size:13px;border-radius:12px;padding:2px 10px">صورتي</div>` : ''}${badge ? `<div style="position:absolute;bottom:8px;left:8px;width:34px;height:34px;border-radius:50%;background:${T.teal500};display:flex;align-items:center;justify-content:center">${icon('check', 20, '#fff')}</div>` : ''}</div>`;
  const importCard = `<div class="abs" style="top:118px;left:16px;right:16px;height:236px;border-radius:32px;background:${T.paper};border:3px dashed ${T.rose500};box-shadow:0 14px 26px -16px rgba(38,33,79,.5);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;text-align:center">
    <div style="position:absolute;top:14px;right:16px;display:flex;align-items:center;gap:6px;background:${T.night100};color:${T.night700};font-weight:700;font-size:14px;border-radius:14px;padding:3px 12px">${icon('lock', 16, T.night700, T.night100)} للأهل</div>
    <div class="round" style="width:72px;height:72px;background:${T.rose100}">${icon('image', 40, T.rose700, T.rose100, T.sun500)}</div>
    <div class="h3" style="color:${T.night800}">أضيف صورة من جوالي</div>
    <div class="small" style="color:${T.ink2};padding:0 18px;line-height:1.4;font-size:15.5px">بتضلّ على جوالك، وما بتروح لأي مكان</div>
    <div class="btn rose" style="min-height:64px;padding:0 22px;font-size:18px;margin-top:2px">${icon('plus', 22, T.night900)} اختر ملف</div>
  </div>`;
  const body = `${importCard}
  <div class="abs" style="top:368px;left:16px;right:16px"><div class="h3" style="color:${T.rose700};margin-bottom:6px">صوري</div>
    <div style="display:flex;gap:12px">${th(thumbLantern(), true, false)}${th(thumbBird(), true, true)}</div></div>
  <div class="abs" style="top:566px;left:16px;right:16px"><div class="h3" style="color:${T.night700};margin-bottom:6px">صور المدار</div>
    <div style="display:flex;gap:12px">${th(thumbMandala(0), false, true)}${th(thumbMandala(1), false, false)}</div></div>`;
  return page({ title: 'التلوين — المعرض', body: bg + kidsTop({ title: 'التلوين' }) + body, bg: `linear-gradient(180deg,${T.rose100},${T.paper} 60%)` });
}

// ---------- 08b: a coloured page ----------
function s08b() {
  const cols = [T.rose500, T.sun500, T.teal500, T.night500, T.rose300, T.sun300, T.teal200, T.night300];
  const fill = (k) => (k === 'w' ? '#fff' : k);
  let petals = '', gaps = '', ring = '';
  const petalFill = [T.rose500, T.sun500, T.teal500, 'w', T.rose500, 'w', T.teal500, T.sun500];
  for (let k = 0; k < 8; k++) {
    const a = (k * 45 - 90) * Math.PI / 180, b = a + Math.PI / 8;
    const p = (r, ang) => `${(r * Math.cos(ang)).toFixed(1)},${(r * Math.sin(ang)).toFixed(1)}`;
    petals += `<polygon points="${p(46, a)} ${p(92, a - 0.3)} ${p(148, a)} ${p(92, a + 0.3)}" fill="${fill(petalFill[k])}" stroke="${T.night800}" stroke-width="3.2" stroke-linejoin="round"/>`;
    petals += `<polygon points="${p(70, a)} ${p(92, a - 0.12)} ${p(116, a)} ${p(92, a + 0.12)}" fill="${fill(k % 2 ? 'w' : T.sun300)}" stroke="${T.night800}" stroke-width="2.4"/>`;
    gaps += `<polygon points="${p(60, b)} ${p(98, b - 0.14)} ${p(124, b)} ${p(98, b + 0.14)}" fill="${fill([T.night300, 'w', T.teal200, 'w', 'w', T.night300, 'w', T.rose300][k])}" stroke="${T.night800}" stroke-width="2.4" stroke-linejoin="round"/>`;
    ring += `<polygon points="${p(24, a)} ${p(36, a + Math.PI / 8)} ${p(46, a)} ${p(36, a - Math.PI / 8)}" fill="${fill(k % 2 ? T.sun300 : 'w')}" stroke="${T.night800}" stroke-width="2.4"/>`;
  }
  const mandala = `<svg width="312" height="312" viewBox="-160 -160 320 320">${gaps}${petals}${ring}
    ${circle(0, 0, 24, `fill="${T.sun500}" stroke="${T.night800}" stroke-width="3"`)}${star8(0, 0, 15, `fill="${fill('w')}" stroke="${T.night800}" stroke-width="2.4"`)}
    ${circle(0, 0, 156, `fill="none" stroke="${T.night800}" stroke-width="3" stroke-dasharray="1 9" stroke-linecap="round"`)}</svg>`;
  const canvas = `<div class="abs card" style="top:118px;left:16px;right:16px;height:360px;background:#fff;display:flex;align-items:center;justify-content:center">${mandala}
    </div>`;
  const sw = (c, on) => `<div style="flex:none;width:64px;height:64px;border-radius:50%;background:${c};${on ? `box-shadow:0 0 0 4px ${T.paper},0 0 0 8px ${T.night800}` : 'box-shadow:0 4px 0 rgba(38,33,79,.25)'};border:2px solid rgba(255,255,255,.5)"></div>`;
  const palette = `<div class="abs" style="top:508px;left:0;right:0;display:flex;gap:11px;padding:10px 22px 10px 16px;direction:rtl;overflow:hidden">${cols.map((c, i) => sw(c, i === 0)).join('')}</div>`;
  const tools = `<div class="abs" style="top:600px;left:16px;right:16px;display:flex;gap:12px;align-items:center">
    <div class="round" style="background:${T.paper};box-shadow:0 5px 0 rgba(38,33,79,.14)">${icon('redo', 30, T.ink, T.paper, T.sun500, 'transform:scaleX(-1)')}</div>
    <div class="round" style="background:${T.paper};box-shadow:0 5px 0 rgba(38,33,79,.14)">${icon('eraser', 32, T.ink, T.rose300)}</div>
    <div class="btn teal" style="flex:1;font-size:21px">${icon('check', 24, '#fff')} خلصت</div>
  </div>
  <div class="abs" style="top:690px;left:16px;right:16px;text-align:center;font-size:15.5px;color:${T.ink2};font-weight:600">${icon('shield', 20, T.teal700, '#fff')} الصورة وألوانها محفوظة على جوالك فقط</div>`;
  return page({ title: 'التلوين — صفحة ملوّنة', body: kidsTop({ title: 'التلوين' }) + canvas + palette + tools, bg: `linear-gradient(180deg,${T.rose100},${T.paper} 60%)` });
}

module.exports = { s07a, s07b, s08a, s08b };
