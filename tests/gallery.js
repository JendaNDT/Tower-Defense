// Galerie: čtyři typy věží na stejné úrovni vedle sebe, všechny 4 úrovně; pak každý typ nepřítele zblízka.
//   node tests/gallery.js [--w=1000] [--h=562] [--low] [--part=towers|enemies|both]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(8127);
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const part = args.part || 'both';
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: parseInt(args.w || 1000), height: parseInt(args.h || 562) } });
  const logs = []; page.on('console', m => { if (m.type() !== 'log' || /ERROR|WARN/.test(m.text())) logs.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', e => logs.push('[pageerror] ' + e));
  const st = async () => JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
  const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
  const shot = async n => { await page.screenshot({ path: path.join(OUT, n + '.png'), timeout: 240000 }); console.log('snímek', n); };
  await page.goto(`http://localhost:8127/index.html?test=1&skipintro=1${args.low ? '&q=low' : ''}`);
  await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 240000 });
  await cmd({ op: 'freeze', v: true });
  await cmd({ op: 'gold', v: 20000 });
  const world = (cx, cz) => [-24 + (cx + 0.5) * 2, -24 + (cz + 0.5) * 2];
  if (part !== 'enemies') {
    const cells = (await cmd({ op: 'cells' })).cells;
    const set = new Set(cells.map(c => c.cx + ',' + c.cz));
    let run = null;
    for (const c of cells) { if (c.s > 40 && c.cx >= 2 && [0, 1, 2, 3].every(i => set.has((c.cx + i) + ',' + c.cz))) { run = c; break; } }
    if (!run) for (const c of cells) { if ([0, 1, 2, 3].every(i => set.has((c.cx + i) + ',' + c.cz))) { run = c; break; } }
    console.log('řada polí:', JSON.stringify(run));
    const types = ['archer', 'cannon', 'mage', 'frost'];
    const ids = [];
    for (let i = 0; i < 4; i++) { const r = await cmd({ op: 'build', type: types[i], cx: run.cx + i, cz: run.cz }); ids.push(r.id); }
    const [wx, wz] = world(run.cx + 1.5, run.cz);
    for (const yaw of [45]) {
      await cmd({ op: 'cam', yaw, zoom: 11, px: wx, pz: wz });
      for (let level = 1; level <= 4; level++) {
        await sleep(1500);
        await shot(`gal_veze_L${level}`);
        if (level < 4) { for (const id of ids) await cmd({ op: 'upgrade', id }); await cmd({ op: 'step', t: 2.5 }); }
      }
    }
  }
  if (part !== 'towers') {
    const li = await cmd({ op: 'lineup', s0: 30, ds: 3.4 });
    const mid = li.pos[2];
    console.log('řada nepřátel:', JSON.stringify(li.pos));
    for (const [k, yaw] of [[0, 45], [1, 135]]) {
      await cmd({ op: 'cam', yaw, zoom: 11, px: mid[0], pz: mid[2] });
      await sleep(1500);
      await shot(`gal_nepratele_${k}`);
    }
  }
  console.log(logs.slice(0, 40).join('\n'));
  await browser.close(); srv.close();
})();
