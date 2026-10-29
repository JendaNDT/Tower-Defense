// Test nových funkcí v prohlížeči skutečnými kliky: menu (režim, obtížnost, ostrov), uložení voleb, aktivní schopnosti,
// noví nepřátelé, varování před letci, rekordy, nekonečný režim, nápověda.
//   node tests/features_browser.js [--out=tests/out]
const { chromium } = require('playwright');
const TD_THEME_Q = process.env.TD_THEME ? '&theme=' + process.env.TD_THEME : '';   // TD_THEME=scifi => spustí test v daném prostředí
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' });
  fs.createReadStream(f).pipe(res); }).listen(8128);
const sleep = ms => new Promise(r => setTimeout(r, ms));
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
  const shot = async n => page.screenshot({ path: path.join(OUT, 'feat_' + n + '.png') });
  async function waitFor(fn, ms, label) { const t0 = Date.now(); while (Date.now() - t0 < ms) { try { const v = await fn(); if (v) return v; } catch (e) { /* scéna se právě načítá */ } await sleep(500); } throw new Error('Časový limit: ' + label); }
  const ready = async () => { await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 }); await sleep(800); };
  const approx = (a, b, t = 0.05) => Math.abs(a - b) <= t;

  // ---------------------------------------------------------------- 1) menu při startu
  await page.goto('http://localhost:8128/index.html?test=1&q=low&nosound=1' + TD_THEME_Q);
  await ready();
  let h = await hud();
  check('při startu je otevřené menu s výchozími volbami (Příběh, Normální, Klikatá stezka)', h.intro_visible && h.menu.mode === 'campaign' && h.menu.diff === 'normal' && h.menu.island === 0 && h.menu.island_name === 'Klikatá stezka', h.menu);
  check('menu při startu nenabízí návrat do rozehrané hry a tlačítko je „Začít hru“', !h.menu.back_visible && h.menu.start_text === 'Začít hru');
  check('rekord pro čerstvou instalaci: zatím žádný', h.menu.record.includes('zatím žádný'), h.menu.record);
  await shot('01_menu');

  // ---------------------------------------------------------------- 2) výběr voleb kliknutím
  await clickUi('menu_mode_endless');
  await clickUi('menu_diff_hard');
  await clickUi('menu_island_next'); await clickUi('menu_island_next');
  h = await hud();
  check('kliknutí mění volby v menu (Nekonečný, Těžká, Hadí údolí)', h.menu.mode === 'endless' && h.menu.diff === 'hard' && h.menu.island === 2 && h.menu.island_name === 'Hadí údolí', h.menu);
  await clickUi('menu_island_next');
  h = await hud();
  check('čtvrtá volba ostrova je „Náhodný ostrov“', h.menu.island === 3 && h.menu.island_name === 'Náhodný ostrov', h.menu.island_name);
  await clickUi('menu_island_next');
  h = await hud();
  check('výběr ostrova se točí dokola (zpět na Klikatou stezku)', h.menu.island === 0);
  await clickUi('menu_island_prev'); await clickUi('menu_island_prev');
  h = await hud();
  check('šipka zpět', h.menu.island === 2, h.menu.island_name);
  await shot('02_menu_volby');

  // ---------------------------------------------------------------- 3) start: jiný ostrov = nové načtení světa a hra rovnou běží
  await clickUi('menu_start');
  await waitFor(async () => { const s = await settings(); const q = await st(); return s.island_name === 'Hadí údolí' && !q.modal; }, 240000, 'načtení nového ostrova');
  await sleep(1500);
  let s = await settings();
  h = await hud();
  let q = await st();
  check('po startu je zvolený ostrov Hadí údolí, nekonečný režim, těžká obtížnost', s.island_name === 'Hadí údolí' && s.game_mode === 'endless' && s.game_diff === 'hard' && s.total_waves === 0, { island: s.island_name, mode: s.game_mode, diff: s.game_diff });
  check('těžká obtížnost: start 220 zlata a 15 životů', q.gold === 220 && q.lives === 15, { gold: q.gold, lives: q.lives });
  check('hra běží hned (bez další úvodní obrazovky)', !q.modal && !q.paused, { modal: q.modal, paused: q.paused });
  check('záhlaví ukazuje ostrov, obtížnost a režim', h.info === 'Hadí údolí · Těžká · Nekonečný', h.info);
  check('v nekonečném režimu je ukazatel vln bez limitu', h.wave_lbl === 'Vlna 0' && h.wave_title === 'Další: vlna 1', { lbl: h.wave_lbl, title: h.wave_title });
  await shot('03_hadi_udoli');

  // ---------------------------------------------------------------- 4) uložení voleb (po obnovení stránky)
  await sleep(2500);   // ať se soubor stihne zapsat do úložiště prohlížeče
  await page.reload();
  await ready();
  h = await hud();
  check('volby se po obnovení stránky pamatují (Nekonečný, Těžká, Hadí údolí)', h.menu.mode === 'endless' && h.menu.diff === 'hard' && h.menu.island === 2, h.menu);
  await clickUi('menu_start');           // stejný ostrov => restart pravidel na stejné mapě
  await waitFor(async () => !(await st()).modal, 120000, 'začátek hry po obnovení');
  s = await settings();
  check('stejný ostrov se nenačítá znovu, hra jen začne', s.island_name === 'Hadí údolí' && s.game_mode === 'endless');

  // ---------------------------------------------------------------- 5) schopnosti
  await cmd({ op: 'max_dt', v: 0.5 });
  await cmd({ op: 'gold', v: 1000 });
  h = await hud();
  const abBefore = (await settings()).ability_cd;
  check('všechny schopnosti jsou na začátku připravené', abBefore.meteor === 0 && abBefore.blizzard === 0 && abBefore.gold === 0, abBefore);
  await cmd({ op: 'spawn', type: 'goblin', n: 6, interval: 0.5, hp: 8 });
  await cmd({ op: 'step', t: 5 });
  q = await st();
  check('nepřátelé vyšli z portálu', q.enemies.length === 6, q.enemies.length);
  // Zlatá horečka (klik na tlačítko)
  await clickUi('ability_gold');
  s = await settings();
  check('Zlatá horečka se spustí kliknutím (boost ~15 s, nabíjení 80 s)', s.gold_boost > 14 && s.ability_cd.gold > 78, { boost: s.gold_boost, cd: s.ability_cd.gold });
  await clickUi('ability_gold');
  h = await hud();
  check('druhé kliknutí během nabíjení jen vypíše hlášku', /nabíjí/.test(h.toast), h.toast);
  // Meteor: klik na tlačítko, pak klik do mapy na hlouček nepřátel
  await clickUi('ability_meteor');
  h = await hud();
  check('klik na Meteor zapne míření', h.aiming === 'meteor', h.aiming);
  await page.keyboard.press('Escape'); await sleep(200);
  h = await hud();
  check('Esc míření zruší (schopnost se nespotřebuje)', h.aiming === '' && (await settings()).ability_cd.meteor === 0, h.aiming);
  await page.keyboard.press('5'); await sleep(200);
  h = await hud();
  check('klávesa 5 zapne míření meteoru', h.aiming === 'meteor');
  await cmd({ op: 'max_dt', v: 0.1 });   // zpomalit běh hry vůči skutečnému času, ať hlouček mezi výpočtem a klikem neuteče
  q = await st();
  const mid = q.enemies.reduce((a, e) => ({ x: a.x + e.x / q.enemies.length, y: a.y + e.y / q.enemies.length, z: a.z + e.z / q.enemies.length }), { x: 0, y: 0, z: 0 });
  const pr = (await cmd({ op: 'project', x: mid.x, y: mid.y, z: mid.z })).p;
  const hpFull = q.enemies.map(e => e.max_hp);
  await clickNorm(pr);
  await sleep(300);
  s = await settings();
  check('klik do mapy seslal meteor (nabíjení 35 s, míření skončilo)', s.ability_cd.meteor > 30 && s.abilities_used.meteor === 1 && (await hud()).aiming === '', { cd: s.ability_cd.meteor });
  await cmd({ op: 'freeze', v: true });
  await shot('04_zaměřeno');
  await cmd({ op: 'freeze', v: false });
  await cmd({ op: 'step', t: 1.3 });
  q = await st();
  const damaged = q.enemies.filter((e, i) => e.hp < e.max_hp - 1).length + (6 - q.enemies.length);
  check('meteor zasáhl nepřátele v okruhu (%d z 6 poškozeno nebo zabito)'.replace('%d', damaged), damaged >= 3, { damaged, left: q.enemies.length });
  // Mrazivý poryv (klávesa 6)
  await page.keyboard.press('6'); await sleep(300);
  q = await st();
  const frozen = q.enemies.filter(e => e.frozen).length;
  check('klávesa 6: Mrazivý poryv zmrazí všechny nepřátele na mapě', q.enemies.length > 0 && frozen === q.enemies.length, { frozen, total: q.enemies.length });
  s = await settings();
  check('všechny tři schopnosti byly použity a mají nabíjení', s.abilities_used.meteor === 1 && s.abilities_used.blizzard === 1 && s.abilities_used.gold === 1);
  await cmd({ op: 'step', t: 25 });

  // ---------------------------------------------------------------- 6) varování před letci a noví nepřátelé
  await cmd({ op: 'set_wave', v: 2 });
  h = await hud();
  check('panel další vlny (vlna 3) varuje před létajícími', h.wave_rows.some(r => /Létající/.test(r)) && h.wave_rows.some(r => /Dráček/.test(r)), h.wave_rows);
  await cmd({ op: 'set_wave', v: 3 });
  h = await hud();
  check('panel vlny 4 ukazuje Slizáka', h.wave_rows.some(r => /Slizák × 4/.test(r)), h.wave_rows);
  await cmd({ op: 'wave' });
  await sleep(500);
  h = await hud();
  check('při prvním výskytu nového nepřítele se objeví upozornění', /Nový nepřítel/.test(h.toast), h.toast);
  await cmd({ op: 'set_wave', v: 6 });
  h = await hud();
  check('panel vlny 7 ukazuje Léčitele', h.wave_rows.some(r => /Léčitel/.test(r)), h.wave_rows);
  await cmd({ op: 'set_wave', v: 5 });
  h = await hud();
  check('panel vlny 6 ukazuje Štítonoše', h.wave_rows.some(r => /Štítonoš/.test(r)), h.wave_rows);
  await cmd({ op: 'set_wave', v: 30 });
  h = await hud();
  check('v nekonečném režimu se vlny počítají dál (vlna 31, bez horní meze)', h.wave_title === 'Další: vlna 31' && h.wave_rows.length >= 3, { title: h.wave_title, rows: h.wave_rows.length });

  // ---------------------------------------------------------------- 7) nápověda a menu uprostřed hry
  await clickUi('help_btn');
  h = await hud();
  check('tlačítko ? otevře nápovědu (a hra se pozastaví)', h.help_visible && (await st()).paused === true);
  await clickUi('help_close');
  h = await hud();
  check('zavření nápovědy hru znovu pustí', !h.help_visible && (await st()).paused === false);
  await clickUi('menu_btn');
  h = await hud();
  check('menu uprostřed hry nabízí návrat do hry a „Nová hra“', h.intro_visible && h.menu.back_visible && h.menu.start_text === 'Nová hra', h.menu);
  await clickUi('menu_back');
  h = await hud();
  check('„Zpět do rozehrané hry“ menu zavře a hra běží', !h.intro_visible && (await st()).paused === false);

  // ---------------------------------------------------------------- 8) rekord, konec hry, změna nastavení
  await cmd({ op: 'records', persist: true, clear: true });
  await cmd({ op: 'set_wave', v: 0 });
  await cmd({ op: 'win' });                 // dokončí vlnu 1 => nejlepší vlna 1 (v nekonečném režimu hra nekončí)
  s = await settings();
  q = await st();
  check('nekonečný režim: dokončení vlny hru neukončí, ale zapíše rekord', q.state === 0 && s.records['endless_hard_2'] && s.records['endless_hard_2'].waves === 1, s.records);
  await cmd({ op: 'lives', v: 1 });
  await cmd({ op: 'lineup', types: ['boss'], s0: 119, ds: 1 });
  await cmd({ op: 'step', t: 12 });
  await sleep(1000);
  h = await hud();
  check('prohra zobrazí konec hry s rekordem a statistikami (nekonečný režim)', h.end_visible && /Rekord/.test(h.end_body) && /vlna 1/.test(h.end_body) && /nekonečný/i.test(h.end_body), h.end_body);
  await shot('06_konec');
  await clickUi('end_menu_btn');
  h = await hud();
  check('z konce hry jde změnit nastavení (menu se rekordem pro tuto kombinaci)', h.intro_visible && /vlna 1/.test(h.menu.record), h.menu.record);
  await clickUi('menu_mode_campaign'); await clickUi('menu_diff_easy');
  h = await hud();
  check('rekord je zvlášť pro každou kombinaci (příběh + lehká = zatím žádný)', /zatím žádný/.test(h.menu.record), h.menu.record);
  await clickUi('menu_start');
  await waitFor(async () => !(await st()).modal, 120000, 'restart s novým nastavením');
  s = await settings(); q = await st(); h = await hud();
  check('nová hra na stejném ostrově: příběh, lehká (320 zlata, 30 životů, 12 vln)', s.game_mode === 'campaign' && s.game_diff === 'easy' && q.gold === 320 && q.lives === 30 && h.wave_lbl === 'Vlna 0 / 12', { gold: q.gold, lives: q.lives, lbl: h.wave_lbl });

  // ---------------------------------------------------------------- 9) vítězství v příběhu + rekord
  await cmd({ op: 'records', persist: true, clear: true });
  await cmd({ op: 'win' });
  await sleep(800);
  s = await settings(); h = await hud();
  const rec = s.records['campaign_easy_2'];
  check('příběh: po 12. vlně vítězství a rekord „vítězství“', h.end_visible && /Vítězství/.test(h.end_title) && rec && rec.won === true, { title: h.end_title, rec });
  await shot('07_vitezstvi');

  // ---------------------------------------------------------------- 10) náhodný ostrov
  await clickUi('end_menu_btn');
  await clickUi('menu_island_next');       // z Hadího údolí na Náhodný
  h = await hud();
  check('náhodný ostrov je v menu', h.menu.island === 3, h.menu.island_name);
  await clickUi('menu_start');
  await waitFor(async () => { const t = await settings(); const qq = await st(); return /Náhodný ostrov č\./.test(t.island_name) && !qq.modal; }, 240000, 'načtení náhodného ostrova');
  s = await settings();
  check('náhodný ostrov má vlastní číslo (seed)', s.island === 3 && s.random_seed >= 1000, { name: s.island_name, seed: s.random_seed });
  await shot('08_nahodny');

  check('v konzoli nejsou chyby', errors.length === 0, errors.length);
  fs.writeFileSync(path.join(OUT, 'features_report.json'), JSON.stringify({ checks, errors }, null, 2));
  const bad = checks.filter(c => !c.ok).length;
  console.log(`\n${checks.length - bad} / ${checks.length} kontrol v pořádku`);
  await browser.close(); srv.close();
  process.exit(bad ? 1 : 0);
})().catch(e => { console.error('TEST SELHAL:', e); process.exit(1); });
