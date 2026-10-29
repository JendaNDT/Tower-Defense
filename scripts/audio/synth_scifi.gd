class_name SynthSciFi
extends RefCounted
## Zvukové ladění motivu „Vesmírná stanice“: digitální a elektrické efekty (lasery, plazma, výboje, servomotory, alarmy),
## hukot stanice a tok energie jako ambient a dvě synthové skladby (klidná a bojová, a moll). Vše se počítá v kódu.
## Používá stavební kameny ze Synth (tone, noise, band_noise); co zde chybí, bere Synth z výchozí sady.

const SQUARE: Array = [[3.0, 0.33], [5.0, 0.2], [7.0, 0.14]]
const SAW: Array = [[2.0, 0.5], [3.0, 0.33], [4.0, 0.25], [5.0, 0.2]]
const SOFT: Array = [[2.0, 0.3], [3.0, 0.1]]


# ------------------------------------------------------------------ efekty
## Vrací efekt, nebo null (pak se použije výchozí recept ze Synth).
static func sfx(sfx_name: String) -> AudioStreamWAV:
	var R: int = Synth.RATE
	Synth.rng().seed = hash("scifi_" + sfx_name)
	var b: PackedFloat32Array
	match sfx_name:
		"ui_click":
			b = Synth.buf(0.06)
			Synth.tone(b, R, 0.0, 0.06, 1900.0, 2500.0, 1.0, 50.0, 0.001, SQUARE)
		"ui_error":
			b = Synth.buf(0.32)
			for t0 in [0.0, 0.15]:
				Synth.tone(b, R, t0, 0.12, 130.0, 120.0, 1.0, 6.0, 0.003, SAW)
				Synth.tone(b, R, t0, 0.12, 138.0, 126.0, 0.8, 6.0, 0.003, SAW)
		"build":
			b = Synth.buf(0.6)
			Synth.band_noise(b, R, 0.0, 0.28, 0.7, 300.0, 2200.0, 0.2, 2.0, 0.02, 0.06)
			Synth.tone(b, R, 0.0, 0.3, 140.0, 300.0, 0.6, 5.0, 0.01, SAW)
			Synth.noise(b, R, 0.28, 0.05, 0.9, 50.0, 0.4)
			Synth.tone(b, R, 0.28, 0.25, 260.0, 80.0, 0.9, 12.0)
			Synth.tone(b, R, 0.36, 0.1, 1800.0, 1800.0, 0.35, 25.0, 0.002, SQUARE)
			Synth.tone(b, R, 0.44, 0.1, 2400.0, 2400.0, 0.35, 25.0, 0.002, SQUARE)
		"upgrade":
			b = Synth.buf(1.1)
			var notes: Array = [440.0, 659.25, 880.0, 1318.5]
			for i in range(notes.size()):
				Synth.tone(b, R, float(i) * 0.09, 0.5, notes[i], notes[i], 0.7, 6.0, 0.003, SAW)
				Synth.tone(b, R, float(i) * 0.09, 0.5, notes[i] * 1.004, notes[i] * 1.004, 0.5, 6.0, 0.003, SOFT)
			Synth.band_noise(b, R, 0.05, 0.6, 0.3, 700.0, 6500.0, 0.2, 4.0, 0.02, 0.25)
			Synth.tone(b, R, 0.4, 0.6, 2637.0, 2637.0, 0.25, 5.0, 0.01, SOFT)
		"sell":
			b = Synth.buf(0.4)
			Synth.tone(b, R, 0.0, 0.18, 1568.0, 1046.0, 1.0, 14.0, 0.002, SQUARE)
			Synth.tone(b, R, 0.08, 0.22, 1046.0, 700.0, 0.9, 12.0, 0.002, SQUARE)
			Synth.noise(b, R, 0.0, 0.012, 0.5, 100.0, 0.9, true)
		"archer_shot":
			# laserové „pew“
			b = Synth.buf(0.26)
			Synth.tone(b, R, 0.0, 0.2, 3200.0, 420.0, 0.9, 16.0, 0.001, SQUARE)
			Synth.tone(b, R, 0.0, 0.14, 1700.0, 260.0, 0.5, 20.0, 0.001, SOFT)
			Synth.noise(b, R, 0.0, 0.015, 0.6, 120.0, 0.9, true)
		"arrow_hit":
			b = Synth.buf(0.18)
			Synth.noise(b, R, 0.0, 0.05, 0.9, 70.0, 0.8, true)
			Synth.tone(b, R, 0.0, 0.1, 1100.0, 220.0, 0.8, 30.0, 0.001, SOFT)
		"cannon_shot":
			# plazmový výstřel: nabití, hluboké bum, doznívající hvizd
			b = Synth.buf(0.85)
			Synth.tone(b, R, 0.0, 0.6, 190.0, 55.0, 1.0, 6.0, 0.002, SQUARE)
			Synth.band_noise(b, R, 0.0, 0.5, 0.7, 1500.0, 250.0, 0.3, 6.0, 0.004, 0.1)
			Synth.tone(b, R, 0.02, 0.5, 1400.0, 300.0, 0.45, 7.0, 0.002, SOFT, 14.0, 0.03)
			Synth.noise(b, R, 0.0, 0.03, 1.0, 80.0, 1.0)
		"explosion":
			b = Synth.buf(1.2)
			Synth.noise(b, R, 0.0, 1.0, 1.0, 3.8, 0.16)
			Synth.tone(b, R, 0.0, 0.8, 110.0, 30.0, 1.0, 4.5)
			Synth.noise(b, R, 0.0, 0.05, 1.0, 60.0, 1.0)
			Synth.tone(b, R, 0.05, 0.7, 1800.0, 300.0, 0.4, 6.0, 0.002, SOFT, 30.0, 0.05)
			for i in range(9):
				Synth.noise(b, R, Synth.rng().randf_range(0.05, 0.55), 0.012, 0.5, 150.0, 1.0, true)
		"mage_cast":
			# Teslova cívka: nabíjení rostoucím tónem a praskání
			b = Synth.buf(0.5)
			Synth.tone(b, R, 0.0, 0.4, 260.0, 2300.0, 0.7, 5.0, 0.01, SAW, 18.0, 0.03)
			Synth.band_noise(b, R, 0.0, 0.4, 0.4, 1500.0, 6500.0, 0.2, 5.0, 0.02, 0.1)
			for i in range(6):
				Synth.noise(b, R, 0.1 + float(i) * 0.05, 0.01, 0.5, 200.0, 1.0, true)
		"magic_hit":
			b = Synth.buf(0.32)
			Synth.tone(b, R, 0.0, 0.22, 1600.0, 380.0, 1.0, 14.0, 0.002, SAW, 60.0, 0.06)
			Synth.band_noise(b, R, 0.0, 0.2, 0.7, 5500.0, 1500.0, 0.3, 14.0, 0.002, 0.05)
			Synth.noise(b, R, 0.0, 0.02, 0.8, 100.0, 1.0, true)
		"zap":
			b = Synth.buf(0.3)
			for i in range(14):
				var f: float = Synth.rng().randf_range(500.0, 3400.0)
				Synth.tone(b, R, float(i) * 0.018, 0.025, f, f * 0.7, 0.6, 50.0, 0.001, SQUARE)
			Synth.noise(b, R, 0.0, 0.28, 0.5, 9.0, 0.8, true)
		"frost_pulse":
			# syčení chladiva a krystalický tón
			b = Synth.buf(1.1)
			Synth.band_noise(b, R, 0.0, 0.8, 0.7, 6000.0, 1800.0, 0.2, 3.0, 0.02, 0.4)
			Synth.tone(b, R, 0.0, 0.9, 3136.0, 1568.0, 0.4, 3.5, 0.02, [], 9.0, 0.04)
			Synth.tone(b, R, 0.04, 0.8, 2349.0, 1175.0, 0.3, 3.5, 0.02, [], 9.0, 0.04)
			Synth.tone(b, R, 0.0, 0.4, 140.0, 70.0, 0.5, 8.0, 0.01)
		"freeze_hit":
			b = Synth.buf(0.35)
			Synth.noise(b, R, 0.0, 0.03, 0.9, 80.0, 0.9, true)
			Synth.tone(b, R, 0.0, 0.3, 3500.0, 2500.0, 0.8, 14.0, 0.002, [[1.5, 0.6]])
			Synth.tone(b, R, 0.0, 0.25, 4200.0, 4200.0, 0.4, 20.0)
		"death_goblin":
			b = Synth.buf(0.45)
			Synth.tone(b, R, 0.0, 0.32, 700.0, 110.0, 1.0, 8.0, 0.002, SQUARE, 40.0, 0.07)
			Synth.noise(b, R, 0.02, 0.18, 0.5, 14.0, 0.6, true)
			Synth.noise(b, R, 0.0, 0.01, 0.8, 100.0, 1.0, true)
		"death_wolf":
			b = Synth.buf(0.5)
			Synth.tone(b, R, 0.0, 0.4, 1400.0, 180.0, 0.9, 6.0, 0.003, SAW, 30.0, 0.05)
			Synth.noise(b, R, 0.1, 0.2, 0.4, 10.0, 0.5)
			for i in range(4):
				Synth.noise(b, R, 0.12 + float(i) * 0.06, 0.012, 0.5, 120.0, 0.9, true)
		"death_golem":
			b = Synth.buf(0.9)
			Synth.noise(b, R, 0.0, 0.7, 1.0, 5.5, 0.22)
			Synth.tone(b, R, 0.0, 0.5, 100.0, 40.0, 0.9, 7.0)
			for mf in [520.0, 780.0, 1310.0]:
				Synth.tone(b, R, 0.02, 0.5, mf, mf * 0.98, 0.35, 9.0, 0.001)
			for i in range(6):
				Synth.noise(b, R, Synth.rng().randf_range(0.05, 0.5), 0.02, 0.5, 60.0, 0.5)
		"death_drake":
			b = Synth.buf(0.8)
			Synth.tone(b, R, 0.0, 0.55, 2400.0, 150.0, 0.8, 3.5, 0.003, SQUARE, 25.0, 0.05)
			Synth.noise(b, R, 0.5, 0.25, 0.9, 14.0, 0.3)
			Synth.tone(b, R, 0.5, 0.2, 90.0, 40.0, 0.9, 12.0)
		"death_boss":
			b = Synth.buf(2.4)
			Synth.tone(b, R, 0.0, 1.8, 90.0, 28.0, 1.0, 1.6, 0.003, SAW)
			Synth.noise(b, R, 0.0, 1.8, 1.0, 2.0, 0.1)
			Synth.tone(b, R, 0.0, 1.4, 1500.0, 90.0, 0.4, 1.8, 0.01, SQUARE, 8.0, 0.1)
			for i in range(16):
				Synth.noise(b, R, Synth.rng().randf_range(0.1, 1.6), 0.04, 0.6, 50.0, 0.4)
			Synth.tone(b, R, 1.2, 0.6, 70.0, 28.0, 1.0, 8.0)
		"death_healer":
			b = Synth.buf(0.7)
			Synth.tone(b, R, 0.0, 0.45, 1318.0, 440.0, 0.8, 5.0, 0.004, SOFT, 7.0, 0.04)
			Synth.tone(b, R, 0.1, 0.45, 988.0, 330.0, 0.6, 5.0, 0.004, SOFT, 7.0, 0.04)
			Synth.noise(b, R, 0.0, 0.1, 0.4, 30.0, 0.5, true)
		"death_shield":
			b = Synth.buf(0.7)
			Synth.noise(b, R, 0.0, 0.04, 1.0, 70.0, 1.0)
			for mf in [900.0, 1500.0, 2300.0, 3300.0]:
				Synth.tone(b, R, 0.0, 0.5, mf, mf * 0.97, 0.4, 9.0, 0.001)
			Synth.tone(b, R, 0.0, 0.3, 120.0, 50.0, 0.9, 12.0)
			Synth.band_noise(b, R, 0.05, 0.4, 0.4, 5000.0, 1500.0, 0.3, 8.0, 0.002, 0.1)
		"death_slime":
			b = Synth.buf(0.45)
			Synth.tone(b, R, 0.0, 0.3, 500.0, 90.0, 0.9, 9.0, 0.002, SQUARE, 30.0, 0.15)
			Synth.band_noise(b, R, 0.0, 0.25, 0.5, 4000.0, 700.0, 0.3, 10.0, 0.002, 0.05)
		"death_slimeling":
			b = Synth.buf(0.3)
			Synth.tone(b, R, 0.0, 0.18, 900.0, 200.0, 0.9, 14.0, 0.002, SQUARE, 40.0, 0.12)
			Synth.noise(b, R, 0.0, 0.08, 0.4, 25.0, 0.6, true)
		"slime_split":
			b = Synth.buf(0.4)
			Synth.tone(b, R, 0.0, 0.16, 300.0, 1100.0, 0.9, 10.0, 0.003, SOFT, 26.0, 0.1)
			Synth.tone(b, R, 0.1, 0.2, 1300.0, 350.0, 0.8, 12.0, 0.003, SOFT, 30.0, 0.12)
		"heal":
			b = Synth.buf(0.8)
			for i in range(4):
				var hf: float = [1046.5, 1318.5, 1568.0, 2093.0][i]
				Synth.tone(b, R, float(i) * 0.06, 0.3, hf, hf, 0.55, 8.0, 0.004, SQUARE)
			Synth.band_noise(b, R, 0.0, 0.5, 0.1, 5000.0, 9000.0, 0.2, 6.0, 0.05, 0.2)
		"shield_break":
			b = Synth.buf(0.5)
			Synth.noise(b, R, 0.0, 0.03, 1.0, 80.0, 1.0, true)
			for i in range(7):
				var sf: float = Synth.rng().randf_range(2500.0, 5000.0)
				Synth.tone(b, R, Synth.rng().randf_range(0.0, 0.12), 0.16, sf, sf * 0.4, 0.5, 20.0, 0.001, SQUARE)
			Synth.tone(b, R, 0.0, 0.35, 1800.0, 200.0, 0.5, 9.0)
			Synth.band_noise(b, R, 0.0, 0.4, 0.45, 7000.0, 1500.0, 0.3, 8.0, 0.002, 0.1)
		"coin":
			b = Synth.buf(0.3)
			Synth.tone(b, R, 0.0, 0.1, 1760.0, 1760.0, 1.0, 20.0, 0.001, SQUARE)
			Synth.tone(b, R, 0.06, 0.2, 2349.0, 2349.0, 0.9, 14.0, 0.001, SQUARE)
		"base_hit":
			# poplach reaktoru: dvoutónová siréna a hluboký úder
			b = Synth.buf(1.0)
			for t0 in [0.0, 0.4]:
				Synth.tone(b, R, t0, 0.18, 480.0, 480.0, 1.0, 3.0, 0.005, SAW)
				Synth.tone(b, R, t0 + 0.18, 0.18, 640.0, 640.0, 1.0, 3.0, 0.005, SAW)
				Synth.tone(b, R, t0, 0.3, 80.0, 45.0, 1.0, 7.0)
				Synth.noise(b, R, t0, 0.1, 0.5, 30.0, 0.2)
		"wave_horn":
			# poplachová siréna nové vlny
			b = Synth.buf(1.6)
			Synth.tone(b, R, 0.0, 0.7, 260.0, 520.0, 1.0, 1.2, 0.05, SAW, 5.0, 0.01)
			Synth.tone(b, R, 0.7, 0.8, 520.0, 260.0, 1.0, 1.3, 0.02, SAW, 5.0, 0.01)
			Synth.tone(b, R, 0.0, 1.5, 65.0, 65.0, 0.6, 1.0, 0.1, SQUARE)
		"wave_clear":
			b = Synth.buf(1.4)
			var chime: Array = [587.3, 740.0, 880.0, 1174.7]
			for i in range(chime.size()):
				Synth.tone(b, R, float(i) * 0.11, 0.8, chime[i], chime[i], 0.7, 4.0, 0.003, SAW)
				Synth.tone(b, R, float(i) * 0.11, 0.8, chime[i] * 2.0, chime[i] * 2.0, 0.25, 4.5, 0.003)
			Synth.band_noise(b, R, 0.1, 0.6, 0.12, 4000.0, 8000.0, 0.2, 4.0, 0.02, 0.2)
		"victory":
			b = Synth.buf(3.6)
			var mel: Array = [[0.0, 440.0, 0.22], [0.22, 554.4, 0.22], [0.44, 659.3, 0.22], [0.66, 880.0, 0.45],
				[1.3, 659.3, 0.22], [1.52, 880.0, 0.22], [1.74, 1108.7, 0.22], [1.96, 1318.5, 1.2]]
			for m in mel:
				Synth.tone(b, R, float(m[0]), float(m[2]) + 0.5, float(m[1]), float(m[1]), 0.7, 2.6, 0.01, SAW, 5.5, 0.004)
			for f in [440.0, 554.4, 659.3]:
				Synth.tone(b, R, 1.96, 1.4, f * 0.5, f * 0.5, 0.3, 1.6, 0.05, SOFT)
			Synth.band_noise(b, R, 1.96, 1.2, 0.12, 4000.0, 8000.0, 0.2, 2.0, 0.05, 0.3)
		"defeat":
			b = Synth.buf(2.8)
			Synth.tone(b, R, 0.0, 2.3, 440.0, 38.0, 0.9, 1.2, 0.01, SAW)
			Synth.tone(b, R, 0.0, 2.3, 330.0, 30.0, 0.7, 1.2, 0.01, SQUARE)
			Synth.noise(b, R, 0.0, 1.6, 0.4, 1.8, 0.06)
			for i in range(5):
				Synth.noise(b, R, 0.2 + float(i) * 0.35, 0.015, 0.5, 80.0, 0.9, true)
		"stomp":
			b = Synth.buf(0.35)
			Synth.tone(b, R, 0.0, 0.25, 95.0, 36.0, 1.0, 13.0)
			Synth.noise(b, R, 0.0, 0.03, 0.7, 70.0, 0.4)
			Synth.tone(b, R, 0.0, 0.08, 800.0, 400.0, 0.3, 40.0, 0.001, SOFT)
		"spawn":
			# warp: stoupající šum a tón
			b = Synth.buf(0.75)
			Synth.band_noise(b, R, 0.0, 0.65, 0.8, 200.0, 2800.0, 0.12, 0.0, 0.2, 0.25)
			Synth.tone(b, R, 0.0, 0.65, 80.0, 360.0, 0.5, 1.0, 0.2, SAW)
			Synth.tone(b, R, 0.3, 0.4, 1200.0, 2400.0, 0.2, 5.0, 0.05, SOFT)
		"bird_1":
			b = Synth.buf(0.45)
			for i in range(3):
				Synth.tone(b, R, float(i) * 0.1, 0.05, 1900.0 + 400.0 * float(i % 2), 2200.0, 0.8, 24.0, 0.002, SQUARE)
		"bird_2":
			b = Synth.buf(0.45)
			Synth.tone(b, R, 0.0, 0.3, 2400.0, 1500.0, 0.7, 6.0, 0.01, SOFT, 18.0, 0.03)
			Synth.tone(b, R, 0.15, 0.2, 1500.0, 2000.0, 0.5, 9.0, 0.01, SOFT)
		"bird_3":
			b = Synth.buf(0.5)
			for i in range(7):
				Synth.tone(b, R, float(i) * 0.05, 0.03, 2600.0 + float(i % 3) * 500.0, 2800.0, 0.8, 30.0, 0.002, SQUARE)
		"meteor_fall":
			# orbitální úder: padající hvizd
			b = Synth.buf(1.0)
			Synth.tone(b, R, 0.0, 0.95, 3200.0, 280.0, 0.5, 0.0, 0.5, SAW, 6.0, 0.02)
			Synth.band_noise(b, R, 0.0, 0.95, 0.7, 600.0, 3000.0, 0.18, 0.0, 0.8, 0.04)
		"meteor_hit":
			b = Synth.buf(2.0)
			Synth.noise(b, R, 0.0, 1.8, 1.0, 2.6, 0.14)
			Synth.tone(b, R, 0.0, 1.5, 75.0, 24.0, 1.0, 2.6, 0.002, SAW)
			Synth.noise(b, R, 0.0, 0.06, 1.0, 50.0, 1.0)
			Synth.tone(b, R, 0.0, 0.5, 2000.0, 200.0, 0.4, 5.0, 0.002, SQUARE, 30.0, 0.05)
			for i in range(18):
				Synth.noise(b, R, Synth.rng().randf_range(0.05, 1.0), 0.015, 0.5, 120.0, 1.0, true)
		"blizzard":
			b = Synth.buf(1.8)
			Synth.band_noise(b, R, 0.0, 1.6, 0.6, 5500.0, 900.0, 0.18, 1.2, 0.3, 0.4)
			for i in range(4):
				var bf: float = [2349.0, 3136.0, 3951.0, 4699.0][i]
				Synth.tone(b, R, 0.15 + float(i) * 0.1, 0.9, bf, bf * 0.5, 0.25, 3.5, 0.02, [], 8.0, 0.04)
			Synth.tone(b, R, 0.0, 1.2, 300.0, 120.0, 0.3, 2.0, 0.2, SQUARE)
		"gold_rush":
			b = Synth.buf(1.4)
			for i in range(14):
				var gf: float = [1318.5, 1760.0, 2093.0, 2637.0][i % 4]
				Synth.tone(b, R, float(i) * 0.065, 0.2, gf, gf, 0.55, 14.0, 0.001, SQUARE)
			for cf in [440.0, 659.25, 880.0]:
				Synth.tone(b, R, 0.0, 1.0, cf, cf, 0.22, 2.5, 0.05, SAW)
		"ability_ready":
			b = Synth.buf(0.4)
			Synth.tone(b, R, 0.0, 0.2, 1175.0, 1175.0, 0.7, 14.0, 0.002, SQUARE)
			Synth.tone(b, R, 0.1, 0.25, 1760.0, 1760.0, 0.7, 12.0, 0.002, SQUARE)
		_:
			return null
	Synth.normalize(b, 0.9)
	return Synth.to_wav(b, R)


