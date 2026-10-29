// Test grafiky a animací v prohlížeči: stavba / vylepšení / prodej věže, příchod a smrt nepřátel, vsáknutí do Srdce,
// spáleniny, záblesky, měkké stíny, mlha, kruhy na vodě, přehled výkonu (F3) a vypínání efektů v nízké kvalitě.
// Animace se zastavují v přesném okamžiku (freeze / step / seek), takže test nezávisí na rychlosti počítače.
//   node tests/gfx_browser.js [--out=tests/out]      (DOCS_DIR=složka s exportem, jinak docs/)
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' });
  fs.createReadStream(f).pipe(res); }).listen(8129);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const checks = []; const errors = [];
function check(name, ok, detail) { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? '  OK ' : ' CHYBA'}  ${name}${detail !== undefined ? '  (' + (typeof detail === 'string' ? detail : JSON.stringify(detail)) + ')' : ''}`); }

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 720 } })).newPage();
  page.on('console', m => { const t = m.text(); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
  page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
  const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
  const shot = async n => { await sleep(1800); const t0 = Date.now(); await page.screenshot({ path: path.join(OUT, 'gfx_' + n + '.png'), timeout: 240000 }); console.log('   snímek', n, ((Date.now() - t0) / 1000).toFixed(1) + ' s'); };
  const cam = async (p, zoom, yaw = 45) => cmd({ op: 'cam', yaw, zoom, px: p[0], pz: p[2] });
  const enemies = async () => (await cmd({ op: 'enemies' }));
  const by = (list, type) => list.find(e => e.type === type);

  await page.goto('http://localhost:8129/index.html?test=1&q=high&nosound=1&skipintro=1');
  await page.waitForFunction(() => window.TD_ready === true, null, { timeout: 300000 });
  await sleep(1500);
  await cmd({ op: 'freeze', v: true });
  await cmd({ op: 'gold', v: 3000 });

  // ------------------------------------------------------------ 1) svět: mlha, kvalita
  let gi = await cmd({ op: 'gfx_info' });
  check('hloubková mlha je zapnutá a kvalita je vysoká', gi.fog && gi.quality, { fog: gi.fog, quality: gi.quality });
  await cam([0, 0, 0], 62);
  await shot('01_ostrov');

  // ------------------------------------------------------------ 2) stavba věže (růst ze země s přeskokem)
  const cells = (await cmd({ op: 'cells' })).cells;
  const mid = cells[Math.floor(cells.length * 0.4)];
  const b = await cmd({ op: 'build', type: 'archer', cx: mid.cx, cz: mid.cz });
  check('věž lze postavit', b.ok, b);
  let ti = await cmd({ op: 'tower_info', id: b.id });
  const tp = ti.pos;
  await cam(tp, 9);
  const sy = []; let maxSy = 0;
  for (let i = 0; i <= 12; i++) { const t = (0.6 * i) / 12; const r = await cmd({ op: 'tower_anim', id: b.id, kind: 'build', t }); sy.push(+r.sy.toFixed(3)); maxSy = Math.max(maxSy, r.sy); if (i === 2 || i === 5 || i === 8) await shot('02_stavba_' + i); }
  check('stavba: začíná téměř nulovou výškou', sy[0] < 0.1, sy[0]);
  check('stavba: výška roste (prvních pět vzorků je rostoucích)', sy[1] < sy[2] && sy[2] < sy[3] && sy[3] < sy[4], sy.slice(0, 5));
  check('stavba: krátce přeskočí přes 100 % (odraz) a vrátí se na 100 %', maxSy > 1.02 && maxSy < 1.25 && Math.abs(sy[12] - 1) < 0.001, { max: +maxSy.toFixed(3), konec: sy[12] });
  const fin = await cmd({ op: 'tower_anim', id: b.id, kind: 'build', t: 0.6 });
  check('stavba: na konci stojí věž přesně na zemi (y = 0)', Math.abs(fin.y) < 0.001 && Math.abs(fin.sx - 1) < 0.001, fin);

  // ------------------------------------------------------------ 3) vylepšení: starý model mizí, nový se nafoukne
  await cmd({ op: 'upgrade', id: b.id });
  ti = await cmd({ op: 'tower_info', id: b.id });
  check('vylepšení: věž má úroveň 2 a hned po něm dva modely (nový + mizející starý)', ti.level === 2 && ti.visuals === 2, { level: ti.level, visuals: ti.visuals });
  const u0 = await cmd({ op: 'tower_anim', id: b.id, kind: 'upgrade', t: 0.0 });
  check('vylepšení: nový model začíná zmenšený (~55 %)', u0.sx > 0.5 && u0.sx < 0.6, u0.sx);
  await cmd({ op: 'tower_anim', id: b.id, kind: 'upgrade', t: 0.2 });
  await shot('03_vylepseni');
  const u1 = await cmd({ op: 'tower_anim', id: b.id, kind: 'upgrade', t: 0.5 });
  check('vylepšení: nový model skončí v plné velikosti', Math.abs(u1.sx - 1) < 0.001, u1.sx);
  await sleep(4000);
  ti = await cmd({ op: 'tower_info', id: b.id });
  check('vylepšení: starý model se nakonec uvolní (zbyde jeden)', ti.visuals === 1, ti.visuals);

  // ------------------------------------------------------------ 4) prodej: zmenšení
  const r0 = await cmd({ op: 'tower_anim', id: b.id, kind: 'retire', t: 0.11 });
  check('prodej: věž se zmenšuje a zvedá', r0.sx < 0.9 && r0.sx > 0.05 && r0.y > 0.0, r0);
  await shot('04_prodej');
  const gold0 = (await cmd({ op: 'gold', v: 0 })).gold;
  await cmd({ op: 'sell', id: b.id });
  const gold1 = (await cmd({ op: 'gold', v: 0 })).gold;
  check('prodej: peníze se vrátily', gold1 > gold0, { gold0, gold1 });
  ti = await cmd({ op: 'tower_info', id: b.id });
  check('prodej: věž už ve hře není', !ti.ok);

  // ------------------------------------------------------------ 5) příchod nepřátel (portál)
  const types = ['goblin', 'wolf', 'golem', 'drake', 'slime'];
  const L = await cmd({ op: 'lineup', types, s0: 14, ds: 2.8 });
  const pm = L.pos[2];
  await cam(pm, 12, 35);
  let en = await enemies();
  const g0 = by(en.list, 'goblin');
  check('příchod: nepřátelé začínají zmenšení (~35 %)', g0.sx > 0.3 && g0.sx < 0.45, g0.sx);
  await cmd({ op: 'step', t: 0.1 });
  en = await enemies();
  const g1 = by(en.list, 'goblin');
  check('příchod: po 0,1 s jsou větší, ale ještě ne v plné velikosti', g1.sx > g0.sx && g1.sx < 1.0, { z: g0.sx, po: g1.sx });
  await cmd({ op: 'step', t: 0.1 });
  await shot('05_prichod');
  await cmd({ op: 'step', t: 0.6 });
  en = await enemies();
  check('příchod: po 0,8 s mají všichni přesně plnou velikost a stojí na zemi', en.list.every(e => Math.abs(e.sx - 1) < 0.001 && Math.abs(e.vy) < 0.001), en.list.map(e => [e.type, +e.sx.toFixed(3)]));
  gi = await cmd({ op: 'gfx_info' });
  check('měkké stíny: pod každým nepřítelem je jeden stín', gi.blobs === types.length, gi.blobs);

  // ------------------------------------------------------------ 6) smrt podle typu
  await cmd({ op: 'kill' });
  await cam(pm, 12, 35);
  const samples = {};
  const times = [0.12, 0.2, 0.28, 0.4];   // celkem 0,12 / 0,32 / 0,60 / 1,00 s po zabití
  let tsum = 0;
  for (const t of times) {
    await cmd({ op: 'step', t }); tsum += t;
    const e = await enemies();
    samples[tsum.toFixed(2)] = e.list;
    if (tsum < 0.7) await shot('06_smrt_' + tsum.toFixed(2).replace('.', '_'));
  }
  const s32 = samples['0.32'], s60 = samples['0.60'], s100 = samples['1.00'];
  check('smrt: všechny typy mají vlastní trvání (goblin 0,6 / vlk 0,55 / golem 0,8 / dráček 0,85 / slizák 0,5)', ['goblin', 'wolf', 'golem', 'drake', 'slime'].every(t => by(s32, t)), s32.map(e => [e.type, e.dur]));
  const gb = by(s32, 'goblin'), wf = by(s32, 'wolf'), gl = by(s32, 'golem'), dr = by(s32, 'drake'), sl = by(s32, 'slime');
  check('smrt: skřet padá na záda (otočení kolem X záporné)', gb.rx < -0.5, +gb.rx.toFixed(2));
  check('smrt: vlk padá na bok (otočení kolem Z)', wf.rz > 0.5, +wf.rz.toFixed(2));
  check('smrt: golem se rozsypává (je zploštělý a široký)', gl.sy < 0.9 && gl.sx > 1.0, [+gl.sx.toFixed(2), +gl.sy.toFixed(2)]);
  check('smrt: dráček padá k zemi', dr.pos[1] < (by(samples['0.12'], 'drake').pos[1]) - 0.1, [by(samples['0.12'], 'drake').pos[1], dr.pos[1]]);
  check('smrt: slizák se rozplácne (široký a nízký)', sl.sx > 1.2 && sl.sy < 0.6, [+sl.sx.toFixed(2), +sl.sy.toFixed(2)]);
  const left60 = s60.filter(e => e.type !== 'slimeling').map(e => e.type);
  check('smrt: po 0,6 s zmizel slizák, skřet a vlk; golem a dráček ještě padají', !left60.includes('slime') && left60.includes('golem') && left60.includes('drake'), left60);
  check('smrt: po 1,0 s zbývají už jen rozpadlí slizánci', s100.every(e => e.type === 'slimeling'), s100.map(e => e.type));

  // ------------------------------------------------------------ 7) vsáknutí do Srdce
  await cmd({ op: 'kill' }); await cmd({ op: 'step', t: 1.5 });
  const pl = (await enemies()).path_len;
  const L2 = await cmd({ op: 'lineup', types: ['goblin', 'goblin', 'wolf'], s0: pl - 9, ds: 2.4 });
  await cmd({ op: 'step', t: 0.6 });
  const baseP = (await enemies()).base;
  await cam(baseP, 12, 35);
  const before = (await enemies()).list.filter(e => !e.dying);
  await cmd({ op: 'reach' });
  await cmd({ op: 'step', t: 0.25 });
  const mid25 = (await enemies()).list;
  await shot('07_srdce');
  await cmd({ op: 'step', t: 0.4 });
  const late = (await enemies()).list;
  const tgtY = baseP[1] + 1.9;
  check('vsáknutí: nepřátelé letí do Srdce (vzdálenost k cíli se zmenšuje a zmenšují se)', mid25.length > 0 && late.length > 0 && late[0].sx < mid25[0].sx && Math.hypot(late[0].pos[0] - baseP[0], late[0].pos[1] - tgtY, late[0].pos[2] - baseP[2]) < Math.hypot(mid25[0].pos[0] - baseP[0], mid25[0].pos[1] - tgtY, mid25[0].pos[2] - baseP[2]), { pred: mid25[0] && +mid25[0].sx.toFixed(2), po: late[0] && +late[0].sx.toFixed(2) });
  await cmd({ op: 'step', t: 1.0 });
  check('vsáknutí: po 0,7 s jsou všichni pryč', (await enemies()).list.length === 0);

  // ------------------------------------------------------------ 8) spáleniny a záblesky
  await cmd({ op: 'lives', v: 20 });
  const cmid = cells[Math.floor(cells.length * 0.7)];
  const cw = await cmd({ op: 'cell_screen', cx: cmid.cx, cz: cmid.cz });
  const sp = L.pos[0];
  await cam(sp, 9);
  await cmd({ op: 'fx_test', kind: 'scorch', x: sp[0], y: sp[1], z: sp[2], r: 2.2, a: 0.8 });
  gi = await cmd({ op: 'gfx_info' });
  check('spálenina: vznikla ve vysoké kvalitě', gi.scorches === 1, gi.scorches);
  await shot('08_spalenina');
  await cmd({ op: 'step', t: 6 });
  await cmd({ op: 'step', t: 7 });
  gi = await cmd({ op: 'gfx_info' });
  check('spálenina: po 13 s sama zmizela', gi.scorches === 0, gi.scorches);
  for (let i = 0; i < 20; i++) await cmd({ op: 'fx_test', kind: 'scorch', x: sp[0] + i * 0.5, y: sp[1], z: sp[2], r: 1 });
  gi = await cmd({ op: 'gfx_info' });
  check('spálenina: počet je omezený (nejvýše 14)', gi.scorches <= 14 && gi.scorches > 0, gi.scorches);

  // ------------------------------------------------------------ 9) skutečný výstřel dělem zanechá spálenu
  await cmd({ op: 'lives', v: 20 });
  await cmd({ op: 'step', t: 13 });                       // staré spáleniny doutnají nejvýš 12 s
  gi = await cmd({ op: 'gfx_info' });
  check('dělo: před zkouškou nezůstaly žádné staré spáleniny', gi.scorches === 0, gi.scorches);
  const cn = await cmd({ op: 'build', type: 'cannon', cx: mid.cx, cz: mid.cz });
  await cmd({ op: 'step', t: 1.0 });
  await cmd({ op: 'lineup', types: ['goblin', 'goblin', 'goblin', 'golem'], s0: Math.max(mid.s - 8, 1), ds: 1.6 });
  let maxScorch = 0, flying = false;
  for (let i = 0; i < 24; i++) {
    await cmd({ op: 'step', t: 0.5 });
    const x = await cmd({ op: 'gfx_info' }); maxScorch = Math.max(maxScorch, x.scorches);
    if (!flying && (await cmd({ op: 'tower_info', id: cn.id })).shots >= 2) { flying = true; await cam((await cmd({ op: 'tower_info', id: cn.id })).pos, 9, 35); await shot('09_delo'); }
  }
  ti = await cmd({ op: 'tower_info', id: cn.id });
  check('dělo: věž střílela a způsobila poškození', ti.shots > 0 && ti.damage_dealt > 0, { shots: ti.shots, dmg: Math.round(ti.damage_dealt) });
  check('dělo: po výbuších zůstala na zemi spálenina', maxScorch > 0, maxScorch);
  await cmd({ op: 'sell', id: cn.id });

  // ------------------------------------------------------------ 10) kruhy na vodě při přechodu mostu
  await cmd({ op: 'kill' }); await cmd({ op: 'step', t: 1.5 });
  const br = gi.bridges[0];
  const sb = (br[0] + br[1]) / 2;
  const Lb = await cmd({ op: 'lineup', types: ['goblin'], s0: sb, ds: 1 });
  await cmd({ op: 'step', t: 0.1 });
  await cam(Lb.pos[0], 9);
  let ringsMax = 0;
  for (let i = 0; i < 6; i++) { await cmd({ op: 'step', t: 0.2 }); const x = await cmd({ op: 'gfx_info' }); ringsMax = Math.max(ringsMax, x.rings); }
  check('most: kroky na mostě vytvářejí kruhy na hladině', ringsMax > 0, ringsMax);
  await shot('10_most');

  // ------------------------------------------------------------ 11) přehled výkonu F3
  await cmd({ op: 'kill' }); await cmd({ op: 'step', t: 1.5 });
  await cam([0, 0, 0], 62);
  await page.keyboard.press('F3');
  await sleep(2500);
  gi = await cmd({ op: 'gfx_info' });
  check('F3: přehled výkonu se zobrazil', gi.stats_visible);
  check('F3: renderer hlásí volání vykreslení, objekty i trojúhelníky', gi.draw_calls > 0 && gi.objects > 0 && gi.primitives > 0, { calls: gi.draw_calls, objects: gi.objects, kprims: Math.round(gi.primitives / 1000) });
  await shot('11_f3');
  await page.keyboard.press('F3');
  await sleep(500);
  gi = await cmd({ op: 'gfx_info' });
  check('F3: druhý stisk přehled skryje', !gi.stats_visible);

  // ------------------------------------------------------------ 12) nízká kvalita vypíná drahé efekty
  const q = await cmd({ op: 'quality', v: false });
  check('kvalita: přepnutí na nízkou se projeví i v efektech', q.quality === false, q);
  await cmd({ op: 'fx_test', kind: 'scorch', x: sp[0], y: sp[1], z: sp[2], r: 2 });
  gi = await cmd({ op: 'gfx_info' });
  check('kvalita: v nízké kvalitě spáleniny nevznikají', gi.scorches === 0, gi.scorches);
  await cmd({ op: 'lineup', types: ['goblin', 'wolf'], s0: 14, ds: 2.8 });
  await cmd({ op: 'step', t: 0.1 });
  gi = await cmd({ op: 'gfx_info' });
  check('kvalita: měkké stíny zůstávají i v nízké kvalitě (tam nahrazují skutečné stíny)', gi.blobs === 2, gi.blobs);
  await cam(L.pos[0], 14, 35);
  await shot('12_nizka');
  await cmd({ op: 'quality', v: true });

  // ------------------------------------------------------------ souhrn
  const bad = checks.filter(c => !c.ok);
  check('v konzoli prohlížeče nejsou žádné chyby', errors.length === 0, errors.slice(0, 5));
  console.log(`\nVýsledek: ${checks.filter(c => c.ok).length}/${checks.length} kontrol v pořádku`);
  fs.writeFileSync(path.join(OUT, 'gfx_browser.json'), JSON.stringify({ checks, errors }, null, 1));
  await browser.close(); srv.close();
  process.exit(checks.every(c => c.ok) ? 0 : 1);
})().catch(e => { console.error('SELHÁNÍ TESTU', e); process.exit(2); });
