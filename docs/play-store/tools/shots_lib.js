const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const TOKEN = process.env.DEVOTEE_TOKEN;
const devotee = JSON.parse(fs.readFileSync(__dirname + '/devotee.json', 'utf8')).data;

async function open() {
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 780 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true, locale: 'en-IN', timezoneId: 'Asia/Kolkata', geolocation: { latitude: 17.385, longitude: 78.4867 }, permissions: ['geolocation'] });
  await ctx.addInitScript(([token, dev]) => {
    const set = (k, v) => localStorage.setItem('flutter.' + k, JSON.stringify(v));
    set('devotee_token', token);
    set('devotee', JSON.stringify(dev));
    set('door_animations', false);
    set('opening_bell', false);
    set('api_base', 'http://127.0.0.1:8000');
  }, [TOKEN, devotee]);
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('pageerror', String(e).slice(0, 200)));
  await page.goto('http://localhost:8811/', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => !document.getElementById('loading'), null, { timeout: 60000 });
  await page.waitForTimeout(2500);
  // Accessibility tree on, so buttons and text can be found by name.
  await page.evaluate(() => { const p = document.querySelector('flt-semantics-placeholder'); if (p) p.click(); });
  await page.waitForTimeout(800);
  return { browser, page };
}

async function labels(page) {
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics [aria-label], flt-semantics')].map(e => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean).filter((v, i, a) => a.indexOf(v) === i).slice(0, 120));
}

async function tap(page, text, opts = {}) {
  const loc = page.locator('flt-semantics').filter({ hasText: text }).last();
  const byLabel = page.locator(`[aria-label*="${text}"]`).first();
  const target = (await byLabel.count()) ? byLabel : loc;
  await target.scrollIntoViewIfNeeded().catch(() => {});
  await target.click({ timeout: opts.timeout ?? 8000 });
  await page.waitForTimeout(opts.wait ?? 1800);
}

async function scroll(page, dy) {
  await page.mouse.move(195, 500);
  await page.mouse.wheel(0, dy);
  await page.waitForTimeout(900);
}

module.exports = { open, labels, tap, scroll };
