// Snímky motivu (prostředí): menu s výběrem, přehled světa, věže všech úrovní, nepřátelé, efekty.
//   node tests/shots_theme.js --theme=scifi [--out=tests/out] [--what=menu,world,towers,enemies,fx] [--low]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const THEME = String(args.theme || 'scifi');
const WHAT = String(args.what || 'menu,world,towers,enemies,fx').split(',');
const PORT = Number(args.port || 8131);
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(PORT);
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const errors = [];
  async function open(query, w = 1280, h = 720) {
    const page = await (await browser.newContext({ viewport: { width: w, height: h } })).newPage();
    page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
    page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
    await page.goto('http://localhost:' + PORT + '/index.html?test=1&nosound=1&' + (args.low ? 'q=low&' : '') + 'theme=' + THEME + '&' + query);
    await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 });
    const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
    return { page, cmd };
  }
  const shot = async (page, name) => { await page.screenshot({ path: path.join(OUT, THEME + '_' + name + '.png') }); console.log('snímek', THEME + '_' + name); };
  if (WHAT.includes('menu')) {
    const { page } = await open('');
    await sleep(2500);
    await shot(page, 'menu');
    await page.context().close();
  }
  if (WHAT.includes('world')) {
    const { page, cmd } = await open('skipintro=1');
    await cmd({ op: 'cam', yaw: 45, zoom: 62, px: 0, pz: 0 });
    await sleep(4000);
    await shot(page, 'svet');
    await cmd({ op: 'cam', yaw: 20, zoom: 30, px: -12, pz: -12 });
    await sleep(2500);
    await shot(page, 'svet_blizko');
    await cmd({ op: 'cam', yaw: 200, zoom: 40, px: 14, pz: 14 });
    await sleep(2500);
    await shot(page, 'svet_pustina');
    await page.context().close();
  }
  if (WHAT.includes('towers')) {
    const { page, cmd } = await open('skipintro=1');
    await cmd({ op: 'freeze', v: true });
    await cmd({ op: 'gold', v: 20000 });
    const cells = (await cmd({ op: 'cells' })).cells;
    const set = new Set(cells.map(c => c.cx + ',' + c.cz));
    let run = null;
    for (const c of cells) { if (c.s > 40 && c.cx >= 2 && [0, 1, 2, 3].every(i => set.has((c.cx + i) + ',' + c.cz))) { run = c; break; } }
    if (!run) for (const c of cells) { if ([0, 1, 2, 3].every(i => set.has((c.cx + i) + ',' + c.cz))) { run = c; break; } }
    const types = ['archer', 'cannon', 'mage', 'frost'];
    const ids = [];
    for (let i = 0; i < 4; i++) { const r = await cmd({ op: 'build', type: types[i], cx: run.cx + i, cz: run.cz }); ids.push(r.id); }
    const wx = -24 + (run.cx + 2) * 2, wz = -24 + (run.cz + 0.5) * 2;
    await cmd({ op: 'cam', yaw: 45, zoom: 11, px: wx, pz: wz });
    for (let level = 1; level <= 4; level++) {
      await cmd({ op: 'step', t: 2.5 });
      await sleep(1500);
      await shot(page, 'veze_L' + level);
      if (level < 4) { for (const id of ids) await cmd({ op: 'upgrade', id }); }
    }
    await page.context().close();
  }
  if (WHAT.includes('enemies')) {
    const { page, cmd } = await open('skipintro=1');
    await cmd({ op: 'freeze', v: true });
    const types = ['goblin', 'wolf', 'golem', 'drake', 'healer', 'shield', 'slime', 'slimeling', 'boss'];
    const li = await cmd({ op: 'lineup', types, s0: 14, ds: 4.0 });
    for (let i = 0; i < types.length; i++) {
      const p = li.pos[i];
      await cmd({ op: 'cam', yaw: 40, zoom: types[i] === 'boss' ? 12 : (types[i] === 'golem' ? 8 : 6.5), px: p[0], pz: p[2] });
      await sleep(3200);
      const pr = (await cmd({ op: 'project', x: p[0], y: p[1] + 0.5, z: p[2] })).p;
      const cw = 560, ch = 420;
      const cx = Math.min(Math.max(pr[0] * 1280 - cw / 2, 0), 1280 - cw), cy = Math.min(Math.max(pr[1] * 720 - ch / 2, 0), 720 - ch);
      await page.screenshot({ path: path.join(OUT, THEME + '_nepritel_' + types[i] + '.png'), clip: { x: cx, y: cy, width: cw, height: ch } });
      console.log('snímek', THEME + '_nepritel_' + types[i]);
    }
    await page.context().close();
  }
  if (WHAT.includes('models')) {
    // samostatné modely mimo hrací pole (pozadí = vesmír / mraky), zblízka a ze dvou stran
    const { page, cmd } = await open('skipintro=1');
    await cmd({ op: 'freeze', v: true });
    const etypes = ['goblin', 'wolf', 'golem', 'drake', 'healer', 'shield', 'slime', 'slimeling', 'boss'];
    for (let i = 0; i < etypes.length; i++) await cmd({ op: 'put_visual', kind: 'enemy', type: etypes[i], x: 90 + i * 10, y: etypes[i] === "drake" ? 0.6 : 0, z: 90 });
    for (let i = 0; i < etypes.length; i++) {
      await cmd({ op: 'cam', yaw: 30, zoom: etypes[i] === 'boss' ? 7.5 : (etypes[i] === 'golem' ? 4.6 : 3.4), px: 90 + i * 10, pz: 90 });
      await sleep(2600);
      await page.screenshot({ path: path.join(OUT, THEME + '_model_' + etypes[i] + '.png'), clip: { x: 340, y: 110, width: 600, height: 500 } });
      console.log('snímek model', etypes[i]);
    }
    const ttypes = ['archer', 'cannon', 'mage', 'frost'];
    for (let ti = 0; ti < 4; ti++) for (let lv = 1; lv <= 4; lv++) await cmd({ op: 'put_visual', kind: 'tower', type: ttypes[ti], level: lv, x: 90 + lv * 4, z: 140 + ti * 4 });
    await cmd({ op: 'cam', yaw: 38, zoom: 14, px: 98, pz: 146 });
    await sleep(3000);
    await page.screenshot({ path: path.join(OUT, THEME + '_model_veze.png'), clip: { x: 200, y: 60, width: 880, height: 600 } });
    console.log('snímek model veze');
    await page.context().close();
  }
  if (WHAT.includes('fx')) {
    const { page, cmd } = await open('skipintro=1');
    await cmd({ op: 'gold', v: 20000 });
    const cells = (await cmd({ op: 'cells' })).cells;
    const pick = (n) => cells.filter(c => c.s > 20).filter((c, i) => i % Math.max(1, Math.floor(cells.length / 40)) === 0).slice(0, n);
    const types = ['archer', 'cannon', 'mage', 'frost', 'archer', 'mage'];
    const sel = pick(6);
    for (let i = 0; i < sel.length; i++) { const r = await cmd({ op: 'build', type: types[i], cx: sel[i].cx, cz: sel[i].cz }); await cmd({ op: 'upgrade', id: r.id }); await cmd({ op: 'upgrade', id: r.id }); }
    await cmd({ op: 'max_dt', v: 0.1 });
    await cmd({ op: 'spawn', type: 'goblin', n: 6, interval: 0.5, hp: 400 });
    await cmd({ op: 'spawn', type: 'golem', n: 2, interval: 1.2, hp: 300, delay: 1 });
    await cmd({ op: 'spawn', type: 'drake', n: 3, interval: 0.8, hp: 300, delay: 2 });
    await cmd({ op: 'cam', yaw: 45, zoom: 26, px: sel[0] ? -24 + sel[0].cx * 2 : 0, pz: sel[0] ? -24 + sel[0].cz * 2 : 0 });
    await cmd({ op: 'step', t: 14 });
    await sleep(1500);
    await shot(page, 'boj');
    await cmd({ op: 'cast', id: 'blizzard' });
    await cmd({ op: 'step', t: 0.6 });
    await sleep(1500);
    await shot(page, 'kryo_vlna');
    await page.context().close();
  }
  console.log('chyby:', errors.length);
  await browser.close(); srv.close();
  process.exit(errors.length ? 1 : 0);
})();
