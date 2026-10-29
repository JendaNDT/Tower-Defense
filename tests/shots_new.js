// Snímky nových věcí: menu, ostrovy (všechna rozložení), noví nepřátelé, schopnosti.
//   node tests/shots_new.js [--out=tests/out] [--what=menu,islands,enemies,abilities]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const WHAT = String(args.what || 'menu,islands,enemies,abilities').split(',');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(8127);
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const errors = [];
  async function open(query, w = 1280, h = 720) {
    const page = await (await browser.newContext({ viewport: { width: w, height: h } })).newPage();
    page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
    page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
    await page.goto('http://localhost:8127/index.html?test=1&q=low&nosound=1&' + query);
    await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 });
    const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
    return { page, cmd };
  }
  if (WHAT.includes('menu')) {
    const { page } = await open('');
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, 'nove_menu.png') });
    console.log('snímek nove_menu');
    await page.context().close();
  }
  if (WHAT.includes('islands')) {
    for (const q of ['island=0', 'island=1', 'island=2', 'island=3&seed=1002']) {
      const { page, cmd } = await open(q + '&skipintro=1');
      await cmd({ op: 'cam', yaw: 45, zoom: 62, px: 0, pz: 0 });
      await sleep(4000);
      await page.screenshot({ path: path.join(OUT, 'ostrov_' + q.replace(/[^a-z0-9]/gi, '_') + '.png') });
      console.log('snímek ostrov', q);
      await page.context().close();
    }
  }
  if (WHAT.includes('enemies')) {
    const { page, cmd } = await open('skipintro=1');
    const r = await cmd({ op: 'lineup', types: ['healer', 'shield', 'slime', 'slimeling', 'goblin'], s0: 12, ds: 2.6 });
    await cmd({ op: 'freeze', v: true });
    const p0 = r.pos[2];
    await cmd({ op: 'cam', yaw: 35, zoom: 11, px: p0[0], pz: p0[2] });
    await sleep(3500);
    await page.screenshot({ path: path.join(OUT, 'nepratele_novi.png') });
    console.log('snímek nepratele_novi');
    await page.context().close();
  }
  if (WHAT.includes('abilities')) {
    const { page, cmd } = await open('skipintro=1');
    await cmd({ op: 'max_dt', v: 0.1 });
    await cmd({ op: 'spawn', type: 'goblin', n: 8, interval: 0.45, hp: 6 });
    await cmd({ op: 'spawn', type: 'slime', n: 2, interval: 0.6, hp: 6, delay: 1 });
    await cmd({ op: 'step', t: 9 });
    const q = JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
    const mid = q.enemies.reduce((a, e) => ({ x: a.x + e.x / q.enemies.length, z: a.z + e.z / q.enemies.length }), { x: 0, z: 0 });
    await cmd({ op: 'cam', yaw: 35, zoom: 18, px: mid.x, pz: mid.z });
    await cmd({ op: 'cast', id: 'meteor', x: mid.x, z: mid.z });
    await cmd({ op: 'step', t: 0.6 });
    await cmd({ op: 'freeze', v: true });
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, 'schopnost_meteor_let.png') });
    await cmd({ op: 'freeze', v: false });
    await cmd({ op: 'step', t: 0.45 });
    await cmd({ op: 'freeze', v: true });
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, 'schopnost_meteor_dopad.png') });
    await cmd({ op: 'freeze', v: false });
    await cmd({ op: 'cast', id: 'blizzard' });
    await cmd({ op: 'step', t: 0.5 });
    await cmd({ op: 'freeze', v: true });
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, 'schopnost_poryv.png') });
    console.log('snímky schopností');
    await page.context().close();
  }
  console.log('chyb v konzoli:', errors.length);
  await browser.close(); srv.close();
})().catch(e => { console.error('SELHALO', e); process.exit(1); });