# ------------------------------------------------------------------ ambient
static func ambient(kind: String) -> AudioStreamWAV:
	var R: int = Synth.MRATE
	Synth.rng().seed = hash("scifi_amb_" + kind)
	var len_s: float = 8.0
	var x_s: float = 0.8
	var raw: PackedFloat32Array = Synth.buf(len_s + x_s, R)
	if kind == "wind":
		# hukot stanice: nízké tóny kvinty s pomalým kolísáním a tlumený šum ventilace
		var r: RandomNumberGenerator = Synth.rng()
		var low: float = 0.0
		var band: float = 0.0
		for i in range(raw.size()):
			var t: float = float(i) / float(R)
			var hum: float = sin(TAU * 55.0 * t) * 0.8 + sin(TAU * 82.4 * t) * (0.4 + 0.2 * sin(TAU * t / 3.7)) \
				+ sin(TAU * 110.3 * t) * (0.3 + 0.2 * sin(TAU * t / 2.3 + 1.0)) + sin(TAU * 165.0 * t) * 0.12 * (0.5 + 0.5 * sin(TAU * t / 5.9))
			var fc: float = 140.0 + 60.0 * sin(TAU * t / 4.1)
			var f: float = 2.0 * sin(PI * fc / float(R))
			var x: float = r.randf() * 2.0 - 1.0
			low += f * band
			var high: float = x - low - 0.5 * band
			band += f * high
			raw[i] = hum * 0.5 + band * 0.7
	else:
		# tok energie: pásmový šum s rychlým chvěním a vysoké zvonivé tóny
		var r2: RandomNumberGenerator = Synth.rng()
		var low2: float = 0.0
		var band2: float = 0.0
		for i in range(raw.size()):
			var t2: float = float(i) / float(R)
			var fc2: float = 1300.0 + 450.0 * sin(TAU * t2 / 1.3) + 250.0 * sin(TAU * t2 / 0.41)
			var f2: float = 2.0 * sin(PI * fc2 / float(R))
			var x2: float = r2.randf() * 2.0 - 1.0
			low2 += f2 * band2
			var high2: float = x2 - low2 - 0.4 * band2
			band2 += f2 * high2
			var flutter: float = 0.7 + 0.3 * sin(TAU * 9.0 * t2) * sin(TAU * t2 / 2.9)
			var shimmer: float = sin(TAU * 2640.0 * t2 + 3.0 * sin(TAU * 0.7 * t2)) * 0.05 * (0.5 + 0.5 * sin(TAU * t2 / 3.3))
			raw[i] = band2 * 0.9 * flutter + sin(TAU * 220.0 * t2) * 0.12 + shimmer
	var loop: PackedFloat32Array = Synth._make_loop(raw, int(len_s * float(R)), int(x_s * float(R)))
	var m: float = 0.0001
	for v in loop:
		m = maxf(m, absf(v))
	for i in range(loop.size()):
		loop[i] = loop[i] / m * 0.8
	var tiled: PackedFloat32Array = PackedFloat32Array()
	for rep_i in range(Synth.AMBIENT_REPEATS):
		tiled.append_array(loop)
	return Synth.to_wav(tiled, R, true)


