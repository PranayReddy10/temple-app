const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs'); const path = require('path');
const { mark, C, gradient } = require('/home/user/temple-app/tool/brand/mark.js');
const D = __dirname;
const fonts = `@font-face{font-family:Serif;src:url(store/NotoSerif_600SemiBold.ttf)}@font-face{font-family:Sans;src:url(store/NotoSans_400Regular.ttf)}@font-face{font-family:SansB;src:url(store/NotoSans_700Bold.ttf)}@font-face{font-family:Deva;src:url(store/NotoSansDevanagari_400Regular.ttf)}`;
const shots = [
  [1, 'Your daily darshan', "Today's deity, mantra and your pilgrimage, every day"],
  [3, 'Every temple, in detail', 'Timings, dress code, directions and sevas'],
  [4, 'Book pujas and sevas', 'Pick the day and time slot, pay securely'],
  [5, 'Your ticket at the counter', 'A QR code the temple scans once'],
  [9, 'Your temple passport', 'A stamp for every temple you visit'],
  [8, 'Festival calendar 2026–27', 'Every festival, Ekadashi and vrat, with reminders'],
  [2, 'Bhajans this week', 'Sing together at a temple near you'],
  [6, "Join bhajan gatherings", "Say “I'll join”, see the songs and who is coming"],
  [7, 'Online hundi', 'Give for annadanam, upkeep or festivals, with a receipt'],
];
const frame = (img, title, sub) => `<html><head><style>${fonts}
*{margin:0;box-sizing:border-box}body{width:1080px;height:1920px;overflow:hidden;background:linear-gradient(160deg,#E07A1F 0%,#B8402A 45%,#9B1B30 100%);font-family:Sans;color:#FFFDF9;position:relative}
.pattern{position:absolute;inset:0;opacity:.08;background-image:radial-gradient(circle at 20px 20px,#F2C94C 2px,transparent 3px);background-size:40px 40px}
.cap{position:absolute;top:96px;left:70px;right:70px;text-align:center}
h1{font-family:Serif;font-size:76px;line-height:1.12;letter-spacing:.5px;text-shadow:0 4px 18px rgba(0,0,0,.18)}
p{font-size:38px;line-height:1.35;margin-top:22px;opacity:.95}
.phone{position:absolute;left:50%;top:400px;transform:translateX(-50%);width:720px;height:1396px;border-radius:80px;background:#1d1210;padding:22px;box-shadow:0 40px 90px rgba(40,5,10,.45),0 0 0 3px rgba(255,255,255,.18) inset}
.screen{width:100%;height:100%;border-radius:64px;overflow:hidden;background:#fff}
.screen img{width:100%;height:100%;object-fit:cover;object-position:top}
.notch{position:absolute;top:40px;left:50%;transform:translateX(-50%);width:26px;height:26px;border-radius:50%;background:#1d1210;box-shadow:0 0 0 4px rgba(255,255,255,.04)}
</style></head><body><div class="pattern"></div><div class="cap"><h1>${title}</h1><p>${sub}</p></div>
<div class="phone"><div class="screen"><img src="${img}"></div></div></body></html>`;
const iconSvg = (size) => { const s = 0.82, off = (100 - 100 * s) / 2; return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 100 100">${gradient('g')}<rect width="100" height="100" fill="url(#g)"/><g transform="translate(${off} ${off}) scale(${s})">${mark(C.ivory, C.goldLight, { door: true })}</g></svg>`; };
const feature = `<html><head><style>${fonts}*{margin:0}body{width:1024px;height:500px;overflow:hidden;background:linear-gradient(120deg,#E07A1F,#9B1B30);font-family:Sans;color:#FFFDF9;position:relative}
.pattern{position:absolute;inset:0;opacity:.08;background-image:radial-gradient(circle at 16px 16px,#F2C94C 2px,transparent 3px);background-size:32px 32px}
.icon{position:absolute;left:70px;top:110px;width:280px;height:280px;border-radius:64px;overflow:hidden;box-shadow:0 20px 50px rgba(40,5,10,.35)}
.t{position:absolute;left:400px;top:120px;right:40px}h1{font-family:Serif;font-size:74px;line-height:1}h2{font-family:Deva;font-size:34px;color:#F2C94C;margin-top:14px;font-weight:400}
p{font-size:28px;margin-top:22px;line-height:1.4;opacity:.95}</style></head><body><div class="pattern"></div><div class="icon">${iconSvg(280)}</div>
<div class="t"><h1>Darshan Saathi</h1><h2>दर्शन साथी · Your temple companion</h2><p>Darshan timings · Puja & seva booking<br>Festival calendar · Temple passport</p></div></body></html>`;
(async () => {
  const b = await chromium.launch();
  const page = await b.newPage();
  fs.mkdirSync(path.join(D, 'out'), { recursive: true });
  for (const [i, [n, title, sub]] of shots.entries()) {
    fs.writeFileSync(path.join(D, 'frame.html'), frame(`raw_${n}.png`, title, sub));
    await page.setViewportSize({ width: 1080, height: 1920 });
    await page.goto('file://' + path.join(D, 'frame.html')); await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(D, 'out', `screenshot-${i + 1}.png`) });
  }
  fs.writeFileSync(path.join(D, 'icon.html'), `<html><body style="margin:0">${iconSvg(512)}</body></html>`);
  await page.setViewportSize({ width: 512, height: 512 }); await page.goto('file://' + path.join(D, 'icon.html'));
  await page.screenshot({ path: path.join(D, 'out', 'icon-512.png'), clip: { x: 0, y: 0, width: 512, height: 512 } });
  fs.writeFileSync(path.join(D, 'feature.html'), feature);
  await page.setViewportSize({ width: 1024, height: 500 }); await page.goto('file://' + path.join(D, 'feature.html')); await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(D, 'out', 'feature-graphic-1024x500.png') });
  await b.close();
})();
