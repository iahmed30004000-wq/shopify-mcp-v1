// Screens 09a, 09b, 09c, 10, 11, 12, 13
const L = require('./lib');
const { T, ad, star8, circle, rosette, tilePattern, starfield, icon, lantern, drop, page, kidsTop } = L;

const bgPat = (c, o = 0.1, size = 64) => `<svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p', c, 1, size)}</defs><rect width="360" height="780" fill="url(#p)" opacity="${o}"/></svg>`;

// ---------- 09a: stories in the parent's voice (child side) ----------
function s09a() {
  const ring = (() => {
    const bars = [];
    for (let i = 0; i < 48; i++) {
      const a = (i / 48) * Math.PI * 2 - Math.PI / 2;
      const h = 8 + 16 * Math.abs(Math.sin(i * 0.9) * Math.cos(i * 0.37));
      const r0 = 88, r1 = r0 + h;
      bars.push(`<line x1="${(110 + r0 * Math.cos(a)).toFixed(1)}" y1="${(110 + r0 * Math.sin(a)).toFixed(1)}" x2="${(110 + r1 * Math.cos(a)).toFixed(1)}" y2="${(110 + r1 * Math.sin(a)).toFixed(1)}" stroke="${i < 17 ? T.sun500 : T.night300}" stroke-width="4" stroke-linecap="round"/>`);
    }
    return `<svg width="220" height="220" viewBox="0 0 220 220">${bars.join('')}${circle(110, 110, 78, `fill="${T.night700}"`)}${star8(110, 110, 62, `fill="${T.night800}" stroke="${T.sun300}" stroke-width="1.5"`)}${star8(110, 110, 40, `fill="none" stroke="${T.sun300}" stroke-width="1.2"`, 22.5)}</svg>`;
  })();
  const now = `<div class="abs" style="top:118px;left:16px;right:16px;height:322px;border-radius:34px;background:linear-gradient(180deg,${T.night800},${T.night700});box-shadow:0 18px 30px -16px rgba(23,20,63,.7);overflow:hidden;text-align:center">
    <svg class="fill" viewBox="0 0 328 322"><defs>${tilePattern('pn', T.sun300, 1, 56)}</defs><rect width="328" height="322" fill="url(#pn)" opacity=".08"/>${starfield(20, 328, 120, 4, '#FFF0CC', [[0, 0, 0, 0]])}</svg>
    <div style="position:absolute;top:14px;right:16px" class="chip"><span style="background:${T.sun500};color:${T.night900};border-radius:18px;padding:5px 14px;font-size:16px;display:inline-flex;gap:6px;align-items:center">${icon('mic', 18, T.night900)} بصوت بابا</span></div>
    <div style="position:absolute;top:44px;left:0;right:0;display:flex;justify-content:center">${ring}</div>
    <div style="position:absolute;top:98px;left:0;right:0;display:flex;justify-content:center"><div style="width:112px;height:112px;display:flex;align-items:center;justify-content:center">${icon('stories', 56, T.sun300, T.night800, T.sun500)}</div></div>
    <div class="h2" style="position:absolute;top:262px;left:0;right:0;color:#fff;font-size:28px">حكاية قبل النوم</div>
    <div class="num" style="position:absolute;top:268px;display:none"></div>
  </div>`;
  const bar = `<div class="abs" style="top:452px;left:28px;right:28px"><div style="height:12px;border-radius:6px;background:${T.sand2}"><div style="width:42%;height:12px;border-radius:6px;background:linear-gradient(270deg,${T.teal500},${T.sun500});float:right"></div></div>
    <div class="num" style="display:flex;justify-content:space-between;font-size:15px;font-weight:600;color:${T.ink2};margin-top:6px"><span>١:٢٤</span><span>٣:٢٠</span></div></div>`;
  const ctl = `<div class="abs" style="top:490px;left:0;right:0;display:flex;justify-content:center;gap:20px;align-items:center">
    <div class="round" style="background:${T.paper};box-shadow:0 5px 0 rgba(38,33,79,.14)">${icon('back', 28, T.ink)}</div>
    <div class="round" style="width:88px;height:88px;background:linear-gradient(180deg,${T.sun300},${T.sun500});box-shadow:0 6px 0 rgba(168,104,15,.5),0 0 0 9px rgba(245,180,49,.22)">${icon('pause', 42, T.night900)}</div>
    <div class="round" style="background:${T.paper};box-shadow:0 5px 0 rgba(38,33,79,.14)">${icon('next', 28, T.ink)}</div>
  </div>`;
  const row = (title, dur, active) => `<div style="height:72px;border-radius:26px;background:${active ? T.sun100 : T.paper};${active ? `border:2.5px solid ${T.sun500}` : ''};box-shadow:0 4px 0 rgba(38,33,79,.12);display:flex;align-items:center;gap:12px;padding:0 10px 0 16px">
      <div class="round" style="width:56px;height:56px;background:${active ? T.sun500 : T.night100}">${icon(active ? 'pause' : 'play', 26, active ? T.night900 : T.night700)}</div>
      <div style="flex:1;font-weight:700;font-size:19px;color:${T.night800}">${title}</div><div class="num" style="font-size:15px;font-weight:600;color:${T.ink2}">${dur}</div></div>`;
  const list = `<div class="abs" style="top:600px;left:16px;right:16px;display:flex;flex-direction:column;gap:8px">${row('حكاية قبل النوم', '٣ دقايق', true)}${row('حكاية الفانوس', '٥ دقايق', false)}</div>`;
  return page({ title: 'حكايات بصوت بابا', body: bgPat(T.night500, 0.07) + kidsTop({ title: 'حكايات بابا' }) + now + bar + ctl + list, bg: `linear-gradient(180deg,${T.night100},${T.paper} 70%)` });
}

