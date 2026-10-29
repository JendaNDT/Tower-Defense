class_name Synth
extends RefCounted
## Syntezátor zvuků a hudby – vše se počítá v kódu (žádné zvukové soubory).
## Zvukové efekty: sčítání tónů s hlasitostní obálkou, šum s filtry (dolní propust, pásmová propust).
## Hudba: události (nástroj, začátek, délka, výška) se vykreslují do bufferu; zápis se „zalamuje“ přes konec,
## takže smyčka navazuje bez cvaknutí.

const RATE: int = 22050        # vzorkovací frekvence efektů
const MRATE: int = 11025       # vzorkovací frekvence hudby a ambientu (úspora výkonu)

static var _rng: RandomNumberGenerator = null
static var cache: Dictionary = {}      # už vygenerované zvuky (efekty, ambient, hudba) – nové načtení scény je nemusí počítat znovu


static func rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	return _rng


static func buf(sec: float, rate: int = RATE) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(maxi(int(sec * float(rate)), 1))
	return b


## Přidá tón s plynulým posunem výšky f0 -> f1 (exponenciálně), obálkou a volitelnými harmonickými [[násobek, síla], ...].
static func tone(b: PackedFloat32Array, rate: int, t0: float, dur: float, f0: float, f1: float, amp: float,
		decay: float = 8.0, attack: float = 0.004, harm: Array = [], vib_hz: float = 0.0, vib_depth: float = 0.0) -> void:
	var i0: int = int(t0 * float(rate))
	var n: int = int(dur * float(rate))
	var size: int = b.size()
	var phase: float = 0.0
	var ratio: float = f1 / maxf(f0, 1.0)
	for k in range(n):
		var idx: int = i0 + k
		if idx >= size:
			break
		var t: float = float(k) / float(rate)
		var u: float = float(k) / float(maxi(n - 1, 1))
		var f: float = f0 * pow(ratio, u)
		if vib_hz > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib_hz * t)
		phase += f / float(rate)
		var env: float = amp * minf(t / attack, 1.0) * exp(-decay * t) * clampf((dur - t) / 0.006, 0.0, 1.0)
		var s: float = sin(TAU * phase)
		for h in harm:
			s += float(h[1]) * sin(TAU * phase * float(h[0]))
		b[idx] += env * s


## Šum s jednopólovou dolní propustí (lp = 1 bez filtru); hp = true => horní propust (šum minus jeho dolní propust).
static func noise(b: PackedFloat32Array, rate: int, t0: float, dur: float, amp: float, decay: float = 10.0,
		lp: float = 1.0, hp: bool = false, attack: float = 0.001) -> void:
	var i0: int = int(t0 * float(rate))
	var n: int = int(dur * float(rate))
	var size: int = b.size()
	var y: float = 0.0
	var r: RandomNumberGenerator = rng()
	for k in range(n):
		var idx: int = i0 + k
		if idx >= size:
			break
		var t: float = float(k) / float(rate)
		var x: float = r.randf() * 2.0 - 1.0
		y += lp * (x - y)
		var s: float = (x - y) if hp else y
		var env: float = amp * minf(t / attack, 1.0) * exp(-decay * t) * clampf((dur - t) / 0.006, 0.0, 1.0)
		b[idx] += env * s


## Šum prohnaný pásmovou propustí s posuvem středu f0 -> f1 (svist, vítr, voda).
static func band_noise(b: PackedFloat32Array, rate: int, t0: float, dur: float, amp: float, f0: float, f1: float,
		q: float = 0.2, decay: float = 0.0, attack: float = 0.01, release: float = 0.05) -> void:
	var i0: int = int(t0 * float(rate))
	var n: int = int(dur * float(rate))
	var size: int = b.size()
	var low: float = 0.0
	var band: float = 0.0
	var r: RandomNumberGenerator = rng()
	var ratio: float = f1 / maxf(f0, 1.0)
	for k in range(n):
		var idx: int = i0 + k
		if idx >= size:
			break
		var t: float = float(k) / float(rate)
		var u: float = float(k) / float(maxi(n - 1, 1))
		var fc: float = f0 * pow(ratio, u)
		# dvojité vzorkování filtru: jinak je při středu nad ~5 kHz nestabilní a vyrobí hlasitý skřek
		var f: float = 2.0 * sin(PI * minf(fc, float(rate) * 0.45) / float(rate * 2))
		var x: float = r.randf() * 2.0 - 1.0
		var acc: float = 0.0
		for sub in range(2):
			low += f * band
			var high: float = x - low - q * band
			band += f * high
			acc += band
		var env: float = amp * minf(t / attack, 1.0) * minf((dur - t) / release, 1.0) * exp(-decay * t)
		b[idx] += env * acc * 0.5 * q * 1.5


