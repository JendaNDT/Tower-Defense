extends Node
## Vstupní bod: postaví svět, hru, kameru a rozhraní; zpracovává myš a klávesnici.
## URL parametry (web): ?q=low (nižší kvalita), ?seed=N, ?skipintro=1, ?test=1 (zapne testovací API window.TD).

var map: GameMap = null
var theme: GameTheme = null
var world: Node3D = null
var game: Game = null
var fx: Fx = null
var rig: CameraRig = null
var overlays: Overlays = null
var hud: Hud = null
var handles: Dictionary = {}
var bridge: TestBridge = null
var audio: AudioManager = null

var build_type: String = ""
var selected: Tower = null
var hover_cell: Vector2i = Vector2i(-1, -1)
var high_quality: bool = true
var args: Dictionary = {}
var ready_to_play: bool = false
var _pick_key: String = ""
var _pick_cache = null
var aim_ability: String = ""          # schopnost, která čeká na výběr místa (meteor)
var island_def: Dictionary = {}
var blobs: BlobShadows = null
var touch_pending: bool = false         # dotyk: vybrané místo čeká na potvrzení tlačítkem
var touch_cell: Vector2i = Vector2i(-1, -1)
var touch_point: Vector3 = Vector3.ZERO
var _stats_t: float = 0.0
var _stats_ft: float = 0.0


func _parse_args() -> void:
	args = {}
	if OS.has_feature("web"):
		var qs = JavaScriptBridge.eval("window.location.search")
		if typeof(qs) == TYPE_STRING and str(qs).length() > 1:
			for part in str(qs).substr(1).split("&"):
				var kv: PackedStringArray = part.split("=")
				if kv.size() >= 1 and kv[0] != "":
					args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if OS.has_feature("web") and not args.has("q"):
		# mobily a slabší stroje: automaticky nižší kvalita (jde přepnout tlačítkem Kvalita)
		var weak = JavaScriptBridge.eval("(/Android|iPhone|iPad|Mobile/i.test(navigator.userAgent) || (navigator.hardwareConcurrency || 4) <= 2) ? 1 : 0")
		if int(weak) == 1:
			args["q"] = "low"
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s.begins_with("--"):
			s = s.substr(2)
		var kv2: PackedStringArray = s.split("=")
		args[kv2[0]] = kv2[1] if kv2.size() > 1 else "1"


func _ready() -> void:
	_parse_args()
	if not args.has("simtest"):
		GameSettings.load_all()
	else:
		GameSettings.loaded = true
	GameSettings.apply_args(args)
	UiProfile.detect(args)
	UiProfile.apply(get_window())
	Themes.use(GameSettings.theme)        # prostředí musí být zvolené dřív, než rozhraní postaví karty věží a texty
	hud = Hud.new()
	add_child(hud)
	# nechat vykreslit načítací obrazovku, pak teprve stavět (generování terénu chvíli trvá)
	await get_tree().process_frame
	await get_tree().process_frame
	_build_everything()