# ------------------------------------------------------------------ hudba (a moll)
## Akordy po taktech: [kořen (midi), typ (3 = moll, 4 = dur)].
static func music_track(kind: String) -> Dictionary:
	var battle: bool = kind == "battle"
	var bpm: float = 132.0 if battle else 84.0
	var bars: int = 16
	var events: Array = []
	var chords: Array = [[45, 3], [41, 4], [48, 4], [43, 4], [45, 3], [41, 4], [50, 3], [40, 4],
		[45, 3], [41, 4], [48, 4], [43, 4], [41, 4], [43, 4], [45, 3], [45, 3]]
	if battle:
		chords = [[45, 3], [45, 3], [41, 4], [43, 4], [45, 3], [45, 3], [41, 4], [40, 4],
			[45, 3], [48, 4], [41, 4], [43, 4], [45, 3], [41, 4], [43, 4], [40, 4]]
	var pent: Array = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79]       # a moll pentatonika (midi)
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 91 if battle else 17
	var prev: int = 4
	for bar in range(bars):
		var root: int = int(chords[bar][0])
		var third: int = root + int(chords[bar][1])
		var fifth: int = root + 7
		var b0: float = float(bar) * 4.0
		# pad: tři tóny akordu
		for m in [root + 12, third + 12, fifth + 12]:
			events.append(["s_pad", b0, 4.0, float(m), 0.8 if not battle else 0.5])
		# basa
		if battle:
			for i in range(8):
				events.append(["s_bass", b0 + float(i) * 0.5, 0.45, float(root - 12 + (12 if i % 4 == 3 else 0)), 0.85])
		else:
			events.append(["s_bass", b0, 2.0, float(root - 12), 0.9])
			events.append(["s_bass", b0 + 2.5, 1.5, float(root - 12 if bar % 2 == 0 else fifth - 12), 0.6])
		# arpeggio
		var chord_tones: Array = [root + 24, third + 24, fifth + 24, root + 36]
		if battle:
			for i2 in range(16):
				var ti: int = [0, 1, 2, 3, 2, 1, 0, 1, 0, 1, 2, 3, 3, 2, 1, 2][i2]
				events.append(["s_arp", b0 + float(i2) * 0.25, 0.3, float(chord_tones[ti]), 0.30 if i2 % 4 != 0 else 0.42])
		else:
			for i3 in range(8):
				var ti2: int = [0, 1, 2, 1, 3, 2, 1, 2][i3]
				events.append(["s_arp", b0 + float(i3) * 0.5, 0.5, float(chord_tones[ti2]), 0.26 if i3 % 2 == 0 else 0.18])
		# bicí
		if battle:
			for i4 in range(4):
				events.append(["kick", b0 + float(i4), 0.3, 0.0, 0.95])
			events.append(["s_clap", b0 + 1.0, 0.2, 0.0, 0.8])
			events.append(["s_clap", b0 + 3.0, 0.2, 0.0, 0.8])
			for i5 in range(8):
				events.append(["hat", b0 + float(i5) * 0.5 + 0.25, 0.06, 0.0, 0.35])
		else:
			events.append(["kick", b0, 0.3, 0.0, 0.45])
			events.append(["kick", b0 + 2.0, 0.3, 0.0, 0.3])
			for i6 in range(8):
				events.append(["hat", b0 + float(i6) * 0.5 + 0.25, 0.06, 0.0, 0.14])
		# melodie: pomalu po pentatonice
		var rhythms: Array = [[2.0, 1.0, 1.0], [1.5, 0.5, 2.0], [1.0, 1.0, 2.0], [3.0, 1.0], [0.5, 0.5, 1.0, 2.0]]
		if battle:
			rhythms = [[1.0, 0.5, 0.5, 1.0, 1.0], [0.5, 0.5, 0.5, 0.5, 2.0], [1.0, 1.0, 1.0, 1.0], [0.75, 0.75, 0.5, 1.0, 1.0]]
		var pat: Array = rhythms[r.randi() % rhythms.size()]
		var pos: float = b0
		for dur in pat:
			var step: int = r.randi_range(-2, 2)
			if r.randf() < 0.3:
				step = 0
			prev = clampi(prev + step, 1, pent.size() - 1)
			if bar % 2 == 1 and pos == b0:
				prev = clampi(prev + 1, 1, pent.size() - 1)
			events.append(["s_lead", pos, float(dur) * 0.92, float(pent[prev]), 0.5 if not battle else 0.45])
			pos += float(dur)
	return {"bpm": bpm, "beats": float(bars) * 4.0, "events": events}


