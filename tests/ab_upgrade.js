// Kontrolovaný pokus v prohlížeči: jedna věž, stejná skupina nepřátel, mezi koly vylepšení KLIKNUTÍM na tlačítko v panelu.
//   node tests/ab_upgrade.js [--type=archer]
const { chromium } = require('playwright');
const TD_THEME_Q = process.env.TD_THEME ? '&theme=' + process.env.TD_THEME : '';   // TD_THEME=scifi => spustí test v daném prostředí
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(res); }).listen(8131);
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const type = args.type || 'archer';
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 800, height: 450 } });
  const logs = []; page.on('console', m => { if (m.type() !== 'log' || /ERROR|WARN/.test(m.text())) logs.push(`[${m.type()}] ${m.text()}`); });
  const st = async () => JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
  const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
  const box = async () => page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  const clickNorm = async p => { const b = await box(); const x = b.x + p[0] * b.w, y = b.y + p[1] * b.h; await page.mouse.move(x, y, { steps: 3 }); await page.mouse.click(x, y); };
  await page.goto('http://localhost:8131/index.html?test=1&skipintro=1&q=low' + TD_THEME_Q);
  await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 240000 });
  await cmd({ op: 'freeze', v: true });
  await cmd({ op: 'gold', v: 5000 });
  await cmd({ op: 'lives', v: 100000 });   // aby unikající nepřátelé neukončili pokus
  const cells = (await cmd({ op: 'cells' })).cells.filter(c => c.s > 12 && c.d < 2.1);
  // pole musí být na obrazovce ve volné střední části (ne pod lištami rozhraní), ať jde na věž skutečně kliknout
  let c0 = null;
  for (const c of cells) {
    const p = (await cmd({ op: 'cell_screen', cx: c.cx, cz: c.cz })).p;
    if (p[0] > 0.35 && p[0] < 0.7 && p[1] > 0.25 && p[1] < 0.6) { c0 = c; break; }
  }
  if (!c0) throw new Error('nenašlo se pole ve volné části obrazovky');
  console.log('pole pro věž:', JSON.stringify(c0));
  const built = await cmd({ op: 'build', type, cx: c0.cx, cz: c0.cz });
  const id = built.id;
  const rows = [];
  for (let level = 1; level <= 4; level++) {
    const info0 = await cmd({ op: 'tower_info', id });
    const s0 = await st();
    // stejná skupina nepřátel pro každé kolo (zdraví ×5)
    await cmd({ op: 'spawn', type: 'goblin', n: 10, interval: 1.0, lane: 0, hp: 5 });
    await cmd({ op: 'spawn', type: 'golem', n: 3, interval: 2.0, lane: 0, delay: 12, hp: 4 });
    await cmd({ op: 'spawn', type: 'wolf', n: 6, interval: 0.8, lane: 0, delay: 24, hp: 5 });
    await cmd({ op: 'spawn', type: 'drake', n: 3, interval: 1.2, lane: 0, delay: 34, hp: 5 });
    for (let i = 0; i < 40; i++) { await cmd({ op: 'step', t: 5 }); const q = await st(); if (q.spawn_left === 0 && q.enemies.length === 0) break; }
    const info1 = await cmd({ op: 'tower_info', id });
    const s1 = await st();
    rows.push({ level, stats: info1.stats, damage: Math.round(info1.damage_dealt - info0.damage_dealt), kills: info1.kills - info0.kills, leaked: s1.leaked - s0.leaked, shots: info1.shots - info0.shots });
    console.log(`Úroveň ${level}: dmg/zásah ${info1.stats.damage}, dosah ${info1.stats.range}, cd ${info1.stats.cooldown} -> způsobeno ${rows[rows.length - 1].damage}, zabito ${rows[rows.length - 1].kills}, uniklo ${rows[rows.length - 1].leaked}, výstřelů ${rows[rows.length - 1].shots}`);
    if (level < 4) {
      // vylepšení skutečným klikáním: klik na věž, klik na tlačítko Vylepšit
      const tp = (await cmd({ op: 'tower_screen', id })).p; await clickNorm(tp); await sleep(700);
      const sel = await st();
      console.log('  klik na věž na obrazovce', JSON.stringify(tp), '-> vybraná věž', sel.selected, '(čekáno', id + ')', 'režim stavby:', JSON.stringify(sel.build_type));
      const u = await cmd({ op: 'ui', name: 'upgrade_btn' });
      if (!u.ok) await page.screenshot({ path: path.join(OUT, 'ab_debug.png'), timeout: 240000 });
      if (!u.ok) throw new Error('tlačítko Vylepšit není vidět');
      await clickNorm(u.p); await sleep(600);
      await page.keyboard.press('Escape');
    }
  }
  fs.writeFileSync(path.join(OUT, `ab_upgrade_${type}.json`), JSON.stringify(rows, null, 2));
  console.log('chyb v konzoli:', logs.filter(l => /error/i.test(l)).length);
  await browser.close(); srv.close();
})().catch(e => { console.error('TEST SELHAL:', e); process.exit(1); });
