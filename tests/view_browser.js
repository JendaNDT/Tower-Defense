// Test pohledu shora a výraznější mřížky v prohlížeči (stůl 1280 × 720 i telefon na šířku 844 × 390).
//   node tests/view_browser.js [--out=tests/out] [--theme=sky_island] [--port=8165]
// Kontroluje: přepnutí V / tlačítkem / Home, sklon 90° a zarovnání natočení na 90°, čtvercová síť polí, převod obrazovka ↔ pole
// (klik trefí pole v izometrii i shora), tažení mapy „přilepené“ k myši, výřez kamery v minimapě, stavbu klikem shora,
// trvalou mřížku (G, tlačítko) a její viditelnost na snímku, rozložení tlačítek na stolu i na telefonu a dotykové ovládání.
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const THEME = String(args.theme || 'sky_island');
const PORT = Number(args.port || 8165);
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' });
  fs.createReadStream(f).pipe(res); }).listen(PORT);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const checks = []; const errors = [];
function check(name, ok, detail) { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? '  OK ' : ' CHYBA'}  ${name}${detail !== undefined ? '  (' + (typeof detail === 'string' ? detail : JSON.stringify(detail)) + ')' : ''}`); }
const overlap = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
const near = (a, b, eps) => Math.abs(a - b) <= eps;
const off90 = x => { const m = ((x % 90) + 90) % 90; return Math.min(m, 90 - m); };   // vzdálenost natočení od nejbližšího násobku 90°

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  async function open(query, w, h, touch = false, dpr = 1) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr, isMobile: touch, hasTouch: touch });
    const page = await ctx.newPage();
    page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
    page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
    await page.goto('http://localhost:' + PORT + '/index.html?test=1&nosound=1&skipintro=1&q=low&theme=' + THEME + '&' + query);
    await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 });
    await sleep(800);
    const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
    const px = async (cx, cz) => { const r = await cmd({ op: 'cell_screen', cx, cz }); return [r.p[0] * w, r.p[1] * h]; };
    // počká, až se kamera ustálí (sklon, natočení, přiblížení, střed se plynule dotahují)
    const settle = async (tries = 40) => {
      let last = null;
      for (let i = 0; i < tries; i++) {
        const c = await cmd({ op: 'cam_info' });
        const key = [c.yaw, c.pitch, c.zoom, c.pivot[0], c.pivot[1]].map(v => v.toFixed(3)).join('|');
        if (key === last && Math.abs(c.pitch - c.target_pitch) < 0.01 && Math.abs(c.yaw - c.target_yaw) < 0.01) return c;
        last = key; await sleep(500);
      }
      return cmd({ op: 'cam_info' });
    };
    return { ctx, page, cmd, px, settle };
  }
  // střední rozdíl barvy (0–255 na kanál) mezi dvěma snímky v obdélníku [x, y, w, h]
  async function meanDiff(page, a, b, rect) {
    return page.evaluate(async ([ba, bb, r]) => {
      const load = s => new Promise(res => { const im = new Image(); im.onload = () => res(im); im.src = 'data:image/png;base64,' + s; });
      const [ia, ib] = [await load(ba), await load(bb)];
      const get = im => { const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; const g = c.getContext('2d'); g.drawImage(im, 0, 0); return g.getImageData(r[0], r[1], r[2], r[3]).data; };
      const da = get(ia), db = get(ib); let sum = 0, tot = 0;
      for (let i = 0; i < da.length; i += 4) { tot++; sum += Math.abs(da[i] - db[i]) + Math.abs(da[i + 1] - db[i + 1]) + Math.abs(da[i + 2] - db[i + 2]); }
      return sum / tot / 3;
    }, [a.toString('base64'), b.toString('base64'), rect]);
  }

  // ===================================================================== A) stolní počítač
  console.log('\n=== Stolní počítač (1280 × 720) ===');
  const W = 1280, H = 720;
  const d = await open('island=0', W, H);
  const { page, cmd, px, settle } = d;
  await cmd({ op: 'freeze', v: true });
  await cmd({ op: 'gold', v: 4000 });

  let ci = await cmd({ op: 'cam_info' });
  check('na začátku je izometrie (sklon 35,26°, natočení 45°), pohled shora vypnutý', near(ci.pitch, 35.264, 0.01) && near(ci.yaw, 45, 0.01) && !ci.top && !ci.view_btn && !ci.grid_btn, { pitch: ci.pitch, yaw: ci.yaw });

  // rozložení tlačítek: svislý pruh pod horní lištou
  const names = ['info_panel', 'wave_panel', 'ability_box', 'minimap', 'cam_strip', 'view_btn', 'grid_btn', 'cam_zoom_in', 'help_btn', 'menu_btn'];
  const R = {};
  for (const n of names) { const r = await cmd({ op: 'ui_rect', name: n }); R[n] = r.ok ? r.px : null; }
  check('tlačítka pohledu shora a mřížky jsou vidět, celá uvnitř okna a aspoň 40 px velká', ['view_btn', 'grid_btn'].every(n => R[n] && R[n][0] >= 0 && R[n][1] >= 0 && R[n][0] + R[n][2] <= W && R[n][1] + R[n][3] <= H && R[n][2] >= 40 && R[n][3] >= 40), { view: R.view_btn, grid: R.grid_btn });
  const olaps = [];
  for (const a of ['cam_strip', 'view_btn', 'grid_btn']) for (const b of ['info_panel', 'wave_panel', 'ability_box', 'minimap', 'cam_zoom_in', 'help_btn', 'menu_btn']) if (R[a] && R[b] && overlap(R[a], R[b])) olaps.push(a + '×' + b);
  check('pruh s tlačítky se nepřekrývá s horní lištou ani s ostatními panely', olaps.length === 0, olaps);

  // viditelnost mřížky na snímku: stejný záběr s mřížkou a bez ní
  await cmd({ op: 'cam', yaw: 45, zoom: 36, px: -4, pz: -8 });
  await page.mouse.move(640, 705); await sleep(3000);
  const shotOff = await page.screenshot({ timeout: 240000 });
  await page.keyboard.press('1'); await sleep(1200); await page.mouse.move(640, 705); await sleep(2500);
  const shotOn = await page.screenshot({ timeout: 240000 });
  fs.writeFileSync(path.join(OUT, 'pohled_mrizka_izo.png'), shotOn);
  const md = await meanDiff(page, shotOff, shotOn, [200, 120, 880, 400]);
  check('mřížka je na snímku výrazná (střední změna barvy při zapnutí aspoň 16 z 255; dřívější mřížka měla asi 11)', md >= 16, +md.toFixed(1));
  await page.keyboard.press('Escape'); await sleep(500);

  // přepnutí klávesou V
  await cmd({ op: 'cam', yaw: 45, zoom: 40, px: 0, pz: 0 });
  await sleep(500);
  const zoom0 = (await cmd({ op: 'cam_info' })).zoom;
  await page.keyboard.press('v');
  ci = await settle();
  check('klávesa V přepne na pohled shora: sklon 90°, natočení zarovnané na násobek 90°, přiblížení beze změny',
    ci.top && near(ci.pitch, 90, 0.05) && near(off90(ci.yaw), 0, 0.05) && near(ci.zoom, zoom0, 0.3) && ci.view_btn, { pitch: ci.pitch, yaw: ci.yaw, zoom: [zoom0, ci.zoom], btn: ci.view_btn });
  await page.mouse.move(640, 705); await sleep(1500);
  fs.writeFileSync(path.join(OUT, 'pohled_shora.png'), await page.screenshot({ timeout: 240000 }));

  // geometrie: pole tvoří čtvercovou síť
  const a = await px(15, 15), b = await px(16, 15), c = await px(15, 16);
  const dx = [b[0] - a[0], b[1] - a[1]], dz = [c[0] - a[0], c[1] - a[1]];
  const len = Math.hypot(dx[0], dx[1]);
  check('shora jsou sousední pole souměrně vedle sebe (kolmé a stejně dlouhé kroky, osy rovnoběžné s okrajem obrazovky)',
    Math.abs(dx[0] * dz[0] + dx[1] * dz[1]) < 1.0 && near(len, Math.hypot(dz[0], dz[1]), 0.5) && (Math.min(Math.abs(dx[0]), Math.abs(dx[1])) < 0.5), { dx, dz });
  check('velikost pole na obrazovce odpovídá přiblížení (2 m × 720 / přiblížení)', near(len, 2.0 * H / ci.zoom, 1.0), { len: +len.toFixed(2), ocekavano: +(2.0 * H / ci.zoom).toFixed(2) });

  // převod obrazovka → pole: klik trefí pole shora i v izometrii
  async function pickRound(label) {
    const cells = (await cmd({ op: 'cells' })).cells;
    const sample = [0.1, 0.35, 0.6, 0.85].map(f => cells[Math.floor(f * (cells.length - 1))]);
    const bad = [];
    for (const s of sample) {
      const p = await px(s.cx, s.cz);
      const r = await cmd({ op: 'pick', x: p[0], y: p[1] });
      if (!r.ok || r.cell[0] !== s.cx || r.cell[1] !== s.cz) bad.push({ s: [s.cx, s.cz], got: r.cell });
    }
    check(`${label}: střed pole na obrazovce se při výběru převede zpět na totéž pole (4 pole)`, bad.length === 0, bad);
  }
  await pickRound('shora');

  // tažení prostředním tlačítkem: pole pod myší zůstane pod myší
  async function dragGrab(label, dxp, dyp) {
    const p0 = [W * 0.5 - 40, H * 0.5 + 30];
    const before = await cmd({ op: 'pick', x: p0[0], y: p0[1] });
    await page.mouse.move(p0[0], p0[1]);
    await page.mouse.down({ button: 'middle' });
    for (let i = 1; i <= 8; i++) { await page.mouse.move(p0[0] + dxp * i / 8, p0[1] + dyp * i / 8); await sleep(60); }
    await page.mouse.up({ button: 'middle' });
    await settle();
    const after = await cmd({ op: 'pick', x: p0[0] + dxp, y: p0[1] + dyp });
    const dist = before.ok && after.ok ? Math.hypot(before.p[0] - after.p[0], before.p[2] - after.p[2]) : 99;
    check(`${label}: tažením prostředním tlačítkem se mapa posune s myší (bod pod myší zůstane pod ní)`, dist < 0.8, +dist.toFixed(2));
  }
  await cmd({ op: 'cam', px: 0, pz: 0 }); await settle();
  await dragGrab('shora', 120, 70);

  // výřez kamery v minimapě: shora má poměr stran obrazovky, v izometrii je svisle delší
  let mv = await cmd({ op: 'minimap_view' });
  check('minimapa shora ukazuje výřez s poměrem stran obrazovky (svislý / vodorovný = 720 / 1280)', mv.ok && near(mv.half[1] / mv.half[0], H / W, 0.01), mv.half);

  // stavba klikem shora
  const free = (await cmd({ op: 'cells' })).cells;
  const cb = free[Math.floor(free.length * 0.4)];
  await cmd({ op: 'cam', px: 0, pz: 0 }); await settle();
  const pc = await px(cb.cx, cb.cz);
  const before = (await cmd({ op: 'touch_state' })).towers;
  await page.keyboard.press('1'); await sleep(500);
  await page.mouse.move(pc[0], pc[1]); await sleep(900);
  await page.mouse.click(pc[0], pc[1]); await sleep(900);
  const after = (await cmd({ op: 'touch_state' })).towers;
  const left = (await cmd({ op: 'cells' })).cells;
  check('klik na pole při pohledu shora postaví věž přesně na to pole', after === before + 1 && !left.some(q => q.cx === cb.cx && q.cz === cb.cz), { cell: [cb.cx, cb.cz], towers: [before, after] });
  await page.keyboard.press('Escape'); await sleep(400);

  // mřížka: klávesa G a tlačítko
  ci = await cmd({ op: 'cam_info' });
  check('bez stavění a bez zapnutí není mřížka vidět', !ci.grid_visible && !ci.grid_pinned && !ci.grid_btn, { v: ci.grid_visible, p: ci.grid_pinned });
  await page.keyboard.press('g'); await sleep(500);
  ci = await cmd({ op: 'cam_info' });
  check('klávesa G zapne mřížku trvale (tlačítko svítí)', ci.grid_visible && ci.grid_pinned && ci.grid_btn, ci);
  await page.keyboard.press('2'); await sleep(400); await page.keyboard.press('Escape'); await sleep(400);
  ci = await cmd({ op: 'cam_info' });
  check('zrušení stavění trvalou mřížku nevypne', ci.grid_visible && ci.grid_pinned, { v: ci.grid_visible });
  const gb = await cmd({ op: 'ui', name: 'grid_btn' });
  await page.mouse.click(gb.p[0] * W, gb.p[1] * H); await sleep(500);
  ci = await cmd({ op: 'cam_info' });
  check('tlačítko mřížky ji vypne (a po zrušení stavění je opravdu pryč)', !ci.grid_visible && !ci.grid_pinned && !ci.grid_btn, ci);
  await page.keyboard.press('1'); await sleep(400);
  ci = await cmd({ op: 'cam_info' });
  check('při stavění se mřížka zobrazí i bez trvalého zapnutí a po zrušení zmizí', ci.grid_visible && !ci.grid_pinned, ci);
  await page.keyboard.press('Escape'); await sleep(400);
  ci = await cmd({ op: 'cam_info' });
  check('… po zrušení stavění zmizí', !ci.grid_visible, ci);

  // návrat do izometrie: V vrátí původní natočení, Home vrátí vše
  await page.keyboard.press('v');
  ci = await settle();
  check('druhé V vrátí izometrii a původní natočení 45°', !ci.top && near(ci.pitch, 35.264, 0.05) && near(ci.yaw, 45, 0.05) && !ci.view_btn, { pitch: ci.pitch, yaw: ci.yaw });
  await pickRound('izometrie');
  await dragGrab('izometrie', -90, 60);
  mv = await cmd({ op: 'minimap_view' });
  check('minimapa v izometrii ukazuje výřez svisle delší (poměr 720 / 1280 / sin 35,26°)', near(mv.half[1] / mv.half[0], (H / W) / Math.sin(35.264 * Math.PI / 180), 0.02), mv.half);

  // otočení v pohledu shora se při návratu nepřepisuje
  await page.keyboard.press('v'); await settle();
  const rl = await cmd({ op: 'ui', name: 'cam_rot_l' });
  await page.mouse.click(rl.p[0] * W, rl.p[1] * H);
  ci = await settle();
  check('shora jde natočit tlačítkem o 45° (síť polí se pak natočí)', near(off90(ci.yaw), 45, 0.1), ci.yaw);
  await page.keyboard.press('v');
  ci = await settle();
  check('po ručním otočení se při návratu do izometrie natočení nepřepíše', !ci.top && near(off90(ci.yaw), 45, 0.1), ci.yaw);
  await page.keyboard.press('v'); await settle();
  await page.keyboard.press('Home');
  ci = await settle();
  check('klávesa Home vrátí původní pohled (izometrie, natočení 45°)', !ci.top && near(ci.pitch, 35.264, 0.05) && near(ci.yaw, 45, 0.05) && !ci.view_btn, { pitch: ci.pitch, yaw: ci.yaw });

  // tlačítko pohledu shora
  const vb = await cmd({ op: 'ui', name: 'view_btn' });
  await page.mouse.click(vb.p[0] * W, vb.p[1] * H);
  ci = await settle();
  check('tlačítko pohledu shora přepne kameru a svítí', ci.top && near(ci.pitch, 90, 0.05) && ci.view_btn, { pitch: ci.pitch, btn: ci.view_btn });
  // shora se dá postavit i dál od středu, a výběr věže klikem funguje
  await page.keyboard.press('v'); await settle();
  await page.close(); await d.ctx.close();

  // ===================================================================== B) telefon na šířku
  console.log('\n=== Telefon (844 × 390, dotyk) ===');
  const PW = 844, PH = 390;
  const t = await open('island=0', PW, PH, true, 2);
  await t.cmd({ op: 'gold', v: 3000 });
  await t.cmd({ op: 'freeze', v: true });
  const client = await t.ctx.newCDPSession(t.page);
  const T = (type, pts) => client.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map((p, i) => ({ x: p[0], y: p[1], id: i + 1 })) });
  const tap = async (x, y) => { await T('touchStart', [[x, y]]); await sleep(70); await T('touchEnd', []); await sleep(900); };
  const state = () => t.cmd({ op: 'touch_state' });
  const s0 = await state();
  const vpw = s0.viewport;
  const pn = ['info_panel', 'wave_panel', 'ability_box', 'minimap', 'pause_btn', 'speed_btn', 'more_btn', 'view_btn', 'grid_btn', 'card_archer'];
  const PR = {};
  for (const n of pn) { const r = await t.cmd({ op: 'ui_rect', name: n }); PR[n] = r.ok ? r.px : null; }
  check('na telefonu jsou tlačítka pohledu shora a mřížky v horní liště, celá uvnitř obrazovky', ['view_btn', 'grid_btn'].every(n => PR[n] && PR[n][0] >= 0 && PR[n][1] >= 0 && PR[n][0] + PR[n][2] <= vpw[0] + 0.5 && PR[n][1] + PR[n][3] <= vpw[1] + 0.5), { view: PR.view_btn, grid: PR.grid_btn, vp: vpw });
  const po = [];
  for (const a of ['view_btn', 'grid_btn']) for (const b of ['info_panel', 'wave_panel', 'ability_box', 'minimap', 'card_archer']) if (PR[a] && PR[b] && overlap(PR[a], PR[b])) po.push(a + '×' + b);
  check('tlačítka se na telefonu nepřekrývají s panely ani s minimapou', po.length === 0, po);
  const cssPer = PH / vpw[1];
  check('dotyková tlačítka mají aspoň 40 px (CSS pixely)', Math.min(PR.view_btn[2], PR.view_btn[3], PR.grid_btn[2], PR.grid_btn[3]) * cssPer >= 40, +(Math.min(PR.view_btn[2], PR.view_btn[3]) * cssPer).toFixed(1));
  let r = await t.cmd({ op: 'ui', name: 'view_btn' });
  await tap(r.p[0] * PW, r.p[1] * PH);
  let pc2 = await t.settle();
  check('klepnutí na tlačítko přepne na pohled shora', pc2.top && near(pc2.pitch, 90, 0.05) && pc2.view_btn, { pitch: pc2.pitch });
  // stavba klepnutím při pohledu shora
  r = await t.cmd({ op: 'ui', name: 'card_archer' });
  await tap(r.p[0] * PW, r.p[1] * PH);
  const all = (await t.cmd({ op: 'cells' })).cells;
  const vis = [];
  for (const c of all) { const sp = await t.px(c.cx, c.cz); if (sp[0] > 90 && sp[0] < PW - 200 && sp[1] > 90 && sp[1] < PH - 110) vis.push(Object.assign({ sx: sp[0], sy: sp[1] }, c)); }
  const cc = vis[Math.floor(vis.length * 0.5)];
  if (cc) await tap(cc.sx, cc.sy);
  const s1 = await state();
  check('shora klepnutí na pole označí přesně to pole (před potvrzením věž nestojí)', !!cc && s1.pending && s1.touch_cell[0] === cc.cx && s1.touch_cell[1] === cc.cz && s1.towers === 0, { pole: cc ? [cc.cx, cc.cz] : null, oznaceno: s1.touch_cell, vybrano: vis.length });
  await tap(cc.sx, cc.sy);
  const s2 = await state();
  check('druhé klepnutí věž postaví', s2.towers === 1, s2.towers);
  r = await t.cmd({ op: 'ui', name: 'grid_btn' });
  await tap(r.p[0] * PW, r.p[1] * PH);
  pc2 = await t.cmd({ op: 'cam_info' });
  check('klepnutí na tlačítko mřížky ji zapne trvale', pc2.grid_pinned && pc2.grid_visible && pc2.grid_btn, pc2);
  await sleep(1500); await t.page.screenshot({ path: path.join(OUT, 'pohled_telefon_shora.png'), timeout: 240000 });
  await t.ctx.close();

  check('konzole bez chyb', errors.length === 0, errors.slice(0, 3));
  await browser.close(); srv.close();
  const bad = checks.filter(x => !x.ok);
  console.log(`\nVýsledek: ${checks.length - bad.length} / ${checks.length} kontrol v pořádku, chyb v konzoli: ${errors.length}`);
  process.exit(bad.length ? 1 : 0);
})().catch(e => { console.error('SELHÁNÍ', e); process.exit(2); });
