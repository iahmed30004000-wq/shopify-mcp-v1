// Screens 01a, 01b, 01c, 02
const L = require('./lib');
const { T, star8, circle, rosette, tilePattern, dotPattern, starfield, icon, lantern, page, kidsTop } = L;

// ---------- shared: world tile ----------
const TONES = {
  gold: [T.sun100, T.sun500, T.night900],
  teal: [T.teal100, T.teal500, '#fff'],
  rose: [T.rose100, T.rose500, T.night900],
  indigo: [T.night100, T.night500, '#fff'],
  tealDeep: [T.teal200, T.teal700, '#fff'],
  roseDeep: [T.rose100, T.rose700, '#fff'],
};
function medallion(size, tone, iconName) {
  const [soft, main, onMain] = TONES[tone];
  return `<div style="position:relative;width:${size}px;height:${size}px;flex:none">
    <svg width="${size}" height="${size}" viewBox="0 0 64 64" style="position:absolute;inset:0">
      ${star8(32, 33.5, 31, `fill="rgba(23,20,63,.18)"`)}
      ${star8(32, 32, 31, `fill="${main}"`)}
      ${star8(32, 32, 25, `fill="none" stroke="${soft}" stroke-width="1.4" opacity=".7"`, 22.5)}
    </svg>
    <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">${icon(iconName, size * 0.5, onMain === '#fff' ? '#fff' : onMain, main, soft)}</div>
  </div>`;
}
function tile({ x, y, w, h, label, ic, tone, hint }) {
  const [soft] = TONES[tone];
  return `<div class="abs" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;border-radius:28px;background:${soft};box-shadow:0 5px 0 rgba(23,20,63,.14),0 14px 20px -12px rgba(23,20,63,.5);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;text-align:center">
    ${medallion(58, tone, ic)}
    <div style="font-weight:700;font-size:17px;line-height:1.15;color:${T.ink};padding:0 4px">${label}</div>
  </div>`;
}

// ---------- 01a: the main app with the entry card ----------
function s01a() {
  const glass = (x, y, label, c1, c2) => `<div class="abs" style="left:${x}px;top:${y}px;width:156px;height:84px;border-radius:24px;background:rgba(22,34,79,.55);border:1.5px solid rgba(232,199,122,.22);display:flex;align-items:center;gap:12px;padding:0 14px">
    <div style="width:46px;height:46px;border-radius:50%;background:radial-gradient(circle at 35% 30%,${c1},${c2});flex:none"></div>
    <div style="color:#F4EEDD;font-weight:600;font-size:17px">${label}</div></div>`;
  const body = `
  <svg class="fill" viewBox="0 0 360 780">${starfield(70, 360, 780, 11, '#F4EEDD', [[0, 30, 360, 100], [16, 104, 344, 320], [0, 320, 360, 380]])}</svg>
  <div class="abs" style="top:46px;right:20px;left:20px;display:flex;justify-content:space-between;align-items:center">
    <div style="font-family:'Reem';font-weight:700;font-size:30px;color:#E8C77A">مدار</div>
    <div style="font-size:16px;color:#C7C3D6;font-weight:500">الرئيسية</div>
  </div>

  <!-- the one new card -->
  <div class="abs" style="left:16px;right:16px;top:104px;height:216px;border-radius:32px;background:linear-gradient(135deg,${T.paper},${T.sand});box-shadow:0 0 0 3px rgba(255,212,121,.55),0 0 46px 6px rgba(245,180,49,.35);overflow:hidden">
    <svg class="fill" viewBox="0 0 328 216"><defs>${tilePattern('p1', T.sun500, 1.2, 56)}</defs><rect width="328" height="216" fill="url(#p1)" opacity=".35"/>
      ${rosette(260, 62, 56, T.sun500, T.paper, T.teal500)}</svg>
    <div class="abs" style="right:22px;top:112px;left:22px">
      <div style="font-family:'Reem';font-weight:700;font-size:32px;color:${T.night800};line-height:1.1;word-spacing:.18em">مدار الصغار</div>
      <div style="font-size:16px;color:${T.ink2};font-weight:500;margin-top:4px">مكان آمن للّعب والتعلّم</div>
    </div>
    <div class="abs" style="left:18px;bottom:16px;width:136px;height:64px;border-radius:32px;background:linear-gradient(180deg,${T.teal500},${T.teal700});color:#fff;font-weight:700;font-size:22px;display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:0 5px 0 rgba(15,85,82,.5)">ادخل ${icon('next', 22, '#fff')}</div>
    <div class="abs" style="left:18px;bottom:16px;width:136px;height:64px;border-radius:32px;box-shadow:0 0 0 6px rgba(47,165,156,.28)"></div>
  </div>

  <div class="abs" style="left:24px;right:24px;top:330px;text-align:center;font-size:15.5px;line-height:1.55;color:#C7C3D6;font-weight:500">الدخول بلمسة وحدة.<br>الخروج بالرقم السري أو البصمة فقط.</div>

  ${glass(188, 408, 'الصلاة', '#8FB8FF', '#3D5BD9')}${glass(16, 408, 'القرآن', '#F2CF7E', '#B8893A')}
  ${glass(188, 504, 'العائلة', '#F0A6C0', '#B3406A')}${glass(16, 504, 'الصحة', '#9BE8C6', '#2B8F6A')}
  ${glass(188, 600, 'المال', '#F2CF7E', '#8A6A2A')}${glass(16, 600, 'العمل', '#B7A8F5', '#5A4BC0')}
  <div class="abs" style="left:0;right:0;bottom:14px;display:flex;justify-content:center;gap:34px">
    ${[0, 1, 2, 3, 4].map((i) => `<div style="width:12px;height:12px;border-radius:50%;background:${i === 0 ? '#E8C77A' : 'rgba(244,238,221,.3)'}"></div>`).join('')}
  </div>`;
  return page({ title: 'مدار الصغار — الدخول من التطبيق', body, bg: 'linear-gradient(180deg,#03050F,#0D1430 60%,#16204A)', statusColor: '#F4EEDD' });
}

