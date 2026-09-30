// Renders every icon of the app and the website from mark.js.
//   node tool/brand/render.js   (from temple-app; the website repo beside it)
// Needs Playwright's Chromium. Writes PNGs into both repos and the SVG masters.
const fs = require('fs');
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const { mark, C, gradient } = require('./mark');

const APP = path.resolve(__dirname, '../..');
const SITE = path.resolve(APP, '../temple-website');

// scale: how much of the canvas the 100-unit mark box takes (the tower itself
// spans 76 units of it). bg: 'gradient', a colour, or null (transparent).
const svg = ({ scale = 0.8, bg = 'gradient', fg = C.ivory, ac = C.goldLight, door = true, radius = 0 }) => {
  const off = (100 - 100 * scale) / 2;
  const back = bg === 'gradient'
    ? `${gradient('g')}<rect width="100" height="100" rx="${radius}" fill="url(#g)"/>`
    : bg ? `<rect width="100" height="100" rx="${radius}" fill="${bg}"/>` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${back}<g transform="translate(${off} ${off}) scale(${scale})">${mark(fg, ac, { door })}</g></svg>`;
};

const jobs = [];
// Opaque unless it has rounded corners or no background: iOS rejects app
// icons with an alpha channel.
const png = (file, size, opts) => jobs.push({ file, size, svg: svg(opts), transparent: !!opts.radius || opts.bg === null });

// --- Android: legacy launcher icons (full square, the launcher rounds them)
// and the adaptive foreground (mark inside the middle 66% safe zone, on the
// gradient background drawable).
const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
for (const [d, m] of Object.entries(dens)) {
  png(`${APP}/android/app/src/main/res/mipmap-${d}/ic_launcher.png`, 48 * m, { scale: 0.82, radius: 0 });
  png(`${APP}/android/app/src/main/res/mipmap-${d}/ic_launcher_foreground.png`, 108 * m, { scale: 0.56, bg: null });
}

// --- iOS: opaque squares (iOS rounds them itself; no transparency allowed).
const ios = JSON.parse(fs.readFileSync(`${APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, 'utf8'));
for (const img of ios.images) {
  if (!img.filename) continue;
  const px = Math.round(parseFloat(img.size) * parseFloat(img.scale));
  png(`${APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset/${img.filename}`, px, { scale: 0.78 });
}

// --- Flutter web (darshansaathi.com): favicon, PWA icons, share image.
png(`${APP}/web/favicon.png`, 64, { scale: 0.96, radius: 18, door: true });
png(`${APP}/web/icons/Icon-192.png`, 192, { scale: 0.82, radius: 22 });
png(`${APP}/web/icons/Icon-512.png`, 512, { scale: 0.82, radius: 22 });
png(`${APP}/web/icons/Icon-maskable-192.png`, 192, { scale: 0.6 });
png(`${APP}/web/icons/Icon-maskable-512.png`, 512, { scale: 0.6 });

// --- The server (temple.darshansaathi.com): admin, portal, QR pages.
png(`${SITE}/public/icons/icon-192.png`, 192, { scale: 0.82, radius: 22 });
png(`${SITE}/public/icons/icon-512.png`, 512, { scale: 0.82, radius: 22 });
png(`${SITE}/public/icons/icon-maskable-512.png`, 512, { scale: 0.6 });
png(`${SITE}/public/icons/apple-touch-icon.png`, 180, { scale: 0.8 });
png(`${SITE}/public/icons/favicon-32.png`, 32, { scale: 0.98, radius: 20, door: false });

// SVG masters, for print, the Play Store listing and anything drawn later.
const lockup = (fg, ac, text, tag) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 420 100"><g transform="translate(0 0)">${mark(fg, ac)}</g><text x="108" y="58" font-family="Georgia, 'Noto Serif', serif" font-weight="700" font-size="40" fill="${text}">Darshan Saathi</text><text x="110" y="82" font-family="system-ui, 'Segoe UI', sans-serif" font-size="13" letter-spacing="2.4" fill="${tag}">YOUR TEMPLE COMPANION</text></svg>`;
const masters = {
  'logo-icon.svg': svg({ scale: 0.82, radius: 22 }),
  'logo-mark.svg': `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${mark(C.kumkum, C.saffron)}</svg>`,
  'logo-mark-light.svg': `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${mark(C.sandal, C.gold)}</svg>`,
  'logo-lockup.svg': lockup(C.kumkum, C.saffron, C.deep, C.saffron),
  'logo-lockup-dark.svg': lockup(C.sandal, C.gold, C.sandal, C.gold),
};
for (const dir of [`${APP}/tool/brand`, `${SITE}/public/brand`]) {
  fs.mkdirSync(dir, { recursive: true });
  for (const [f, s] of Object.entries(masters)) fs.writeFileSync(`${dir}/${f}`, s);
}

// The share card (Open Graph, 1200×630) for darshansaathi.com.
const og = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630"><rect width="1200" height="630" fill="${C.sandal}"/>
  <g transform="translate(120 150) scale(3.3)">${svg({ scale: 0.82, radius: 22 }).replace(/^<svg[^>]*>|<\/svg>$/g, '')}</g>
  <text x="520" y="300" font-family="Georgia, 'Noto Serif', serif" font-weight="700" font-size="84" fill="${C.deep}">Darshan Saathi</text>
  <text x="524" y="360" font-family="system-ui, sans-serif" font-size="26" letter-spacing="5" fill="${C.saffron}">YOUR TEMPLE COMPANION</text>
  <text x="524" y="425" font-family="system-ui, sans-serif" font-size="23" fill="#7a6a60">Darshan timings · Puja &amp; seva booking · Directions</text></svg>`;
jobs.push({ file: `${APP}/web/og.png`, w: 1200, h: 630, svg: og, transparent: false });

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const j of jobs) {
    const w = j.w || j.size, h = j.h || j.size;
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<html><body style="margin:0;background:transparent">${j.svg.replace('<svg ', `<svg width="${w}" height="${h}" `)}</body></html>`);
    fs.mkdirSync(path.dirname(j.file), { recursive: true });
    await page.screenshot({ path: j.file, omitBackground: !!j.transparent, clip: { x: 0, y: 0, width: w, height: h } });
    console.log(`${path.relative(path.resolve(APP, '..'), j.file)}  ${w}×${h}`);
  }
  await browser.close();
})();
