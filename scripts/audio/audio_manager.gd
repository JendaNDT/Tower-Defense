class_name AudioManager
extends Node
## Správce zvuku: efekty (3D pozice => stereo panorama podle polohy na ostrově), hudba (klidná / bojová s plynulým
## prolínáním), ambient (vítr, voda, ptáci). Vše se syntetizuje v kódu při startu (efekty hned, hudba na pozadí).
## Vlastní zvukové sběrnice se záměrně nevytvářejí: ve webovém exportu Godot (přehrávání „sample“) z nich udělá
## smyčku a Web Audio ji ztlumí. Hlasitost a vypínání se proto řeší přímo u přehrávačů.

const BUDGET_US: int = 7000
const SFX_BOOST_DB: float = 1.0     # všechny efekty o chlup hlasitěji, nejhlasitější se ale ořežou na SFX_CAP_DB (bez přebuzení)
const SFX_CAP_DB: float = -4.0
const CALM_DB: float = -10.0
const BATTLE_DB: float = -8.0
const WIND_DB: float = -24.0
const WATER_DB: float = -23.0

# základní hlasitosti efektů v dB (každý efekt je normalizovaný na stejnou špičku)
const BASE_DB: Dictionary = {
	"ui_click": -9.0, "ui_error": -8.0, "build": -4.0, "upgrade": -5.0, "sell": -6.0,
	"archer_shot": -11.0, "arrow_hit": -12.0, "cannon_shot": -3.0, "explosion": -2.0,
	"mage_cast": -9.0, "magic_hit": -10.0, "zap": -10.0, "frost_pulse": -8.0, "freeze_hit": -9.0,
	"death_goblin": -9.0, "death_wolf": -9.0, "death_golem": -6.0, "death_drake": -8.0, "death_boss": 0.0,
	"coin": -12.0, "base_hit": -2.0, "wave_horn": -4.0, "wave_clear": -5.0, "victory": -3.0, "defeat": -3.0,
	"stomp": -6.0, "spawn": -12.0, "bird_1": -16.0, "bird_2": -16.0, "bird_3": -16.0,
	"heal": -14.0, "shield_break": -9.0, "slime_split": -9.0, "death_healer": -9.0, "death_shield": -8.0,
	"death_slime": -9.0, "death_slimeling": -11.0, "meteor_fall": -6.0, "meteor_hit": -1.0, "blizzard": -6.0,
	"gold_rush": -9.0, "ability_ready": -12.0,
}
const MIN_GAP: Dictionary = {
	"archer_shot": 0.06, "arrow_hit": 0.05, "magic_hit": 0.05, "zap": 0.03, "coin": 0.06,
	"death_goblin": 0.05, "death_wolf": 0.05, "death_golem": 0.08, "death_drake": 0.06,
	"stomp": 0.18, "spawn": 0.25, "ui_click": 0.04, "freeze_hit": 0.05,
	"heal": 0.4, "shield_break": 0.15, "slime_split": 0.1, "death_slime": 0.06, "death_slimeling": 0.06,
	"death_healer": 0.08, "death_shield": 0.08,
}
const PITCH_VAR: Dictionary = {
	"archer_shot": 0.10, "arrow_hit": 0.12, "death_goblin": 0.10, "death_wolf": 0.10, "death_golem": 0.08,
	"death_drake": 0.10, "coin": 0.05, "explosion": 0.07, "cannon_shot": 0.06, "magic_hit": 0.08,
	"zap": 0.10, "mage_cast": 0.06, "frost_pulse": 0.04, "stomp": 0.08, "build": 0.05,
	"death_slime": 0.1, "death_slimeling": 0.12, "slime_split": 0.1, "death_shield": 0.06, "shield_break": 0.08,
}

var game = null
var rig = null
var sfx_on: bool = true
var ambient_on: bool = true        # jen pro testy (měření samotných efektů bez šumu pozadí)
var music_on: bool = true
var started: bool = false
var play_counts: Dictionary = {}
var sounds_ready: int = 0
var calm_ready: bool = false
var battle_ready: bool = false