func _build_everything() -> void:
	var t0: int = Time.get_ticks_msec()
	high_quality = str(args.get("q", "high")) != "low"
	Gfx.quality_high = high_quality
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	if GameSettings.island == Islands.RANDOM_ID and GameSettings.random_seed == 0:
		GameSettings.random_seed = 1000 + int(Time.get_ticks_usec() % 9000)
	island_def = Islands.resolve(GameSettings.island, GameSettings.random_seed)
	var map_seed: int = int(island_def["seed"])
	if args.has("seed") and GameSettings.island != Islands.RANDOM_ID:
		map_seed = int(args["seed"])
	map = GameMap.new(map_seed, island_def)
	map.build()
	theme = Themes.cur()
	handles = theme.build_world(world, map, high_quality)
	fx = Fx.new()
	world.add_child(fx)

	game = Game.new()
	game.name = "Game"
	game.mode_id = GameSettings.mode
	game.diff_id = GameSettings.difficulty
	game.island_hp = float(island_def.get("hp", 1.0))
	game.persist_records = not args.has("simtest") and not args.has("test")     # testy rekordy nepřepisují
	add_child(game)
	game.setup(map, theme, world, fx)
	game.ambient = handles.get("ambient")

	blobs = BlobShadows.new()
	world.add_child(blobs)
	blobs.setup(game)

	rig = CameraRig.new()
	add_child(rig)
	game.camera_rig = rig
	fx.rig = rig
	rig.tapped.connect(_on_tap)
	rig.ui_blocker = hud.point_over_ui

	overlays = Overlays.new()
	world.add_child(overlays)
	overlays.setup(map, theme)

	# zvuk a hudba (syntetizované v kódu); v headless testech se nevytváří
	if not args.has("simtest") and not args.has("nosound") and DisplayServer.get_name() != "headless":
		audio = AudioManager.new()
		add_child(audio)
		audio.setup(game, rig)
		game.audio = audio

	hud.bind(game, island_def)
	hud.request_build.connect(_on_request_build)
	hud.request_ability.connect(_on_request_ability)
	hud.request_new_game.connect(_on_new_game)
	hud.request_cancel.connect(_cancel_all)
	hud.request_confirm.connect(_confirm_touch)
	hud.request_upgrade.connect(_upgrade_selected)
	hud.request_sell.connect(_sell_selected)
	hud.request_cycle_target.connect(_cycle_target)
	hud.request_start_wave.connect(_start_wave)
	hud.request_speed.connect(func(m): game.speed_mul = m)
	hud.request_pause.connect(_set_paused)
	hud.request_auto.connect(func(on): game.auto_wave = on)
	hud.request_restart.connect(_restart)
	hud.request_cam.connect(_on_cam)
	hud.request_focus.connect(func(p): rig.focus_xz(p))
	hud.request_quality.connect(_on_quality)
	hud.request_begin.connect(_on_begin)
	hud.request_sound.connect(func(n): _play_ui(n))
	hud.request_audio.connect(_on_audio_toggle)
	if audio != null:
		_load_audio_settings()
	game.tower_built.connect(func(_t): overlays.rebuild_grid())
	game.tower_removed.connect(_on_tower_removed)
	game.wave_changed.connect(func(_a, _b): pass)

	if not high_quality:
		_on_quality(false)

	if OS.has_feature("web") or args.has("test"):
		bridge = TestBridge.new()
		bridge.setup(self)

	print("[Ostrov] svět postaven za %d ms, volných polí: %d, překážek: %d, tras: %d, portálů: %d, nejdelší trasa: %.1f m" % [
		Time.get_ticks_msec() - t0, _count_free(), map.obstacles.size(), map.lane_count(), map.portals.size(), map.longest_lane().length])

	hud.set_loading(false)
	ready_to_play = true
	if args.has("simtest"):
		SimTest.run(self)
		return
	if args.has("skipintro") or GameSettings.autostart:
		GameSettings.autostart = false
		_on_begin()
	else:
		game.paused = true
		hud.show_intro(true)


func _count_free() -> int:
	var n: int = 0
	for c in map.cells:
		if c == GameMap.Cell.FREE:
			n += 1
	return n


# ------------------------------------------------------------------ akce
func _on_begin() -> void:
	game.paused = false
	hud.set_paused(false)
	if audio != null:
		audio.start()


func _play_ui(sound: String) -> void:
	if audio != null:
		audio.play(sound)


func _load_audio_settings() -> void:
	var cf: ConfigFile = GameSettings.cfg_load()
	var sfx: bool = bool(cf.get_value("zvuk", "efekty", true))
	var mus: bool = bool(cf.get_value("zvuk", "hudba", true))
	audio.set_sfx(sfx)
	audio.set_music(mus)
	hud.set_audio_state(sfx, mus)


