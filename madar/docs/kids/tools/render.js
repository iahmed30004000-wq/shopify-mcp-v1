// Renders docs/kids/html/*.html to docs/kids/png/*.png (2x). Usage: node render.js [name-prefix]
const path = require('path');
const fs = require('fs');
const { chromium } = require(process.env.PW_PATH || '/opt/node-tools/node_modules/playwright');

(async () => {
  const root = path.resolve(__dirname, '..');
  const only = process.argv[2] || '';
  const browser = await chromium.launch();
  const files = fs.readdirSync(path.join(root, 'html')).filter((n) => n.endsWith('.html') && n.startsWith(only));
  for (const n of files) {
    const board = n.startsWith('00-');
    const ctx = await browser.newContext({
      viewport: board ? { width: 1900, height: 900 } : { width: 360, height: 780 },
      deviceScaleFactor: board ? 1 : 2,
    });
    const pg = await ctx.newPage();
    await pg.goto('file://' + path.join(root, 'html', n));
    await pg.evaluate(() => document.fonts.ready);
    await pg.waitForTimeout(250);
    const out = path.join(root, 'png', n.replace('.html', '.png'));
    if (board) {
      const h = await pg.evaluate(() => document.documentElement.scrollHeight);
      await pg.setViewportSize({ width: 1900, height: h });
      await pg.screenshot({ path: out });
    } else {
      await pg.screenshot({ path: out });
    }
    console.log('ok', n);
    await ctx.close();
  }
  await browser.close();
})();