static func note_length(instr: String, dur: float, rate: int) -> int:
	var tail: float = 0.0
	var d: float = dur
	match instr:
		"s_pad":
			tail = 0.9
		"s_bass":
			tail = 0.12
		"s_arp":
			tail = 0.06
			d = minf(dur, 0.5)
		"s_lead":
			tail = 0.25
		"s_clap":
			tail = 0.0
			d = 0.18
	return int((d + tail) * float(rate))


## Vykreslí část noty (vzorky k0..k1) do bufferu (zápis se zalamuje přes konec = bezešvá smyčka).
static func render_note(b: PackedFloat32Array, rate: int, instr: String, t0: float, dur: float, freq: float,
		vel: float, k0: int, k1: int) -> void:
	var size: int = b.size()
	var i0: int = int(t0 * float(rate))
	var w: float = TAU * freq
	var r: RandomNumberGenerator = Synth.rng()
	var total: int = note_length(instr, dur, rate)
	var kend: int = mini(k1, total)
	for k in range(k0, kend):
		var t: float = float(k) / float(rate)
		var idx: int = (i0 + k) % size
		var v: float = 0.0
		match instr:
			"s_pad":
				# dva mírně rozladěné „pilové“ hlasy s pomalým náběhem
				var env: float = minf(t / 0.5, 1.0) * (1.0 if t < dur else exp(-(t - dur) * 3.5))
				var wt: float = w * t
				var wt2: float = w * 1.006 * t
				v = (sin(wt) + 0.5 * sin(wt * 2.0) + 0.25 * sin(wt * 3.0) + sin(wt2) + 0.5 * sin(wt2 * 2.0)) * env * 0.055
			"s_bass":
				var envb: float = minf(t / 0.008, 1.0) * exp(-t * 3.2)
				var wtb: float = w * t
				v = (sin(wtb) + 0.33 * sin(wtb * 3.0) + 0.2 * sin(wtb * 5.0) + 0.5 * sin(wtb * 0.5)) * envb * 0.42
			"s_arp":
				var enva: float = minf(t / 0.002, 1.0) * exp(-t * 11.0)
				var wta: float = w * t
				v = (sin(wta) + 0.5 * sin(wta * 2.0) + 0.25 * sin(wta * 3.0)) * enva * 0.26
			"s_lead":
				var envl: float = minf(t / 0.04, 1.0) * (1.0 if t < dur else exp(-(t - dur) * 10.0))
				var wtl: float = w * t + 0.6 * sin(TAU * 5.5 * t) * minf(t / 0.3, 1.0)
				v = (sin(wtl) + 0.5 * sin(wtl * 2.0) + 0.3 * sin(wtl * 3.0) + 0.2 * sin(wtl * 4.0)) * envl * 0.1
			"s_clap":
				var nz: float = r.randf() * 2.0 - 1.0
				var burst: float = exp(-t * 28.0) + 0.7 * exp(-maxf(t - 0.012, 0.0) * 28.0) * (1.0 if t > 0.012 else 0.0) + 0.5 * exp(-maxf(t - 0.026, 0.0) * 22.0) * (1.0 if t > 0.026 else 0.0)
				v = nz * burst * 0.42
		b[idx] += v * vel
