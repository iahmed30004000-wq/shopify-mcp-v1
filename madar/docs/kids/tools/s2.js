// Screens 03, 04a, 04b, 05, 06
const L = require('./lib');
const { T, star8, circle, rosette, tilePattern, starfield, icon, lantern, drop, page, kidsTop, wordRow } = L;

const ayahMark = (n) => `<span style="display:inline-flex;position:relative;width:38px;height:38px;align-items:center;justify-content:center;vertical-align:middle"><svg width="38" height="38" viewBox="0 0 64 64" style="position:absolute;inset:0">${star8(32, 32, 31, `fill="${T.sun100}" stroke="${T.sun700}" stroke-width="2.4"`)}</svg><span style="position:relative;font-family:'Amiri';font-weight:700;font-size:17px;color:${T.sun700};line-height:1">${n}</span></span>`;
const frameCorner = (x, y, rot) => `<g transform="translate(${x} ${y}) rotate(${rot})">${star8(0, 0, 11, `fill="${T.sun500}"`)}${circle(0, 0, 3.4, `fill="${T.paper}"`)}</g>`;

// ---------- 03: Juz' Amma reading ----------
function s03() {
  const w = (state) => ({ t: '[كلمة]', state });
  const bg = `<svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p', T.sun500, 1, 64)}</defs><rect width="360" height="780" fill="url(#p)" opacity=".12"/></svg>`;
  const banner = `<div class="abs" style="top:118px;left:16px;right:16px;height:64px;display:flex;align-items:center;justify-content:center;gap:12px">
    <svg width="40" height="40" viewBox="0 0 64 64">${star8(32, 32, 31, `fill="${T.teal500}"`)}${star8(32, 32, 14, `fill="${T.paper}"`, 22.5)}</svg>
    <span class="ph" style="font-size:19px;padding:6px 20px;border-radius:16px">[اسم السورة]</span>
    <svg width="40" height="40" viewBox="0 0 64 64">${star8(32, 32, 31, `fill="${T.teal500}"`)}${star8(32, 32, 14, `fill="${T.paper}"`, 22.5)}</svg>
  </div>`;
  const page_ = `<div class="abs" style="top:192px;left:16px;right:16px;height:352px;border-radius:30px;background:#FFFDF6;box-shadow:0 16px 30px -14px rgba(38,33,79,.55);">
    <svg class="fill" viewBox="0 0 328 352" style="position:absolute"><rect x="9" y="9" width="310" height="334" rx="22" fill="none" stroke="${T.sun500}" stroke-width="2.4"/><rect x="15" y="15" width="298" height="322" rx="17" fill="none" stroke="${T.sun500}" stroke-width="1" opacity=".6"/>
      ${frameCorner(14, 14, 0)}${frameCorner(314, 14, 0)}${frameCorner(14, 338, 0)}${frameCorner(314, 338, 0)}</svg>
    <div style="position:absolute;top:30px;left:0;right:0;text-align:center"><span class="ph">[نص السورة من مصحف المدينة]</span></div>
    <div style="position:absolute;top:78px;left:18px;right:18px;display:flex;flex-direction:column;gap:6px;align-items:center">
      <div style="display:flex;align-items:center;gap:4px">${wordRow([w('done'), w('done'), w('done')], 25)}${ayahMark('١')}</div>
      ${wordRow([w('done'), w('now'), w('next')], 25)}
      <div style="display:flex;align-items:center;gap:4px">${wordRow([w('next'), w('next')], 25)}${ayahMark('٢')}</div>
      <div style="display:flex;align-items:center;gap:4px">${wordRow([w('next'), w('next'), w('next')], 25)}${ayahMark('٣')}</div>
    </div>
    <div style="position:absolute;bottom:28px;left:0;right:0;display:flex;justify-content:center;align-items:flex-end;gap:5px;height:30px">${[8, 14, 22, 16, 24, 12, 18, 9].map((h) => `<div style="width:5px;height:${h}px;border-radius:3px;background:${T.sun500}"></div>`).join('')}</div>
  </div>`;
  const reader = `<div class="abs" style="top:574px;left:16px;right:16px;text-align:center;font-size:16px;color:${T.ink2};font-weight:500">${icon('speaker', 20, T.ink2)} القارئ: <span class="ph" style="font-size:13px">[اسم القارئ — صوت مرخّص]</span></div>`;
  const prog = `<div class="abs" style="top:616px;left:24px;right:24px;height:12px;border-radius:6px;background:${T.sand2}"><div style="width:36%;height:12px;border-radius:6px;margin-right:0;background:linear-gradient(270deg,${T.teal500},${T.sun500});float:right"></div></div>
  <div class="abs num" style="top:632px;left:24px;right:24px;display:flex;justify-content:space-between;font-size:15px;color:${T.ink2};font-weight:600"><span>٠:٤٢</span><span>الآية ٢ من ٦</span><span>٢:١٠</span></div>`;
  const ctl = `<div class="abs" style="top:668px;left:0;right:0;display:flex;justify-content:center;align-items:flex-start;gap:24px">
    <div style="text-align:center"><div class="round" style="background:${T.rose100};box-shadow:0 5px 0 rgba(169,53,86,.3)">${icon('mic', 32, T.rose700)}</div><div style="font-size:14px;font-weight:700;margin-top:3px;color:${T.rose700}">جرّب أنت</div></div>
    <div style="text-align:center"><div class="round" style="width:84px;height:84px;background:linear-gradient(180deg,${T.sun300},${T.sun500});box-shadow:0 6px 0 rgba(168,104,15,.5),0 0 0 8px rgba(245,180,49,.22)">${icon('pause', 40, T.night900)}</div></div>
    <div style="text-align:center"><div class="round" style="background:${T.teal100};box-shadow:0 5px 0 rgba(15,85,82,.25)">${icon('redo', 30, T.teal700)}</div><div style="font-size:14px;font-weight:700;margin-top:3px;color:${T.teal700}">عيد الآية</div></div>
  </div>`;
  return page({ title: 'جزء عمّ — القراءة', body: bg + kidsTop({ title: 'جزء عمّ' }) + banner + page_ + reader + prog + ctl, bg: `linear-gradient(180deg,${T.sand},${T.paper})` });
}