var _sounds: Dictionary = {}
var _last_play: Dictionary = {}
var _pool3d: Array = []
var _pool2d: Array = []
var _calm: AudioStreamPlayer = null
var _battle: AudioStreamPlayer = null
var _wind: AudioStreamPlayer = null
var _water: AudioStreamPlayer = null
var _listener: AudioListener3D = null
var _fade: float = 0.0            # 0 = klidná hudba, 1 = bojová
var _duck: float = 1.0
var _calm_timer: float = 0.0
var _bird_timer: float = 6.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _players_started: bool = false


func setup(game_ref, rig_ref) -> void:
	name = "Audio"
	game = game_ref
	rig = rig_ref
	_rng.seed = 5150

	_listener = AudioListener3D.new()
	_listener.position = Vector3(0.0, 8.0, 0.0)
	rig.add_child(_listener)
	_listener.make_current()

	for i in range(22):
		var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 22.0
		p.max_distance = 170.0
		p.max_db = 0.0
		add_child(p)
		_pool3d.append(p)
	for i in range(6):
		var p2: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p2)
		_pool2d.append(p2)

	_calm = _make_player(CALM_DB)
	_battle = _make_player(-80.0)
	_wind = _make_player(WIND_DB)
	_water = _make_player(WATER_DB)

	# efekty se syntetizují hned (stovky milisekund), hudba a smyčky na pozadí
	var t0: int = Time.get_ticks_msec()
	var th: String = Themes.cur().audio_id
	for n in Synth.SFX_NAMES:
		var key: String = "sfx_%s_%s" % [th, str(n)]
		if not Synth.cache.has(key):
			Synth.cache[key] = Synth.make_sfx(str(n), th)
		_sounds[n] = Synth.cache[key]
	sounds_ready = _sounds.size()
	print("[Zvuk] %d efektů připraveno za %d ms" % [sounds_ready, Time.get_ticks_msec() - t0])
	_generate_async()


