// Prohlídka světa: jedna relace, víc pohledů kamery. node tests/tour.js [--low] [--w=1000] [--h=562] [--views=a,b,c]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(8126);
const VIEWS = {
  fall: { px: 6, pz: 27, yaw: 45, zoom: 18 },
  fall_s: { px: 5, pz: 28, yaw: 0, zoom: 36 },
  fall_e: { px: 5, pz: 28, yaw: 90, zoom: 36 },
  fall2: { px: 6, pz: 27, yaw: 135, zoom: 22 },
  portal: { px: -22, pz: -16, yaw: 45, zoom: 16 },
  heart: { px: 19, pz: -14, yaw: 45, zoom: 16 },
  bridge: { px: 3, pz: 11, yaw: 45, zoom: 16 },
  back: { px: 0, pz: 0, yaw: 225, zoom: 56 },
  side: { px: 0, pz: 0, yaw: 135, zoom: 50 },
  under: { px: 0, pz: 0, yaw: 45, zoom: 64 },
};
(async () => {
  const names = (args.views || 'fall,portal,heart,bridge,back').split(',');
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: parseInt(args.w || 1000), height: parseInt(args.h || 562) } });
  const logs = []; page.on('console', m => { if (m.type() !== 'log' || /ERROR|WARN/.test(m.text())) logs.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', e => logs.push('[pageerror] ' + e));
  await page.goto(`http://localhost:8126/index.html?test=1&skipintro=1${args.low ? '&q=low' : ''}`);
  await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 240000 });
  for (const n of names) {
    const v = VIEWS[n];
    await page.evaluate(o => { window.TD_cmd(JSON.stringify(o)); }, { op: 'cam', ...v });
    await new Promise(r => setTimeout(r, 2500));
    await page.screenshot({ path: path.join(OUT, 'tour_' + n + '.png'), timeout: 240000 });
    console.log('hotovo', n);
  }
  console.log(logs.slice(0, 40).join('\n'));
  await browser.close(); srv.close();
})();
