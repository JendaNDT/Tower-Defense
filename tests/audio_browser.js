// Ověření zvuku v prohlížeči (Chromium + Playwright). Poslech nahradit nelze, proto se měří skutečný výstup Web Audio:
// do každého uzlu zapojeného na výstup se přidá analyzátor a sleduje se hlasitost (RMS) v čase.
//   node tests/audio_browser.js [--low] [--out=tests/out]
// Kontroly: zvuk se bez kliknutí nespustí; po kliknutí na „Začít hru“ hraje hudba a ambient; stavba/vylepšení/střelba
// přidají efekty; tlačítka reproduktor/nota ztlumí příslušnou sběrnici (RMS padne k nule); klidná -> bojová hudba;
// v konzoli nejsou chyby.
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const args = Object.fromEntries(process.argv.slice(2).map(a => { const [k, v] = a.replace(/^--/, '').split('='); return [k, v === undefined ? true : v]; }));
const ROOT = process.env.DOCS_DIR ? path.resolve(process.env.DOCS_DIR) : path.resolve(__dirname, '..', 'docs');
const OUT = path.resolve(args.out || path.join(__dirname, 'out')); fs.mkdirSync(OUT, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };
const srv = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-cache' });
  fs.createReadStream(f).pipe(res); }).listen(8125);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const checks = []; const errors = [];
