const { open, tap, scroll } = require('./shots_lib');
async function run(n, fn) {
  const { browser, page } = await open();
  try { await fn(page); await page.mouse.move(5, 5); await page.waitForTimeout(800); await page.screenshot({ path: `raw_${n}.png` }); console.log('ok', n); }
  catch (e) { console.log('!!', n, String(e).slice(0, 200)); await page.screenshot({ path: `raw_${n}_err.png` }); }
  await browser.close();
}
const temple = async (page) => { await tap(page, 'Search temples', { wait: 1500 }); await page.keyboard.type('Bhadrachalam', { delay: 30 }); await page.waitForTimeout(2500); await tap(page, 'Bhadrachalam Sita Ramachandraswamy', { wait: 4000 }); };
(async () => {
  const only = process.argv[2];
  const jobs = {
    1: async () => {},
    2: async (p) => { for (let i = 0; i < 9; i++) await scroll(p, 900); },
    3: async (p) => { await temple(p); await scroll(p, 420); },
    4: async (p) => { await temple(p); await p.waitForTimeout(3000); await scroll(p, 700); await tap(p, 'Book in the app', { wait: 3500, timeout: 20000 }); await scroll(p, 300); await tap(p, 'Book in the app · ₹116', { wait: 3500 }); await tap(p, 'Tomorrow', { wait: 2500 }); await tap(p, '8:00 – 9:00 AM', { wait: 1500 }); },
    5: async (p) => { await tap(p, 'Profile', { wait: 2500 }); await scroll(p, 600); await tap(p, 'My bookings', { wait: 3000 }); await tap(p, 'Sahasranama Archana', { wait: 3500 }); },
    6: async (p) => { await tap(p, 'Profile', { wait: 2500 }); await scroll(p, 600); await tap(p, 'My bookings', { wait: 3000 }); await tap(p, 'Sri Rama Bhajan Sandhya', { wait: 3500 }); for (let i = 0; i < 3; i++) await scroll(p, 900); await tap(p, 'Open the event', { wait: 4000, timeout: 15000 }); },
    7: async (p) => { await temple(p); await scroll(p, 700); await tap(p, 'Give', { wait: 3000 }); await tap(p, '₹501', { wait: 1200 }); await tap(p, 'Annadanam', { wait: 1200 }); },
    8: async (p) => { await tap(p, 'Festival calendar', { wait: 3500 }); },
    9: async (p) => { await tap(p, 'Passport', { wait: 3500 }); await p.mouse.click(272, 670); await p.waitForTimeout(2000); await p.mouse.click(272, 670); await p.waitForTimeout(2000); await p.mouse.click(272, 670); await p.waitForTimeout(2200); },
  };
  for (const [n, fn] of Object.entries(jobs)) if (!only || only.split(',').includes(n)) await run(n, fn);
})();
