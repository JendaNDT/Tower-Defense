// Kontrola ovládání a obrazovek: kamera (klávesy/myš), nepovolená stavba, prodej, cíl, pauza, rychlost, prohra+restart, výhra.
const { chromium } = require('playwright');
const TD_THEME_Q = process.env.TD_THEME ? '&theme=' + process.env.TD_THEME : '';   // TD_THEME=scifi => spustí test v daném prostředí
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(8129);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const results = [];
function check(name, ok, info) { results.push({ name, ok: !!ok, info }); console.log(ok ? 'OK  ' : 'CHYBA', name, info === undefined ? '' : JSON.stringify(info)); }
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 800, height: 450 } });
  const logs = []; page.on('console', m => { if (m.type() !== 'log' || /ERROR|WARN/.test(m.text())) logs.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', e => logs.push('[pageerror] ' + e));
  const st = async () => JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
  const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
  const box = async () => page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  const toPx = async p => { const b = await box(); return [b.x + p[0] * b.w, b.y + p[1] * b.h]; };
  const clickNorm = async p => { const [x, y] = await toPx(p); await page.mouse.move(x, y, { steps: 3 }); await page.mouse.click(x, y); };
  const shot = async n => { await page.screenshot({ path: path.join(OUT, n + '.png'), timeout: 240000 }); console.log('snímek', n); };
  await page.goto('http://localhost:8129/index.html?test=1&skipintro=1&q=low' + TD_THEME_Q);
  await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 240000 });
  await sleep(1500);
  let s = await st();
  const y0 = s.camera.yaw, z0 = s.camera.zoom;

  // --- kamera: klávesy Q/E, kolečko, tažení pravým tlačítkem
  await page.keyboard.down('q'); await sleep(2500); await page.keyboard.up('q');
  await sleep(800); s = await st();
  check('Klávesa Q otáčí kameru', Math.abs(s.camera.yaw - y0) > 5, { yaw: s.camera.yaw });
  const yq = s.camera.yaw;
  const b = await box(); const cxp = b.x + b.w / 2, cyp = b.y + b.h / 2;
  await page.mouse.move(cxp, cyp);
  for (let i = 0; i < 4; i++) { await page.mouse.wheel(0, -120); await sleep(200); }
  await sleep(1500); s = await st();
  check('Kolečko myši přibližuje', s.camera.zoom < z0 - 3, { zoom: s.camera.zoom });
  await page.mouse.move(cxp, cyp); await page.mouse.down({ button: 'right' });
  await page.mouse.move(cxp + 120, cyp, { steps: 6 }); await page.mouse.up({ button: 'right' });
  await sleep(1200); s = await st();
  check('Tažení pravým tlačítkem otáčí', Math.abs(s.camera.yaw - yq) > 10, { yaw: s.camera.yaw });
  await cmd({ op: 'cam', yaw: 45, zoom: 44, px: 0, pz: 0 });

  // --- stavba: nepovolené pole (cesta) a nedostatek zlata
  await page.keyboard.press('1');
  const pathCell = { cx: 15, cz: 24 };   // společný úsek tras (mapa Dvě brány), uprostřed obrazovky mimo minimapu
  let r = await cmd({ op: 'cell_screen', cx: pathCell.cx, cz: pathCell.cz });
  await clickNorm(r.p); await sleep(400);
  let h = await cmd({ op: 'hud' });
  check('Stavba na cestě je odmítnuta s hláškou', /nedá/.test(h.toast), { toast: h.toast });
  await page.keyboard.press('Escape');
  await cmd({ op: 'gold', v: -230 }); // zbude 10 zlata
  const cells = (await cmd({ op: 'cells' })).cells;
  const c0 = cells.find(c => c.s > 95 && c.d < 2.6) || cells[5];   // pole u konce trasy, kam nezasahuje minimapa
  await page.keyboard.press('2');
  r = await cmd({ op: 'cell_screen', cx: c0.cx, cz: c0.cz }); await clickNorm(r.p); await sleep(400);
  h = await cmd({ op: 'hud' }); s = await st();
  check('Nedostatek zlata -> hláška, věž nepostavena', /zlata/i.test(h.toast) && s.towers.length === 0, { toast: h.toast });
  await page.keyboard.press('Escape');
  await cmd({ op: 'gold', v: 1000 });

  // --- stavba, cíl (T), prodej (X)
  await page.keyboard.press('3');
  r = await cmd({ op: 'cell_screen', cx: c0.cx, cz: c0.cz }); await clickNorm(r.p); await sleep(500);
  s = await st();
  check('Mág postaven klikem', s.towers.length === 1 && s.towers[0].type === 'mage', s.towers[0]);
  await page.keyboard.press('Escape');
  const tw = s.towers[0];
  const tp = (await cmd({ op: 'tower_screen', id: tw.id })).p; await clickNorm(tp); await sleep(500);
  s = await st();
  check('Klik na věž ji vybere (panel)', s.selected === tw.id, { selected: s.selected });
  await page.keyboard.press('t'); await sleep(500); s = await st();
  check('Klávesa T mění režim cílení', s.towers[0].mode !== 'first', { mode: s.towers[0].mode });
  const goldBefore = s.gold;
  await page.keyboard.press('u'); await sleep(500); s = await st();
  check('Klávesa U vylepší věž', s.towers[0].level === 2 && s.gold < goldBefore, { level: s.towers[0].level, gold: s.gold });
  const goldMid = s.gold;
  await page.keyboard.press('x'); await sleep(500); s = await st();
  check('Klávesa X věž prodá (vrátí 70 %)', s.towers.length === 0 && s.gold > goldMid, { gold: s.gold, vraceno: s.gold - goldMid });

  // --- pauza a rychlost
  await page.keyboard.press('p'); await sleep(500); s = await st();
  check('Klávesa P pozastaví hru', s.paused === true);
  await shot('ui_pauza');
  await page.keyboard.press('p'); await sleep(300); s = await st();
  check('Druhé P pokračuje', s.paused === false);
  await page.keyboard.press('f'); await sleep(300); s = await st();
  check('Klávesa F přepne rychlost na 2×', s.speed === 2, { speed: s.speed });
  await page.keyboard.press('f'); await page.keyboard.press('f'); await sleep(300); s = await st();
  check('Po třech stisknutích zpět 1×', s.speed === 1, { speed: s.speed });

  // --- prohra a restart
  await cmd({ op: 'lives', v: 1 });
  await cmd({ op: 'lineup', types: ['boss'], s0: 133, ds: 1 });
  await cmd({ op: 'step', t: 6.0 });
  await sleep(1200); s = await st();
  check('Prohra (životy 0, stav LOST)', s.lives === 0 && s.state === 2, { lives: s.lives, state: s.state });
  await shot('ui_konec_hry');
  const rr = await cmd({ op: 'ui', name: 'end_btn' });
  if (rr.ok) await clickNorm(rr.p);
  await sleep(1200); s = await st();
  check('Hrát znovu: reset hry', s.state === 0 && s.lives === 20 && s.gold === 240 && s.wave === 0, { lives: s.lives, gold: s.gold, wave: s.wave });

  // --- výhra
  await cmd({ op: 'win' });
  await sleep(1200); s = await st();
  check('Výhra (stav WON)', s.state === 1, { state: s.state });
  await shot('ui_vitezstvi');
  console.log('\nchyby v konzoli:', logs.filter(l => /error|pageerror/i.test(l)).length);
  console.log(logs.filter(l => /error|pageerror/i.test(l)).slice(0, 10).join('\n'));
  fs.writeFileSync(path.join(OUT, 'ui_flow_report.json'), JSON.stringify({ results, logs: logs.slice(0, 50) }, null, 2));
  await browser.close(); srv.close();
  process.exit(results.every(r => r.ok) ? 0 : 1);
})().catch(e => { console.error('TEST SELHAL:', e); process.exit(1); });