// ---------- 04: recitation check ----------
function recit(state) {
  const soft = state === 'soft';
  const w = (n, s) => ({ t: '[كلمة]', state: s });
  const bg = `<svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p', T.night500, 1, 64)}</defs><rect width="360" height="780" fill="url(#p)" opacity=".08"/></svg>`;
  const verse = `<div class="abs card" style="top:120px;left:16px;right:16px;height:152px;background:#FFFDF6">
    <div style="position:absolute;top:12px;right:16px"><span class="ph" style="font-size:13px">[آية من مصحف المدينة]</span></div>
    <div style="position:absolute;top:62px;left:0;right:0">${wordRow([w(1, 'done'), w(2, soft ? 'now' : 'done'), w(3, soft ? 'next' : 'done')], 26)}</div>
    <div style="position:absolute;left:10px;top:8px;width:56px;height:56px;border-radius:50%;background:${T.teal100};display:flex;align-items:center;justify-content:center;box-shadow:0 4px 0 rgba(15,85,82,.2)">${icon('speaker', 28, T.teal700)}</div>
  </div>`;
  const orb = soft
    ? `<div class="abs" style="top:286px;left:0;right:0;display:flex;flex-direction:column;align-items:center">
        <div style="position:relative;width:150px;height:150px">
          <svg class="fill" viewBox="0 0 150 150"><circle cx="75" cy="75" r="72" fill="${T.retry100}"/><circle cx="75" cy="75" r="56" fill="none" stroke="${T.retry}" stroke-width="2" stroke-dasharray="3 9" stroke-linecap="round"/>${circle(75, 75, 40, `fill="${T.retry}"`)}</svg>
          <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">${icon('mic', 40, T.night900)}</div>
        </div></div>`
    : `<div class="abs" style="top:286px;left:0;right:0;display:flex;flex-direction:column;align-items:center">
        <div style="position:relative;width:150px;height:150px">
          <svg class="fill" viewBox="0 0 150 150"><circle cx="75" cy="75" r="72" fill="url(#glowTeal)"/>${star8(75, 75, 70, `fill="${T.teal500}"`)}${star8(75, 75, 56, `fill="${T.teal200}"`, 22.5, .72)}${star8(75, 75, 34, `fill="${T.sun500}"`)}</svg>
          <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">${icon('check', 36, T.night900)}</div>
        </div></div>`;
  const msg = soft
    ? `<div class="abs" style="top:456px;left:16px;right:16px;border-radius:30px;background:${T.retry100};border:3px solid ${T.retry};padding:18px 20px;text-align:center">
        <div class="h1" style="font-size:36px;color:${T.retry700}">ما سمعت منيح، عيد</div>
        <div class="body" style="font-size:19px;color:${T.ink};margin-top:6px">ولا يهمك! جرّب كمان مرّة، أنا بسمعك.</div></div>
       <div class="abs" style="top:610px;left:16px;right:16px;display:flex;gap:12px;align-items:center">
         <div class="btn gold" style="flex:1;min-height:80px;font-size:26px">${icon('redo', 32, T.night900)} عيد</div>
       </div>
       <div class="abs" style="top:708px;left:16px;right:16px;text-align:center;font-size:16px;color:${T.ink2};font-weight:600">${icon('star', 20, T.sun500, T.paper)} نجومك محفوظة زي ما هي</div>`
    : `<div class="abs" style="top:456px;left:16px;right:16px;border-radius:30px;background:${T.teal100};border:3px solid ${T.teal500};padding:18px 20px;text-align:center">
        <div class="h1" style="font-size:38px;color:${T.teal800}">أحسنت!</div>
        <div class="body" style="font-size:19px;color:${T.ink};margin-top:6px">قرأتها حلو. نجمة جديدة إلك!</div></div>
       <div class="abs" style="top:610px;left:16px;right:16px;display:flex;gap:12px;align-items:center">
         <div class="round" style="width:80px;height:80px;background:${T.teal100};box-shadow:0 5px 0 rgba(15,85,82,.25)">${icon('redo', 32, T.teal700)}</div>
         <div class="btn teal" style="flex:1;min-height:80px;font-size:24px">الكلمة الجاية ${icon('next', 24, '#fff')}</div>
       </div>
       <div class="abs" style="top:708px;left:16px;right:16px;text-align:center;font-size:17px;color:${T.ink2};font-weight:700">${icon('star', 22, T.sun500, T.paper)} نجمتك صارت <span class="num">٢٥</span></div>`;
  const rings = soft ? '' : `<svg class="abs" width="360" height="200" viewBox="0 0 360 200" style="top:260px;left:0">${[[60, 40, 6], [300, 60, 8], [86, 150, 5], [276, 150, 6], [40, 100, 4], [322, 112, 5]].map(([x, y, r]) => star8(x, y, r * 1.8, `fill="${T.sun500}" opacity=".85"`)).join('')}</svg>`;
  return page({ title: soft ? 'التسميع — ما سمعت منيح' : 'التسميع — أحسنت', body: bg + kidsTop({ title: 'التسميع' }) + verse + orb + rings + msg, bg: `linear-gradient(180deg,${T.night100},${T.paper} 55%)` });
}
const s04a = () => recit('soft');
const s04b = () => recit('good');