// ---------- 01b: pinning offer ----------
function s01b() {
  const body = `
  <svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p2', T.sun300, 1, 64)}</defs>
    <rect width="360" height="780" fill="url(#p2)" opacity=".10"/>
    ${starfield(40, 360, 300, 5, '#FFF0CC', [[0, 0, 360, 34], [60, 60, 300, 290]])}
    <circle cx="180" cy="180" r="170" fill="url(#glowSun)"/>
    ${rosette(180, 165, 96, T.sun500, T.sun100, T.teal500)}
  </svg>
  <div class="abs" style="top:262px;left:0;right:0;text-align:center;color:#fff">
    <div style="font-family:'Reem';font-weight:700;font-size:38px;word-spacing:.18em">مدار الصغار</div>
  </div>
  <div class="abs" style="left:0;right:0;bottom:0;height:420px;border-radius:40px 40px 0 0;background:${T.paper};box-shadow:0 -20px 50px rgba(10,8,40,.5);padding:28px 24px 0">
    <div style="display:flex;align-items:center;gap:12px">
      <div class="round" style="width:64px;height:64px;background:${T.teal100}">${icon('shield', 38, T.teal700, '#fff')}</div>
      <div><span class="chip" style="background:${T.night100};color:${T.night700};height:32px;font-size:15px">للأهل</span>
        <div class="h2" style="color:${T.night800};margin-top:2px">نثبّت الشاشة؟</div></div>
    </div>
    <div class="body" style="margin-top:16px;color:${T.ink}">تثبيت الشاشة بيخلّي الجوال على مدار الصغار فقط، وما بيطلع منه إلا الأهل.</div>
    <div class="btn teal" style="margin-top:20px;width:100%;min-height:68px">${icon('shield', 28, '#fff', T.teal700)} ثبّت الشاشة</div>
    <div class="btn ghost" style="margin-top:12px;width:100%;color:${T.ink2};border-color:${T.sand2};min-height:64px;font-size:18px">مش هلأ، كمّل بدون تثبيت</div>
    <div class="small" style="margin-top:12px;color:${T.ink2};text-align:center;font-size:15px">بتقدر تغيّرها بعدين من إعدادات الأهل.</div>
  </div>`;
  return page({ title: 'مدار الصغار — تثبيت الشاشة', body, bg: `linear-gradient(180deg,${T.night900},${T.night700} 55%,${T.night500})`, statusColor: '#fff' });
}

