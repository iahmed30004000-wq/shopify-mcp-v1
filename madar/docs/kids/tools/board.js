// Overview board: every screen side by side, plus palette and type scale.
const { T, CSS, star8, tilePattern } = require('./lib');

const items = [
  ['01a-entry-main-app', '١أ', 'الدخول بلمسة وحدة', 'Enter with one tap'],
  ['01b-entry-pinning-offer', '١ب', 'تثبيت الشاشة', 'Offer to pin the screen'],
  ['01c-parent-gate', '١ج', 'بوابة الأهل', 'Parent gate: PIN or fingerprint'],
  ['02-kids-home', '٢', 'الرئيسية: كوكب العوالم', 'Home: a planet of small worlds'],
  ['03-juz-amma-reading', '٣', 'جزء عمّ: الكلمة تضيء', 'Juz’ Amma, current word lit'],
  ['04a-recitation-soft-retry', '٤أ', 'ما سمعت منيح، عيد', 'Soft retry, never an error'],
  ['04b-recitation-heard-well', '٤ب', 'أحسنت!', 'Heard well'],
  ['05-prayer-wudu', '٥', 'الصلاة والوضوء', 'Wudu step by step (sheikh review)'],
  ['06-prophet-story', '٦', 'القصص: مكان ونور وأغراض', 'Stories: no face, no figure'],
  ['07a-arabic-letters', '٧أ', 'الحروف', 'Arabic letters'],
  ['07b-maths', '٧ب', 'الحساب', 'Maths: × ÷ and fractions'],
  ['08a-colouring-import', '٨أ', 'التلوين: أضيف صورة', 'Colouring gallery + import'],
  ['08b-colouring-page', '٨ب', 'صفحة ملوّنة', 'A coloured page'],
  ['09a-voice-stories-child', '٩أ', 'حكايات بصوت بابا', 'Stories in the parent’s voice'],
  ['09b-voice-stories-parent-corner', '٩ب', 'ركن الأهل: التسجيل', 'Record / re-record / delete'],
  ['09c-interactive-story', '٩ج', 'قصة تفاعلية', 'Interactive story, voice + motion'],
  ['10-game-card', '١٠', 'الألعاب', 'A game card'],
  ['11-rewards', '١١', 'جوائزي', 'Rewards on the device'],
  ['12-screen-time-end', '١٢', 'انتهى وقت اللعب', 'Screen time ends gently'],
  ['13-adhkar', '١٣', 'الأذكار للصغار', 'Adhkar, kids version'],
];

const cell = ([f, n, ar, en]) => `<div class="cell"><div class="frame"><img src="../png/${f}.png" width="256" height="555"></div>
  <div class="cap"><span class="badge">${n}</span><div><div class="ar">${ar}</div><div class="en">${en}</div></div></div></div>`;

const sw = (name, hex, role) => `<div class="sw"><div class="dot" style="background:${hex}"></div><div><b>${name}</b><br><span>${hex}</span><br><i>${role}</i></div></div>`;
const palette = `<div class="panel">
  <div class="ptitle">الألوان · Palette</div>
  <div class="swg">
   ${sw('ليل النيلي', T.night800, 'night indigo')}${sw('ليل أعمق', T.night900, 'deep night')}
   ${sw('ذهب الشروق', T.sun500, 'sunrise gold')}${sw('ذهب فاتح', T.sun300, 'soft gold')}
   ${sw('فيروزي هادئ', T.teal500, 'soft teal')}${sw('فيروزي غامق', T.teal700, 'teal, white text')}
   ${sw('وردي', T.rose500, 'rose')}${sw('وردي فاتح', T.rose300, 'light rose')}
   ${sw('ورق', T.paper, 'paper')}${sw('كهرمان «عيد»', T.retry, 'soft retry, never red')}
  </div>
  <div class="ptitle" style="margin-top:18px">الخطوط · Type</div>
  <div class="type"><div style="font-family:'Reem';font-weight:700;font-size:34px;word-spacing:.18em">ريم كوفي للعناوين</div><div style="font-size:20px;font-weight:500">إيبي إم بلكس للقراءة · ٢٠ بكسل</div><div style="font-family:'AmiriQuran';font-size:28px">أميري قرآن للنص القرآني</div></div>
</div>`;
const rules = `<div class="panel dark">
  <div class="ptitle" style="color:${T.sun300}">القفل · Lock rules</div>
  <ul><li>الدخول بلمسة، الخروج بالرقم السري أو البصمة <i>One-way lock</i></li>
  <li>مقفول من الداخل: الصحة، الدواء، المحفظة، كوكب العائلة، المحادثة، لوحة العمل <i>Six areas out</i></li>
  <li>لا محادثة حرّة مع نموذج، لا إنترنت، لا إعلانات <i>No chat, no network, no ads</i></li>
  <li>لا وجه ولا صورة لنبيّ أو صحابي <i>No prophet or companion drawn</i></li>
  <li>كل نصّ ديني مؤقّت (إطار ذهبي متقطّع) لحد ما الشيخ يوافق <i>Gold dashed = placeholder, flagged off</i></li></ul>
</div>`;

