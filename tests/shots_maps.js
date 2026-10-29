// Snímky map: celý ostrov shora (každá mapa, každé prostředí) + detaily.
//   node tests/shots_maps.js [--islands=0,1,2] [--themes=sky_island,scifi] [--out=tests/out] [--low] [--detail]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const ISLANDS = String(args.islands || '0,1,2').split(',');
const THEMES = String(args.themes || 'sky_island,scifi').split(',');
const PORT = Number(args.port || 8133);
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(PORT);
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const errors = [];
  for (const theme of THEMES) for (const isl of ISLANDS) {
    const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
    page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
    page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
    const t0 = Date.now();
    await page.goto('http://localhost:' + PORT + '/index.html?test=1&nosound=1&skipintro=1&' + (args.low ? 'q=low&' : '') + 'theme=' + theme + '&island=' + isl);
    await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 });
    console.log(theme, isl, 'načteno za', Date.now() - t0, 'ms');
    const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
    await cmd({ op: 'freeze', v: true });
    await cmd({ op: 'cam', yaw: 45, zoom: 92, px: 0, pz: 0 });
    await sleep(4500);
    await page.screenshot({ path: path.join(OUT, `mapa_${theme}_${isl}.png`) });
    console.log('snímek', `mapa_${theme}_${isl}`);
    if (args.detail) {
      const info = await cmd({ op: 'map_info' });
      console.log(JSON.stringify({ lanes: info.lanes.map(l => Math.round(l.len)), portals: info.portals.length, hills: info.hills.length, elev: info.elev_free }));
      for (let k = 0; k < info.hills.length && k < 2; k++) {
        const h = info.hills[k];
        await cmd({ op: 'cam', yaw: 30, zoom: 34, px: h.x, pz: h.z });
        await sleep(2500);
        await page.screenshot({ path: path.join(OUT, `mapa_${theme}_${isl}_kopec${k}.png`) });
      }
    }
    await page.context().close();
  }
  await browser.close(); srv.close();
  console.log(errors.length ? 'CHYBY: ' + errors.length : 'bez chyb');
  process.exit(errors.length ? 1 : 0);
})();