// ---------- 05: prayer & wudu ----------
function handShape(fill, accent) {
  const fingers = [[-34, 50], [-16, 62], [2, 66], [20, 54]].map(([x, h]) => `<rect x="${x}" y="${18 - h}" width="14" height="${h}" rx="7" fill="${fill}"/>`).join('');
  return `<g>${fingers}<rect x="-34" y="0" width="68" height="62" rx="24" fill="${fill}"/>
    <rect x="-52" y="26" width="14" height="42" rx="7" fill="${fill}" transform="rotate(-38 -45 30)"/>
    ${star8(0, 30, 17, `fill="none" stroke="${accent}" stroke-width="2"`)}${star8(0, 30, 8, `fill="${accent}"`, 22.5)}</g>`;
}
function s05() {
  const art = `<div class="abs" style="top:196px;left:16px;right:16px;height:290px;border-radius:34px;overflow:hidden;box-shadow:0 18px 30px -16px rgba(15,85,82,.7)">
    <svg class="fill" viewBox="0 0 328 290">
      <defs><linearGradient id="wg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.night800}"/><stop offset=".6" stop-color="${T.teal700}"/><stop offset="1" stop-color="${T.teal500}"/></linearGradient>${tilePattern('wp', T.teal200, 1, 56)}</defs>
      <rect width="328" height="290" fill="url(#wg)"/><rect width="328" height="290" fill="url(#wp)" opacity=".16"/>
      <circle cx="164" cy="70" r="120" fill="url(#glowSun)" opacity=".8"/>
      ${rosette(164, 62, 40, T.sun300, T.sun100, T.teal500)}
      <!-- stream of water -->
      <path d="M164 104C158 130 170 148 164 176" stroke="#CFF3EE" stroke-width="14" stroke-linecap="round" fill="none" opacity=".9"/>
      <path d="M150 112C146 134 154 150 150 170M178 112C182 134 174 150 178 170" stroke="#9EE0D8" stroke-width="5" stroke-linecap="round" fill="none" opacity=".8"/>
      ${drop(132, 150, .9, '#CFF3EE')}${drop(196, 140, .8, '#CFF3EE')}${drop(120, 188, .6, '#9EE0D8')}${drop(210, 182, .7, '#9EE0D8')}${drop(164, 196, .7, '#fff', .9)}
      <!-- two hands as geometry -->
      <g transform="translate(106 214) scale(.62) rotate(8)">${handShape(T.sand, T.teal700)}</g>
      <g transform="translate(222 214) scale(-.62 .62) rotate(8)">${handShape(T.sand, T.teal700)}</g>
      <!-- ripples -->
      <ellipse cx="164" cy="268" rx="120" ry="12" fill="none" stroke="#CFF3EE" stroke-width="2" opacity=".6"/><ellipse cx="164" cy="268" rx="80" ry="7" fill="none" stroke="#fff" stroke-width="2" opacity=".6"/>
    </svg>
    <div class="abs" style="top:14px;right:14px;width:64px;height:64px">
      <svg width="64" height="64" viewBox="0 0 64 64">${star8(32, 32, 31, `fill="${T.sun500}" stroke="${T.paper}" stroke-width="2"`)}</svg>
      <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-family:'Reem';font-weight:700;font-size:32px;color:${T.night900}" class="num">٢</div>
    </div>
  </div>`;
  const tabs = `<div class="abs" style="top:118px;left:16px;right:16px;height:64px;border-radius:32px;background:${T.teal100};display:flex;padding:6px;gap:6px">
    <div style="flex:1;border-radius:26px;background:linear-gradient(180deg,${T.teal500},${T.teal700});color:#fff;display:flex;align-items:center;justify-content:center;gap:8px;font-weight:700;font-size:20px">${icon('drop', 24, '#fff', T.teal700)} الوضوء</div>
    <div style="flex:1;border-radius:26px;color:${T.teal800};display:flex;align-items:center;justify-content:center;gap:8px;font-weight:700;font-size:20px">${icon('prayer', 26, T.teal800, T.teal100, T.teal500)} الصلاة</div>
  </div>`;
  const dots = `<div class="abs" style="top:500px;left:0;right:0;display:flex;justify-content:center;gap:10px;align-items:center">${[1, 1, 0, 0, 0, 0, 0].map((d, i) => `<div style="${i === 1 ? `width:34px;background:${T.sun500}` : `width:14px;background:${d ? T.teal500 : T.sand2}`};height:14px;border-radius:7px"></div>`).join('')}</div>`;
  const text = `<div class="abs" style="top:528px;left:20px;right:20px;text-align:center">
    <div class="ph" style="font-size:18px;padding:4px 16px">[عنوان الخطوة]</div>
    <div class="body" style="margin-top:12px;color:${T.ink2}"><span class="ph" style="font-size:15px">[وصف الخطوة — بعد مراجعة الشيخ]</span></div>
  </div>
  <div class="abs" style="top:626px;left:16px;right:16px;border-radius:18px;background:${T.sun100};border:1.5px dashed ${T.sun700};color:${T.sun700};font-size:14px;font-weight:600;text-align:center;padding:6px 10px;line-height:1.35">محتوى مؤقّت · بانتظار مراجعة الشيخ قبل الظهور للطفل</div>`;
  const nav = `<div class="abs" style="top:680px;left:16px;right:16px;display:flex;gap:12px;align-items:center">
    <div class="round" style="background:${T.teal100};box-shadow:0 5px 0 rgba(15,85,82,.25)">${icon('back', 28, T.teal700)}</div>
    <div class="round" style="background:${T.sun100};box-shadow:0 5px 0 rgba(168,104,15,.3)">${icon('speaker', 30, T.sun700)}</div>
    <div class="btn gold" style="flex:1;font-size:22px">التالي ${icon('next', 24, T.night900)}</div>
  </div>`;
  return page({ title: 'الصلاة والوضوء', body: kidsTop({ title: 'الصلاة والوضوء' }) + tabs + art + dots + text + nav, bg: `linear-gradient(180deg,${T.teal100},${T.paper} 60%)` });
}

