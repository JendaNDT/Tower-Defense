// Automatický „odehraný“ test v prohlížeči (Chromium + Playwright). Hraje jako člověk: klikání myší, klávesy.
//   node tests/e2e_play.js [--low] [--waves=3] [--out=tests/out]
// Předpoklad: hra sestavená v docs/ (tools/build_web.sh). Výstup: screenshoty + výpis do konzole + out/e2e_report.json.
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const args = Object.fromEntries(process.argv.slice(2).map(a => {
  const [k, v] = a.replace(/^--/, '').split('=');
  return [k, v === undefined ? true : v];
}));
const ROOT = path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out'));
const WAVES = parseInt(args.waves || '3', 10);
const QUALITY = args.low ? '&q=low' : '';
fs.mkdirSync(OUT, { recursive: true });

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };
function serve(port) {
  return new Promise(resolve => {
    const srv = http.createServer((req, res) => {
      let p = decodeURIComponent(req.url.split('?')[0]);
      if (p === '/') p = '/index.html';
      const f = path.join(ROOT, p);
      if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); res.end('nenalezeno'); return; }
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(f)] || 'application/octet-stream',
        'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache',
      });
      fs.createReadStream(f).pipe(res);
    }).listen(port, () => resolve(srv));
  });
}
const sleep = ms => new Promise(r => setTimeout(r, ms));
const report = { steps: [], errors: [], console: [] };
function log(...a) { const s = a.join(' '); console.log(s); report.steps.push(s); }