func _make_player(db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	return p


func _budget() -> int:
	# na pomalých strojích (málo snímků/s) se za snímek spočítá víc
	var fps: float = maxf(Engine.get_frames_per_second(), 1.0)
	return maxi(BUDGET_US, int(1000000.0 / fps * 0.4))


func _generate_async() -> void:
	## Vygenerované zvuky se drží ve statické mezipaměti (přežije znovunačtení scény při změně ostrova).
	var t0: int = Time.get_ticks_msec()
	var th: String = Themes.cur().audio_id
	for kind in ["wind", "water"]:
		if not Synth.cache.has("amb_%s_%s" % [th, kind]):
			Synth.cache["amb_%s_%s" % [th, kind]] = Synth.make_ambient(kind, th)
	_wind.stream = Synth.cache["amb_%s_wind" % th]
	_water.stream = Synth.cache["amb_%s_water" % th]
	await get_tree().process_frame
	if not Synth.cache.has("music_%s_calm" % th):
		Synth.cache["music_%s_calm" % th] = await _render_music_async("calm")
	_calm.stream = Synth.cache["music_%s_calm" % th]
	calm_ready = true
	print("[Zvuk] klidná hudba hotová za %d ms" % (Time.get_ticks_msec() - t0))
	_start_ready_players()
	if not Synth.cache.has("music_%s_battle" % th):
		Synth.cache["music_%s_battle" % th] = await _render_music_async("battle")
	_battle.stream = Synth.cache["music_%s_battle" % th]
	battle_ready = true
	print("[Zvuk] bojová hudba hotová za %d ms" % (Time.get_ticks_msec() - t0))
	_start_ready_players()


func _render_music_async(kind: String) -> AudioStreamWAV:
	var tr: Dictionary = Synth.music_track(kind, Themes.cur().audio_id)
	var spb: float = 60.0 / float(tr["bpm"])
	var total: int = int(float(tr["beats"]) * spb * float(Synth.MRATE))
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(total)
	Synth.rng().seed = hash(kind)
	var t_frame: int = Time.get_ticks_usec()
	var budget: int = _budget()
	for ev in tr["events"]:
		var instr: String = str(ev[0])
		var t0: float = float(ev[1]) * spb
		var dur: float = float(ev[2]) * spb
		var freq: float = Synth.midi_freq(float(ev[3]))
		var n: int = Synth.note_length(instr, dur, Synth.MRATE)
		var k: int = 0
		while k < n:
			var k2: int = mini(k + 5000, n)
			Synth.render_note(b, Synth.MRATE, instr, t0, dur, freq, float(ev[4]), k, k2)
			k = k2
			if Time.get_ticks_usec() - t_frame > budget:
				await get_tree().process_frame
				t_frame = Time.get_ticks_usec()
				budget = _budget()
	Synth.finish_music(b)
	await get_tree().process_frame
	return Synth.to_wav(b, Synth.MRATE, true)


## Voláno po prvním kliknutí hráče (prohlížeč do té doby zvuk nepustí).
func start() -> void:
	started = true
	_start_ready_players()


func _start_ready_players() -> void:
	if not started:
		return
	if _wind.stream != null and not _wind.playing:
		_wind.play()
	if _water.stream != null and not _water.playing:
		_water.play()
	if calm_ready and not _calm.playing:
		_calm.play()
	if battle_ready and not _battle.playing:
		_battle.play()


func set_sfx(on: bool) -> void:
	sfx_on = on
	if not on:
		for p in _pool3d:
			(p as AudioStreamPlayer3D).stop()
		for p2 in _pool2d:
			(p2 as AudioStreamPlayer).stop()


func set_music(on: bool) -> void:
	music_on = on


# ------------------------------------------------------------------ přehrávání efektů
func play(sound: String, pos = null, vol_db: float = 0.0) -> void:
	if not sfx_on or not _sounds.has(sound):
		return
	var gap: float = float(MIN_GAP.get(sound, 0.02))
	if _time - float(_last_play.get(sound, -10.0)) < gap:
		return
	_last_play[sound] = _time
	play_counts[sound] = int(play_counts.get(sound, 0)) + 1
	var pv: float = float(PITCH_VAR.get(sound, 0.0))
	var pitch: float = 1.0 + _rng.randf_range(-pv, pv)
	var db: float = minf(float(BASE_DB.get(sound, -6.0)) + SFX_BOOST_DB, SFX_CAP_DB) + vol_db
	if pos != null:
		for p in _pool3d:
			var pl: AudioStreamPlayer3D = p
			if not pl.playing:
				pl.stream = _sounds[sound]
				pl.volume_db = db
				pl.pitch_scale = pitch
				pl.global_position = pos
				pl.play()
				return
	else:
		for p2 in _pool2d:
			var pl2: AudioStreamPlayer = p2
			if not pl2.playing:
				pl2.stream = _sounds[sound]
				pl2.volume_db = db
				pl2.pitch_scale = pitch
				pl2.play()
				return


# ------------------------------------------------------------------ stav hry => hudba a ambient
func _process(delta: float) -> void:
	_time += delta
	if game == null:
		return
	# duck: konec hry / pauza ztlumí hudbu
	var duck_target: float = 1.0
	if game.state != 0:
		duck_target = 0.0
	elif game.paused:
		duck_target = 0.45
	_duck = move_toward(_duck, duck_target, delta * (0.7 if duck_target < _duck else 1.2))
	# boj / klid
	var fighting: bool = game.is_wave_active()
	if fighting:
		_calm_timer = 3.0
	else:
		_calm_timer = maxf(_calm_timer - delta, 0.0)
	var want_battle: bool = (fighting or _calm_timer > 0.0) and battle_ready
	_fade = move_toward(_fade, 1.0 if want_battle else 0.0, delta * 0.45)
	var mus: float = 1.0 if music_on else 0.0
	var calm_lin: float = cos(_fade * PI * 0.5) * db_to_linear(CALM_DB) * _duck * mus
	var battle_lin: float = sin(_fade * PI * 0.5) * db_to_linear(BATTLE_DB) * _duck * mus
	_calm.volume_db = linear_to_db(maxf(calm_lin, 0.0001))
	_battle.volume_db = linear_to_db(maxf(battle_lin, 0.0001))
	var amb: float = clampf(_duck + 0.3, 0.0, 1.0) * (1.0 if sfx_on and ambient_on else 0.0)
	_wind.volume_db = WIND_DB + linear_to_db(maxf(amb, 0.0001))
	_water.volume_db = WATER_DB + linear_to_db(maxf(amb, 0.0001))
	# ptáci
	if started and game.state == 0 and not game.paused:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = _rng.randf_range(6.0, 14.0)
			var a: float = _rng.randf() * TAU
			var r: float = _rng.randf_range(8.0, 26.0)
			play("bird_%d" % (1 + _rng.randi() % 3), Vector3(cos(a) * r, 7.0 + _rng.randf() * 4.0, sin(a) * r))
