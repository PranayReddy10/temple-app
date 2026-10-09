// 15-second ad videos: the app's screens one after another with a line each,
// opening and closing on the brand, with the app's temple bell. Portrait
// (9:16), landscape (16:9) and square (1:1), in English, Telugu and Hindi.
// Writes ../videos/darshan-saathi-<lang>-<shape>.mp4.
//
//   FFMPEG=/path/to/ffmpeg node video.js [en|te|hi] [portrait|landscape|square]
//
// Each frame is drawn by the page for a given time and screenshotted, so
// the video is identical every run. Upload the MP4s to YouTube (unlisted
// is fine) and add the links to the ad group.
const { chromium } = require(process.env.PLAYWRIGHT || '/opt/node22/lib/node_modules/playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { LANGS, THEMES, icon, screen, BASE_CSS } = require('./creative.js');

const FPS = 30;
const SECONDS = 15;
const SHAPES = {
  portrait: { w: 1080, h: 1920 },
  landscape: { w: 1920, h: 1080 },
  square: { w: 1080, h: 1080 },
};
const END = {
  en: 'Search “Darshan Saathi” on Google Play',
  te: 'Google Play లో “దర్శన్ సాథీ” అని వెతకండి',
  hi: 'Google Play पर “दर्शन साथी” खोजें',
};
// The four screens shown, in order, between the opening and the end card.
const SCENES = ['companion', 'timings', 'sevas', 'festivals'].map((k) => THEMES.find((t) => t.key === k));
const BELL = path.resolve(__dirname, '../../../assets/sounds/temple_bell.wav');

function page(shape, code) {
  const L = LANGS[code];
  const { w, h } = SHAPES[shape];
  const wide = shape === 'landscape';
  const sq = shape === 'square';
  const phoneW = wide ? 440 : sq ? 440 : 640;
  const phoneTop = wide ? 120 : sq ? 360 : 620;
  const phoneLeft = wide ? w - phoneW - 260 : (w - phoneW) / 2;
  const capStyle = wide
    ? 'left:140px;top:0;bottom:0;width:900px;display:flex;flex-direction:column;justify-content:center'
    : `left:70px;right:70px;top:${sq ? 70 : 180}px;text-align:center`;
  const titlePx = wide ? 88 : sq ? 72 : 96;
  const subPx = wide ? 40 : sq ? 34 : 44;
  const iconPx = wide ? 300 : 360;

  const scenes = SCENES.map((t, i) => `
    <div class="scene" id="s${i}">
      <div class="cap" style="position:absolute;${capStyle}">
        <h1 style="font-family:${L.head};font-size:${titlePx}px;line-height:1.15;text-shadow:0 4px 18px rgba(0,0,0,.2)">${t[code][0]}</h1>
        <p style="font-family:${L.body};font-size:${subPx}px;line-height:1.35;margin-top:18px;opacity:.95">${t[code][1]}</p>
      </div>
      <div class="phone" style="width:${phoneW}px;height:${phoneW * 2}px;left:${phoneLeft}px;top:${phoneTop}px"><div class="scr"><img src="${screen(t.screen)}"></div></div>
    </div>`).join('');

  const card = (id, withEnd) => `
    <div class="scene" id="${id}" style="display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;gap:${wide ? 22 : 34}px">
      <div class="ic" style="width:${iconPx}px;height:${iconPx}px;border-radius:22%;overflow:hidden;box-shadow:0 24px 60px rgba(40,5,10,.4)">${icon(iconPx)}</div>
      <h1 style="font-family:${L.head};font-size:${wide ? 92 : 104}px;line-height:1.1">${L.name}</h1>
      <p style="font-family:${L.body};font-size:${wide ? 42 : 48}px;color:#F2C94C">${L.tagline}</p>
      ${withEnd ? `<div class="badge" style="font-family:${L.body === 'Sans' ? 'SansB' : L.body};font-size:${wide ? 36 : 40}px">${L.badge}</div>
      <p style="font-family:${L.body};font-size:${wide ? 34 : 38}px;opacity:.95;max-width:90%">${END[code]}</p>` : ''}
    </div>`;

  return `<html><head><meta charset="utf-8"><style>${BASE_CSS}
    body{width:${w}px;height:${h}px}
    .scene{position:absolute;inset:0;opacity:0}
  </style></head><body><div class="pattern"></div>
  <div class="glow" style="width:${Math.max(w, h)}px;height:${Math.max(w, h)}px;left:${(w - Math.max(w, h)) / 2}px;top:${(h - Math.max(w, h)) / 2}px;opacity:.6"></div>
  ${card('intro', false)}${scenes}${card('outro', true)}
  <script>
    // Times in seconds: opening, four screens, end card.
    const T = [[0, 2.2], [2.2, 4.8], [4.8, 7.4], [7.4, 10], [10, 12.6], [12.6, 15.01]];
    const ids = ['intro', 's0', 's1', 's2', 's3', 'outro'];
    const ease = (x) => 1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 3);
    window.render = (t) => {
      ids.forEach((id, i) => {
        const [a, b] = T[i];
        const el = document.getElementById(id);
        const fadeIn = i === 0 ? 1 : ease((t - a) / 0.35);
        const fadeOut = i === ids.length - 1 ? 1 : 1 - ease((t - (b - 0.3)) / 0.3);
        const on = t >= a - 0.01 && t < b;
        el.style.opacity = on ? Math.min(fadeIn, fadeOut) : 0;
        const k = ease((t - a) / 0.7);
        const phone = el.querySelector('.phone');
        if (phone) phone.style.transform = 'translateY(' + (1 - k) * 160 + 'px) rotate(' + ${wide ? -4 : 0} * k + 'deg)';
        const cap = el.querySelector('.cap');
        if (cap) cap.style.transform = 'translateY(' + (1 - k) * 30 + 'px)';
        const ic = el.querySelector('.ic');
        if (ic) ic.style.transform = 'scale(' + (0.85 + 0.15 * ease((t - a) / 0.6)) + ')';
      });
    };
  </script></body></html>`;
}

async function render(browser, shape, code) {
  const { w, h } = SHAPES[shape];
  const out = path.join(__dirname, '..', 'videos', `darshan-saathi-${code}-${shape}.mp4`);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const tmp = path.join(os.tmpdir(), `ds-video-${code}-${shape}.html`);
  fs.writeFileSync(tmp, page(shape, code));

  const tab = await browser.newPage({ viewport: { width: w, height: h } });
  await tab.goto('file://' + tmp);
  await tab.evaluate(() => document.fonts.ready);
  await tab.waitForTimeout(300);

  // The bell as it opens, and again on the end card.
  const ff = spawn(process.env.FFMPEG || 'ffmpeg', [
    '-y', '-loglevel', 'error',
    '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-i', BELL, '-i', BELL,
    '-filter_complex', '[1]volume=0.7[a1];[2]adelay=12600|12600,volume=0.7[a2];[a1][a2]amix=inputs=2:normalize=0,apad[a]',
    '-map', '0:v', '-map', '[a]',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'medium', '-r', String(FPS),
    '-c:a', 'aac', '-b:a', '128k', '-ar', '44100', '-ac', '2', '-t', String(SECONDS), '-movflags', '+faststart',
    out,
  ], { stdio: ['pipe', 'inherit', 'inherit'] });

  for (let i = 0; i < FPS * SECONDS; i++) {
    await tab.evaluate((t) => window.render(t), i / FPS);
    const jpg = await tab.screenshot({ type: 'jpeg', quality: 92 });
    if (!ff.stdin.write(jpg)) await new Promise((r) => ff.stdin.once('drain', r));
  }
  ff.stdin.end();
  await new Promise((resolve, reject) => ff.on('close', (c) => (c === 0 ? resolve() : reject(new Error('ffmpeg exited ' + c)))));
  await tab.close();
  console.log(out);
}

(async () => {
  const [onlyLang, onlyShape] = process.argv.slice(2);
  const browser = await chromium.launch();
  for (const code of Object.keys(LANGS)) {
    if (onlyLang && code !== onlyLang) continue;
    for (const shape of Object.keys(SHAPES)) {
      if (onlyShape && shape !== onlyShape) continue;
      await render(browser, shape, code);
    }
  }
  await browser.close();
})();