// ---------- 09b: parent corner, recording management ----------
function s09b() {
  const rb = (ic, label, bg, ink) => `<div style="text-align:center"><div class="round" style="background:${bg};box-shadow:0 4px 0 rgba(0,0,0,.25)">${icon(ic, 30, ink)}</div><div style="font-size:14px;font-weight:700;color:${T.night100};margin-top:3px">${label}</div></div>`;
  const card = (top, h, inner) => `<div class="abs" style="top:${top}px;left:16px;right:16px;height:${h}px;border-radius:28px;background:rgba(255,248,234,.09);border:1.5px solid rgba(255,212,121,.22);padding:14px 16px">${inner}</div>`;
  const head = (t, sub, subColor = T.night300) => `<div style="display:flex;justify-content:space-between;align-items:baseline"><div class="h3" style="color:#fff;font-size:22px">${t}</div><div class="num" style="font-size:15px;font-weight:600;color:${subColor}">${sub}</div></div>`;
  const wave = (n, c, on) => `<div style="display:flex;gap:4px;align-items:center;height:36px;justify-content:center">${Array.from({ length: n }, (_, i) => `<div style="width:5px;border-radius:3px;height:${6 + Math.abs(Math.sin(i * 0.8)) * 26}px;background:${on && i < n * 0.6 ? c : 'rgba(255,248,234,.3)'}"></div>`).join('')}</div>`;
  const c1 = card(178, 180, `${head('حكاية قبل النوم', '٣:٢٠')}<div style="margin-top:6px">${wave(34, T.sun300, true)}</div>
    <div style="display:flex;justify-content:space-between;margin-top:6px;padding:0 6px">${rb('play', 'شغّل', T.sun300, T.night900)}${rb('redo', 'سجّل من جديد', T.teal500, '#fff')}${rb('trash', 'احذف', T.rose300, T.night900)}</div>`);
  const c2 = card(370, 196, `${head('حكاية السفر', 'قيد التسجيل', T.rose300)}<div style="margin-top:6px;position:relative">${wave(34, T.rose300, true)}</div>
    <div style="display:flex;align-items:center;justify-content:space-between;margin-top:4px;padding:0 6px">
      <div class="num" style="font-family:'Reem';font-weight:700;font-size:36px;color:${T.rose300};direction:ltr">٠:٤٨</div>
      <div style="display:flex;gap:16px">${rb('cross', 'ألغِ', 'rgba(255,248,234,.2)', '#fff')}
      <div style="text-align:center"><div class="round" style="width:72px;height:72px;background:${T.rose500};box-shadow:0 0 0 8px rgba(226,106,137,.3)"><div style="width:26px;height:26px;border-radius:7px;background:#fff"></div></div><div style="font-size:14px;font-weight:700;color:${T.night100};margin-top:3px">وقّف واحفظ</div></div></div></div>`);
  const c3 = card(578, 120, `${head('حكاية الفانوس', 'فاضية')}<div class="btn rose" style="margin-top:12px;width:100%;min-height:64px">${icon('mic', 28, T.night900)} سجّل بصوتك</div>`);
  const hdr = `<div class="abs" style="top:46px;left:16px;right:16px;display:flex;align-items:center;gap:12px">
    <div class="round" style="background:${T.teal700};box-shadow:0 4px 0 rgba(0,0,0,.25)">${icon('home', 30, '#fff')}</div>
    <div style="flex:1"><span class="chip" style="background:${T.night700};color:${T.sun300};height:30px;font-size:14px">${icon('lock', 16, T.sun300, T.night700)} ركن الأهل</span><div class="h2" style="color:#fff;margin-top:2px">حكاياتي بصوتي</div></div></div>`;
  const note = `<div class="abs" style="top:128px;left:20px;right:20px;color:${T.night100};font-size:16px;line-height:1.5;font-weight:500">سجّل حكايات لإبنك، وهو بيسمعها بصوتك.</div>
  <div class="abs" style="top:706px;left:20px;right:20px;color:${T.night300};font-size:15px;line-height:1.5;font-weight:500;text-align:center">${icon('shield', 18, T.teal200, T.night800)} التسجيلات بتضلّ على هالجوال فقط. إذا اجتك مكالمة، التسجيل بيوقف وبيتحفظ.</div>`;
  return page({ title: 'ركن الأهل — حكاياتي بصوتي', body: bgPat(T.sun300, 0.06) + hdr + note + c1 + c2 + c3, bg: `linear-gradient(180deg,${T.night900},${T.night800})`, statusColor: T.night100 });
}