func _save_audio_settings() -> void:
	var cf: ConfigFile = GameSettings.cfg_load()
	cf.set_value("zvuk", "efekty", audio.sfx_on)
	cf.set_value("zvuk", "hudba", audio.music_on)
	cf.save(GameSettings.path)


func _on_audio_toggle(kind: String, on: bool) -> void:
	if audio == null:
		return
	if kind == "sfx":
		audio.set_sfx(on)
	else:
		audio.set_music(on)
	_save_audio_settings()


func _toggle_all_audio() -> void:
	if audio == null:
		return
	var turn_on: bool = not (audio.sfx_on or audio.music_on)
	audio.set_sfx(turn_on)
	audio.set_music(turn_on)
	hud.set_audio_state(turn_on, turn_on)
	_save_audio_settings()


func _set_paused(on: bool) -> void:
	game.paused = on
	hud.set_paused(on)


func _restart() -> void:
	game.configure(GameSettings.mode, GameSettings.difficulty)
	aim_ability = ""
	hud.set_aim(false)
	selected = null
	build_type = ""
	hud.show_tower(null)
	hud.set_build_type("")
	overlays.rebuild_grid()
	overlays.hide_selection()
	overlays.hide_ghost()
	overlays.hide_range()
	overlays.show_grid(false)
	game.paused = false
	hud.set_paused(false)
	hud.set_speed_label(1.0)
	game.speed_mul = 1.0
	hud._speed_idx = 0
	hud.refresh_cards()
	hud._refresh_wave_panel()
	hud.refresh_info()


## Nová hra z menu: stejný ostrov = jen restart pravidel, jiný ostrov = nové načtení scény (svět se staví znovu).
func _on_new_game(mode_in: String, diff_in: String, island_in: int, theme_in: String) -> void:
	var old_island: int = GameSettings.island
	var old_theme: String = GameSettings.theme
	var fresh: bool = game.waves_started == 0 and game.time < 0.5
	GameSettings.mode = mode_in
	GameSettings.difficulty = diff_in
	GameSettings.island = island_in
	GameSettings.theme = theme_in
	GameSettings.save_all()
	# stejný ostrov a prostředí (nebo ještě nezačatý náhodný ostrov) = jen nová pravidla na stejné mapě
	if theme_in == old_theme and island_in == old_island and (island_in != Islands.RANDOM_ID or fresh):
		_restart()
		hud.show_intro(false)
		_on_begin()
		return
	if island_in == Islands.RANDOM_ID:
		GameSettings.random_seed = 1000 + int(Time.get_ticks_usec() % 9000)
	GameSettings.autostart = true
	hud.set_loading(true)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().reload_current_scene()


func _on_request_ability(id: String) -> void:
	if game.paused or game.state != Game.State.PLAYING:
		return
	if id == "meteor":
		if aim_ability == "meteor":
			_cancel_aim()
			return
		if not game.ability_ready("meteor"):
			game.toast.emit(Themes.t("ability_charging") % int(ceil(float(game.ability_cd["meteor"]))), "warn")
			return
		_cancel_all()
		aim_ability = "meteor"
		hud.set_aim(true)
		game.toast.emit(Themes.t("aim_touch") if UiProfile.touch_mode else Themes.t("aim_mouse"), "info")
		return
	var ok: bool = false
	if id == "blizzard":
		ok = game.cast_blizzard()
	elif id == "gold":
		ok = game.cast_gold()
	if not ok:
		game.toast.emit("%s se ještě nabíjí (%d s)." % [Themes.ability_name(id), int(ceil(float(game.ability_cd[id])))], "warn")


func _cancel_aim() -> void:
	aim_ability = ""
	hud.set_aim(false)
	overlays.hide_range()
	_clear_pending()


func _on_request_build(type: String) -> void:
	if aim_ability != "":
		_cancel_aim()
	if build_type == type:
		_cancel_all()
		return
	_select_tower(null)
	_clear_pending()
	build_type = type
	hud.set_build_type(type)
	overlays.show_grid(true)


