// Odehraje všech 12 vln botem uvnitř exportované webové verze (v prohlížeči). node tests/browser_bot.js [--pol=vysoka]
const { chromium } = require('playwright');
const TD_THEME_Q = process.env.TD_THEME ? '&theme=' + process.env.TD_THEME : '';   // TD_THEME=scifi => spustí test v daném prostředí
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(res); }).listen(8130);
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 640, height: 360 } });
  const logs = []; page.on('console', m => { if (m.type() !== 'log' || /ERROR|WARN/.test(m.text())) logs.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', e => logs.push('[pageerror] ' + e));
  await page.goto('http://localhost:8130/index.html?test=1&skipintro=1&q=low' + TD_THEME_Q);
  await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 240000 });
  const t0 = Date.now();
  await page.evaluate(o => { window.TD_cmd(JSON.stringify(o)); }, { op: 'simbot', pol: args.pol || 'vysoka' });
  const out = JSON.parse(await page.evaluate(() => window.TD_out));
  const b = out.report;
  console.log('simulace v prohlížeči trvala', ((Date.now() - t0) / 1000).toFixed(1), 's');
  console.log(JSON.stringify({ state: b.state, lives: b.lives, waves: b.waves_started, kills: b.kills, leaked: b.leaked, game_time: b.game_time, physics_ok: b.physics_ok, proj_hits: b.proj_hits, proj_fizzles: b.proj_fizzles, max_jump: b.max_jump_over_allowed, dy_ground: b.max_dy_ground, min_obs: b.min_dist_enemy_to_obstacle }));
  console.log(b.waves.map(w => `v${w.wave}: životy ${w.lives}, zabito ${w.kills}, uniklo ${w.leaked}`).join(' | '));
  console.log('chyby/varování v konzoli:', logs.length); console.log(logs.slice(0, 10).join('\n'));
  await browser.close(); srv.close();
})();
