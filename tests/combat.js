// Snímky boje: věže na různých úrovních + nepřátelé + letící projektily. node tests/combat.js [--w=1000] [--h=562]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(8128);
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: parseInt(args.w || 1000), height: parseInt(args.h || 562) } });
  const logs = []; page.on('console', m => { if (m.type() !== 'log' || /ERROR|WARN/.test(m.text())) logs.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', e => logs.push('[pageerror] ' + e));
  const st = async () => JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
  const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
  const shot = async n => { await page.screenshot({ path: path.join(OUT, n + '.png'), timeout: 240000 }); console.log('snímek', n); };
  await page.goto(`http://localhost:8128/index.html?test=1&skipintro=1`);
  await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 240000 });
  await cmd({ op: 'freeze', v: true });
  await cmd({ op: 'gold', v: 20000 });
  const cells = (await cmd({ op: 'cells' })).cells.filter(c => c.s > 20 && c.s < 62 && c.d < 2.6);
  const spots = [];
  for (const c of cells) { if (spots.every(p => Math.hypot(p.cx - c.cx, p.cz - c.cz) >= 2)) spots.push(c); if (spots.length >= 4) break; }
  const plan = [['archer', 3], ['cannon', 2], ['mage', 3], ['frost', 2]];
  for (let i = 0; i < spots.length; i++) {
    const r = await cmd({ op: 'build', type: plan[i][0], cx: spots[i].cx, cz: spots[i].cz });
    for (let l = 1; l < plan[i][1]; l++) await cmd({ op: 'upgrade', id: r.id });
  }
  const w = (c) => [-24 + (c.cx + 0.5) * 2, -24 + (c.cz + 0.5) * 2];
  const cx = spots.reduce((a, c) => a + w(c)[0], 0) / spots.length, cz = spots.reduce((a, c) => a + w(c)[1], 0) / spots.length;
  await cmd({ op: 'cam', yaw: 45, zoom: 17, px: cx, pz: cz });
  await cmd({ op: 'lineup', types: ['goblin', 'goblin', 'wolf', 'golem', 'drake', 'goblin', 'boss'], s0: 12, ds: 4.0 });
  let shots = 0, t = 0;
  while (shots < 6 && t < 90) {
    await cmd({ op: 'step', t: 0.45 }); t += 0.45;
    const s = await st();
    if (s.projectiles > 0 && s.enemies.length > 0 && (t > 2)) { await shot(`boj_${shots}`); shots++; await cmd({ op: 'step', t: 0.2 }); }
  }
  const s = await st();
  console.log('stav:', JSON.stringify({ kills: s.kills, gold: s.gold, enemies: s.enemies.length, hits: s.proj_hits, draw_calls: s.draw_calls, objects: s.objects, primitives: s.primitives }));
  console.log(logs.slice(0, 40).join('\n'));
  await browser.close(); srv.close();
})();