func _cancel_all() -> void:
	if aim_ability != "":
		_cancel_aim()
	build_type = ""
	_clear_pending()
	hud.set_build_type("")
	overlays.show_grid(false)
	overlays.hide_ghost()
	overlays.hide_range()
	_select_tower(null)


func _select_tower(t: Tower) -> void:
	selected = t
	hud.show_tower(t)
	if t == null:
		overlays.hide_selection()
	else:
		overlays.show_selection(t.position)


func _upgrade_selected() -> void:
	if selected != null:
		game.upgrade_tower(selected)
		hud.refresh_tower_panel()


func _sell_selected() -> void:
	if selected != null:
		var t: Tower = selected
		_select_tower(null)
		overlays.hide_range()
		game.sell_tower(t)


func _cycle_target() -> void:
	if selected == null:
		return
	var i: int = Cfg.TARGET_MODES.find(selected.target_mode)
	selected.target_mode = Cfg.TARGET_MODES[(i + 1) % Cfg.TARGET_MODES.size()]
	hud.refresh_tower_panel()


func _start_wave() -> void:
	if game.paused:
		return
	if not game.start_next_wave():
		return
	hud._refresh_wave_panel()


func _on_tower_removed(t) -> void:
	if selected == t:
		_select_tower(null)
	overlays.rebuild_grid()


func _on_cam(action: String) -> void:
	match action:
		"rot_l":
			rig.rotate_by(45.0)
		"rot_r":
			rig.rotate_by(-45.0)
		"zoom_in":
			rig.zoom_by(0.8)
		"zoom_out":
			rig.zoom_by(1.25)
		"reset":
			rig.reset_view()


## Text přehledu výkonu (F3); obnovuje se čtyřikrát za vteřinu, aby nezatěžoval.
func _update_stats(delta: float) -> void:
	_stats_ft = delta if _stats_ft <= 0.0 else lerpf(_stats_ft, delta, 0.1)
	_stats_t -= delta
	if _stats_t > 0.0:
		return
	_stats_t = 0.25
	var calls: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	var prims: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	var txt: String = "FPS: %d   (snímek %.1f ms)\n" % [int(Engine.get_frames_per_second()), _stats_ft * 1000.0]
	txt += "Volání vykreslení: %d\nObjekty: %d\nTrojúhelníky: %dk\n" % [calls, objs, int(prims / 1000)]
	txt += "Kvalita: %s\n" % ("vysoká" if high_quality else "nízká")
	txt += "Nepřátelé: %d   Věže: %d   Stíny: %d   Spáleniny: %d" % [game.enemies.size(), game.towers.size(), blobs.count(), game.fx.scorch_count()]
	hud.set_stats_text(txt)


func _on_quality(high: bool) -> void:
	high_quality = high
	Gfx.quality_high = high
	hud.set_quality_state(high)
	var sun: DirectionalLight3D = handles.get("sun")
	if sun != null:
		sun.shadow_enabled = high
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED


# ------------------------------------------------------------------ vstupy
## Zjišťuje, jestli hráč ovládá hru prstem nebo myší (podle toho se ukazuje potvrzení stavby místo náhledu pod myší).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiProfile.touch_mode = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			if UiProfile.touch_mode and not UiProfile.phone:
				UiProfile.touch_mode = false
				_clear_pending()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F3:
		hud.toggle_stats()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).device == InputEvent.DEVICE_ID_EMULATION:
		return                  # emulace myši z dotyku: klepnutí na mapu zpracuje kamera (signál tapped)
	if not ready_to_play or hud.is_modal_open():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			if not rig.was_drag():
				_cancel_all()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_1:
				_on_request_build("archer")
			KEY_2:
				_on_request_build("cannon")
			KEY_3:
				_on_request_build("mage")
			KEY_4:
				_on_request_build("frost")
			KEY_5:
				_on_request_ability("meteor")
			KEY_6:
				_on_request_ability("blizzard")
			KEY_7:
				_on_request_ability("gold")
			KEY_ESCAPE:
				if build_type != "" or selected != null or aim_ability != "":
					_cancel_all()
				else:
					_set_paused(not game.paused)
			KEY_SPACE:
				_start_wave()
			KEY_U:
				_upgrade_selected()
			KEY_X, KEY_DELETE:
				_sell_selected()
			KEY_T:
				_cycle_target()
			KEY_P:
				_set_paused(not game.paused)
			KEY_F:
				hud.cycle_speed()
			KEY_H:
				hud.show_help(true)
			KEY_M:
				_toggle_all_audio()
			KEY_N:
				hud.toggle_minimap()
			KEY_HOME:
				rig.reset_view()


