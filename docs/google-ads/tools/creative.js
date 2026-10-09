// Shared look for the ad images and videos: the brand gradient, the app's
// fonts, a phone showing a real app screen, and the text per language.
const path = require('path');
const { mark, C, gradient } = require('../../../tool/brand/mark.js');

const ROOT = path.resolve(__dirname, '../../..');
const font = (f) => 'file://' + path.join(ROOT, 'assets/fonts', f);
const screen = (name) => 'file://' + path.join(__dirname, 'screens', name + '.jpg');

const FONTS = `
@font-face{font-family:Serif;src:url(${font('NotoSerif_600SemiBold.ttf')})}
@font-face{font-family:Sans;src:url(${font('NotoSans_400Regular.ttf')})}
@font-face{font-family:SansB;src:url(${font('NotoSans_700Bold.ttf')})}
@font-face{font-family:Telugu;src:url(${font('NotoSansTelugu_400Regular.ttf')})}
@font-face{font-family:Deva;src:url(${font('NotoSansDevanagari_400Regular.ttf')})}`;

// Headings in the language's own script; English headings in the serif.
const LANGS = {
  en: { head: 'Serif', body: 'Sans', badge: 'Free on Android', name: 'Darshan Saathi', tagline: 'Your temple companion' },
  te: { head: 'Telugu', body: 'Telugu', badge: 'ఆండ్రాయిడ్‌లో ఉచితం', name: 'దర్శన్ సాథీ', tagline: 'మీ ఆలయ సహచరుడు' },
  hi: { head: 'Deva', body: 'Deva', badge: 'Android पर मुफ़्त', name: 'दर्शन साथी', tagline: 'आपका मंदिर साथी' },
};

// One image per feature: the screen and its two lines in each language.
const THEMES = [
  { key: 'companion', screen: 'home',
    en: ['Your temple companion', 'Darshan timings, sevas and festivals in one app'],
    te: ['మీ ఆలయ సహచరుడు', 'దర్శన సమయాలు, సేవలు, పండుగలు – ఒకే యాప్‌లో'],
    hi: ['आपका मंदिर साथी', 'दर्शन का समय, सेवाएँ और त्योहार – एक ही ऐप में'] },
  { key: 'timings', screen: 'temple',
    en: ['Know before you go', 'Darshan timings, dress code and directions'],
    te: ['వెళ్లే ముందే తెలుసుకోండి', 'దర్శన సమయాలు, దుస్తుల నియమం, దారి'],
    hi: ['जाने से पहले जानें', 'दर्शन का समय, ड्रेस कोड और रास्ता'] },
  { key: 'sevas', screen: 'booking',
    en: ['Book pujas & sevas', 'Pick a time slot, show the QR at the counter'],
    te: ['పూజలు, సేవలు బుక్ చేయండి', 'సమయం ఎంచుకోండి, కౌంటర్‌లో QR చూపించండి'],
    hi: ['पूजा और सेवा बुक करें', 'समय चुनें, काउंटर पर QR दिखाएँ'] },
  { key: 'festivals', screen: 'calendar',
    en: ['Never miss a festival', 'Ekadashi, vrats and festivals, with reminders'],
    te: ['ఏ పండుగనూ మరచిపోకండి', 'ఏకాదశి, వ్రతాలు, పండుగలు – ముందే గుర్తు చేస్తాం'],
    hi: ['कोई त्योहार न छूटे', 'एकादशी, व्रत और त्योहार – पहले से याद दिलाएँ'] },
  { key: 'passport', screen: 'passport',
    en: ['Your temple passport', 'A stamp for every temple you visit'],
    te: ['మీ ఆలయ పాస్‌పోర్ట్', 'దర్శించిన ప్రతి ఆలయానికి ఒక ముద్ర'],
    hi: ['आपका मंदिर पासपोर्ट', 'हर मंदिर दर्शन पर एक मुहर'] },
];

// The app icon: the gopuram and diya on the brand gradient.
const icon = (size) => {
  const s = 0.82, off = (100 - 100 * s) / 2;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 100 100">${gradient('g' + size)}<rect width="100" height="100" fill="url(#g${size})"/><g transform="translate(${off} ${off}) scale(${s})">${mark(C.ivory, C.goldLight, { door: true })}</g></svg>`;
};

const BASE_CSS = `${FONTS}
*{margin:0;box-sizing:border-box}
body{overflow:hidden;background:linear-gradient(150deg,#E07A1F 0%,#B8402A 48%,#9B1B30 100%);color:#FFFDF9;position:relative}
.pattern{position:absolute;inset:0;opacity:.08;background-image:radial-gradient(circle at 20px 20px,#F2C94C 2px,transparent 3px);background-size:40px 40px}
.glow{position:absolute;border-radius:50%;background:radial-gradient(circle,rgba(242,201,76,.35),transparent 65%)}
.phone{position:absolute;border-radius:7%/3.6%;background:#1d1210;padding:2.4%;box-shadow:0 30px 80px rgba(40,5,10,.45),0 0 0 3px rgba(255,255,255,.16) inset}
.phone .scr{width:100%;height:100%;border-radius:6%/3%;overflow:hidden;background:#fff}
.phone img{width:100%;height:100%;object-fit:cover;object-position:top;display:block}
.brand{display:flex;align-items:center;gap:.5em}
.brand .ic{border-radius:22%;overflow:hidden;box-shadow:0 8px 24px rgba(40,5,10,.3);flex:none}
.badge{display:inline-block;background:#FFFDF9;color:#9B1B30;border-radius:999px;font-family:SansB;padding:.45em 1.1em;box-shadow:0 8px 20px rgba(40,5,10,.25)}
`;

module.exports = { LANGS, THEMES, icon, screen, BASE_CSS, C };
