// Rychlý test: načte hru v Chromiu, počká na svět a uloží screenshot + výpis konzole.
//   node tests/smoke.js [--low] [--skipintro] [--wait=8000] [--out=tests/out] [--w=1280] [--h=720] [--yaw=45] [--zoom=50] [--shot=name]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(8124);
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: parseInt(args.w || 1280), height: parseInt(args.h || 720) } });
  const logs = [];
  page.on('console', m => { logs.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', e => logs.push('[pageerror] ' + e));
  const t0 = Date.now();
  await page.goto(`http://localhost:8124/index.html?test=1${args.low ? '&q=low' : ''}${args.skipintro ? '&skipintro=1' : ''}`);
  try { await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 240000 }); } catch (e) { logs.push('TIMEOUT waiting TD_ready'); }
  console.log('načteno za', ((Date.now() - t0) / 1000).toFixed(1), 's');
  if (args.yaw || args.zoom || args.px) await page.evaluate(o => { window.TD_cmd(JSON.stringify(o)); }, { op: 'cam', yaw: parseFloat(args.yaw || 45), zoom: parseFloat(args.zoom || 50), px: parseFloat(args.px || 0), pz: parseFloat(args.pz || 0) });
  await sleep(parseInt(args.wait || 8000));
  console.log(logs.slice(0, 80).join('\n'));
  const st = await page.evaluate(() => { window.TD_state(); return window.TD_out; });
  console.log('stav:', String(st).slice(0, 400));
  const t1 = Date.now();
  await page.screenshot({ path: path.join(OUT, (args.shot || 'smoke') + '.png'), timeout: 240000 });
  console.log('screenshot za', ((Date.now() - t1) / 1000).toFixed(1), 's');
  const st2 = JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
  console.log('fps', st2.fps);
  await browser.close(); srv.close();
})();
