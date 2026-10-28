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

var build_type: String = ""
var selected: Tower = null
var hover_cell: Vector2i = Vector2i(-1, -1)
var high_quality: bool = true
var args: Dictionary = {}
var ready_to_play: bool = false
var _pick_key: String = ""
var _pick_cache = null


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

	map = GameMap.new(int(args.get("seed", "7")))
	map.build()
	theme = ThemeSkyIsland.new()
	handles = theme.build_world(world, map, high_quality)
	fx = Fx.new()
	world.add_child(fx)

	game = Game.new()
	game.name = "Game"
	add_child(game)
	game.setup(map, theme, world, fx)
	game.ambient = handles.get("ambient")

	rig = CameraRig.new()
	add_child(rig)
	game.camera_rig = rig
	fx.rig = rig

	overlays = Overlays.new()
	world.add_child(overlays)
	overlays.setup(map, theme)

	hud.bind(game)
	hud.request_build.connect(_on_request_build)
	hud.request_cancel.connect(_cancel_all)
	hud.request_upgrade.connect(_upgrade_selected)
	hud.request_sell.connect(_sell_selected)
	hud.request_cycle_target.connect(_cycle_target)
	hud.request_start_wave.connect(_start_wave)
	hud.request_speed.connect(func(m): game.speed_mul = m)
	hud.request_pause.connect(_set_paused)
	hud.request_auto.connect(func(on): game.auto_wave = on)
	hud.request_restart.connect(_restart)
	hud.request_cam.connect(_on_cam)
	hud.request_quality.connect(_on_quality)
	hud.request_begin.connect(_on_begin)
	game.tower_built.connect(func(_t): overlays.rebuild_grid())
	game.tower_removed.connect(_on_tower_removed)
	game.wave_changed.connect(func(_a, _b): pass)

	if not high_quality:
		_on_quality(false)

	if OS.has_feature("web") or args.has("test"):
		bridge = TestBridge.new()
		bridge.setup(self)

	print("[Ostrov] svět postaven za %d ms, volných polí: %d, překážek: %d, délka cesty: %.1f m" % [
		Time.get_ticks_msec() - t0, _count_free(), map.obstacles.size(), map.terrain.path.length])

	hud.set_loading(false)
	ready_to_play = true
	if args.has("simtest"):
		SimTest.run(self)
		return
	if args.has("skipintro"):
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


func _set_paused(on: bool) -> void:
	game.paused = on
	hud.set_paused(on)


func _restart() -> void:
	game.reset()
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


func _on_request_build(type: String) -> void:
	if build_type == type:
		_cancel_all()
		return
	_select_tower(null)
	build_type = type
	hud.set_build_type(type)
	overlays.show_grid(true)


func _cancel_all() -> void:
	build_type = ""
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


func _on_quality(high: bool) -> void:
	high_quality = high
	var sun: DirectionalLight3D = handles.get("sun")
	if sun != null:
		sun.shadow_enabled = high
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED


# ------------------------------------------------------------------ vstupy
func _unhandled_input(event: InputEvent) -> void:
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
			KEY_ESCAPE:
				if build_type != "" or selected != null:
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
				hud.show_intro(true)
			KEY_HOME:
				rig.reset_view()


func _click(pos: Vector2) -> void:
	var p = rig.pick_ground(pos, map)
	if p == null:
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
	_update_hover()


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
	var vp: Viewport = get_viewport()
	var mp: Vector2 = vp.get_mouse_position()
	var over_gui: bool = vp.gui_get_hovered_control() != null
	var p = null if over_gui else _pick_cached(mp)
	hover_cell = Vector2i(-1, -1)
	if p != null:
		hover_cell = Cfg.world_to_cell(p.x, p.z)
	if build_type != "":
		if Cfg.cell_valid(hover_cell) and not over_gui:
			var valid: bool = map.can_build(hover_cell) and game.gold >= Cfg.tower_cost(build_type)
			var wp: Vector3 = map.cell_world(hover_cell)
			overlays.show_ghost(build_type, wp, valid)
			var rng: float = float(Cfg.tower_level(build_type, 1)["range"])
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
