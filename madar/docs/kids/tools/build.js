// Writes docs/kids/html/*.html from the screen modules, then (optionally) renders them.
const fs = require('fs');
const path = require('path');
const out = path.resolve(__dirname, '..', 'html');
fs.mkdirSync(out, { recursive: true });

const mods = ['./s1', './s2', './s3', './s4', './board'].filter((m) => fs.existsSync(path.join(__dirname, m + '.js')));
const names = {
  s01a: '01a-entry-main-app', s01b: '01b-entry-pinning-offer', s01c: '01c-parent-gate', s02: '02-kids-home',
  s03: '03-juz-amma-reading', s04a: '04a-recitation-soft-retry', s04b: '04b-recitation-heard-well',
  s05: '05-prayer-wudu', s06: '06-prophet-story',
  s07a: '07a-arabic-letters', s07b: '07b-maths', s08a: '08a-colouring-import', s08b: '08b-colouring-page',
  s09a: '09a-voice-stories-child', s09b: '09b-voice-stories-parent-corner', s09c: '09c-interactive-story',
  board: '00-board', s10: '10-game-card', s11: '11-rewards', s12: '12-screen-time-end', s13: '13-adhkar',
};
for (const m of mods) {
  const mod = require(m);
  for (const [k, v] of Object.entries(mod)) {
    if (names[k] && typeof v === 'function') {
      fs.writeFileSync(path.join(out, names[k] + '.html'), v());
      console.log('wrote', names[k]);
    }
  }
}