// ---------- 09c: interactive story with voice and motion ----------
function s09c() {
  const body = `<svg class="abs" style="top:0;left:0" width="360" height="780" viewBox="0 0 360 780">
    <defs>
      <linearGradient id="isky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.night900}"/><stop offset=".55" stop-color="${T.night700}"/><stop offset="1" stop-color="${T.rose500}"/></linearGradient>
      ${tilePattern('ip', T.sun100, 1, 72)}
    </defs>
    <rect width="360" height="780" fill="url(#isky)"/><rect width="360" height="500" fill="url(#ip)" opacity=".06"/>
    ${starfield(60, 360, 440, 31, '#FFF0CC', [[0, 0, 360, 34], [0, 30, 360, 110], [40, 160, 320, 360]])}
    <!-- motion trail: dashed path with fading ghosts -->
    <path d="M70 190C120 150 160 260 210 250S300 330 286 390" fill="none" stroke="${T.sun300}" stroke-width="3" stroke-dasharray="3 10" stroke-linecap="round" opacity=".8"/>
    ${star8(70, 190, 26, `fill="${T.night300}" opacity=".16"`)}${star8(118, 178, 24, `fill="${T.night300}" opacity=".26"`)}${star8(168, 232, 23, `fill="${T.night300}" opacity=".4"`)}
    <!-- the little star: dim, then lighting -->
    <circle cx="214" cy="252" r="60" fill="url(#glowSun)" opacity=".7"/>
    ${star8(214, 252, 30, `fill="${T.sun300}" stroke="#fff" stroke-width="2.5"`)}${star8(214, 252, 16, `fill="#fff"`, 22.5, .72)}
    <!-- hill + tree + lantern target -->
    <path d="M0 470C70 440 150 462 230 452S330 440 360 452V560H0Z" fill="${T.night800}"/>
    <path d="M0 500C80 478 170 498 250 490S330 480 360 488V560H0Z" fill="${T.night900}"/>
    <g transform="translate(60 468)"><path d="M0 0V-34" stroke="${T.night900}" stroke-width="6" stroke-linecap="round"/><circle cx="0" cy="-48" r="22" fill="${T.teal700}"/><circle cx="-14" cy="-38" r="15" fill="${T.teal700}"/><circle cx="14" cy="-38" r="15" fill="${T.teal700}"/></g>
    ${lantern(288, 410, 1.15, false, T.sun500, T.sun300, T.night500)}
    <!-- sparkles -->
    ${[[262, 340, 5], [310, 366, 4], [248, 372, 3]].map(([x, y, r]) => star8(x, y, r * 1.6, `fill="${T.sun300}"`)).join('')}
  </svg>`;
  const dots = `<div class="abs" style="top:116px;left:0;right:0;display:flex;justify-content:center;gap:10px">${[1, 1, 0, 0].map((d, i) => `<div style="${i === 1 ? 'width:34px;' : 'width:14px;'}height:14px;border-radius:7px;background:${i === 1 ? T.sun500 : d ? T.teal200 : 'rgba(255,248,234,.3)'}"></div>`).join('')}</div>`;
  const sheet = `<div class="abs" style="left:0;right:0;bottom:0;height:254px;border-radius:36px 36px 0 0;background:${T.paper};box-shadow:0 -18px 40px rgba(10,8,40,.45);padding:20px 20px 0;text-align:center">
    <div class="body" style="font-weight:600;color:${T.night800};font-size:21px;line-height:1.55">النجمة الصغيرة ضاع ضوؤها. ساعدها تلاقي الفانوس!</div>
    <div style="display:flex;align-items:center;justify-content:center;gap:16px;margin-top:14px">
      <div class="round" style="background:${T.teal100};box-shadow:0 5px 0 rgba(15,85,82,.25)">${icon('speaker', 30, T.teal700)}</div>
      <div style="position:relative;width:96px;height:96px"><svg class="fill" viewBox="0 0 96 96"><circle cx="48" cy="48" r="46" fill="${T.rose100}"/><circle cx="48" cy="48" r="36" fill="none" stroke="${T.rose500}" stroke-width="2" stroke-dasharray="3 7" stroke-linecap="round"/></svg>
        <div class="round" style="position:absolute;left:12px;top:12px;width:72px;height:72px;background:linear-gradient(180deg,${T.rose300},${T.rose500});box-shadow:0 5px 0 rgba(169,53,86,.5)">${icon('mic', 34, T.night900)}</div></div>
      <div class="round" style="background:${T.sun100};box-shadow:0 5px 0 rgba(168,104,15,.3)">${icon('redo', 28, T.sun700)}</div>
    </div>
    <div style="margin-top:10px;font-family:'Reem';font-weight:700;font-size:28px;color:${T.rose700};word-spacing:.18em">قُل: ضوء!</div>
  </div>`;
  return page({ title: 'قصة تفاعلية', body: body + kidsTop({ title: 'حكاية النجمة', ink: '#fff', ringBg: 'rgba(255,248,234,.92)' }) + dots + sheet, bg: T.night900, statusColor: '#fff' });
}

