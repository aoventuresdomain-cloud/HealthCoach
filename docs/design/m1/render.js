// Renders each .phone in mockups.html to png/<id>.png at 2x.
// Usage: node docs/design/m1/render.js  (needs Playwright with Chromium)
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 2 });
  await page.goto('file://' + path.join(__dirname, 'mockups.html'));
  await page.evaluate(() => document.fonts.ready);
  for (const el of await page.$$('.phone')) {
    const id = await el.getAttribute('id');
    await el.screenshot({ path: path.join(__dirname, 'png', id + '.png'), omitBackground: true });
  }
  await browser.close();
})();
