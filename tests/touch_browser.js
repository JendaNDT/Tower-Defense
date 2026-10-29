// Test dotykového ovládání v prohlížeči (emulace telefonu na šířku, skutečné dotykové události přes CDP):
// rozpoznání telefonu, kompaktní rozložení bez překryvů, karty a tlačítka, stavba s potvrzením, výběr věže,
// posun jedním prstem, přiblížení / otáčení dvěma prsty, klepnutí × tažení, meteor s potvrzením.
//   node tests/touch_browser.js [--out=tests/out] [--w=844 --h=390]   (DOCS_DIR = složka s exportem, jinak docs/)
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const W = +(args.w || 844), H = +(args.h || 390);
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-cache' }); fs.createReadStream(f).pipe(res); }).listen(8141);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const checks = []; const errors = [];
function check(name, ok, detail) { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? '  OK ' : ' CHYBA'}  ${name}${detail !== undefined ? '  (' + (typeof detail === 'string' ? detail : JSON.stringify(detail)) + ')' : ''}`); }

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });

  async function open(query, vw, vh, touch, dpr = 1) {
    const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, deviceScaleFactor: dpr, isMobile: touch, hasTouch: touch });
    const page = await ctx.newPage();
    page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
    page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
    await page.goto('http://localhost:8141/index.html?test=1&q=low&nosound=1&skipintro=1' + query);
    await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 });
    await sleep(1500);
    const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
    const client = touch ? await ctx.newCDPSession(page) : null;
    const T = (type, pts) => client.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map((p, i) => ({ x: p[0], y: p[1], id: i + 1 })) });
    return {
      ctx, page, cmd, client,
      state: () => cmd({ op: 'touch_state' }),
      tap: async (x, y) => { await T('touchStart', [[x, y]]); await sleep(70); await T('touchEnd', []); await sleep(900); },
      drag: async (a, b, steps = 8) => { await T('touchStart', [a]); await sleep(40); for (let i = 1; i <= steps; i++) { await T('touchMove', [[a[0] + (b[0] - a[0]) * i / steps, a[1] + (b[1] - a[1]) * i / steps]]); await sleep(40); } await T('touchEnd', []); await sleep(900); },
      pinch: async (a0, b0, a1, b1, steps = 8) => { await T('touchStart', [a0, b0]); await sleep(40); for (let i = 1; i <= steps; i++) { const f = i / steps; await T('touchMove', [[a0[0] + (a1[0] - a0[0]) * f, a0[1] + (a1[1] - a0[1]) * f], [b0[0] + (b1[0] - b0[0]) * f, b0[1] + (b1[1] - b0[1]) * f]]); await sleep(40); } await T('touchEnd', []); await sleep(900); },
      ui: async name => { const r = await cmd({ op: 'ui', name }); return r.ok ? [r.p[0] * vw, r.p[1] * vh] : null; },
      cell: async (cx, cz) => { const r = await cmd({ op: 'cell_screen', cx, cz }); return [r.p[0] * vw, r.p[1] * vh]; },
      shot: async n => { await sleep(2500); await page.screenshot({ path: path.join(OUT, 'dotyk_' + n + '.png'), timeout: 240000 }); },
    };
  }
  const overlap = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];

  // ===================================================================== A) telefon na šířku
  const t = await open('', W, H, true, 2);
  await t.cmd({ op: 'gold', v: 3000 });
  await t.cmd({ op: 'freeze', v: true });
  await t.cmd({ op: 'cam', yaw: 45, zoom: 44, px: 0, pz: 0 });
  let s = await t.state();
  check('telefon je rozpoznán (malá dotyková obrazovka) a ovládání je v dotykovém režimu', s.phone && s.touch_mode, { phone: s.phone, touch: s.touch_mode });
  check('obsah okna je zmenšen: logická velikost kolem 990 × 460 (rozhraní je větší)', s.viewport[1] >= 440 && s.viewport[1] <= 480 && s.viewport[0] >= 900 && s.viewport[0] <= 1100, s.viewport);

  // rozložení: žádné překryvy a vše uvnitř obrazovky
  const names = ['info_panel', 'wave_panel', 'ability_box', 'card_archer', 'card_cannon', 'card_mage', 'card_frost', 'pause_btn', 'speed_btn', 'more_btn'];
  const R = {};
  for (const n of names) { const r = await t.cmd({ op: 'ui_rect', name: n }); R[n] = r.ok ? r.px : null; }
  const missing = names.filter(n => !R[n]);
  check('všechny hlavní prvky rozhraní jsou vidět', missing.length === 0, missing);
  const vp = s.viewport;
  check('všechny prvky leží celé uvnitř obrazovky', names.every(n => R[n] && R[n][0] >= 0 && R[n][1] >= 0 && R[n][0] + R[n][2] <= vp[0] + 0.5 && R[n][1] + R[n][3] <= vp[1] + 0.5), R);
  const groups = [['info_panel', 'wave_panel', 'ability_box', 'card_archer', 'card_frost', 'pause_btn', 'more_btn']];
  const olaps = [];
  for (const g of groups) for (let i = 0; i < g.length; i++) for (let j = i + 1; j < g.length; j++) if (overlap(R[g[i]], R[g[j]])) olaps.push(g[i] + '×' + g[j]);
  check('panely a tlačítka se navzájem nepřekrývají', olaps.length === 0, olaps);
  const minSide = Math.min(...['pause_btn', 'speed_btn', 'more_btn', 'card_archer'].map(n => Math.min(R[n][2], R[n][3])));
  const cssPerLogical = H / vp[1];
  check('dotyková tlačítka mají aspoň 40 px na obrazovce (CSS pixely)', minSide * cssPerLogical >= 40, +(minSide * cssPerLogical).toFixed(1));
  await t.shot('01_hra');

  // karta věže: klepnutí
  let p = await t.ui('card_archer');
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('klepnutí na kartu zapne stavění lučištníka', s.build_type === 'archer', s.build_type);
  // pole, která na obrazovce neleží pod žádným panelem (karty dole, panely nahoře a vpravo)
  const allCells = (await t.cmd({ op: 'cells' })).cells;
  const cells = [];
  for (const c of allCells) {
    const sp = await t.cell(c.cx, c.cz);
    if (sp[0] > 90 && sp[0] < W - 200 && sp[1] > 90 && sp[1] < H - 110) cells.push(Object.assign({ sx: sp[0], sy: sp[1] }, c));
  }
  check('na obrazovce je dost volných polí mimo panely (pro zkoušky klepáním)', cells.length >= 8, cells.length);
  const c1 = cells[Math.floor(cells.length * 0.2)], c2 = cells[Math.floor(cells.length * 0.5)];
  p = await t.cell(c1.cx, c1.cz);
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('klepnutí na pole věž nepostaví hned, jen označí místo a ukáže potvrzení', s.pending && s.confirm_visible && s.towers === 0 && s.touch_cell[0] === c1.cx && s.touch_cell[1] === c1.cz, { pending: s.pending, confirm: s.confirm_visible, towers: s.towers, cell: s.touch_cell });
  await t.shot('02_oznaceno');
  p = await t.cell(c2.cx, c2.cz);
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('klepnutí na jiné pole přesune označení', s.pending && s.touch_cell[0] === c2.cx && s.touch_cell[1] === c2.cz && s.towers === 0, s.touch_cell);
  const gold0 = s.gold;
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('druhé klepnutí na totéž pole věž postaví', s.towers === 1 && s.gold < gold0 && !s.pending && !s.confirm_visible, { towers: s.towers, gold: [gold0, s.gold] });
  // potvrzení tlačítkem
  p = await t.cell(c1.cx, c1.cz);
  await t.tap(p[0], p[1]);
  p = await t.ui('confirm_ok');
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('tlačítko Postavit potvrdí stavbu (2 věže), režim stavění zůstává', s.towers === 2 && s.build_type === 'archer' && !s.pending, { towers: s.towers, build: s.build_type });
  // zrušení
  const c3 = cells[Math.floor(cells.length * 0.8)];
  p = await t.cell(c3.cx, c3.cz);
  await t.tap(p[0], p[1]);
  p = await t.ui('confirm_cancel');
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('křížek zruší označení i režim stavění beze stavby', s.build_type === '' && !s.pending && !s.confirm_visible && s.towers === 2, s);
  // výběr věže a panel
  const tw = await t.cmd({ op: 'tower_info', id: 1 });
  const tp = (await t.cmd({ op: 'tower_screen', id: 1 })).p;
  await t.tap(tp[0] * W, tp[1] * H);
  s = await t.state();
  check('klepnutí na věž ji vybere', s.selected >= 1, s.selected);
  const panel = await t.cmd({ op: 'ui_rect', name: 'tower_panel' });
  const wavep = await t.cmd({ op: 'ui_rect', name: 'wave_panel' });
  check('panel věže se otevře a panel vlny se schová (sdílí místo)', panel.ok && !wavep.ok, { panel: panel.ok, wave: wavep.ok });
  check('panel věže se vejde na obrazovku', panel.ok && panel.px[1] + panel.px[3] <= s.viewport[1] && panel.px[0] >= 0, panel.px);
  await t.shot('03_panel_veze');
  p = await t.ui('tower_close');
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('křížek v panelu věž odznačí a panel vlny se vrátí', s.selected === -1 && (await t.cmd({ op: 'ui_rect', name: 'wave_panel' })).ok, s.selected);
  // vylepšení tlačítkem v panelu
  await t.tap(tp[0] * W, tp[1] * H);
  p = await t.ui('upgrade_btn');
  await t.tap(p[0], p[1]);
  const after = await t.cmd({ op: 'tower_info', id: 1 });
  check('vylepšení klepnutím na tlačítko v panelu funguje', after.level === 2, after.level);
  p = await t.ui('tower_close'); await t.tap(p[0], p[1]);

  // ===================================================================== B) kamera
  await t.cmd({ op: 'cam', yaw: 45, zoom: 44, px: 0, pz: 0 });
  s = await t.state();
  const piv0 = s.pivot.slice();
  await t.drag([W * 0.55, H * 0.5], [W * 0.40, H * 0.35]);
  s = await t.state();
  check('tažení jedním prstem posune kameru', Math.hypot(s.pivot[0] - piv0[0], s.pivot[1] - piv0[1]) > 1.0, { z: piv0, na: s.pivot });
  check('tažení po mapě nic nevybralo ani nepostavilo', s.selected === -1 && s.towers === 2 && !s.pending, { sel: s.selected, towers: s.towers });
  // tažení začínající na tlačítku kameru neposouvá
  const piv1 = s.pivot.slice();
  p = await t.ui('card_cannon');
  await t.drag(p, [p[0], p[1] - 150]);
  s = await t.state();
  check('tažení začínající na tlačítku kameru neposouvá', Math.hypot(s.pivot[0] - piv1[0], s.pivot[1] - piv1[1]) < 0.3, { z: piv1, na: s.pivot });
  await t.cmd({ op: 'cancel' });
  // přiblížení dvěma prsty
  await t.cmd({ op: 'cam', yaw: 45, zoom: 44, px: 0, pz: 0 });
  s = await t.state();
  const z0 = s.zoom;
  await t.pinch([W * 0.45, H * 0.5], [W * 0.55, H * 0.5], [W * 0.30, H * 0.5], [W * 0.70, H * 0.5]);
  s = await t.state();
  check('roztažení dvou prstů kameru přiblíží', s.zoom < z0 * 0.8, { z: z0, na: s.zoom });
  const z1 = s.zoom;
  await t.pinch([W * 0.30, H * 0.5], [W * 0.70, H * 0.5], [W * 0.45, H * 0.5], [W * 0.55, H * 0.5]);
  s = await t.state();
  check('stažení dvou prstů kameru oddálí', s.zoom > z1 * 1.2, { z: z1, na: s.zoom });
  // otočení: dva prsty se otočí po směru hodinových ručiček => mapa se na obrazovce otočí po směru hodinových ručiček
  await t.cmd({ op: 'cam', yaw: 45, zoom: 44, px: 0, pz: 0 });
  s = await t.state();
  const yaw0 = s.yaw;
  const pr0 = (await t.cmd({ op: 'project', x: 10, y: 0, z: 0 })).p;
  const c0 = (await t.cmd({ op: 'project', x: 0, y: 0, z: 0 })).p;
  const cx = W * 0.5, cy = H * 0.5, r = 90, a = 0.5;     // dva prsty na kružnici, otočí se o 0,5 rad (~29°) po směru hodinových ručiček (y dolů)
  await t.pinch([cx - r, cy], [cx + r, cy], [cx - r * Math.cos(a), cy - r * Math.sin(a)], [cx + r * Math.cos(a), cy + r * Math.sin(a)], 10);
  s = await t.state();
  const pr1 = (await t.cmd({ op: 'project', x: 10, y: 0, z: 0 })).p;
  const c1p = (await t.cmd({ op: 'project', x: 0, y: 0, z: 0 })).p;
  const v0 = [pr0[0] - c0[0], pr0[1] - c0[1]], v1 = [pr1[0] - c1p[0], pr1[1] - c1p[1]];
  const cross = v0[0] * v1[1] - v0[1] * v1[0];           // > 0: otočení po směru hodinových ručiček na obrazovce (osa y dolů)
  check('otočení dvou prstů změní natočení kamery', Math.abs(s.yaw - yaw0) > 10, { z: yaw0, na: s.yaw });
  check('mapa se otáčí stejným směrem jako prsty (po směru hodinových ručiček)', cross > 0, { cross: +cross.toFixed(4) });
  await t.shot('04_kamera');

  // ===================================================================== C) meteor
  await t.cmd({ op: 'cam', yaw: 45, zoom: 44, px: 0, pz: 0 });
  p = await t.ui('ability_meteor');
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('klepnutí na schopnost Meteor zapne míření', s.aim === 'meteor', s.aim);
  const pm = await t.cell(c3.cx, c3.cz);
  await t.tap(pm[0], pm[1]);
  s = await t.state();
  check('klepnutí na mapu meteor jen označí a ukáže potvrzení', s.pending && s.confirm_visible && s.meteor_cd === 0, { pending: s.pending, cd: s.meteor_cd });
  await t.shot('05_meteor');
  p = await t.ui('confirm_ok');
  await t.tap(p[0], p[1]);
  s = await t.state();
  check('potvrzení seslalo meteor (schopnost se nabíjí) a míření skončilo', s.meteor_cd > 0 && s.aim === '' && !s.confirm_visible, { cd: s.meteor_cd, aim: s.aim });

  // ===================================================================== D) rozbalovací panel a nabídka
  p = await t.ui('more_btn');
  await t.tap(p[0], p[1]);
  const more = await t.cmd({ op: 'ui_rect', name: 'more_panel' });
  check('tlačítko „…“ rozbalí panel s dalším ovládáním', more.ok && more.px[0] >= 0 && more.px[0] + more.px[2] <= vp[0] && more.px[1] + more.px[3] <= vp[1], more.px);
  await t.shot('06_dalsi');
  p = await t.ui('menu_btn');
  await t.tap(p[0], p[1]);
  const start = await t.cmd({ op: 'ui_rect', name: 'menu_start' });
  check('úvodní nabídka se na telefonu vejde celá na obrazovku', start.ok && start.px[1] + start.px[3] <= vp[1] && start.px[0] + start.px[2] <= vp[0], start.px);
  await t.shot('07_menu');
  p = await t.ui('menu_back');
  await t.tap(p[0], p[1]);
  p = await t.ui('help_btn');
  if (!p) { const mb = await t.ui('more_btn'); await t.tap(mb[0], mb[1]); p = await t.ui('help_btn'); }
  await t.tap(p[0], p[1]);
  const hc = await t.cmd({ op: 'ui_rect', name: 'help_close' });
  check('nápověda se vejde na obrazovku a má tlačítko Zavřít', hc.ok && hc.px[1] + hc.px[3] <= vp[1], hc.px);
  await t.shot('08_napoveda');
  await t.ctx.close();

  // ===================================================================== E) počítač: nic se nemění
  const d = await open('', 1280, 720, false, 1);
  let ds = await d.state();
  check('na počítači se profil telefonu nezapne a ovládání je myší', !ds.phone && !ds.touch_mode, { phone: ds.phone, touch: ds.touch_mode });
  const dc = (await d.cmd({ op: 'cells' })).cells;
  await d.cmd({ op: 'gold', v: 3000 });
  await d.cmd({ op: 'freeze', v: true });
  await d.cmd({ op: 'cam', yaw: 45, zoom: 44, px: 0, pz: 0 });
  let q = await d.ui('card_archer');
  await d.page.mouse.click(q[0], q[1]);
  await sleep(900);
  const cc = dc[Math.floor(dc.length * 0.5)];
  const cp = await d.cell(cc.cx, cc.cz);
  await d.page.mouse.move(cp[0] - 5, cp[1] - 5); await sleep(300);
  await d.page.mouse.click(cp[0], cp[1]);
  await sleep(1200);
  ds = await d.state();
  check('na počítači klik myší postaví věž hned (beze potvrzení)', ds.towers === 1 && !ds.pending, { towers: ds.towers, pending: ds.pending });
  await d.ctx.close();

  // ===================================================================== F) vynucení profilu
  const f = await open('&touch=1', 1280, 720, false, 1);
  const fs1 = await f.state();
  check('?touch=1 vynutí profil telefonu i na počítači (pro zkoušení)', fs1.phone && fs1.viewport[1] >= 440 && fs1.viewport[1] <= 800, { phone: fs1.phone, vp: fs1.viewport });
  await f.shot('09_vynuceny_profil');
  await f.ctx.close();

  // ===================================================================== G) telefon na výšku
  const pt = await open('', 390, 844, true, 2);
  const ps = await pt.state();
  const ro = await pt.cmd({ op: 'ui_rect', name: 'rotate_overlay' });
  check('telefon na výšku ukáže výzvu k otočení a hra se pozastaví', ro.ok && ps.paused, { overlay: ro.ok, paused: ps.paused });
  await pt.shot('10_na_vysku');
  await pt.ctx.close();

  // ===================================================================== H) rozlišení plátna na telefonu
  const hd = await open('', W, H, true, 3);
  const cw = await hd.page.evaluate(() => document.getElementById('canvas').width);
  check('na telefonu s hustotou pixelů 3 se plátno omezí na dvojnásobek (kratší vykreslování)', cw === W * 2, { sirka: cw, css: W });
  await hd.ctx.close();
  const hl = await open('&dpr=1', W, H, true, 3);
  const cw1 = await hl.page.evaluate(() => document.getElementById('canvas').width);
  check('?dpr=1 omezí plátno na jeden pixel na CSS pixel', cw1 === W, { sirka: cw1, css: W });
  await hl.ctx.close();

  const ok = checks.every(c => c.ok);
  check('v konzoli prohlížeče nejsou žádné chyby', errors.length === 0, errors.slice(0, 5));
  console.log(`\nVýsledek: ${checks.filter(c => c.ok).length}/${checks.length} kontrol v pořádku`);
  fs.writeFileSync(path.join(OUT, 'touch_browser.json'), JSON.stringify({ checks, errors }, null, 1));
  await browser.close(); srv.close();
  process.exit(ok && errors.length === 0 ? 0 : 1);
})().catch(e => { console.error('SELHÁNÍ TESTU', e); process.exit(2); });