## Klepnutí na mapu (dotyk). Při stavbě a míření meteoru se místo nejdřív jen označí a potvrdí se tlačítkem
## (nebo dalším klepnutím na totéž místo); jinak klepnutí vybere věž.
func _on_tap(pos: Vector2) -> void:
	if not ready_to_play or hud.is_modal_open():
		return
	UiProfile.touch_mode = true
	var p = rig.pick_ground(pos, map)
	if p == null:
		return
	if aim_ability == "meteor":
		touch_point = Vector3(p.x, 0.0, p.z)
		touch_pending = true
		hud.show_confirm(Themes.t("aim_confirm"), true)
		return
	var c: Vector2i = Cfg.world_to_cell(p.x, p.z)
	if build_type != "":
		if not Cfg.cell_valid(c):
			return
		if touch_pending and c == touch_cell and _can_build_at(c):
			_confirm_touch()
			return
		touch_cell = c
		touch_pending = true
		var cost: int = Cfg.tower_cost(build_type)
		hud.show_confirm("Postavit  (%d)" % cost, _can_build_at(c))
		if not map.can_build(c):
			game.toast.emit("Sem se stavět nedá.", "warn")
		elif game.gold < cost:
			game.toast.emit("Nemáš dost %s." % Themes.t("gold_gen"), "warn")
		return
	_select_tower(game.tower_at(c) if Cfg.cell_valid(c) else null)


func _can_build_at(c: Vector2i) -> bool:
	return Cfg.cell_valid(c) and map.can_build(c) and game.gold >= Cfg.tower_cost(build_type)


## Potvrzení označeného místa tlačítkem (✓ ve spodní liště).
func _confirm_touch() -> void:
	if not touch_pending:
		return
	if aim_ability == "meteor":
		if game.cast_meteor(touch_point):
			_cancel_aim()
		return
	if build_type != "" and _can_build_at(touch_cell):
		game.build_tower(build_type, touch_cell)
		hud.refresh_cards()
		_clear_pending()


func _clear_pending() -> void:
	touch_pending = false
	touch_cell = Vector2i(-1, -1)
	if hud != null:
		hud.hide_confirm()


func _click(pos: Vector2) -> void:
	var p = rig.pick_ground(pos, map)
	if p == null:
		return
	if aim_ability == "meteor":
		if game.cast_meteor(Vector3(p.x, 0.0, p.z)):
			_cancel_aim()
		return
	var c: Vector2i = Cfg.world_to_cell(p.x, p.z)
	if build_type != "":
		if Cfg.cell_valid(c):
			game.build_tower(build_type, c)
			hud.refresh_cards()
		return
	var t: Tower = game.tower_at(c) if Cfg.cell_valid(c) else null
	_select_tower(t)


func _process(_delta: float) -> void:
	if not ready_to_play:
		return
	game.advance(_delta)
	if blobs != null:
		blobs.refresh()
	if hud.stats_visible():
		_update_stats(_delta)
	_update_hover()