const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>لوحة تصميم مدار الصغار</title><style>${CSS}
html,body{width:1900px;height:auto;overflow:visible;background:#17143F}
body{padding:40px 48px 56px;color:#fff;position:relative}
.head{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:34px;border-bottom:2px solid rgba(255,212,121,.3);padding-bottom:22px}
.head h1{font-family:'Reem';font-weight:700;font-size:62px;word-spacing:.18em;color:${T.sun300}}
.head p{font-size:19px;color:${T.night100};line-height:1.6;max-width:720px;text-align:left;direction:ltr}
.grid{display:grid;grid-template-columns:repeat(6,276px);gap:44px 28px;justify-content:space-between}
.frame{width:276px;padding:10px;border-radius:40px;background:#0B0A26;box-shadow:0 0 0 2px #3a3680,0 24px 40px -14px rgba(0,0,0,.7)}
.frame img{display:block;border-radius:30px}
.cell{width:276px}
.cap{display:flex;align-items:center;gap:12px;margin-top:14px}
.badge{flex:none;width:46px;height:46px;border-radius:50%;background:${T.sun500};color:${T.night900};font-family:'Reem';font-weight:700;font-size:21px;display:flex;align-items:center;justify-content:center}
.ar{font-weight:700;font-size:21px;color:#fff}.en{font-size:15px;color:${T.night300};direction:ltr;text-align:right;font-weight:500}
.panel{grid-column:span 2;background:${T.paper};color:${T.ink};border-radius:32px;padding:26px 28px}
.panel.dark{background:${T.night800};color:#fff;border:1.5px solid rgba(255,212,121,.3)}
.ptitle{font-family:'Reem';font-weight:700;font-size:28px;margin-bottom:12px;word-spacing:.18em}
.swg{display:grid;grid-template-columns:1fr 1fr;gap:12px 20px}
.sw{display:flex;gap:12px;align-items:center;font-size:15px;line-height:1.35}.sw .dot{width:46px;height:46px;border-radius:50%;flex:none;box-shadow:inset 0 0 0 2px rgba(0,0,0,.12)}.sw span{direction:ltr;unicode-bidi:isolate;color:${T.ink2};font-weight:600}.sw i{color:${T.ink2};font-style:normal;direction:ltr;unicode-bidi:isolate}
.type{display:flex;flex-direction:column;gap:6px}
.panel ul{list-style:none;display:flex;flex-direction:column;gap:12px;font-size:18px;line-height:1.5;font-weight:500}.panel li i{display:block;font-style:normal;font-size:14px;color:${T.night300};direction:ltr;text-align:right}
</style></head><body>
<div class="head"><h1>مدار الصغار · لوحة التصميم</h1><p>Madar Kids: design board for the owner's approval. Nothing is built yet. Gold dashed boxes are placeholders: all religious text and audio will come later from verified, licensed sources and stay hidden until the named sheikh approves.</p></div>
<div class="grid">${items.slice(0, 18).map(cell).join('')}
${items.slice(18).map(cell).join('')}${palette}${rules}</div>
</body></html>`;
module.exports = { board: () => html };
