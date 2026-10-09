// Ad images for the app campaign: every theme in landscape (1.91:1),
// square (1:1) and portrait (4:5), in English, Telugu and Hindi, plus a
// brand card. Writes ../images/<lang>/<theme>-<shape>.png.
//
//   node images.js            (needs Playwright; see ../README.md)
const { chromium } = require(process.env.PLAYWRIGHT || '/opt/node22/lib/node_modules/playwright');
const fs = require('fs');
const path = require('path');
const { LANGS, THEMES, icon, screen, BASE_CSS } = require('./creative.js');

const SHAPES = {
  landscape: { w: 1200, h: 628 },
  square: { w: 1200, h: 1200 },
  portrait: { w: 1200, h: 1500 },
};

const brandRow = (L, px) => `<div class="brand" style="font-family:${L.head};font-size:${px}px">
  <div class="ic" style="width:${px * 1.7}px;height:${px * 1.7}px">${icon(px * 1.7)}</div><span>${L.name}</span></div>`;

// A feature image: the line, the sub-line, the badge, and the phone.
function feature(shape, L, [title, sub], img) {
  const { w, h } = SHAPES[shape];
  if (shape === 'landscape') {
    return `<body style="width:${w}px;height:${h}px"><div class="pattern"></div>
      <div class="glow" style="width:700px;height:700px;right:-120px;top:-60px"></div>
      <div style="position:absolute;left:64px;top:62px;width:600px">
        ${brandRow(L, 30)}
        <h1 style="font-family:${L.head};font-size:62px;line-height:1.15;margin-top:42px;text-shadow:0 4px 18px rgba(0,0,0,.18)">${title}</h1>
        <p style="font-family:${L.body};font-size:28px;line-height:1.4;margin-top:18px;opacity:.95">${sub}</p>
        <div class="badge" style="font-family:${L.body === 'Sans' ? 'SansB' : L.body};font-size:24px;margin-top:34px">${L.badge}</div>
      </div>
      <div class="phone" style="width:330px;height:660px;right:110px;top:52px;transform:rotate(-4deg)"><div class="scr"><img src="${img}"></div></div></body>`;
  }
  const tall = shape === 'portrait';
  const phoneW = tall ? 620 : 540;
  const phoneTop = tall ? 600 : 520;
  return `<body style="width:${w}px;height:${h}px"><div class="pattern"></div>
    <div class="glow" style="width:1000px;height:1000px;left:100px;top:${phoneTop - 80}px"></div>
    <div style="position:absolute;left:70px;right:70px;top:${tall ? 76 : 56}px;text-align:center">
      <div style="display:flex;justify-content:center">${brandRow(L, 34)}</div>
      <h1 style="font-family:${L.head};font-size:${tall ? 80 : 72}px;line-height:1.15;margin-top:${tall ? 36 : 26}px;text-shadow:0 4px 18px rgba(0,0,0,.18)">${title}</h1>
      <p style="font-family:${L.body};font-size:${tall ? 38 : 34}px;line-height:1.35;margin-top:14px;opacity:.95">${sub}</p>
      <div class="badge" style="font-family:${L.body === 'Sans' ? 'SansB' : L.body};font-size:${tall ? 30 : 28}px;margin-top:${tall ? 30 : 22}px">${L.badge}</div>
    </div>
    <div class="phone" style="width:${phoneW}px;height:${phoneW * 2}px;left:${(w - phoneW) / 2}px;top:${phoneTop}px"><div class="scr"><img src="${img}"></div></div></body>`;
}

// The brand card: icon, name, tagline, badge. No screen.
function brand(shape, L) {
  const { w, h } = SHAPES[shape];
  const ic = shape === 'landscape' ? 240 : 360;
  return `<body style="width:${w}px;height:${h}px"><div class="pattern"></div>
    <div class="glow" style="width:${ic * 3}px;height:${ic * 3}px;left:${w / 2 - ic * 1.5}px;top:${h / 2 - ic * 1.5}px"></div>
    <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:${shape === 'landscape' ? 18 : 30}px">
      <div class="ic" style="width:${ic}px;height:${ic}px;border-radius:22%;overflow:hidden;box-shadow:0 20px 50px rgba(40,5,10,.35)">${icon(ic)}</div>
      <h1 style="font-family:${L.head};font-size:${shape === 'landscape' ? 64 : 88}px;line-height:1.1">${L.name}</h1>
      <p style="font-family:${L.body};font-size:${shape === 'landscape' ? 30 : 42}px;color:#F2C94C">${L.tagline}</p>
      <div class="badge" style="font-family:${L.body === 'Sans' ? 'SansB' : L.body};font-size:${shape === 'landscape' ? 24 : 32}px">${L.badge}</div>
    </div></body>`;
}

(async () => {
  const out = path.join(__dirname, '..', 'images');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const tmp = path.join(require('os').tmpdir(), 'ds-ad.html');
  let n = 0;
  for (const [code, L] of Object.entries(LANGS)) {
    fs.mkdirSync(path.join(out, code), { recursive: true });
    for (const [shape, { w, h }] of Object.entries(SHAPES)) {
      const jobs = THEMES.map((t) => [t.key, feature(shape, L, t[code], screen(t.screen))]);
      jobs.push(['brand', brand(shape, L)]);
      await page.setViewportSize({ width: w, height: h });
      for (const [key, body] of jobs) {
        // From a file, so the file:// fonts and screens may load.
        fs.writeFileSync(tmp, `<html><head><meta charset="utf-8"><style>${BASE_CSS}</style></head>${body}</html>`);
        await page.goto('file://' + tmp);
        await page.evaluate(() => document.fonts.ready);
        await page.waitForTimeout(150);
        await page.screenshot({ path: path.join(out, code, `${key}-${shape}.png`), clip: { x: 0, y: 0, width: w, height: h } });
        n++;
      }
    }
  }
  await browser.close();
  console.log(`${n} images in ${out}`);
})();