function check(name, ok, detail) { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? '  OK ' : ' CHYBA'}  ${name}${detail !== undefined ? '  (' + detail + ')' : ''}`); }

// Vložené do stránky před spuštěním hry: zachytí AudioContext a všechno, co se připojí na jeho výstup.
const HOOK = () => {
  const origConnect = AudioNode.prototype.connect;
  window.__au = { ctxs: [], an: null, rmsLog: [], tapped: [], meter: null, meterRes: null };
  // měřič v audio vlákně: sčítá energii a špičku ze VŠECH vzorků (při 1–2 snímcích/s by vzorkování z hlavního vlákna minulo krátké zvuky)
  const METER_CODE = `class M extends AudioWorkletProcessor {
    constructor() { super(); this.reset(); this.port.onmessage = e => { if (e.data === 'reset') this.reset(); else if (e.data === 'get') this.port.postMessage({ s: this.s, n: this.n, pk: this.pk }); }; }
    reset() { this.s = [0, 0]; this.n = 0; this.pk = [0, 0]; }
    process(inputs) { const i = inputs[0]; if (i && i.length) { for (let c = 0; c < 2; c++) { const ch = i[Math.min(c, i.length - 1)]; for (let k = 0; k < ch.length; k++) { const v = ch[k]; this.s[c] += v * v; const a = Math.abs(v); if (a > this.pk[c]) this.pk[c] = a; } } this.n += i[0].length; } return true; } }
    registerProcessor('meter', M);`;
  window.__meterSetup = ctx => {
    if (window.__au.meterSetup) return; window.__au.meterSetup = true;
    ctx.audioWorklet.addModule(URL.createObjectURL(new Blob([METER_CODE], { type: 'application/javascript' }))).then(() => {
      const m = new AudioWorkletNode(ctx, 'meter', { numberOfInputs: 1, numberOfOutputs: 0, channelCount: 2, channelCountMode: 'explicit' });
      m.port.onmessage = e => { if (window.__au.meterRes) { window.__au.meterRes(e.data); window.__au.meterRes = null; } };
      window.__au.meter = m;
      for (const n of window.__au.tapped) origConnect.call(n, m);
    }).catch(e => console.log('meter chyba ' + e));
  };
  window.__meterReset = () => { if (window.__au.meter) window.__au.meter.port.postMessage('reset'); return !!window.__au.meter; };
  window.__meterGet = () => new Promise(res => { window.__au.meterRes = res; window.__au.meter.port.postMessage('get'); });
  AudioNode.prototype.connect = function (dest, ...rest) {
    const r = origConnect.call(this, dest, ...rest);
    try {
      if (dest && dest.constructor && dest.constructor.name === 'AudioDestinationNode') {
        const ctx = this.context;
        if (!window.__au.an) {
          const an = ctx.createAnalyser(); an.fftSize = 2048; window.__au.an = an;
        }
        if (!window.__au.lr) {
          const sp = ctx.createChannelSplitter(2), l = ctx.createAnalyser(), r = ctx.createAnalyser(); l.fftSize = r.fftSize = 2048;
          origConnect.call(sp, l, 0); origConnect.call(sp, r, 1); window.__au.lr = { sp, l, r }; window.__au.tapNode = sp;
        }
        origConnect.call(this, window.__au.an);
        origConnect.call(this, window.__au.lr.sp);
        window.__au.tapped.push(this); window.__meterSetup(ctx);
        if (window.__au.meter) origConnect.call(this, window.__au.meter);
      }
    } catch (e) { console.log('hook chyba ' + e); }
    return r;
  };
  const AC = window.AudioContext || window.webkitAudioContext;
  const patched = function (...a) { const c = new AC(...a); window.__au.ctxs.push(c); return c; };
  patched.prototype = AC.prototype; window.AudioContext = patched;
  // záznam startů zvukových zdrojů: Godot na webu smyčku řeší restartem po skončení => měříme mezeru mezi koncem a novým startem
  window.__au.starts = [];
  const origStart = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...a) {
    try { window.__au.starts.push({ t: this.context.currentTime, dur: this.buffer ? this.buffer.duration : 0, len: this.buffer ? this.buffer.length : 0 }); } catch (e) {}
    return origStart.apply(this, a);
  };
  window.__peak = 0;
  // špička hlasitosti levého a pravého kanálu za dané období (ms)
  window.__lrPeak = ms => new Promise(res => { let ml = 0, mr = 0; const t0 = performance.now(); const rms = an => { const b = new Float32Array(an.fftSize); an.getFloatTimeDomainData(b); let q = 0; for (const v of b) q += v * v; return Math.sqrt(q / b.length); };
    (function tick() { const lr = window.__au.lr; if (lr) { ml = Math.max(ml, rms(lr.l)); mr = Math.max(mr, rms(lr.r)); } if (performance.now() - t0 < ms) setTimeout(tick, 20); else res([ml, mr]); })(); });
  window.__rms = () => {
    const an = window.__au.an; if (!an) return -1;
    const buf = new Float32Array(an.fftSize); an.getFloatTimeDomainData(buf);
    let s = 0; for (const v of buf) { s += v * v; if (Math.abs(v) > window.__peak) window.__peak = Math.abs(v); } return Math.sqrt(s / buf.length);
  };
  window.__peakRms = ms => new Promise(res => { let m = 0; const t0 = performance.now(); (function tick() {
    m = Math.max(m, window.__rms()); if (performance.now() - t0 < ms) setTimeout(tick, 30); else res(m); })(); });
};

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-webgl', '--no-sandbox'] });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await ctx.newPage();
  await page.addInitScript(HOOK);
  const consoleLines = [];
  page.on('console', m => { const t = m.text(); consoleLines.push(t); if (m.type() === 'error' || /SCRIPT ERROR|ERROR/i.test(t)) { errors.push(t); console.log('[konzole]', t); } });
  page.on('pageerror', e => { errors.push(String(e)); console.log('[pageerror]', String(e)); });
  const cmd = async o => JSON.parse(await page.evaluate(x => { window.TD_cmd(JSON.stringify(x)); return window.TD_out; }, o));
  const st = async () => JSON.parse(await page.evaluate(() => { window.TD_state(); return window.TD_out; }));
  const box = async () => page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height }; });
  const clickNorm = async p => { const b = await box(); const x = b.x + p[0] * b.w, y = b.y + p[1] * b.h; await page.mouse.move(x, y, { steps: 4 }); await page.mouse.click(x, y); };
  const clickUi = async name => { const r = await cmd({ op: 'ui', name }); if (!r.ok) throw new Error('UI prvek nenalezen: ' + name); await clickNorm(r.p); };
  const audio = async () => cmd({ op: 'audio' });
  const waitFor = async (fn, ms, label) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { const v = await fn(); if (v) return v; await sleep(500); } throw new Error('Časový limit: ' + label); };

  const t0 = Date.now();
  await page.goto('http://localhost:8125/index.html?test=1' + (args.low ? '&q=low' : ''));
  await waitFor(() => page.evaluate(() => window.TD_ready === true), 300000, 'načtení hry');
  console.log('Hra načtena za', ((Date.now() - t0) / 1000).toFixed(1), 's');

  // 1) před kliknutím nesmí hrát nic
  let a = await audio();
  check('zvukový systém existuje', a.ok, JSON.stringify({ sounds: a.sounds }));
  check('všech 42 efektů připraveno hned při startu', a.sounds === 42, a.sounds);
  check('před prvním kliknutím nehraje hudba', !a.started && !a.calm_playing);
  const rms0 = await page.evaluate(() => window.__peakRms(600));
  check('před kliknutím je výstup tichý', rms0 <= 0.0005, rms0.toFixed(5));

  // 2) kliknutí na „Začít hru“ = první gesto hráče
  await clickUi('intro_btn');
  await sleep(500);
  a = await audio();
  check('po kliknutí je zvuk spuštěn (started)', a.started);
  const t1 = Date.now();
  await waitFor(async () => (await audio()).calm_ready, 240000, 'klidná hudba');
  const tCalm = (Date.now() - t0) / 1000;
  console.log(`  klidná hudba připravena ${tCalm.toFixed(1)} s po otevření stránky`);
  await waitFor(async () => (await audio()).battle_ready, 240000, 'bojová hudba');
  console.log(`  bojová hudba připravena ${((Date.now() - t0) / 1000).toFixed(1)} s po otevření stránky`);
  await sleep(1500);
  a = await audio();
  check('hraje klidná hudba a ambient', a.calm_playing && a.wind_playing, JSON.stringify({ calm: a.calm_playing, wind: a.wind_playing }));
  const ctxState = await page.evaluate(() => window.__au.ctxs.map(c => c.state));
  check('AudioContext běží (state = running)', ctxState.length > 0 && ctxState.every(s => s === 'running'), ctxState.join(','));
  const rmsMusic = await page.evaluate(() => window.__peakRms(1500));
  check('na výstupu je slyšitelný signál (hudba + ambient)', rmsMusic > 0.003, 'RMS ' + rmsMusic.toFixed(4));

  // 3) vypnutí hudby i efektů tlačítky (skutečné kliky)
  await cmd({ op: 'gold', v: 1000 });
  await clickUi('music_btn'); await sleep(400);
  a = await audio();
  check('tlačítko noty vypne hudbu', !a.music_on);
  const rmsNoMusic = await page.evaluate(() => window.__peakRms(1200));
  console.log(`  RMS s hudbou ${rmsMusic.toFixed(4)} -> bez hudby ${rmsNoMusic.toFixed(4)}`);
  check('po vypnutí hudby výstup výrazně klesne (zůstává jen ambient)', rmsNoMusic < rmsMusic * 0.8, `${rmsNoMusic.toFixed(4)} < ${(rmsMusic * 0.8).toFixed(4)}`);
  await clickUi('sfx_btn'); await sleep(400);
  a = await audio();
  check('tlačítko reproduktoru vypne efekty (a ambient)', !a.sfx_on);
  const rmsOff = await page.evaluate(() => window.__peakRms(1200));
  check('při vypnutí všeho je výstup tichý', rmsOff < 0.0008, rmsOff.toFixed(5));
  await clickUi('music_btn'); await clickUi('sfx_btn'); await sleep(400);
  a = await audio();
  check('zapnutí zpět funguje', a.music_on && a.sfx_on);
  // klávesa M: vypne vše, druhé stisknutí zapne
  await page.keyboard.press('m'); await sleep(300);
  a = await audio(); check('klávesa M vypne zvuk', !a.music_on && !a.sfx_on);
  await page.keyboard.press('m'); await sleep(300);
  a = await audio(); check('klávesa M zvuk znovu zapne', a.music_on && a.sfx_on);

  // 3b) prostorový zvuk: výstřel vlevo vs. vpravo od posluchače (kamery) => převaha příslušného kanálu.
  //     Měří se v audio vlákně (energie všech vzorků); hudba i ambient jsou na chvíli vypnuté, ať měříme jen výstřel.
  await cmd({ op: 'audio_set', sfx: true, music: false, ambient: false });
  await sleep(1500);
  async function shotEnergy(side, front = 0) {
    await page.evaluate(() => window.__meterReset()); await sleep(300);
    await cmd({ op: 'audio_play', sound: 'cannon_shot', side, dist: 22, front });
    await sleep(3500);
    const m = await page.evaluate(() => window.__meterGet());
    return m;
  }
  const mq = await page.evaluate(() => window.__meterReset());
  check('měřič v audio vlákně běží', mq);
  const eLeft = await shotEnergy(-1), eRight = await shotEnergy(1), eFront = await shotEnergy(0, 22);
  const fmt = m => `L ${m.s[0].toFixed(3)} / P ${m.s[1].toFixed(3)} (špička ${m.pk[0].toFixed(3)} / ${m.pk[1].toFixed(3)})`;
  console.log(`  výstřel vlevo: ${fmt(eLeft)}; vpravo: ${fmt(eRight)}; přímo před kamerou: ${fmt(eFront)}`);
  check('výstřel byl slyšet (energie > 0)', eLeft.s[0] + eLeft.s[1] > 0.01, (eLeft.s[0] + eLeft.s[1]).toFixed(3));
  check('zvuk vlevo od kamery je víc v levém kanálu', eLeft.s[0] > eLeft.s[1] * 1.5, `${eLeft.s[0].toFixed(3)} vs ${eLeft.s[1].toFixed(3)}`);
  check('zvuk vpravo od kamery je víc v pravém kanálu', eRight.s[1] > eRight.s[0] * 1.5, `${eRight.s[1].toFixed(3)} vs ${eRight.s[0].toFixed(3)}`);
  check('zvuk přímo před kamerou je v obou kanálech stejně', Math.abs(eFront.s[0] - eFront.s[1]) < 0.15 * (eFront.s[0] + eFront.s[1]), `${eFront.s[0].toFixed(3)} vs ${eFront.s[1].toFixed(3)}`);
  await cmd({ op: 'audio_set', sfx: true, music: true, ambient: true });
  await sleep(300);
  await page.evaluate(() => window.__meterReset());   // od teď se sleduje špička pro kontrolu přebuzení

  // 4) efekty: stavba, vylepšení, střelba (skutečné kliky a vlna)
  const cells = (await cmd({ op: 'cells' })).cells;
  const cell = cells.find(c => c.s >= 14 && c.s <= 30 && c.d < 2.6);
  const cnt0 = (await audio()).counts || {};
  await page.keyboard.press('1');
  const cs = await cmd({ op: 'cell_screen', cx: cell.cx, cz: cell.cz });
  { const b = await box(); const x = b.x + cs.p[0] * b.w, y = b.y + cs.p[1] * b.h;
    await page.mouse.move(x, y, { steps: 6 }); await sleep(400); await page.mouse.click(x, y); await sleep(500); }
  await page.keyboard.press('Escape');
  let s = await st();
  const tw = s.towers[0];
  check('věž postavena kliknutím', !!tw);
  await sleep(300);
  let cnt1 = (await audio()).counts || {};
  check('stavba přehrála zvuk „build“', (cnt1.build || 0) > (cnt0.build || 0), JSON.stringify({ build: cnt1.build }));
  if (tw) {
    await clickNorm((await cmd({ op: 'tower_screen', id: tw.id })).p); await sleep(400);
    await clickUi('upgrade_btn'); await sleep(500);
    cnt1 = (await audio()).counts || {};
    check('vylepšení přehrálo zvuk „upgrade“', (cnt1.upgrade || 0) >= 1, JSON.stringify({ upgrade: cnt1.upgrade }));
  }
  await page.keyboard.press('Escape');
  await cmd({ op: 'speed', v: 3 });
  await clickUi('wave_btn'); await sleep(1500);
  a = await audio();
  check('začátek vlny přehrál roh', (a.counts.wave_horn || 0) >= 1);
  await waitFor(async () => (await audio()).fade > 0.5, 90000, 'přechod na bojovou hudbu');
  a = await audio();
  check('v boji se hudba přeplynula na bojovou', a.fade > 0.5 && a.battle_db > -40, `fade ${a.fade.toFixed(2)}, bojová ${a.battle_db.toFixed(1)} dB, klidná ${a.calm_db.toFixed(1)} dB`);
  const rmsBattle = await page.evaluate(() => window.__peakRms(1500));
  check('v boji je na výstupu signál', rmsBattle > 0.003, 'RMS ' + rmsBattle.toFixed(4));
  // během vlny sledujeme špičku po úsecích a zjišťujeme, které zvuky v úseku zazněly (hledání původce největší špičky)
  const peaks = []; let prevCounts = (await audio()).counts || {};
  await waitFor(async () => {
    const m = await page.evaluate(async () => { const r = await window.__meterGet(); window.__meterReset(); return r; });
    const cur = (await audio()).counts || {};
    const added = Object.keys(cur).filter(k => (cur[k] || 0) > (prevCounts[k] || 0)).map(k => k + '×' + (cur[k] - (prevCounts[k] || 0)));
    peaks.push({ pk: Math.max(m.pk[0], m.pk[1]), added }); prevCounts = cur;
    const q = await st(); return q.spawn_left === 0 && q.enemies.length === 0; }, 600000, 'konec vlny');
  peaks.sort((a, b) => b.pk - a.pk);
  console.log('  největší špičky ve vlně:', peaks.slice(0, 4).map(p => p.pk.toFixed(3) + ' [' + p.added.join(', ') + ']').join(' | '));
  a = await audio();
  console.log('  přehrané efekty:', JSON.stringify(a.counts));
  check('při vlně zazněly výstřely i zásahy', (a.counts.archer_shot || 0) >= 3 && ((a.counts.arrow_hit || 0) >= 1), JSON.stringify({ shot: a.counts.archer_shot, hit: a.counts.arrow_hit }));
  check('zabití přehrálo zvuk smrti a minci', ((a.counts.death_goblin || 0) + (a.counts.death_wolf || 0) + (a.counts.death_golem || 0) + (a.counts.death_drake || 0)) >= 1 && (a.counts.coin || 0) >= 1);
  await waitFor(async () => (await audio()).fade < 0.2, 120000, 'návrat ke klidné hudbě');
  check('po vlně se hudba vrátila ke klidné', true);

  // 4b) schopnosti a noví nepřátelé mají vlastní zvuky
  const ca = (await audio()).counts || {};
  await cmd({ op: 'spawn', type: 'slime', n: 1, interval: 1, hp: 0.0001 });
  await cmd({ op: 'step', t: 2 });
  const qs = await st();
  const sl = qs.enemies.find(e => e.type === 'slime');
  await cmd({ op: 'cast', id: 'blizzard' });
  await cmd({ op: 'cast', id: 'gold' });
  await cmd({ op: 'cast', id: 'meteor', x: sl ? sl.x : 0, z: sl ? sl.z : 0 });
  await cmd({ op: 'step', t: 2 });
  await sleep(400);
  const cb2 = (await audio()).counts || {};
  const grew = k => (cb2[k] || 0) > (ca[k] || 0);
  check('schopnosti přehrály své zvuky (meteor padá a dopadá, poryv, horečka)', grew('meteor_fall') && grew('meteor_hit') && grew('blizzard') && grew('gold_rush'), JSON.stringify({ fall: cb2.meteor_fall, hit: cb2.meteor_hit, bliz: cb2.blizzard, gold: cb2.gold_rush }));
  check('slizák se při smrti rozpadl a ozval se (rozpad + smrt)', !!sl && grew('slime_split') && grew('death_slime'), JSON.stringify({ split: cb2.slime_split, death_slime: cb2.death_slime }));

  // 5) konec hry: prohra (znělka + ztlumení hudby), restart, výhra (fanfára)
  const cb = (await audio()).counts || {};
  await cmd({ op: 'lives', v: 1 });
  await cmd({ op: 'lineup', types: ['boss'], s0: 133, ds: 1 });
  await cmd({ op: 'step', t: 6.0 });
  await sleep(1500);
  let a2 = await audio();
  check('prohra přehrála znělku a zvuk ztráty života', (a2.counts.defeat || 0) > (cb.defeat || 0) && (a2.counts.base_hit || 0) > (cb.base_hit || 0), JSON.stringify({ defeat: a2.counts.defeat, base_hit: a2.counts.base_hit }));
  await sleep(2500);
  const rmsLost = await page.evaluate(() => window.__peakRms(1200));
  console.log(`  po prohře RMS ${rmsLost.toFixed(4)} (hudba je ztlumená)`);
  await clickUi('end_btn'); await sleep(1500);
  await cmd({ op: 'win' }); await sleep(1500);
  a2 = await audio();
  check('výhra přehrála fanfáru', (a2.counts.victory || 0) >= 1, a2.counts.victory);
  const mfin = await page.evaluate(() => window.__meterGet());
  const peak = Math.max(mfin.pk[0], mfin.pk[1], ...peaks.map(p => p.pk));
  check('na výstupu nedochází k přebuzení (skutečná špička ze všech vzorků < 1.0)', peak < 1.0, 'špička ' + peak.toFixed(3));
  const starts = await page.evaluate(() => window.__au.starts);
  const byLen = {};
  for (const st2 of starts) if (st2.dur > 5) (byLen[st2.len] = byLen[st2.len] || []).push(st2);
  for (const [len, arr] of Object.entries(byLen)) {
    // zdroje stejné délky (vítr a voda) se prokládají: každý start spárujeme s nejbližším dříve skončeným zdrojem
    const ends = [], gaps = [];
    for (const a of arr) {
      let bi = -1;
      for (let i = 0; i < ends.length; i++) if (ends[i] <= a.t + 0.002 && (bi < 0 || ends[i] > ends[bi])) bi = i;
      if (bi >= 0) { gaps.push(a.t - ends[bi]); ends.splice(bi, 1); }
      ends.push(a.t + a.dur);
    }
    if (gaps.length) {
      const sorted = gaps.slice().sort((x, y) => x - y);
      console.log(`  smyčka ${arr[0].dur.toFixed(1)} s: ${arr.length} startů, mezera mezi koncem a restartem: medián ${(sorted[sorted.length >> 1] * 1000).toFixed(0)} ms, nejmenší ${(sorted[0] * 1000).toFixed(0)} ms, největší ${(sorted[sorted.length - 1] * 1000).toFixed(0)} ms`);
    }
  }
  check('v konzoli nejsou chyby', errors.length === 0, errors.length);
  fs.writeFileSync(path.join(OUT, 'audio_browser_report.json'), JSON.stringify({ checks, errors, console: consoleLines.filter(l => /Zvuk|Ostrov/.test(l)) }, null, 2));
  const bad = checks.filter(c => !c.ok).length;
  console.log(`\n${checks.length - bad} / ${checks.length} kontrol v pořádku`);
  await browser.close(); srv.close();
  process.exit(bad ? 1 : 0);
})().catch(e => { console.error('TEST SELHAL:', e); process.exit(1); });