// ---------- 06: prophet story (places, light, objects; never a figure) ----------
function palm(x, y, s, fill) {
  const leaves = [-70, -40, -10, 20, 50, 80].map((a) => `<ellipse cx="0" cy="-22" rx="5" ry="26" fill="${fill}" transform="rotate(${a}) translate(0 -2)"/>`).join('');
  return `<g transform="translate(${x} ${y}) scale(${s})"><path d="M0 0C-3 -30 3 -50 -2 -78" stroke="${fill}" stroke-width="7" stroke-linecap="round" fill="none"/><g transform="translate(-2 -80)">${leaves}</g></g>`;
}
function s06() {
  const scene = `<svg class="abs" style="top:0;left:0" width="360" height="470" viewBox="0 0 360 470">
    <defs>
      <linearGradient id="ssky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.night900}"/><stop offset=".5" stop-color="${T.night500}"/><stop offset=".8" stop-color="${T.rose500}"/><stop offset="1" stop-color="${T.sun300}"/></linearGradient>
      <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.sun100}" stop-opacity=".95"/><stop offset="1" stop-color="${T.sun300}" stop-opacity="0"/></linearGradient>
      <linearGradient id="road" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.sun100}" stop-opacity=".9"/><stop offset="1" stop-color="${T.sun300}" stop-opacity=".15"/></linearGradient>
      ${tilePattern('sp', T.sun100, 1, 72)}
    </defs>
    <rect width="360" height="470" fill="url(#ssky)"/><rect width="360" height="300" fill="url(#sp)" opacity=".07"/>
    ${starfield(46, 360, 250, 9, '#FFF0CC', [[0, 0, 360, 34], [0, 30, 360, 110]])}
    <!-- column of light -->
    <path d="M150 340L168 150H192L210 340Z" fill="url(#beam)" opacity=".85"/>
    <circle cx="180" cy="160" r="64" fill="url(#glowSun)"/>
    ${rosette(180, 158, 34, T.sun300, T.sun100, T.rose500)}
    <!-- far dunes -->
    <path d="M0 322C60 292 130 312 190 304S320 290 360 306V470H0Z" fill="${T.rose700}"/>
    <path d="M0 352C80 326 150 346 230 338S330 330 360 344V470H0Z" fill="#7F2E57"/>
    ${palm(54, 336, 1, T.night800)}${palm(96, 346, .7, T.night800)}
    <!-- path of light -->
    <path d="M168 336L192 336L300 470H64Z" fill="url(#road)"/>
    <path d="M0 392C90 372 180 392 270 382S340 376 360 386V470H0Z" fill="${T.sun700}" opacity=".0"/>
    <path d="M0 410C70 392 140 410 210 404S320 396 360 408V470H0Z" fill="${T.night800}" opacity=".55"/>
    ${lantern(282, 396, 1.05)}
    <!-- stones/objects -->
    <g fill="${T.night800}" opacity=".8"><ellipse cx="60" cy="408" rx="16" ry="8"/><ellipse cx="84" cy="414" rx="9" ry="5"/></g>
  </svg>`;
  const card = `<div class="abs card" style="top:462px;left:16px;right:16px;height:190px;padding:16px 20px;background:#FFFDF6">
    <div style="display:flex;align-items:center;justify-content:space-between"><span class="ph" style="font-size:16px;padding:4px 14px">[اسم النبيّ]</span><span class="chip num" style="background:${T.night100};color:${T.night700};height:34px;font-size:15px">٢ من ٦</span></div>
    <div class="body" style="margin-top:12px;line-height:1.75"><span class="ph" style="font-size:16px;line-height:2">[نص القصة من مصدر موثّق — كلمة بكلمة]</span></div>
    <div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap">
      <span class="chip" style="background:${T.teal100};color:${T.teal800};height:34px;font-size:15px">${icon('bulb', 18, T.teal700, '#fff')} نور</span>
      <span class="chip" style="background:${T.rose100};color:${T.rose700};height:34px;font-size:15px">${icon('home', 18, T.rose700, '#fff')} مكان</span>
      <span class="chip" style="background:${T.sun100};color:${T.sun700};height:34px;font-size:15px">${icon('rewards', 18, T.sun700, '#fff')} أغراض</span>
    </div>
  </div>
  <div class="abs" style="top:676px;left:16px;right:16px;display:flex;gap:12px;align-items:center">
    <div class="round" style="background:${T.night100};box-shadow:0 5px 0 rgba(47,42,120,.25)">${icon('back', 28, T.night700)}</div>
    <div class="btn gold" style="flex:1;font-size:21px;padding:0 10px;white-space:nowrap">${icon('speaker', 28, T.night900)} اسمع القصة</div>
    <div class="round" style="background:${T.night100};box-shadow:0 5px 0 rgba(47,42,120,.25)">${icon('next', 28, T.night700)}</div>
  </div>`;
  return page({ title: 'القصص — قصة نبي', body: scene + kidsTop({ title: 'القصص', ink: '#fff', ringBg: 'rgba(255,248,234,.92)' }) + card, bg: T.paper, statusColor: '#fff' });
}

module.exports = { s03, s04a, s04b, s05, s06 };