## Náhled při ovládání prstem: ukazuje se jen označené místo (ne místo pod „myší“).
func _update_touch_preview() -> void:
	hover_cell = Vector2i(-1, -1)
	if aim_ability == "meteor":
		overlays.hide_ghost()
		if touch_pending:
			overlays.show_range(Vector3(touch_point.x, map.height_at(touch_point.x, touch_point.z), touch_point.z), float(Cfg.ABILITIES["meteor"]["radius"]), Themes.pal("meteor_aim"))
		else:
			overlays.hide_range()
		return
	if build_type != "":
		if touch_pending and Cfg.cell_valid(touch_cell):
			var valid: bool = _can_build_at(touch_cell)
			var wp: Vector3 = map.cell_world(touch_cell)
			overlays.show_ghost(build_type, wp, valid)
			overlays.show_range(wp, float(Cfg.tower_level(build_type, 1)["range"]) * float(Cfg.ELEV_RANGE[map.elev_at(touch_cell)]), Color(0.45, 1.0, 0.55) if valid else Color(1.0, 0.4, 0.35))
			hud.set_confirm_enabled(valid)
		else:
			overlays.hide_ghost()
			overlays.hide_range()
		return
	overlays.hide_ghost()
	if selected != null and is_instance_valid(selected):
		overlays.show_range(selected.position, float(selected.stats()["range"]), Color(0.45, 0.8, 1.0))
		overlays.show_selection(selected.position)
	else:
		overlays.hide_range()


## Výběr bodu na terénu pod myší; když se nezměnila myš ani kamera, použije se předchozí výsledek.
func _pick_cached(mp: Vector2):
	var key: String = "%.1f_%.1f_%.2f_%.2f_%.2f_%.2f" % [mp.x, mp.y, rig.yaw_deg, rig.zoom_size, rig.position.x, rig.position.z]
	if key != _pick_key:
		_pick_key = key
		_pick_cache = rig.pick_ground(mp, map)
	return _pick_cache


func _update_hover() -> void:
	if hud.is_modal_open():
		overlays.hide_ghost()
		return
	if UiProfile.touch_mode:
		_update_touch_preview()
		return
	var vp: Viewport = get_viewport()
	var mp: Vector2 = vp.get_mouse_position()
	var over_gui: bool = vp.gui_get_hovered_control() != null
	var p = null if over_gui else _pick_cached(mp)
	hover_cell = Vector2i(-1, -1)
	if p != null:
		hover_cell = Cfg.world_to_cell(p.x, p.z)
	if aim_ability == "meteor":
		overlays.hide_ghost()
		if p != null and not over_gui:
			overlays.show_range(Vector3(p.x, map.height_at(p.x, p.z), p.z), float(Cfg.ABILITIES["meteor"]["radius"]), Themes.pal("meteor_aim"))
		else:
			overlays.hide_range()
		return
	if build_type != "":
		if Cfg.cell_valid(hover_cell) and not over_gui:
			var valid: bool = map.can_build(hover_cell) and game.gold >= Cfg.tower_cost(build_type)
			var wp: Vector3 = map.cell_world(hover_cell)
			overlays.show_ghost(build_type, wp, valid)
			var rng: float = float(Cfg.tower_level(build_type, 1)["range"]) * float(Cfg.ELEV_RANGE[map.elev_at(hover_cell)])
			overlays.show_range(wp, rng, Color(0.45, 1.0, 0.55) if valid else Color(1.0, 0.4, 0.35))
		else:
			overlays.hide_ghost()
			overlays.hide_range()
		return
	overlays.hide_ghost()
	if selected != null and is_instance_valid(selected):
		overlays.show_range(selected.position, float(selected.stats()["range"]), Color(0.45, 0.8, 1.0))
		overlays.show_selection(selected.position)
	elif Cfg.cell_valid(hover_cell) and not over_gui:
		var ht: Tower = game.tower_at(hover_cell)
		if ht != null:
			overlays.show_range(ht.position, float(ht.stats()["range"]), Color(0.9, 0.9, 0.9))
		else:
			overlays.hide_range()
	else:
		overlays.hide_range()
