// Test prostředí (motivů) v prohlížeči skutečnými kliky: výběr v menu, přepnutí se znovunačtením světa, texty a názvy,
// zapamatování volby, stejná pravidla (síla věží po vylepšeních), návrat k prvnímu prostředí, parametr ?theme=.
//   node tests/themes_browser.js [--out=tests/out]
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' });
  fs.createReadStream(f).pipe(res); }).listen(8151);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const sameObj = (a, b) => Object.keys(b).every(k => a && a[k] === b[k]) && Object.keys(a || {}).length === Object.keys(b).length;
const checks = []; const errors = [];
function check(name, ok, detail) { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? '  OK ' : ' CHYBA'}  ${name}${detail !== undefined ? '  (' + (typeof detail === 'string' ? detail : JSON.stringify(detail)) + ')' : ''}`); }

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
  page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
  const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
  const st = async () => JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
  const box = async () => page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  const clickNorm = async p => { const b = await box(); const x = b.x + p[0] * b.w, y = b.y + p[1] * b.h; await page.mouse.move(x, y, { steps: 3 }); await page.mouse.click(x, y); };
  const clickUi = async name => { const r = await cmd({ op: 'ui', name }); if (!r.ok) throw new Error('UI prvek nenalezen nebo skrytý: ' + name); await clickNorm(r.p); await sleep(250); return r; };
  const hud = async () => cmd({ op: 'hud' });
  const settings = async () => cmd({ op: 'settings' });
  const shot = async n => page.screenshot({ path: path.join(OUT, 'theme_' + n + '.png') });
  async function waitFor(fn, ms, label) { const t0 = Date.now(); while (Date.now() - t0 < ms) { try { const v = await fn(); if (v) return v; } catch (e) { /* scéna se právě načítá */ } await sleep(500); } throw new Error('Časový limit: ' + label); }
  const ready = async () => { await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 }); await sleep(800); };

  // ---------------------------------------------------------------- 1) výchozí prostředí a nabídka v menu
  await page.goto('http://localhost:8151/index.html?test=1&q=low&nosound=1');
  await ready();
  let h = await hud();
  let s = await settings();
  check('výchozí prostředí je Ostrov v oblacích', s.theme === 'sky_island' && s.theme_name === 'Ostrov v oblacích', { theme: s.theme });
  check('menu nabízí obě prostředí (tlačítka)', (await cmd({ op: 'ui', name: 'menu_theme_sky_island' })).ok && (await cmd({ op: 'ui', name: 'menu_theme_scifi' })).ok);
  check('karty věží mají názvy ostrova (Lučištník, Kanón, Mág, Mráz)', sameObj(h.card_names, { archer: 'Lučištník', cannon: 'Kanón', mage: 'Mág', frost: 'Mráz' }), h.card_names);
  check('nadpis menu je „Ostrov v oblacích“, mapa se jmenuje „Ostrov“', h.menu.title === 'Ostrov v oblacích' && h.menu.place === 'Ostrov', { title: h.menu.title, place: h.menu.place });
  await shot('01_menu_ostrov');

  // ---------------------------------------------------------------- 2) výběr sci-fi kliknutím: menu se přepíše hned (náhled)
  await clickUi('menu_theme_scifi');
  h = await hud();
  check('kliknutí na Vesmírná stanice přepne volbu a nadpis menu', h.menu.theme === 'scifi' && h.menu.title === 'Vesmírná stanice' && h.menu.place === 'Plošina', { theme: h.menu.theme, title: h.menu.title, place: h.menu.place });
  check('před startem se prostředí ještě nezměnilo (běží ostrov)', (await settings()).theme === 'sky_island');
  await shot('02_menu_scifi');

  // ---------------------------------------------------------------- 3) start: jiné prostředí = nové načtení světa, hra rovnou běží
  await clickUi('menu_start');
  await waitFor(async () => { const x = await settings(); const q = await st(); return x.theme === 'scifi' && !q.modal; }, 300000, 'načtení sci-fi světa');
  await sleep(1500);
  s = await settings();
  h = await hud();
  const q0 = await st();
  check('po startu běží Vesmírná stanice', s.theme === 'scifi' && s.theme_name === 'Vesmírná stanice', { theme: s.theme, name: s.theme_name });
  check('hra běží hned a pravidla jsou stejná (240 zlata/kreditů, 20 životů, 12 vln)', !q0.modal && !q0.paused && q0.gold === 240 && q0.lives === 20 && s.total_waves === 12, { gold: q0.gold, lives: q0.lives, waves: s.total_waves });
  check('karty věží mají sci-fi názvy (Laser, Plazmomet, Teslova věž, Kryo věž)', sameObj(h.card_names, { archer: 'Laser', cannon: 'Plazmomet', mage: 'Teslova věž', frost: 'Kryo věž' }), h.card_names);
  check('schopnosti mají sci-fi názvy (Orbitální úder, Kryo vlna, Kreditový šok)', /^Orbitální úder/.test(h.ability_tips.meteor) && /^Kryo vlna/.test(h.ability_tips.blizzard) && /^Kreditový šok/.test(h.ability_tips.gold), h.ability_tips);
  check('náhled vlny používá sci-fi jméno nepřítele (Pěšák-bot)', h.wave_rows.some(r => r.includes('Pěšák-bot')), h.wave_rows);
  await sleep(1500);
  await shot('03_scifi_hra');

  // ---------------------------------------------------------------- 4) hlášky a texty podle prostředí
  await cmd({ op: 'max_dt', v: 0.5 });
  await clickUi('ability_gold');
  await clickUi('ability_gold');
  h = await hud();
  check('hláška o nabíjení používá sci-fi název (Kreditový šok)', /Kreditový šok/.test(h.toast), h.toast);
  await cmd({ op: 'gold', v: -230 });
  await clickUi('card_cannon');
  let cells = (await cmd({ op: 'cells' })).cells;
  await clickNorm((await cmd({ op: 'cell_screen', cx: cells[0].cx, cz: cells[0].cz })).p);
  await sleep(300);
  h = await hud();
  check('nedostatek peněz: hláška říká „kreditů“ (ne zlata)', /kreditů/.test(h.toast) && !/zlata/.test(h.toast), h.toast);
  await page.keyboard.press('Escape');

  // ---------------------------------------------------------------- 5) pravidla jsou stejná: věž má po vylepšeních stejnou sílu jako na ostrově
  await cmd({ op: 'gold', v: 5000 });
  cells = (await cmd({ op: 'cells' })).cells;
  const b = await cmd({ op: 'build', type: 'archer', cx: cells[0].cx, cz: cells[0].cz });
  let ti = await cmd({ op: 'tower_info', id: b.id });
  const lv1 = ti.stats;
  for (let i = 0; i < 3; i++) await cmd({ op: 'upgrade', id: b.id });
  ti = await cmd({ op: 'tower_info', id: b.id });
  check('laser L1 má stejné hodnoty jako lučištník (9 dmg, dosah 7)', lv1.damage === 9 && lv1.range === 7, { damage: lv1.damage, range: lv1.range });
  check('laser L4: 22 dmg, dosah 9,6, 2 výstřely, 25 % kritický zásah (stejně jako lučištník)', ti.level === 4 && ti.stats.damage === 22 && ti.stats.shots === 2 && Math.abs(ti.stats.range - 9.6) < 0.01 && ti.stats.crit === 0.25, { level: ti.level, stats: ti.stats });
  check('věž má po vylepšení nový model (tvar L4 se liší od L1)', ti.visuals !== undefined, ti.visuals);

  // ---------------------------------------------------------------- 6) zapamatování volby po obnovení stránky
  await sleep(2500);
  await page.reload();
  await ready();
  h = await hud();
  check('po obnovení stránky se pamatuje Vesmírná stanice', h.menu.theme === 'scifi' && (await settings()).theme === 'scifi', { menu: h.menu.theme });
  check('rozhraní po obnovení už ukazuje sci-fi texty (nadpis, karty)', h.menu.title === 'Vesmírná stanice' && h.card_names.archer === 'Laser', { title: h.menu.title });

  // ---------------------------------------------------------------- 7) návrat k Ostrovu v oblacích
  await clickUi('menu_theme_sky_island');
  await clickUi('menu_start');
  await waitFor(async () => { const x = await settings(); const q = await st(); return x.theme === 'sky_island' && !q.modal; }, 300000, 'návrat na ostrov');
  await sleep(1500);
  h = await hud();
  check('zpět na ostrov: původní názvy karet i schopností', h.card_names.archer === 'Lučištník' && /^Meteor/.test(h.ability_tips.meteor), { cards: h.card_names, tip: h.ability_tips.meteor });
  await shot('04_zpet_ostrov');

  // ---------------------------------------------------------------- 8) parametr ?theme= vynutí prostředí bez ukládání
  await page.goto('http://localhost:8151/index.html?test=1&q=low&nosound=1&skipintro=1&theme=scifi');
  await ready();
  s = await settings();
  check('?theme=scifi spustí Vesmírnou stanici hned (bez menu)', s.theme === 'scifi' && !(await st()).modal, { theme: s.theme });

  check('v konzoli nebyla žádná chyba', errors.length === 0, errors.slice(0, 3));
  const failed = checks.filter(c => !c.ok);
  console.log(`\nVýsledek: ${checks.length - failed.length} / ${checks.length} kontrol v pořádku`);
  fs.writeFileSync(path.join(OUT, 'themes_result.json'), JSON.stringify({ checks, errors }, null, 1));
  await browser.close(); srv.close();
  process.exit(failed.length ? 1 : 0);
})().catch(e => { console.log('VÝJIMKA', e); process.exit(2); });