(async () => {
  const srv = await serve(8123);
  const browser = await chromium.launch({
    args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox', '--enable-features=Vulkan'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { const t = m.text(); report.console.push(t); if (m.type() === 'error' || /SCRIPT ERROR|ERROR|WARNING: .*shader/i.test(t)) { report.errors.push(t); console.log('[konzole]', t); } });
  page.on('pageerror', e => { report.errors.push(String(e)); console.log('[pageerror]', String(e)); });

  const st = async () => JSON.parse(await page.evaluate(() => window.TD_state()));
  const cmd = async o => JSON.parse(await page.evaluate(x => window.TD_cmd(JSON.stringify(x)), o));
  const box = async () => page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  const toPx = async p => { const b = await box(); return [b.x + p[0] * b.w, b.y + p[1] * b.h]; };
  const clickNorm = async p => { const [x, y] = await toPx(p); await page.mouse.move(x, y, { steps: 4 }); await page.mouse.click(x, y); };
  const shot = async name => { await page.screenshot({ path: path.join(OUT, name + '.png') }); log('  screenshot', name); };
  const clickUi = async name => { const r = await cmd({ op: 'ui', name }); if (!r.ok) throw new Error('UI prvek nenalezen: ' + name); await clickNorm(r.p); return r; };
  async function waitFor(fn, timeoutMs, label, pollMs = 500) {
    const t0 = Date.now();
    while (Date.now() - t0 < timeoutMs) { const v = await fn(); if (v) return v; await sleep(pollMs); }
    throw new Error('Časový limit: ' + label);
  }

  const t0 = Date.now();
  await page.goto(`http://localhost:8123/index.html?test=1${QUALITY}`);
  await waitFor(() => page.evaluate(() => window.TD_ready === true), 300000, 'načtení hry', 1000);
  log('Hra načtena za', ((Date.now() - t0) / 1000).toFixed(1), 's');
  await sleep(1500);
  await shot('01_uvod');

  // --- úvodní obrazovka -> klik na „Začít hru“
  await clickUi('intro_btn');
  await sleep(600);
  let s = await st();
  log('Po kliknutí na Začít: modal =', s.modal, ', paused =', s.paused, ', zlato =', s.gold, ', životy =', s.lives);
  await cmd({ op: 'max_dt', v: 0.5 });
  await shot('02_hra_pohled');

  // --- výběr míst u cesty
  const cells = (await cmd({ op: 'cells' })).cells;
  log('Volných polí u cesty:', cells.length);
  const pick = (sMin, sMax, n, used) => cells.filter(c => c.s >= sMin && c.s <= sMax && !used.some(u => u.cx === c.cx && u.cz === c.cz) && c.d < 2.6).slice(0, n);

  // --- stavba skutečnou myší: klávesa 1 -> klik na pole
  const built = [];
  async function buildReal(key, type, cell) {
    await page.keyboard.press(key);
    const r = await cmd({ op: 'cell_screen', cx: cell.cx, cz: cell.cz });
    const [x, y] = await toPx(r.p);
    await page.mouse.move(x, y, { steps: 6 });
    await sleep(400);
    await page.mouse.click(x, y);
    await sleep(300);
    const s2 = await st();
    const t = s2.towers.find(t => t.cx === cell.cx && t.cz === cell.cz);
    log(`Stavba ${type} na [${cell.cx},${cell.cz}] -> ${t ? 'OK (id ' + t.id + ')' : 'SELHALO'}, zlato ${s2.gold}`);
    if (t) built.push({ ...t, cell });
    await page.keyboard.press('Escape');
    return t;
  }
  const mid = cells.filter(c => c.d < 2.6);
  const spots = [];
  const take = (lo, hi) => { const c = mid.find(c => c.s >= lo && c.s <= hi && !spots.some(u => u.cx === c.cx && u.cz === c.cz)); if (c) spots.push(c); return c; };
  const a1 = take(14, 30), a2 = take(30, 46), c1 = take(46, 66);
  await buildReal('1', 'archer', a1);
  await shot('03_po_stavbe_lucistnika');
  await buildReal('1', 'archer', a2);
  await buildReal('2', 'cannon', c1);
  await shot('04_tri_veze');

  // --- zrychlení a první vlny
  await cmd({ op: 'speed', v: 3 });
  const waveResults = [];
  for (let w = 1; w <= WAVES; w++) {
    s = await st();
    log(`--- Vlna ${w}: zlato ${s.gold}, životy ${s.lives}`);
    await clickUi('wave_btn');
    await sleep(800);
    s = await st();
    log('  vlna spuštěna, nepřátel ve frontě:', s.spawn_left, ', na mapě:', s.enemies.length);
    let shots = 0;
    await waitFor(async () => {
      const q = await st();
      if (q.spawn_left === 0 && q.enemies.length === 0 && q.wave >= w) return true;
      if (shots < 3 && q.enemies.length >= 3 && Math.random() < 0.35) { shots++; await shot(`w${w}_boj_${shots}`); }
      return false;
    }, 900000, `dokončení vlny ${w}`, 1500);
    s = await st();
    log(`  vlna ${w} dokončena: zlato ${s.gold}, životy ${s.lives}, zabití ${s.kills}, uniklí ${s.leaked}, zásahy/ztraceno projektilů ${s.proj_hits}/${s.proj_fizzles}, FPS ${s.fps}`);
    waveResults.push({ wave: w, gold: s.gold, lives: s.lives, kills: s.kills, leaked: s.leaked, fps: s.fps });
    await shot(`w${w}_hotovo`);

    // po 1. vlně: vylepšení věže skutečným klikáním
    if (w === 1) {
      const t = s.towers.find(t => t.type === 'archer');
      const before = (await cmd({ op: 'tower_info', id: t.id }));
      await cmd({ op: 'gold', v: 200 });  // jistota, aby šlo vylepšit (v testu)
      const tp = (await cmd({ op: 'tower_screen', id: t.id })).p;
      await clickNorm(tp);
      await sleep(500);
      await shot('05_panel_veze_L1');
      log(`  vybrána věž ${t.id}: úroveň ${before.level}, dmg ${before.stats.damage}, dosah ${before.stats.range}, cd ${before.stats.cooldown}; způsobeno ${before.damage_dealt.toFixed(0)}`);
      await clickUi('upgrade_btn');
      await sleep(900);
      const after = (await cmd({ op: 'tower_info', id: t.id }));
      log(`  po vylepšení: úroveň ${after.level}, dmg ${after.stats.damage}, dosah ${after.stats.range}, cd ${after.stats.cooldown}`);
      await shot('06_panel_veze_L2');
      report.upgrade_ui = { before: before.stats, after: after.stats, level_before: before.level, level_after: after.level };
      await page.keyboard.press('Escape');
    }
  }
  report.waves = waveResults;

  // --- kontrolovaný pokus v prohlížeči: stejná skupina nepřátel na L1 vs. vylepšené věži (jedna věž)
  if (args.ab) {
    log('--- Pokus L1 vs L2+ v prohlížeči');
  }
  fs.writeFileSync(path.join(OUT, 'e2e_report.json'), JSON.stringify(report, null, 2));
  log('Chyb v konzoli:', report.errors.length);
  await browser.close();
  srv.close();
  process.exit(report.errors.length ? 2 : 0);
})().catch(e => { console.error('TEST SELHAL:', e); fs.writeFileSync(path.join(OUT, 'e2e_report.json'), JSON.stringify({ ...report, fatal: String(e) }, null, 2)); process.exit(1); });