// ---------- 10: games hub with a game card ----------
function s10() {
  const cardArt = (c, on, glyph) => `<div style="width:84px;height:100px;border-radius:20px;${on ? `background:#fff;border:2.5px solid ${T.night800}` : `background:linear-gradient(160deg,${c},${T.night700});border:2.5px solid ${T.night900}`};display:flex;align-items:center;justify-content:center;overflow:hidden;position:relative;box-shadow:0 5px 0 rgba(23,20,63,.3)">
    ${on ? glyph : `<svg width="84" height="100" viewBox="0 0 84 100" style="position:absolute;inset:0"><defs>${tilePattern('b' + c.slice(1), '#fff', 1, 28)}</defs><rect width="84" height="100" fill="url(#b${c.slice(1)})" opacity=".4"/></svg>${star8(42, 50, 16, `fill="${T.sun300}"`)}`}</div>`;
  const grid = `<div style="display:grid;grid-template-columns:repeat(3,84px);gap:12px;justify-content:center">
    ${cardArt(T.rose500, true, icon('rewards', 54, T.night800, '#fff', T.sun500))}${cardArt(T.teal500, false)}${cardArt(T.sun500, false)}
    ${cardArt(T.teal500, false)}${cardArt(T.rose500, true, icon('rewards', 54, T.night800, '#fff', T.sun500))}${cardArt(T.night500, false)}</div>`;
  const hero = `<div class="abs" style="top:118px;left:16px;right:16px;height:352px;border-radius:34px;background:linear-gradient(160deg,${T.night700},${T.night900});box-shadow:0 18px 30px -16px rgba(23,20,63,.75);overflow:hidden">
    <svg class="fill" viewBox="0 0 328 352"><defs>${tilePattern('hp', T.sun300, 1, 56)}</defs><rect width="328" height="352" fill="url(#hp)" opacity=".09"/>${starfield(22, 328, 100, 8, '#FFF0CC', [[0, 0, 0, 0]])}</svg>
    <div style="position:absolute;top:16px;right:18px"><span class="chip" style="background:${T.sun500};color:${T.night900}">لعبة جديدة</span></div>
    <div style="position:absolute;top:62px;left:0;right:0">${grid}</div>
    <div style="position:absolute;top:276px;left:0;right:0;text-align:center"><div class="h2" style="color:#fff;font-size:28px">أزواج النجوم</div>
      <div class="num" style="font-size:16px;font-weight:600;color:${T.night100};margin-top:2px;display:flex;justify-content:center;align-items:center;gap:6px">${icon('star', 20, T.sun500, T.night800)}${icon('star', 20, T.sun500, T.night800)}${icon('star', 20, T.night300, T.night800)}&nbsp;&nbsp;٣ دقايق تقريباً</div></div>
  </div>`;
  const play = `<div class="abs" style="top:488px;left:16px;right:16px"><div class="btn gold" style="width:100%;min-height:76px;font-size:26px">${icon('play', 30, T.night900)} العب</div></div>`;
  const mini = (name, ic, tone, sub) => `<div style="flex:1;height:124px;border-radius:28px;background:${T.paper};box-shadow:0 5px 0 rgba(38,33,79,.14);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;text-align:center">
    <div class="round" style="background:${tone}">${icon(ic, 34, T.night800, '#fff', T.sun500)}</div><div style="font-weight:700;font-size:17px;color:${T.night800}">${name}</div></div>`;
  const more = `<div class="abs" style="top:584px;left:16px;right:16px"><div class="h3" style="color:${T.night700};margin-bottom:6px">ألعاب ثانية</div><div style="display:flex;gap:12px">${mini('طريق الفانوس', 'rewards', T.sun100)}${mini('لمّ النجوم', 'star', T.teal100)}</div></div>`;
  return page({ title: 'الألعاب', body: bgPat(T.night500, 0.07) + kidsTop({ title: 'الألعاب' }) + hero + play + more, bg: `linear-gradient(180deg,${T.night100},${T.paper} 70%)` });
}

// ---------- 11: rewards ----------
function s11() {
  const cols = [T.sun500, T.teal500, T.rose500, T.night500, T.sun300, T.teal200, T.rose300, T.night300, T.sun500];
  const lit = [1, 1, 1, 1, 1, 0, 0, 0, 0];
  const shelf = (row) => `<div style="position:relative;display:flex;justify-content:space-around;padding:0 6px;height:112px;align-items:flex-end">
    ${[0, 1, 2].map((c) => { const i = row * 3 + c; return `<div style="width:92px;height:104px;display:flex;align-items:center;justify-content:center"><svg width="92" height="104" viewBox="-46 -50 92 104" style="overflow:visible">${lantern(0, 0, 1.18, !!lit[i], cols[i], lit[i] ? T.night800 : T.sand2).replace('fill="url(#glowSun)"', 'fill="url(#glowSun)"')}</svg></div>`; }).join('')}
    <div style="position:absolute;left:0;right:0;bottom:0;height:10px;border-radius:5px;background:linear-gradient(180deg,${T.sand2},#CBB27C);box-shadow:0 4px 0 rgba(38,33,79,.15)"></div></div>`;
  const hero = `<div class="abs" style="top:118px;left:16px;right:16px;height:116px;border-radius:32px;background:linear-gradient(120deg,${T.night800},${T.night700});box-shadow:0 14px 24px -14px rgba(23,20,63,.7);display:flex;align-items:center;gap:16px;padding:0 18px;color:#fff">
    <div style="position:relative;width:84px;height:84px;flex:none"><svg class="fill" viewBox="0 0 64 64">${star8(32, 32, 31, `fill="${T.sun500}" stroke="${T.sun100}" stroke-width="1.5"`)}${star8(32, 32, 20, `fill="${T.sun300}"`, 22.5, .72)}</svg></div>
    <div><div class="num" style="font-family:'Reem';font-weight:700;font-size:54px;line-height:1">٢٤</div><div style="font-weight:700;font-size:20px;color:${T.sun300}">نجمة جمعتها</div></div></div>`;
  const next = `<div class="abs" style="top:248px;left:16px;right:16px"><div style="display:flex;justify-content:space-between;font-weight:700;font-size:17px;color:${T.night800}"><span>الفانوس الجاي</span><span class="num">باقي ٦ نجوم</span></div>
    <div style="height:16px;border-radius:8px;background:${T.sand2};margin-top:6px"><div style="width:70%;height:16px;border-radius:8px;background:linear-gradient(270deg,${T.sun500},${T.sun300});float:right;box-shadow:0 0 12px rgba(245,180,49,.6)"></div></div></div>`;
  const shelves = `<div class="abs" style="top:322px;left:16px;right:16px;display:flex;flex-direction:column;gap:14px">${shelf(0)}${shelf(1)}${shelf(2)}</div>`;
  const keep = `<div class="abs" style="top:714px;left:16px;right:16px;display:flex;justify-content:center"><span class="chip" style="background:${T.teal100};color:${T.teal800};height:44px;font-size:16px">${icon('shield', 22, T.teal700, '#fff')} نجومك محفوظة على جوالك</span></div>`;
  return page({ title: 'جوائزي', body: bgPat(T.sun500, 0.12) + kidsTop({ title: 'جوائزي', showStars: false }) + hero + next + shelves + keep, bg: `linear-gradient(180deg,${T.sun100},${T.paper} 70%)` });
}

// ---------- 12: screen time ends gently ----------
function s12() {
  const body = `<svg class="fill" viewBox="0 0 360 780">
    <defs><linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#100E33"/><stop offset=".6" stop-color="${T.night800}"/><stop offset="1" stop-color="#4A3A8A"/></linearGradient>${tilePattern('dp', T.sun300, 1, 72)}</defs>
    <rect width="360" height="780" fill="url(#dusk)"/><rect width="360" height="780" fill="url(#dp)" opacity=".05"/>
    ${starfield(70, 360, 600, 17, '#FFF0CC', [[0, 0, 360, 34], [40, 130, 320, 400]])}
    <mask id="cm"><rect x="-120" y="-120" width="240" height="240" fill="#fff"/><circle cx="30" cy="-12" r="62" fill="#000"/></mask>
    <circle cx="170" cy="210" r="130" fill="url(#glowSun)" opacity=".35"/>
    <g transform="translate(170 210)"><circle r="68" fill="${T.sun100}" mask="url(#cm)"/></g>
    ${star8(246, 170, 9, `fill="${T.sun300}"`)}${star8(96, 296, 6, `fill="${T.sun300}" opacity=".8"`)}
    <path d="M0 704C80 680 160 704 240 692S330 680 360 688V780H0Z" fill="#0E0C2E"/>
    ${lantern(70, 706, 0.8, true, T.sun300, T.sun100)}
    ${lantern(296, 712, 0.62, false, T.sun500, T.night300, T.night700)}
  </svg>
  <div class="abs" style="top:316px;left:16px;right:16px;text-align:center;color:#fff">
    <div class="h1" style="font-size:36px">خلص وقت اللعب اليوم</div>
    <div class="body" style="color:${T.night100};margin-top:8px;font-size:21px">أخذت استراحة حلوة. منكمّل بكرا!</div>
  </div>
  <div class="abs" style="top:430px;left:16px;right:16px;display:flex;justify-content:center"><span class="chip" style="background:rgba(255,248,234,.14);color:${T.sun100};height:48px;font-size:17px;border:1.5px solid rgba(255,248,234,.25)">${icon('star', 26, T.sun500, T.night800)} <span class="num">٢٤</span> نجمة محفوظة ${icon('check', 20, T.teal200)}</span></div>
  <div class="abs" style="top:506px;left:16px;right:16px"><div class="btn gold" style="width:100%;min-height:76px;font-size:26px">${icon('moon', 32, T.night900, T.night900, T.rose500)} تمام</div></div>
  <div class="abs" style="top:596px;left:16px;right:16px;display:flex;justify-content:center"><div style="display:flex;align-items:center;gap:8px;min-height:64px;padding:0 20px;color:${T.night100};font-weight:600;font-size:16px">${icon('lock', 20, T.night100, T.night800)} للأهل: زيادة الوقت</div></div>`;
  return page({ title: 'انتهى وقت اللعب', body, bg: T.night900, statusColor: T.night100 });
}

// ---------- 13: adhkar, kids version ----------
function s13() {
  const beads = (() => {
    const n = 20, lit = 7; let s = '';
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 - Math.PI / 2;
      s += circle(120 + 106 * Math.cos(a), 120 + 106 * Math.sin(a), 9, `fill="${i < lit ? T.sun500 : T.teal200}" stroke="${i < lit ? T.sun700 : T.teal500}" stroke-width="1.6"`);
    }
    return s;
  })();
  const counter = `<div class="abs" style="top:346px;left:60px;width:240px;height:240px">
    <svg class="fill" viewBox="0 0 240 240">${circle(120, 120, 106, `fill="none" stroke="${T.teal200}" stroke-width="2"`)}${beads}${circle(120, 126, 82, 'fill="rgba(15,85,82,.18)"')}${circle(120, 120, 82, `fill="${T.teal700}"`)}${star8(120, 120, 76, `fill="none" stroke="${T.teal200}" stroke-width="1.4" opacity=".7"`, 22.5)}${star8(120, 120, 64, `fill="${T.teal500}"`)}</svg>
    <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#fff"><div class="num" style="font-family:'Reem';font-weight:700;font-size:80px;line-height:1">٧</div><div class="ph" style="margin-top:6px;background:transparent;color:${T.sun300};border-color:${T.sun300}">من [العدد]</div></div></div>`;
  const text = `<div class="abs card" style="top:196px;left:16px;right:16px;height:128px;background:#FFFDF6;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px">
    <span class="ph" style="font-family:'Plex'">[نص الذكر من مصدر موثّق]</span>
    <div style="font-family:'AmiriQuran';font-size:24px;color:${T.ink2}">[كلمة] [كلمة] [كلمة]</div></div>`;
  const tabs = `<div class="abs" style="top:118px;left:16px;right:16px;height:64px;border-radius:32px;background:${T.teal100};display:flex;padding:6px;gap:6px">
    <div style="flex:1;border-radius:26px;background:linear-gradient(180deg,${T.sun300},${T.sun500});color:${T.night900};display:flex;align-items:center;justify-content:center;gap:8px;font-weight:700;font-size:19px">${icon('sparkle', 22, T.night900)} الصباح</div>
    <div style="flex:1;border-radius:26px;color:${T.teal800};display:flex;align-items:center;justify-content:center;gap:8px;font-weight:700;font-size:19px">${icon('moon', 24, T.teal800, T.teal100, T.teal500)} المساء</div></div>`;
  const tap = `<div class="abs" style="top:600px;left:0;right:0;text-align:center;font-weight:700;font-size:19px;color:${T.teal800}">المس الدايرة كل ما تقول الذكر</div>`;
  const nav = `<div class="abs" style="top:650px;left:16px;right:16px;display:flex;gap:12px;align-items:center">
    <div class="round" style="background:${T.teal100};box-shadow:0 5px 0 rgba(15,85,82,.25)">${icon('back', 28, T.teal700)}</div>
    <div class="round" style="background:${T.sun100};box-shadow:0 5px 0 rgba(168,104,15,.3)">${icon('speaker', 30, T.sun700)}</div>
    <div class="btn teal" style="flex:1;font-size:20px;padding:0 10px;white-space:nowrap">الذكر الجاي ${icon('next', 24, '#fff')}</div></div>`;
  return page({ title: 'الأذكار', body: bgPat(T.teal500, 0.1) + kidsTop({ title: 'الأذكار' }) + tabs + text + counter + tap + nav, bg: `linear-gradient(180deg,${T.teal100},${T.paper} 65%)` });
}

module.exports = { s09a, s09b, s09c, s10, s11, s12, s13 };