static func normalize(b: PackedFloat32Array, peak: float = 0.9) -> void:
	var m: float = 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var g: float = peak / m
	for i in range(b.size()):
		b[i] *= g
	# krátké doběhnutí na nulu (žádné cvaknutí na konci)
	var fade: int = mini(int(0.004 * float(RATE)), b.size())
	for i in range(fade):
		b[b.size() - 1 - i] *= float(i) / float(fade)


static func to_wav(b: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var n: int = b.size()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w


## Seznam efektů (jména pro play()).
const SFX_NAMES: Array = [
	"ui_click", "ui_error", "build", "upgrade", "sell",
	"archer_shot", "arrow_hit", "cannon_shot", "explosion", "mage_cast", "magic_hit", "zap",
	"frost_pulse", "freeze_hit",
	"death_goblin", "death_wolf", "death_golem", "death_drake", "death_boss", "coin",
	"base_hit", "wave_horn", "wave_clear", "victory", "defeat", "stomp", "spawn",
	"bird_1", "bird_2", "bird_3",
	"heal", "shield_break", "slime_split", "death_healer", "death_shield", "death_slime", "death_slimeling",
	"meteor_fall", "meteor_hit", "blizzard", "gold_rush", "ability_ready",
]


static func make_sfx(sfx_name: String, theme: String = "sky_island") -> AudioStreamWAV:
	if theme == "scifi":
		var sw: AudioStreamWAV = SynthSciFi.sfx(sfx_name)
		if sw != null:
			return sw
	var R: int = RATE
	rng().seed = hash(sfx_name)
	var b: PackedFloat32Array
	match sfx_name:
		"ui_click":
			b = buf(0.07)
			tone(b, R, 0.0, 0.07, 1100.0, 1700.0, 1.0, 45.0, 0.002, [[2.0, 0.3]])
		"ui_error":
			b = buf(0.3)
			for t0 in [0.0, 0.14]:
				tone(b, R, t0, 0.12, 150.0, 140.0, 1.0, 6.0, 0.005, [[2.0, 0.6], [3.0, 0.4]])
				tone(b, R, t0, 0.12, 157.0, 147.0, 0.8, 6.0, 0.005, [[2.0, 0.6], [3.0, 0.4]])
		"build":
			b = buf(0.5)
			noise(b, R, 0.0, 0.06, 1.0, 40.0, 0.35)
			tone(b, R, 0.0, 0.3, 170.0, 60.0, 1.0, 14.0)
			tone(b, R, 0.05, 0.25, 1500.0, 1400.0, 0.25, 22.0, 0.002, [[2.7, 0.4]])
			noise(b, R, 0.16, 0.05, 0.8, 45.0, 0.35)
			tone(b, R, 0.16, 0.2, 210.0, 90.0, 0.7, 16.0)
		"upgrade":
			b = buf(1.1)
			var notes: Array = [523.25, 659.25, 783.99, 1046.5]
			for i in range(notes.size()):
				tone(b, R, float(i) * 0.1, 0.7, notes[i], notes[i], 0.8, 5.0, 0.003, [[2.0, 0.25], [3.0, 0.12]])
			tone(b, R, 0.38, 0.6, 1318.5, 1318.5, 0.4, 4.0, 0.01, [[2.0, 0.2]])
			band_noise(b, R, 0.1, 0.5, 0.25, 4000.0, 7000.0, 0.2, 5.0, 0.02, 0.2)
		"sell":
			b = buf(0.4)
			tone(b, R, 0.0, 0.25, 1568.0, 1568.0, 1.0, 14.0, 0.002, [[2.4, 0.3]])
			tone(b, R, 0.07, 0.3, 2093.0, 2093.0, 0.9, 12.0, 0.002, [[2.4, 0.3]])
			noise(b, R, 0.0, 0.015, 0.5, 100.0, 0.9, true)
		"archer_shot":
			b = buf(0.28)
			tone(b, R, 0.0, 0.2, 420.0, 160.0, 0.9, 18.0, 0.001, [[2.0, 0.4], [3.0, 0.2]])
			noise(b, R, 0.0, 0.02, 0.8, 100.0, 0.25, true)
			band_noise(b, R, 0.01, 0.18, 0.5, 2500.0, 900.0, 0.4, 14.0, 0.005, 0.05)
		"arrow_hit":
			b = buf(0.2)
			tone(b, R, 0.0, 0.12, 260.0, 110.0, 1.0, 28.0)
			noise(b, R, 0.0, 0.04, 0.9, 60.0, 0.4)
		"cannon_shot":
			b = buf(0.9)
			tone(b, R, 0.0, 0.7, 120.0, 34.0, 1.0, 5.5, 0.002, [[2.0, 0.3]])
			noise(b, R, 0.0, 0.5, 1.0, 6.0, 0.12)
			noise(b, R, 0.0, 0.03, 1.0, 90.0, 1.0)
			band_noise(b, R, 0.02, 0.4, 0.5, 400.0, 120.0, 0.5, 7.0, 0.005, 0.1)
		"explosion":
			b = buf(1.2)
			noise(b, R, 0.0, 1.0, 1.0, 3.5, 0.18)
			tone(b, R, 0.0, 0.9, 90.0, 28.0, 1.0, 4.0)
			noise(b, R, 0.0, 0.05, 1.0, 60.0, 1.0)
			for i in range(8):
				noise(b, R, rng().randf_range(0.05, 0.5), 0.012, 0.5, 150.0, 1.0, true)
		"mage_cast":
			b = buf(0.5)
			tone(b, R, 0.0, 0.4, 420.0, 1500.0, 0.8, 6.0, 0.01, [[2.0, 0.35], [3.01, 0.2]], 18.0, 0.03)
			band_noise(b, R, 0.0, 0.35, 0.35, 2500.0, 6000.0, 0.2, 6.0, 0.02, 0.1)
			tone(b, R, 0.18, 0.3, 1800.0, 2400.0, 0.3, 9.0)
		"magic_hit":
			b = buf(0.35)
			tone(b, R, 0.0, 0.25, 1300.0, 350.0, 1.0, 14.0, 0.002, [[2.0, 0.5], [3.0, 0.3]])
			band_noise(b, R, 0.0, 0.2, 0.7, 5000.0, 1500.0, 0.3, 14.0, 0.002, 0.05)
			tone(b, R, 0.02, 0.2, 2600.0, 2400.0, 0.3, 18.0)
		"zap":
			b = buf(0.28)
			for i in range(10):
				var f: float = rng().randf_range(600.0, 3000.0)
				tone(b, R, float(i) * 0.02, 0.03, f, f * 0.8, 0.6, 40.0, 0.001, [[3.0, 0.5]])
			noise(b, R, 0.0, 0.25, 0.6, 10.0, 0.7, true)
		"frost_pulse":
			b = buf(1.1)
			for f in [1568.0, 2349.0, 3136.0]:
				tone(b, R, 0.0, 0.9, f, f, 0.5, 4.0, 0.03, [], 9.0, 0.05)
			band_noise(b, R, 0.0, 0.7, 0.35, 3000.0, 7000.0, 0.25, 3.0, 0.15, 0.2)
			tone(b, R, 0.0, 0.5, 300.0, 520.0, 0.3, 4.0, 0.05)
		"freeze_hit":
			b = buf(0.35)
			tone(b, R, 0.0, 0.3, 2793.0, 2790.0, 1.0, 14.0, 0.002, [[1.5, 0.6]])
			tone(b, R, 0.0, 0.25, 3951.0, 3951.0, 0.6, 18.0)
			noise(b, R, 0.0, 0.02, 0.8, 100.0, 0.9, true)
		"death_goblin":
			b = buf(0.4)
			tone(b, R, 0.0, 0.28, 700.0, 260.0, 1.0, 8.0, 0.003, [[2.0, 0.3]], 24.0, 0.06)
			noise(b, R, 0.02, 0.15, 0.4, 14.0, 0.5)
		"death_wolf":
			b = buf(0.45)
			tone(b, R, 0.0, 0.35, 820.0, 330.0, 1.0, 6.0, 0.003, [[2.0, 0.5], [3.0, 0.25]], 12.0, 0.04)
			tone(b, R, 0.05, 0.25, 1200.0, 500.0, 0.4, 10.0)
		"death_golem":
			b = buf(0.8)
			noise(b, R, 0.0, 0.6, 1.0, 6.0, 0.25)
			tone(b, R, 0.0, 0.5, 95.0, 45.0, 0.9, 8.0)
			tone(b, R, 0.02, 0.4, 420.0, 415.0, 0.5, 9.0, 0.002, [[2.76, 0.5], [5.4, 0.3]])
			for i in range(5):
				noise(b, R, rng().randf_range(0.05, 0.4), 0.03, 0.5, 60.0, 0.4)
		"death_drake":
			b = buf(0.7)
			tone(b, R, 0.0, 0.5, 1100.0, 380.0, 0.9, 6.0, 0.003, [[2.0, 0.6], [3.0, 0.5], [4.0, 0.3]], 30.0, 0.08)
			band_noise(b, R, 0.0, 0.4, 0.5, 3000.0, 1200.0, 0.25, 6.0, 0.005, 0.1)
		"heal":
			b = buf(0.8)
			for i in range(3):
				var hf: float = [784.0, 987.8, 1174.7][i]
				tone(b, R, float(i) * 0.07, 0.6, hf, hf, 0.7, 5.0, 0.01, [[2.0, 0.25]])
			band_noise(b, R, 0.0, 0.5, 0.12, 5000.0, 9000.0, 0.2, 6.0, 0.05, 0.2)
		"shield_break":
			b = buf(0.5)
			noise(b, R, 0.0, 0.03, 1.0, 80.0, 1.0, true)
			for i in range(6):
				var sf: float = rng().randf_range(2500.0, 5000.0)
				tone(b, R, rng().randf_range(0.0, 0.12), 0.18, sf, sf * 0.5, 0.5, 18.0, 0.001, [[2.76, 0.5]])
			tone(b, R, 0.0, 0.35, 900.0, 300.0, 0.6, 10.0)
			band_noise(b, R, 0.0, 0.4, 0.4, 6000.0, 2000.0, 0.3, 8.0, 0.002, 0.1)
		"slime_split":
			b = buf(0.4)
			tone(b, R, 0.0, 0.18, 180.0, 420.0, 1.0, 10.0, 0.004, [[2.0, 0.5]], 26.0, 0.12)
			tone(b, R, 0.1, 0.2, 500.0, 200.0, 0.8, 12.0, 0.004, [[2.0, 0.4]], 30.0, 0.15)
			noise(b, R, 0.0, 0.15, 0.4, 16.0, 0.3)
		"death_healer":
			b = buf(0.7)
			tone(b, R, 0.0, 0.5, 988.0, 740.0, 0.8, 5.0, 0.004, [[2.0, 0.3]], 7.0, 0.03)
			tone(b, R, 0.12, 0.5, 740.0, 523.0, 0.7, 5.0, 0.004, [[2.0, 0.3]], 7.0, 0.03)
			noise(b, R, 0.0, 0.1, 0.3, 30.0, 0.3)
		"death_shield":
			b = buf(0.7)
			noise(b, R, 0.0, 0.04, 1.0, 70.0, 1.0)
			for mf in [520.0, 780.0, 1310.0, 2150.0]:
				tone(b, R, 0.0, 0.5, mf, mf * 0.98, 0.5, 9.0, 0.001)
			tone(b, R, 0.0, 0.3, 110.0, 55.0, 0.9, 12.0)
			noise(b, R, 0.05, 0.3, 0.3, 14.0, 0.3)
		"death_slime":
			b = buf(0.4)
			tone(b, R, 0.0, 0.25, 320.0, 90.0, 1.0, 10.0, 0.003, [[2.0, 0.4]], 20.0, 0.1)
			noise(b, R, 0.0, 0.2, 0.5, 14.0, 0.25)
			tone(b, R, 0.02, 0.1, 900.0, 300.0, 0.4, 30.0)
		"death_slimeling":
			b = buf(0.28)
			tone(b, R, 0.0, 0.16, 640.0, 200.0, 1.0, 14.0, 0.002, [[2.0, 0.3]], 22.0, 0.1)
			noise(b, R, 0.0, 0.1, 0.4, 20.0, 0.3)
		"meteor_fall":
			b = buf(1.0)
			tone(b, R, 0.0, 0.95, 2400.0, 320.0, 0.55, 0.0, 0.7, [[2.0, 0.3]], 5.0, 0.02)
			band_noise(b, R, 0.0, 0.95, 0.7, 500.0, 2600.0, 0.18, 0.0, 0.8, 0.04)
			noise(b, R, 0.0, 0.95, 0.35, 2.0, 0.08)
		"meteor_hit":
			b = buf(2.0)
			noise(b, R, 0.0, 1.8, 1.0, 2.6, 0.14)
			tone(b, R, 0.0, 1.5, 70.0, 24.0, 1.0, 2.6, 0.002, [[2.0, 0.4]])
			noise(b, R, 0.0, 0.06, 1.0, 50.0, 1.0)
			tone(b, R, 0.0, 0.3, 160.0, 50.0, 0.9, 8.0)
			for i in range(16):
				noise(b, R, rng().randf_range(0.05, 1.0), 0.015, 0.5, 120.0, 1.0, true)
		"blizzard":
			b = buf(1.8)
			band_noise(b, R, 0.0, 1.6, 0.6, 600.0, 5000.0, 0.18, 1.2, 0.3, 0.4)
			for i in range(4):
				var bf: float = [2093.0, 2637.0, 3136.0, 3951.0][i]
				tone(b, R, 0.2 + float(i) * 0.1, 0.9, bf, bf, 0.3, 3.5, 0.02, [], 8.0, 0.04)
			tone(b, R, 0.0, 1.2, 180.0, 340.0, 0.25, 2.0, 0.2)
		"gold_rush":
			b = buf(1.4)
			for i in range(12):
				var gf: float = [1318.5, 1568.0, 1760.0, 2093.0][i % 4]
				tone(b, R, float(i) * 0.07, 0.25, gf, gf, 0.6, 12.0, 0.002, [[2.0, 0.3]])
			for cf in [523.25, 659.25, 783.99]:
				tone(b, R, 0.0, 1.0, cf, cf, 0.25, 2.5, 0.05, [[2.0, 0.2]])
			band_noise(b, R, 0.0, 0.9, 0.12, 5000.0, 9000.0, 0.2, 2.5, 0.05, 0.3)
		"ability_ready":
			b = buf(0.4)
			tone(b, R, 0.0, 0.25, 880.0, 880.0, 0.7, 12.0, 0.003, [[2.0, 0.25]])
			tone(b, R, 0.1, 0.3, 1318.5, 1318.5, 0.7, 10.0, 0.003, [[2.0, 0.25]])
		"death_boss":
			b = buf(2.2)
			tone(b, R, 0.0, 1.8, 70.0, 32.0, 1.0, 1.6, 0.003, [[2.0, 0.4]])
			noise(b, R, 0.0, 1.8, 1.0, 2.0, 0.1)
			for i in range(14):
				noise(b, R, rng().randf_range(0.1, 1.5), 0.04, 0.6, 50.0, 0.4)
			tone(b, R, 1.2, 0.5, 60.0, 30.0, 1.0, 8.0)
		"coin":
			b = buf(0.3)
			tone(b, R, 0.0, 0.2, 1318.5, 1318.5, 1.0, 18.0, 0.002, [[2.0, 0.3]])
			tone(b, R, 0.06, 0.25, 1760.0, 1760.0, 0.9, 14.0, 0.002, [[2.0, 0.3]])
		"base_hit":
			b = buf(1.0)
			for t0 in [0.0, 0.4]:
				tone(b, R, t0, 0.35, 150.0, 130.0, 1.0, 4.0, 0.01, [[2.0, 0.7], [3.0, 0.5], [4.0, 0.3]], 6.0, 0.02)
				tone(b, R, t0, 0.3, 70.0, 50.0, 1.0, 7.0)
				noise(b, R, t0, 0.1, 0.5, 30.0, 0.2)
		"wave_horn":
			b = buf(1.6)
			tone(b, R, 0.0, 0.55, 293.7, 293.7, 1.0, 1.5, 0.06, [[2.0, 0.8], [3.0, 0.6], [4.0, 0.4], [5.0, 0.25]], 5.5, 0.004)
			tone(b, R, 0.5, 0.95, 440.0, 440.0, 1.0, 1.4, 0.05, [[2.0, 0.8], [3.0, 0.6], [4.0, 0.4], [5.0, 0.25]], 5.5, 0.004)
			tone(b, R, 0.5, 0.95, 220.0, 220.0, 0.5, 1.4, 0.05, [[2.0, 0.6], [3.0, 0.4]])
		"wave_clear":
			b = buf(1.4)
			var chime: Array = [587.3, 740.0, 880.0, 1174.7]
			for i in range(chime.size()):
				tone(b, R, float(i) * 0.12, 0.9, chime[i], chime[i], 0.8, 3.5, 0.003, [[2.0, 0.3], [3.0, 0.15]])
			band_noise(b, R, 0.1, 0.6, 0.15, 4000.0, 8000.0, 0.2, 4.0, 0.02, 0.2)
		"victory":
			b = buf(3.6)
			var mel: Array = [[0.0, 293.7, 0.25], [0.25, 370.0, 0.25], [0.5, 440.0, 0.25], [0.75, 587.3, 0.5],
				[1.4, 440.0, 0.25], [1.65, 587.3, 0.25], [1.9, 740.0, 0.25], [2.15, 880.0, 1.2]]
			for m in mel:
				tone(b, R, float(m[0]), float(m[2]) + 0.5, float(m[1]), float(m[1]), 0.8, 2.5, 0.02, [[2.0, 0.7], [3.0, 0.5], [4.0, 0.3]], 5.5, 0.004)
			for f in [587.3, 740.0, 880.0]:
				tone(b, R, 2.15, 1.4, f * 0.5, f * 0.5, 0.35, 1.6, 0.05, [[2.0, 0.4]])
			band_noise(b, R, 2.15, 1.2, 0.15, 4000.0, 8000.0, 0.2, 2.0, 0.05, 0.3)
		"defeat":
			b = buf(2.6)
			var seq: Array = [[0.0, 293.7], [0.5, 261.6], [1.0, 233.1], [1.5, 220.0]]
			for m in seq:
				tone(b, R, float(m[0]), 0.9, float(m[1]), float(m[1]) * 0.99, 0.8, 2.4, 0.03, [[2.0, 0.6], [3.0, 0.4], [4.0, 0.2]], 5.0, 0.006)
			tone(b, R, 1.5, 1.0, 55.0, 40.0, 1.0, 2.5, 0.02, [[2.0, 0.3]])
		"stomp":
			b = buf(0.35)
			tone(b, R, 0.0, 0.25, 80.0, 36.0, 1.0, 14.0)
			noise(b, R, 0.0, 0.08, 0.8, 40.0, 0.15)
		"spawn":
			b = buf(0.7)
			band_noise(b, R, 0.0, 0.6, 0.8, 250.0, 1400.0, 0.12, 0.0, 0.15, 0.25)
			tone(b, R, 0.0, 0.6, 90.0, 140.0, 0.4, 1.0, 0.2)
		"bird_1":
			b = buf(0.45)
			for i in range(3):
				tone(b, R, float(i) * 0.11, 0.07, 2600.0, 3700.0, 0.8, 20.0, 0.004, [[2.0, 0.15]])
		"bird_2":
			b = buf(0.5)
			tone(b, R, 0.0, 0.35, 3300.0, 2100.0, 0.8, 6.0, 0.02, [[2.0, 0.2]], 22.0, 0.04)
		"bird_3":
			b = buf(0.5)
			for i in range(8):
				tone(b, R, float(i) * 0.04, 0.03, 3000.0 + float(i % 2) * 500.0, 3200.0, 0.8, 30.0, 0.002)
		_:
			b = buf(0.1)
	normalize(b, 0.9)
	return to_wav(b, R)


# ------------------------------------------------------------------ smyčky prostředí
## Plynulá smyčka: nahraje se L + X sekund a konec se prolne se začátkem.
static func _make_loop(raw: PackedFloat32Array, length: int, xfade: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(length)
	for i in range(length):
		out[i] = raw[i]
	for i in range(xfade):
		var w: float = float(i) / float(xfade)
		out[i] = raw[i] * w + raw[length + i] * (1.0 - w)
	return out


const AMBIENT_REPEATS: int = 3


static func make_ambient(kind: String, theme: String = "sky_island") -> AudioStreamWAV:
	if theme == "scifi":
		return SynthSciFi.ambient(kind)
	var R: int = MRATE
	rng().seed = hash(kind)
	var len_s: float = 8.0
	var x_s: float = 0.8
	var raw: PackedFloat32Array = buf(len_s + x_s, R)
	if kind == "wind":
		# vítr: pásmový šum s pomalu kolísající středovou frekvencí
		var low: float = 0.0
		var band: float = 0.0
		var r: RandomNumberGenerator = rng()
		for i in range(raw.size()):
			var t: float = float(i) / float(R)
			var fc: float = 260.0 + 140.0 * sin(TAU * t / 3.1) + 90.0 * sin(TAU * t / 1.7 + 1.0)
			var f: float = 2.0 * sin(PI * fc / float(R))
			var x: float = r.randf() * 2.0 - 1.0
			low += f * band
			var high: float = x - low - 0.35 * band
			band += f * high
			var amp: float = 0.55 + 0.45 * sin(TAU * t / 2.3) * sin(TAU * t / 5.1 + 0.5)
			raw[i] = band * amp
	else:
		# voda: širší šum + nízké hučení
		var low2: float = 0.0
		var band2: float = 0.0
		var lp: float = 0.0
		var r2: RandomNumberGenerator = rng()
		for i in range(raw.size()):
			var t2: float = float(i) / float(R)
			var fc2: float = 900.0 + 250.0 * sin(TAU * t2 / 0.9) + 150.0 * sin(TAU * t2 / 0.37)
			var f2: float = 2.0 * sin(PI * fc2 / float(R))
			var x2: float = r2.randf() * 2.0 - 1.0
			low2 += f2 * band2
			var high2: float = x2 - low2 - 0.5 * band2
			band2 += f2 * high2
			lp += 0.04 * (x2 - lp)
			raw[i] = band2 * 0.8 + lp * 1.5
	var loop: PackedFloat32Array = _make_loop(raw, int(len_s * float(R)), int(x_s * float(R)))
	var m: float = 0.0001
	for v in loop:
		m = maxf(m, absf(v))
	for i in range(loop.size()):
		loop[i] = loop[i] / m * 0.8
	# na webu Godot smyčku po dohrání spouští znovu (krátká mezera), proto ji nahrajeme třikrát za sebou = méně restartů
	var tiled: PackedFloat32Array = PackedFloat32Array()
	for rep_i in range(AMBIENT_REPEATS):
		tiled.append_array(loop)
	return to_wav(tiled, R, true)


# ------------------------------------------------------------------ hudba
static func midi_freq(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


const MINOR: Array = [0, 2, 3, 5, 7, 8, 10]       # d moll (přirozená): d e f g a b♭ c


static func _scale_midi(deg: int) -> float:
	var oct: int = int(floor(float(deg) / 7.0))
	var step: int = ((deg % 7) + 7) % 7
	return 62.0 + 12.0 * float(oct) + float(MINOR[step])


## Událost: [nástroj, začátek (v dobách), délka (v dobách), midi, hlasitost].
## Vrací {bpm, beats, events}.
static func music_track(kind: String, theme: String = "sky_island") -> Dictionary:
	if theme == "scifi":
		return SynthSciFi.music_track(kind)
	var battle: bool = kind == "battle"
	var bpm: float = 124.0 if battle else 88.0
	var bars: int = 16
	var events: Array = []
	# akordy po taktech: kořen (midi) a typ (3 = moll, 4 = dur); druhá polovina je variace (delší smyčka = méně opakování)
	var chords: Array = [[50, 3], [46, 4], [53, 4], [48, 4], [50, 3], [43, 3], [46, 4], [45, 4],
		[43, 3], [50, 3], [46, 4], [53, 4], [43, 3], [46, 4], [48, 4], [45, 4]]
	if battle:
		chords = [[50, 3], [46, 4], [48, 4], [50, 3], [50, 3], [46, 4], [48, 4], [45, 4],
			[50, 3], [43, 3], [46, 4], [48, 4], [50, 3], [43, 3], [45, 4], [45, 4]]
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 77 if battle else 31
	var prev_deg: int = 9
	for bar in range(bars):
		var root: int = int(chords[bar][0])
		var third: int = root + int(chords[bar][1])
		var fifth: int = root + 7
		var b0: float = float(bar) * 4.0
		# pad (struny)
		for m in [root + 12, third + 12, fifth + 12]:
			events.append(["pad", b0, 4.0, float(m), 0.8 if not battle else 0.6])
		# basa
		if battle:
			for i in range(8):
				events.append(["bass", b0 + float(i) * 0.5, 0.5, float(root - 12 + (12 if i % 4 == 3 else 0)), 0.9])
		else:
			events.append(["bass", b0, 2.0, float(root - 12), 0.9])
			events.append(["bass", b0 + 2.0, 2.0, float(root - 12 if bar % 2 == 0 else fifth - 12), 0.7])
		# arpeggio (brnknutí)
		var tones: Array = [root + 12, third + 12, fifth + 12, root + 24, fifth + 12, third + 12, root + 12, third + 12]
		if battle:
			for i in range(16):
				var ti: int = [0, 1, 2, 3, 2, 1, 0, 1, 0, 1, 2, 3, 4, 3, 2, 1][i] % 4
				var mm: int = [root + 24, third + 24, fifth + 24, root + 36][ti]
				events.append(["pluck", b0 + float(i) * 0.25, 0.5, float(mm), 0.35 if i % 4 != 0 else 0.5])
		else:
			for i in range(8):
				events.append(["pluck", b0 + float(i) * 0.5, 0.9, float(tones[i]), 0.35 if i % 2 == 0 else 0.25])
		# bicí
		if battle:
			for i in range(4):
				events.append(["kick", b0 + float(i), 0.3, 0.0, 0.9])
			events.append(["snare", b0 + 1.0, 0.2, 0.0, 0.7])
			events.append(["snare", b0 + 3.0, 0.2, 0.0, 0.7])
			for i in range(8):
				events.append(["hat", b0 + float(i) * 0.5 + 0.25, 0.06, 0.0, 0.35])
			for i in range(4):
				events.append(["hat", b0 + float(i) + 0.5, 0.06, 0.0, 0.2])
		else:
			events.append(["kick", b0, 0.3, 0.0, 0.5])
			events.append(["kick", b0 + 2.5, 0.3, 0.0, 0.35])
			for i in range(8):
				events.append(["hat", b0 + float(i) * 0.5 + 0.25, 0.06, 0.0, 0.18])
		# melodie: noty z akordu a krokem po stupnici
		var rhythms: Array = [[1.5, 0.5, 2.0], [1.0, 1.0, 2.0], [0.5, 0.5, 1.0, 2.0], [2.0, 2.0], [1.0, 0.5, 0.5, 2.0]]
		if battle:
			rhythms = [[1.0, 0.5, 0.5, 1.0, 1.0], [0.5, 0.5, 0.5, 0.5, 2.0], [1.0, 1.0, 1.0, 1.0], [0.75, 0.75, 0.5, 1.0, 1.0]]
		var pat: Array = rhythms[r.randi() % rhythms.size()]
		var ctones: Array = _chord_degrees(root)
		var pos: float = b0
		for dur in pat:
			var deg: int = prev_deg
			if r.randf() < 0.55:
				var best: int = prev_deg
				var bd: int = 99
				for oc in [7, 14]:
					for ct in ctones:
						var cand: int = int(ct) + int(oc)
						if absi(cand - prev_deg) < bd and cand >= 7 and cand <= 16:
							bd = absi(cand - prev_deg)
							best = cand
				deg = best
			else:
				deg = clampi(prev_deg + r.randi_range(-2, 2), 7, 16)
			prev_deg = deg
			var inst: String = "bell"
			if battle:
				inst = "brass"
			events.append([inst, pos, float(dur) * 0.95, _scale_midi(deg), 0.55 if not battle else 0.5])
			pos += float(dur)
	return {"bpm": bpm, "beats": float(bars) * 4.0, "events": events}


## Stupně stupnice (0..6) tónů akordu s daným kořenem (midi) – pro melodii.
static func _chord_degrees(root_midi: int) -> Array:
	match root_midi:
		50:
			return [0, 2, 4]      # d f a
		46:
			return [5, 0, 2]      # b♭ d f
		53:
			return [2, 4, 6]      # f a c
		48:
			return [6, 1, 3]      # c e g
		43:
			return [3, 5, 0]      # g b♭ d
		45:
			return [4, 1, 6]      # a e c
	return [0, 2, 4]


## Vykreslí část noty (vzorky k0..k1) do bufferu (zápis se zalamuje přes konec = bezešvá smyčka).
## Vrací počet vzorků noty celkem (včetně dozvuku), ať volající ví, kdy skončit.
static func note_length(instr: String, dur: float, rate: int) -> int:
	if instr.begins_with("s_"):
		return SynthSciFi.note_length(instr, dur, rate)
	var tail: float = 0.0
	match instr:
		"pad":
			tail = 0.9
		"pluck":
			tail = 0.05
		"bass":
			tail = 0.1
		"bell":
			tail = 0.9
		"brass":
			tail = 0.15
		"kick":
			tail = 0.0
		"snare":
			tail = 0.0
		_:
			tail = 0.0
	var d: float = dur
	if instr == "pluck":
		d = minf(dur, 0.85)
	elif instr == "bell":
		d = minf(dur, 0.4)
	return int((d + tail) * float(rate))


static func render_note(b: PackedFloat32Array, rate: int, instr: String, t0: float, dur: float, freq: float,
		vel: float, k0: int, k1: int) -> void:
	if instr.begins_with("s_"):
		SynthSciFi.render_note(b, rate, instr, t0, dur, freq, vel, k0, k1)
		return
	var size: int = b.size()
	var i0: int = int(t0 * float(rate))
	var w: float = TAU * freq
	var r: RandomNumberGenerator = rng()
	var prev: float = 0.0
	var total: int = note_length(instr, dur, rate)
	var kend: int = mini(k1, total)
	for k in range(k0, kend):
		var t: float = float(k) / float(rate)
		var idx: int = (i0 + k) % size
		var v: float = 0.0
		match instr:
			"pad":
				var env: float = minf(t / 0.35, 1.0) * (1.0 if t < dur else exp(-(t - dur) * 4.0))
				var wt: float = w * t
				v = (sin(wt) + 0.6 * sin(wt * 1.004) + 0.2 * sin(wt * 2.0)) * env * 0.11
			"pluck":
				var envp: float = exp(-t * 6.0) * minf(t / 0.003, 1.0)
				var wtp: float = w * t
				v = (sin(wtp) + 0.4 * sin(wtp * 2.0) * exp(-t * 6.0)) * envp * 0.25
			"bass":
				var envb: float = minf(t / 0.01, 1.0) * exp(-t * 2.4)
				var wtb: float = w * t
				v = (sin(wtb) + 0.35 * sin(wtb * 2.0) + 0.1 * sin(wtb * 3.0)) * envb * 0.45
			"bell":
				var envl: float = exp(-t * 3.2) * minf(t / 0.004, 1.0)
				var wtl: float = w * t
				v = sin(wtl + 1.4 * sin(wtl * 2.01) * exp(-t * 4.0)) * envl * 0.22
			"brass":
				var envr: float = minf(t / 0.04, 1.0) * (1.0 if t < dur else exp(-(t - dur) * 14.0))
				var wtr: float = w * t
				v = (sin(wtr) + 0.6 * sin(wtr * 2.0) + 0.35 * sin(wtr * 3.0) + 0.2 * sin(wtr * 4.0)) * envr * 0.1
			"kick":
				var ph: float = 45.0 * t + (75.0 / 28.0) * (1.0 - exp(-28.0 * t))
				v = sin(TAU * ph) * exp(-t * 9.0) * 0.6
			"snare":
				var nz: float = r.randf() * 2.0 - 1.0
				v = (nz * exp(-t * 22.0) * 0.5 + sin(TAU * 190.0 * t) * exp(-t * 28.0) * 0.35)
			"hat":
				var nh: float = r.randf() * 2.0 - 1.0
				v = (nh - prev) * exp(-t * 70.0) * 0.12
				prev = nh
		b[idx] += v * vel


## Celou skladbu vykreslí synchronně (pro nástroje/testy; hra ji skládá po částech na pozadí).
static func render_music_sync(kind: String, theme: String = "sky_island") -> AudioStreamWAV:
	var tr: Dictionary = music_track(kind, theme)
	var bpm: float = float(tr["bpm"])
	var spb: float = 60.0 / bpm
	var total: int = int(float(tr["beats"]) * spb * float(MRATE))
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(total)
	rng().seed = hash(kind)
	for ev in tr["events"]:
		var t0: float = float(ev[1]) * spb
		var dur: float = float(ev[2]) * spb
		var instr: String = str(ev[0])
		var n: int = note_length(instr, dur, MRATE)
		render_note(b, MRATE, instr, t0, dur, midi_freq(float(ev[3])), float(ev[4]), 0, n)
	finish_music(b)
	return to_wav(b, MRATE, true)


static func finish_music(b: PackedFloat32Array) -> void:
	var m: float = 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var g: float = 0.8 / m
	for i in range(b.size()):
		b[i] = tanh(b[i] * g * 1.15)
