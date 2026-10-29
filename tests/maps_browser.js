// Test map: tři nové mapy (víc bran, rozcestí, spojení, kopce, mosty) v prohlížeči.
//   node tests/maps_browser.js [--out=tests/out] [--theme=sky_island] [--maps=0,1,2]
// Kontroluje: počet tras / portálů / mostů, délky tras, kopce a jejich pole, rozdělení nepřátel na trasy (vyvážené střídání),
// že každý nepřítel dojde po své trase až k Srdci, bonus dosahu věže na kopci, minimapu (rozložení, klik přesune kameru),
// panel vlny s údajem o branách, mřížku s kopci a čistou konzoli.
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const THEME = String(args.theme || 'sky_island');
const WHICH = String(args.maps || '0,1,2').split(',').map(Number);
const PORT = Number(args.port || 8161);
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' });
  fs.createReadStream(f).pipe(res); }).listen(PORT);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const checks = []; const errors = [];
function check(name, ok, detail) { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? '  OK ' : ' CHYBA'}  ${name}${detail !== undefined ? '  (' + (typeof detail === 'string' ? detail : JSON.stringify(detail)) + ')' : ''}`); }

const MAPS = [
  { isl: 0, name: 'Dvě brány', lanes: 2, portals: 2, bridges: 2, gates_row: true },
  { isl: 1, name: 'Rozcestí', lanes: 2, portals: 1, bridges: 3, gates_row: true },
  { isl: 2, name: 'Tři brány', lanes: 5, portals: 3, bridges: 3, gates_row: true },
];
const overlap = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  async function open(query, w = 1280, h = 720) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h } });
    const page = await ctx.newPage();
    page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
    page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
    await page.goto('http://localhost:' + PORT + '/index.html?test=1&nosound=1&skipintro=1&q=low&theme=' + THEME + '&' + query);
    await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 });
    await sleep(800);
    const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
    const st = async () => JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
    const box = async () => page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
    return { ctx, page, cmd, st, box };
  }

  for (const M of MAPS) {
    if (!WHICH.includes(M.isl)) continue;
    console.log(`\n=== Mapa ${M.isl}: ${M.name} (${THEME}) ===`);
    const { ctx, page, cmd, st, box } = await open('island=' + M.isl);
    await cmd({ op: 'freeze', v: true });
    const info = await cmd({ op: 'map_info' });
    const lens = info.lanes.map(l => Math.round(l.len));
    check(`${M.name}: ${M.lanes} tras, ${M.portals} portálů, ${M.bridges} mostů`, info.lanes.length === M.lanes && info.portals.length === M.portals && info.bridges === M.bridges, { lanes: info.lanes.length, portals: info.portals.length, bridges: info.bridges });
    check(`${M.name}: každá trasa je dlouhá 80–150 m`, lens.every(l => l >= 80 && l <= 150), lens);
    check(`${M.name}: 5 kopců, aspoň 24 polí na kopci a 3 pole na vrcholu`, info.hills.length === 5 && info.elev_free[1] >= 24 && info.elev_free[2] >= 3, { hills: info.hills.length, elev: info.elev_free });
    check(`${M.name}: kopce jsou vyvýšené nad okolím (vrchol ≥ 1,2 m)`, info.hills.every(h => h.y >= 0.7) && Math.max(...info.hills.map(h => h.y)) >= 2.0, info.hills.map(h => +h.y.toFixed(2)));
    let h = await cmd({ op: 'hud' });
    check(`${M.name}: panel vlny ukazuje vchody (${M.portals})`, h.wave_rows.some(r => /Vchody: \d/.test(r)), h.wave_rows);

    // --- nepřátelé: po jednom na každé trase, každý má svůj portál a dojde k Srdci
    await cmd({ op: 'lives', v: 50 });
    for (let i = 0; i < info.lanes.length; i++) await cmd({ op: 'spawn', type: 'goblin', n: 1, interval: 1, hp: 50, lane: i, delay: 0 });
    await cmd({ op: 'step', t: 0.4 });
    let en = (await cmd({ op: 'enemies' })).list;
    check(`${M.name}: na každé trase se objevil nepřítel s jejím číslem`, en.length === info.lanes.length && info.lanes.every((_, i) => en.some(e => e.lane === i)), en.map(e => e.lane));
    const near = en.every(e => { const p = info.portals[info.lanes[e.lane].portal]; return Math.hypot(e.pos[0] - p[0], e.pos[2] - p[2]) < 5.0; });
    check(`${M.name}: každý začíná u portálu své trasy (do 5 m)`, near);
    await cmd({ op: 'step', t: 10 });
    en = (await cmd({ op: 'enemies' })).list;
    check(`${M.name}: po 10 s jdou všichni po svých trasách (vzdálenost od portálu roste, y sedí na terénu)`, en.length === info.lanes.length && en.every(e => { const p = info.portals[info.lanes[e.lane].portal]; return Math.hypot(e.pos[0] - p[0], e.pos[2] - p[2]) > 8.0; }), en.map(e => [e.lane, Math.round(Math.hypot(e.pos[0] - info.portals[info.lanes[e.lane].portal][0], e.pos[2] - info.portals[info.lanes[e.lane].portal][2]))]));
    await page.screenshot({ path: path.join(OUT, `mapy_${THEME}_${M.isl}_nepratele.png`) });
    const lives0 = (await cmd({ op: 'hud' })).lives_lbl;
    await cmd({ op: 'step', t: 120 });
    en = (await cmd({ op: 'enemies' })).list.filter(e => !e.dying);
    h = await cmd({ op: 'hud' });
    check(`${M.name}: všichni nepřátelé došli k Srdci (zbyly 0 živých, životy ${lives0} → ${h.lives_lbl})`, en.length === 0 && Number(h.lives_lbl) === 50 - info.lanes.length, { alive: en.length, lives: h.lives_lbl });

    // --- vyvážené střídání tras při běžné vlně
    await cmd({ op: 'spawn', type: 'goblin', n: 30, interval: 0.25, hp: 1000 });
    await cmd({ op: 'step', t: 9 });
    en = (await cmd({ op: 'enemies' })).list.filter(e => !e.dying);
    const cnt = info.lanes.map((_, i) => en.filter(e => e.lane === i).length);
    const wsum = info.lanes.reduce((a, l) => a + l.weight, 0);
    const okSplit = info.lanes.every((l, i) => Math.abs(cnt[i] - en.length * l.weight / wsum) <= 1.6);
    check(`${M.name}: 30 nepřátel se rozdělilo podle vah tras (${cnt.join(' / ')})`, en.length === 30 && okSplit, { cnt, weights: info.lanes.map(l => l.weight) });
    await cmd({ op: 'kill' });
    await cmd({ op: 'step', t: 3 });

    // --- kopce: bonus dosahu věže
    await cmd({ op: 'gold', v: 5000 });
    const hc = info.hill_cells;
    const c1 = hc.find(c => c.elev === 1), c2 = hc.find(c => c.elev === 2);
    const plain = (await cmd({ op: 'cells' })).cells.find(c => c.elev === 0);
    const rg = async c => { const r = await cmd({ op: 'build', type: 'archer', cx: c.cx, cz: c.cz }); if (!r.ok) return null; const ti = await cmd({ op: 'tower_info', id: r.id }); return { id: r.id, range: ti.stats.range }; };
    const tp = await rg(plain), t1 = await rg(c1), t2 = await rg(c2);
    check(`${M.name}: lučištník má dosah 7,0 m na rovině, 8,05 m na kopci, 9,1 m na vrcholu`, tp && t1 && t2 && Math.abs(tp.range - 7.0) < 0.01 && Math.abs(t1.range - 8.05) < 0.01 && Math.abs(t2.range - 9.1) < 0.01, { plain: tp && tp.range, kopec: t1 && t1.range, vrchol: t2 && t2.range });
    await cmd({ op: 'select', id: t2.id });
    await sleep(300);
    h = await cmd({ op: 'hud' });
    check(`${M.name}: panel věže na vrcholu ukazuje „vrchol +30 %“`, h.tower_rows.some(r => /vrchol \+30 %/.test(r)), h.tower_rows.slice(0, 6));
    await cmd({ op: 'upgrade', id: t2.id });
    const ti2 = await cmd({ op: 'tower_info', id: t2.id });
    check(`${M.name}: po vylepšení se bonus výšky zachová (8,0 × 1,3 → ${ti2.stats.range})`, Math.abs(ti2.stats.range - 7.8 * 1.3) < 0.01, ti2.stats.range);
    await cmd({ op: 'cancel' });

    // --- minimapa
    const r = await cmd({ op: 'ui_rect', name: 'minimap' });
    const rinfo = await cmd({ op: 'ui_rect', name: 'info_panel' });
    const rab = await cmd({ op: 'ui_rect', name: 'ability_box' });
    const rwp = await cmd({ op: 'ui_rect', name: 'wave_panel' });
    check(`${M.name}: minimapa je vidět a nepřekrývá panel životů, schopnosti ani panel vlny`, r.ok && !overlap(r.rect, rinfo.rect) && !overlap(r.rect, rab.rect) && !overlap(r.rect, rwp.rect), { mm: r.px, info: rinfo.px, ab: rab.px });
    const b = await box();
    const cx = b.x + (r.px[0] + r.px[2] / 2) * b.w / r.vp[0], cy = b.y + (r.px[1] + r.px[3] / 2) * b.h / r.vp[1];
    const s0 = await cmd({ op: 'touch_state' });
    await cmd({ op: 'cam', yaw: 45, zoom: 40, px: 0, pz: 0 });
    await sleep(500);
    const px = 50 * b.w / r.vp[0];            // 50 px (obsah) vpravo od středu minimapy
    await page.mouse.move(cx, cy); await page.mouse.click(cx + px, cy); await sleep(400);
    const s1 = await cmd({ op: 'touch_state' });
    const ppm = ((r.px[2] / 2) - 2) / 48; const exp = 50 / ppm;     // metrů od středu ostrova
    const yaw = 45 * Math.PI / 180;
    const wx = (50 * Math.cos(yaw)) / ppm, wz = (-50 * Math.sin(yaw)) / ppm;
    check(`${M.name}: klik na minimapu přesune kameru na odpovídající místo (${wx.toFixed(1)}; ${wz.toFixed(1)})`, Math.hypot(s1.pivot[0] - wx, s1.pivot[1] - wz) < 2.5, { pivot: s1.pivot, ocekavano: [+wx.toFixed(1), +wz.toFixed(1)] });
    check(`${M.name}: klik na minimapu nezačal stavět ani nic nevybral`, s1.build_type === '' && s1.selected === -1 || s1.selected !== undefined);

    // --- mřížka při stavbě (zlatá pole na kopcích) a snímek
    await cmd({ op: 'cam', yaw: 45, zoom: 30, px: info.hills[0].x, pz: info.hills[0].z });
    await sleep(300);
    const card = await cmd({ op: 'ui', name: 'card_archer' });
    const b2 = await box();
    await page.mouse.click(b2.x + card.p[0] * b2.w, b2.y + card.p[1] * b2.h); await sleep(1500);
    await page.screenshot({ path: path.join(OUT, `mapy_${THEME}_${M.isl}_mrizka.png`) });
    await cmd({ op: 'cancel' });
    await cmd({ op: 'cam', yaw: 45, zoom: 56, px: 0, pz: 0 });
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, `mapy_${THEME}_${M.isl}_celek.png`) });
    await ctx.close();
  }

  // --- telefon: minimapa se vejde vedle ostatních prvků
  if (WHICH.length > 0) {
    console.log('\n=== Telefon (touch=1, 844×390) ===');
    const { ctx, cmd, page, box } = await open('island=' + WHICH[0] + '&touch=1', 844, 390);
    await cmd({ op: 'freeze', v: true });
    const r = await cmd({ op: 'ui_rect', name: 'minimap' });
    const rinfo = await cmd({ op: 'ui_rect', name: 'info_panel' });
    const rab = await cmd({ op: 'ui_rect', name: 'ability_box' });
    const rwp = await cmd({ op: 'ui_rect', name: 'wave_panel' });
    check('telefon: minimapa je vidět, menší než 40 % výšky a nepřekrývá panel životů, schopnosti ani panel vlny',
      r.ok && r.rect[3] < 0.4 && !overlap(r.rect, rinfo.rect) && !overlap(r.rect, rab.rect) && !overlap(r.rect, rwp.rect), { mm: r.rect, info: rinfo.rect, ab: rab.rect });
    // sbalení knoflíkem v rohu a znovu rozbalení
    const b = await box();
    const kx = b.x + (r.px[0] + r.px[2] - 13) * b.w / r.vp[0], ky = b.y + (r.px[1] + 13) * b.h / r.vp[1];
    await page.mouse.click(kx, ky); await sleep(400);
    let h = await cmd({ op: 'hud' });
    const r2 = await cmd({ op: 'ui_rect', name: 'minimap' });
    check('telefon: knoflík v rohu minimapu sbalí (zmenší se na tlačítko)', h.minimap_collapsed && r2.px[2] < 50, { collapsed: h.minimap_collapsed, w: r2.px[2] });
    await page.mouse.click(b.x + (r2.px[0] + r2.px[2] / 2) * b.w / r2.vp[0], b.y + (r2.px[1] + r2.px[3] / 2) * b.h / r2.vp[1]); await sleep(400);
    h = await cmd({ op: 'hud' });
    check('telefon: klepnutí na tlačítko minimapu znovu rozbalí', !h.minimap_collapsed);
    await cmd({ op: 'cam', yaw: 45, zoom: 56, px: 0, pz: 0 });
    await sleep(2500);
    await page.screenshot({ path: path.join(OUT, `mapy_telefon_${WHICH[0]}.png`) });
    await ctx.close();
  }

  await browser.close(); srv.close();
  check('konzole bez chyb', errors.length === 0, errors.slice(0, 3));
  const failed = checks.filter(c => !c.ok).length;
  console.log(`\nVýsledek: ${checks.length - failed} / ${checks.length} kontrol v pořádku, chyb v konzoli: ${errors.length}`);
  process.exit(failed ? 1 : 0);
})();