// ---------- 01c: calm parent gate ----------
function s01c() {
  const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const key = (txt, extra = '') => `<div style="height:64px;border-radius:32px;background:rgba(255,248,234,.10);border:1.5px solid rgba(255,212,121,.22);display:flex;align-items:center;justify-content:center;color:${T.paper};font-weight:600;font-size:30px;direction:ltr;${extra}">${txt}</div>`;
  const body = `
  <svg class="fill" viewBox="0 0 360 780"><defs>${tilePattern('p3', T.sun300, 1, 72)}</defs>
    <rect width="360" height="780" fill="url(#p3)" opacity=".07"/><circle cx="180" cy="120" r="170" fill="url(#glowTeal)" opacity=".35"/>
    ${starfield(30, 360, 780, 21, '#FFF0CC', [[0, 0, 360, 30], [60, 260, 300, 320], [20, 320, 340, 650]])}
  </svg>
  <div class="abs" style="top:46px;left:0;right:0;display:flex;flex-direction:column;align-items:center">
    <div style="position:relative;width:96px;height:96px">
      <svg width="96" height="96" viewBox="0 0 64 64" style="position:absolute;inset:0">${star8(32, 32, 31, `fill="${T.night700}" stroke="${T.sun300}" stroke-width="1.2"`)}${star8(32, 32, 24, `fill="none" stroke="${T.sun300}" stroke-width="1" opacity=".6"`, 22.5)}</svg>
      <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">${icon('lock', 40, T.sun300, T.night700)}</div>
    </div>
    <div class="h1" style="color:${T.paper};margin-top:10px">ركن الأهل</div>
    <div class="body" style="color:${T.night100};text-align:center;margin-top:4px;padding:0 28px;font-size:19px">اكتب الرقم السري أو المس البصمة<br>عشان تطلع من مدار الصغار</div>
  </div>
  <div class="abs" style="top:282px;left:0;right:0;display:flex;justify-content:center;gap:18px">
    ${[1, 1, 0, 0].map((on) => `<div style="width:22px;height:22px;border-radius:50%;${on ? `background:${T.sun300}` : `border:2.5px solid ${T.night300}`}"></div>`).join('')}
  </div>
  <div class="abs" style="top:326px;left:34px;right:34px;display:grid;grid-template-columns:repeat(3,1fr);gap:12px;direction:ltr">
    ${[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => key(ar[n])).join('')}
    ${key(icon('finger', 38, T.sun300, T.night700), `background:rgba(47,165,156,.28);border-color:${T.teal500}`)}
    ${key(ar[0])}
    ${key(icon('backspace', 34, T.night100, T.night700))}
  </div>
  <div class="abs" style="top:662px;left:34px;right:34px">
    <div class="btn paper" style="width:100%;color:${T.night800};font-size:20px">${icon('home', 26, T.night800, T.paper)} رجوع للّعب</div>
  </div>`;
  return page({ title: 'ركن الأهل — بوابة الخروج', body, bg: `linear-gradient(180deg,${T.night900},${T.night800} 70%,#2A2570)`, statusColor: T.night100 });
}

// ---------- 02: kids home ----------
function s02() {
  const sky = `
  <svg class="fill" viewBox="0 0 360 780">
    <defs>
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.night900}"/><stop offset=".45" stop-color="${T.night700}"/><stop offset=".78" stop-color="${T.rose500}"/><stop offset="1" stop-color="${T.sun300}"/></linearGradient>
      ${tilePattern('pl', T.sun500, 1.1, 60)}
      <clipPath id="planetClip"><circle cx="180" cy="745" r="525"/></clipPath>
    </defs>
    <rect width="360" height="300" fill="url(#sky)"/>
    ${starfield(34, 360, 190, 3, '#FFF0CC', [[0, 0, 360, 30], [150, 36, 360, 130], [0, 30, 90, 110]])}
    <circle cx="180" cy="214" r="150" fill="url(#glowSun)"/>
    ${star8(180, 212, 118, `fill="${T.sun300}" opacity=".35"`)}${star8(180, 212, 92, `fill="${T.sun100}" opacity=".45"`, 22.5, .72)}
    <circle cx="180" cy="212" r="60" fill="${T.sun300}"/><circle cx="180" cy="212" r="60" fill="none" stroke="#fff" stroke-width="2.5" opacity=".7"/>
    <circle cx="180" cy="745" r="535" fill="${T.sun300}" opacity=".55"/>
    <circle cx="180" cy="745" r="525" fill="${T.paper}"/>
    <g clip-path="url(#planetClip)"><rect x="-200" y="200" width="760" height="600" fill="url(#pl)" opacity=".28"/>
      <circle cx="180" cy="745" r="525" fill="none" stroke="${T.sun500}" stroke-width="3" opacity=".7"/></g>
  </svg>`;
  const T0 = 262, W = 102.67, H = 100, G = 10;
  const tiles = [
    ['الصلاة<br>والوضوء', 'prayer', 'teal'], ['القصص', 'stories', 'indigo'], ['الأخلاق', 'manners', 'rose'],
    ['الحروف', 'letters', 'gold'], ['الحساب', 'maths', 'tealDeep'], ['التلوين', 'colour', 'roseDeep'],
    ['الألعاب', 'games', 'indigo'], ['جوائزي', 'rewards', 'gold'], ['الأذكار', 'adhkar', 'teal'],
  ].map(([label, ic, tone], i) => {
    const col = i % 3, row = Math.floor(i / 3);
    return tile({ x: 16 + col * (W + G), y: T0 + 100 + row * (H + G), w: W, h: H, label, ic, tone });
  }).join('');
  const quran = `<div class="abs" style="left:16px;right:16px;top:${T0}px;height:90px;border-radius:30px;background:linear-gradient(100deg,${T.sun500},${T.sun300});box-shadow:0 5px 0 rgba(168,104,15,.45),0 16px 24px -12px rgba(23,20,63,.5);display:flex;align-items:center;gap:14px;padding:0 14px;overflow:hidden">
    <svg class="fill" viewBox="0 0 328 90" style="opacity:.35"><defs>${tilePattern('pq', '#fff', 1, 48)}</defs><rect width="328" height="90" fill="url(#pq)"/></svg>
    <div style="position:relative">${medallion(70, 'indigo', 'quran')}</div>
    <div style="position:relative;flex:1"><div class="h2" style="color:${T.night900}">القرآن</div><div style="font-size:17px;font-weight:600;color:${T.night800}">جزء عمّ · اسمع وعيد</div></div>
    <div style="position:relative">${icon('next', 28, T.night900)}</div>
  </div>`;
  const greet = `<div class="abs" style="top:40px;right:20px;color:#fff"><div class="h1" style="font-size:34px">أهلاً يا نجم!</div><div style="font-size:19px;font-weight:500;color:${T.night100}">وين بدّك تروح اليوم؟</div></div>
  <div class="abs round" style="top:38px;left:16px;background:rgba(255,248,234,.16);border:1.5px solid rgba(255,248,234,.35)">${icon('lock', 30, T.paper, T.night700)}</div>`;
  const bar = `<div class="abs" style="left:16px;right:16px;top:690px;height:64px;display:flex;gap:10px">
    <div style="width:142px;border-radius:32px;background:${T.night800};color:#fff;display:flex;align-items:center;gap:8px;padding:0 14px;font-weight:700;font-size:18px;white-space:nowrap;box-shadow:0 4px 0 rgba(23,20,63,.3)">${icon('star', 34, T.sun500, T.night800)}<span class="num">٢٤ نجمة</span></div>
    <div style="flex:1;border-radius:32px;flex:1;background:${T.teal100};color:${T.teal800};display:flex;align-items:center;gap:8px;padding:0 14px;font-weight:700;font-size:18px;box-shadow:0 4px 0 rgba(15,85,82,.2);white-space:nowrap">${icon('hourglass', 30, T.teal700, T.teal100)}<span class="num">باقي ٤٥ دقيقة</span></div>
  </div>`;
  return page({ title: 'مدار الصغار — الرئيسية', body: sky + greet + quran + tiles + bar, bg: T.night900, statusColor: '#fff' });
}

module.exports = { s01a, s01b, s01c, s02, medallion, tile, TONES };
