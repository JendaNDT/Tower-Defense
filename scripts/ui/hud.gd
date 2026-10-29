class_name Hud
extends CanvasLayer
## Uživatelské rozhraní (vše česky): životy, zlato, vlna, karty věží, panel vybrané věže, náhled vlny,
## ovládání kamery a rychlosti, úvodní/konečná obrazovka. Celé vytvořeno v kódu.

signal request_build(type: String)
signal request_cancel()
signal request_confirm()
signal request_upgrade()
signal request_sell()
signal request_cycle_target()
signal request_start_wave()
signal request_speed(mult: float)
signal request_pause(on: bool)
signal request_auto(on: bool)
signal request_restart()
signal request_cam(action: String)
signal request_focus(world_xz: Vector2)
signal request_quality(high: bool)
signal request_begin()
signal request_sound(sound: String)
signal request_audio(kind: String, on: bool)
signal request_ability(id: String)
signal request_new_game(mode: String, difficulty: String, island: int, theme: String)

const C_BG: Color = Color(0.07, 0.10, 0.17, 0.88)
const C_BG_L: Color = Color(0.13, 0.18, 0.28, 0.92)
const C_BORDER: Color = Color(1, 1, 1, 0.16)
const C_GOLD: Color = Color(1.0, 0.82, 0.30)
const C_GREEN: Color = Color(0.45, 0.90, 0.50)
const C_RED: Color = Color(1.0, 0.40, 0.38)
const C_TEXT: Color = Color(0.95, 0.97, 1.0)
const C_DIM: Color = Color(0.70, 0.76, 0.86)

var game: Game = null

var _root: Control
var _lives_lbl: Label
var _gold_lbl: Label
var _wave_lbl: Label
var _cards: Dictionary = {}
var _wave_title: Label
var _wave_rows: VBoxContainer
var _wave_btn: Button
var _wave_btn_lbl: Label
var _tower_panel: PanelContainer
var _tp: Dictionary = {}
var _toast_panel: PanelContainer
var _toast_lbl: Label
var _toast_tween: Tween = null
var _intro: Control
var _intro_btn: Button
var _end_btn: Button
var _end: Control
var _end_title: Label
var _end_body: Label
var _pause_ov: Control
var _loading: Control
var _speed_btn: Button
var _speed_lbl: Label
var _pause_btn: Button
var _pause_icon: IconCtrl
var _auto_btn: Button
var _sfx_btn: Button
var _music_btn: Button
var _quality_btn: Button
var _island_def: Dictionary = {}
var _info_lbl: Label
var _help: Control
var _menu_btn: Button
var _menu_back_btn: Button
var _menu_start_btn: Button
var _menu_rec: Label
var _menu_island_name: Label
var _menu_island_desc: Label
var _menu_mode_desc: Label
var _menu_diff_desc: Label
var _menu_mode_btns: Dictionary = {}
var _menu_diff_btns: Dictionary = {}
var _menu_mode: String = "campaign"
var _menu_diff: String = "normal"
var _menu_island: int = 0
var _menu_theme: String = "sky_island"
var _menu_theme_btns: Dictionary = {}
var _menu_theme_desc: Label = null
var _menu_title: Label = null
var _menu_sub: Label = null
var _menu_place: Label = null
var _end_menu_btn: Button
var _ab: Dictionary = {}             # id -> {"btn", "cd", "lbl"}
var _ab_box: BoxContainer
var _aiming: bool = false
var _ui: Dictionary = {}              # jméno -> ovládací prvek (pro testy klikáním)
var _build_type: String = ""
var _selected: Tower = null
var _speed_idx: int = 0
var _refresh_t: float = 0.0
var _high_quality: bool = true
var _auto_on: bool = false
var _paused_ui: bool = false
var _stats_lbl: Label = null
var _c: bool = false                         # kompaktní rozložení (telefon)
var _wave_panel: PanelContainer = null
var _minimap: Minimap = null
var _more_btn: Button = null
var _more_panel: PanelContainer = null
var _confirm_bar: PanelContainer = null
var _confirm_ok: Button = null
var _confirm_lbl: Label = null
var _rotate_ov: Control = null              # „otoč telefon“ (na výšku se hra pozastaví)
var _rot_paused: bool = false


# ================================================================== pomocné stavební funkce
## Hodnota podle rozložení: první pro počítač, druhá pro kompaktní (telefon).
func _k(desktop: float, compact: float) -> float:
	return compact if _c else desktop


static func sbox(bg: Color, radius: int = 12, border: Color = C_BORDER, bw: int = 1, pad: Vector4 = Vector4(10, 8, 10, 8)) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb


func _label(text: String, size: int = 16, color: Color = C_TEXT, outline: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(bg: Color = C_BG, radius: int = 14, pad: Vector4 = Vector4(12, 8, 12, 8)) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(bg, radius, C_BORDER, 1, pad))
	return p


func _style_button(b: Button, accent: Color = Color(0.35, 0.6, 1.0), radius: int = 10) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): request_sound.emit("ui_click"))
	b.add_theme_stylebox_override("normal", sbox(C_BG_L, radius, C_BORDER, 1, Vector4(10, 6, 10, 6)))
	b.add_theme_stylebox_override("hover", sbox(C_BG_L.lightened(0.12), radius, accent, 2, Vector4(10, 6, 10, 6)))
	b.add_theme_stylebox_override("pressed", sbox(accent.darkened(0.25), radius, accent, 2, Vector4(10, 6, 10, 6)))
	b.add_theme_stylebox_override("disabled", sbox(Color(0.10, 0.12, 0.16, 0.8), radius, Color(1, 1, 1, 0.06), 1, Vector4(10, 6, 10, 6)))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.65))
	b.add_theme_font_size_override("font_size", 16)


func _place(c: Control, anchor: Vector2, margin: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	var gx: int = Control.GROW_DIRECTION_END
	var ox: float = margin.x
	if anchor.x > 0.66:
		gx = Control.GROW_DIRECTION_BEGIN
		ox = -margin.x
	elif anchor.x >= 0.34:
		gx = Control.GROW_DIRECTION_BOTH
		ox = 0.0
	var gy: int = Control.GROW_DIRECTION_END
	var oy: float = margin.y
	if anchor.y > 0.66:
		gy = Control.GROW_DIRECTION_BEGIN
		oy = -margin.y
	elif anchor.y >= 0.34:
		gy = Control.GROW_DIRECTION_BOTH
		oy = 0.0
	c.grow_horizontal = gx as Control.GrowDirection
	c.grow_vertical = gy as Control.GrowDirection
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy


func _icon_button(kind: String, tip: String, col: Color = C_TEXT, size_px: int = 0) -> Button:
	var b: Button = Button.new()
	var sz: int = size_px if size_px > 0 else int(_k(44, 52))
	b.custom_minimum_size = Vector2(sz, sz)
	b.tooltip_text = tip
	_style_button(b)
	var ic: IconCtrl = IconCtrl.make(kind, 10, col)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 7
	ic.offset_top = 7
	ic.offset_right = -7
	ic.offset_bottom = -7
	b.add_child(ic)
	b.set_meta("icon", ic)
	return b


# ================================================================== sestavení
func _ready() -> void:
	layer = 10
	name = "Hud"
	_c = UiProfile.phone
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top_left()
	_build_top_right()
	_build_cards()
	_build_wave_panel()
	_build_tower_panel()
	_build_abilities()
	_build_toast()
	_build_confirm()
	_build_intro()
	_build_help()
	_build_end()
	_build_pause()
	_build_loading()
	_build_rotate()
	_build_stats()
	if _c:
		_strip_tooltips(_root)
	set_loading(true)


## Na dotykovém displeji by bublinová nápověda po klepnutí zůstala viset, proto se na telefonu nepoužívá.
func _strip_tooltips(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			(ch as Control).tooltip_text = ""
		_strip_tooltips(ch)


func bind(g: Game, island_def: Dictionary = {}) -> void:
	game = g
	_island_def = island_def
	game.gold_changed.connect(_on_gold)
	game.lives_changed.connect(_on_lives)
	game.wave_changed.connect(_on_wave)
	game.state_changed.connect(_on_state)
	game.toast.connect(show_toast)
	game.tower_upgraded.connect(func(_t): refresh_tower_panel())
	_on_gold(game.gold)
	_on_lives(game.lives)
	_on_wave(game.waves_started, game.total_waves)
	refresh_cards()
	refresh_info()
	_build_minimap()


## Minimapa pod panelem životů a zlata (vlevo); na telefonu menší.
func _build_minimap() -> void:
	if _minimap != null or game == null or game.map == null:
		return
	_minimap = Minimap.new()
	_minimap.setup(game, _k(196, 118))
	_minimap.jump_requested.connect(func(p): request_focus.emit(p))
	_root.add_child(_minimap)
	_place(_minimap, Vector2(0, 0), Vector2(_k(12, 8), _k(98, 70)))
	_ui["minimap"] = _minimap


func toggle_minimap() -> void:
	if _minimap != null:
		_minimap.toggle()


func _build_top_left() -> void:
	var p: PanelContainer = _panel(C_BG, 14, Vector4(_k(12, 10), _k(8, 5), _k(12, 10), _k(8, 5)))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	p.add_child(col)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(18, 12)))
	col.add_child(h)
	_info_lbl = _label("", int(_k(12, 11)), C_DIM)
	col.add_child(_info_lbl)
	var g1: HBoxContainer = HBoxContainer.new()
	g1.add_theme_constant_override("separation", 6)
	g1.add_child(IconCtrl.make("heart", _k(30, 24), Color(1.0, 0.35, 0.40)))
	_lives_lbl = _label("20", int(_k(26, 21)), C_TEXT, true)
	_lives_lbl.custom_minimum_size = Vector2(_k(36, 28), 0)
	g1.add_child(_lives_lbl)
	h.add_child(g1)
	var g2: HBoxContainer = HBoxContainer.new()
	g2.add_theme_constant_override("separation", 6)
	g2.add_child(IconCtrl.make("coin", _k(30, 24), C_GOLD))
	_gold_lbl = _label("0", int(_k(26, 21)), C_GOLD, true)
	_gold_lbl.custom_minimum_size = Vector2(_k(60, 46), 0)
	g2.add_child(_gold_lbl)
	h.add_child(g2)
	var g3: HBoxContainer = HBoxContainer.new()
	g3.add_theme_constant_override("separation", 6)
	g3.add_child(IconCtrl.make("flag", _k(28, 22), Color(0.5, 0.8, 1.0)))
	_wave_lbl = _label("Vlna 0 / 12", int(_k(22, 18)), C_TEXT, true)
	g3.add_child(_wave_lbl)
	h.add_child(g3)
	_ui["info_panel"] = p
	_root.add_child(p)
	_place(p, Vector2(0, 0), Vector2(_k(12, 8), _k(12, 8)))


func _build_top_right() -> void:
	var p: PanelContainer = _panel(C_BG, 14, Vector4(8, 6, 8, 6))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	# na telefonu je v liště jen to nejpotřebnější, ostatní je pod tlačítkem „…“ (rozbalovací panel)
	var more_box: VBoxContainer = VBoxContainer.new()
	more_box.add_theme_constant_override("separation", 6)
	var more_grid: GridContainer = GridContainer.new()
	more_grid.columns = 5
	more_grid.add_theme_constant_override("h_separation", 6)
	more_grid.add_theme_constant_override("v_separation", 6)
	more_box.add_child(more_grid)
	var sec: Container = more_grid if _c else h

	_pause_btn = _icon_button("pause", "Pauza (P)")
	_pause_icon = _pause_btn.get_meta("icon")
	_pause_btn.pressed.connect(func(): request_pause.emit(not _paused_ui))
	h.add_child(_pause_btn)

	_speed_btn = _icon_button("ff", "Rychlost hry (F)")
	_speed_lbl = _label("1×", 15, C_TEXT, true)
	_speed_lbl.position = Vector2(_k(26, 32), _k(24, 30))
	_speed_btn.add_child(_speed_lbl)
	_speed_btn.pressed.connect(_cycle_speed)
	h.add_child(_speed_btn)

	_auto_btn = _icon_button("auto", "Automaticky spouštět další vlnu")
	_auto_btn.toggle_mode = true
	_auto_btn.toggled.connect(func(on): _auto_on = on; request_auto.emit(on))
	h.add_child(_auto_btn)

	_sfx_btn = _icon_button("speaker", "Zvukové efekty (M = vše)")
	_sfx_btn.toggle_mode = true
	_sfx_btn.set_pressed_no_signal(true)
	_sfx_btn.toggled.connect(func(on):
		_sync_audio_icons()
		request_audio.emit("sfx", on))
	sec.add_child(_sfx_btn)
	_music_btn = _icon_button("note", "Hudba (M = vše)")
	_music_btn.toggle_mode = true
	_music_btn.set_pressed_no_signal(true)
	_music_btn.toggled.connect(func(on):
		_sync_audio_icons()
		request_audio.emit("music", on))
	sec.add_child(_music_btn)

	if not _c:
		var sep: VSeparator = VSeparator.new()
		h.add_child(sep)

	var rl: Button = _icon_button("rotl", "Otočit doleva (Q)")
	rl.pressed.connect(func(): request_cam.emit("rot_l"))
	sec.add_child(rl)
	var rr: Button = _icon_button("rotr", "Otočit doprava (E)")
	rr.pressed.connect(func(): request_cam.emit("rot_r"))
	sec.add_child(rr)
	var zi: Button = _icon_button("plus", "Přiblížit (kolečko myši)")
	zi.pressed.connect(func(): request_cam.emit("zoom_in"))
	sec.add_child(zi)
	var zo: Button = _icon_button("minus", "Oddálit")
	zo.pressed.connect(func(): request_cam.emit("zoom_out"))
	sec.add_child(zo)
	_ui["cam_zoom_in"] = zi
	_ui["cam_rot_l"] = rl

	if _c:
		var fs: Button = _icon_button("fullscreen", "Celá obrazovka")
		fs.pressed.connect(_toggle_fullscreen)
		sec.add_child(fs)
		_ui["fullscreen_btn"] = fs

	_quality_btn = Button.new()
	_quality_btn.text = "Kvalita: vysoká"
	_quality_btn.custom_minimum_size = Vector2(120, _k(44, 46))
	_style_button(_quality_btn)
	_quality_btn.add_theme_font_size_override("font_size", 13)
	_quality_btn.pressed.connect(func():
		_high_quality = not _high_quality
		_quality_btn.text = "Kvalita: vysoká" if _high_quality else "Kvalita: nízká"
		request_quality.emit(_high_quality))
	if _c:
		more_box.add_child(_quality_btn)
	else:
		h.add_child(_quality_btn)

	_menu_btn = _icon_button("menu", Themes.t("menu_tip"))
	_menu_btn.pressed.connect(func(): show_intro(true))
	sec.add_child(_menu_btn)
	_ui["menu_btn"] = _menu_btn

	var hb: Button = Button.new()
	hb.text = "?"
	var hsz: float = _k(44, 52)
	hb.custom_minimum_size = Vector2(hsz, hsz)
	_style_button(hb)
	hb.add_theme_font_size_override("font_size", 20)
	hb.tooltip_text = "Nápověda (H)"
	hb.pressed.connect(func(): show_help(true))
	sec.add_child(hb)
	_ui["help_btn"] = hb

	if _c:
		_more_btn = _icon_button("more", "Další ovládání")
		_more_btn.toggle_mode = true
		_more_btn.toggled.connect(func(on): _more_panel.visible = on)
		h.add_child(_more_btn)
		_ui["more_btn"] = _more_btn
		_more_panel = _panel(C_BG, 14, Vector4(8, 8, 8, 8))
		_more_panel.add_child(more_box)
		_more_panel.visible = false
		_root.add_child(_more_panel)
		_place(_more_panel, Vector2(1, 0), Vector2(8, 8 + 60))
		_ui["more_panel"] = _more_panel
	_root.add_child(p)
	_place(p, Vector2(1, 0), Vector2(_k(12, 8), _k(12, 8)))


func _build_cards() -> void:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_k(10, 8)))
	for id in Cfg.TOWER_ORDER:
		var spec: Dictionary = Cfg.TOWERS[id]
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(_k(158, 100), _k(96, 68))
		b.toggle_mode = true
		_style_button(b, Themes.tower_color(id), 14)
		var v: VBoxContainer = VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 1)
		var top: HBoxContainer = HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", int(_k(8, 5)))
		top.add_child(IconCtrl.make(Themes.tower_icon(id), _k(34, 26), Themes.tower_color(id), Color(0.2, 0.2, 0.25)))
		var nm: Label = _label(Themes.tower_name(id), int(_k(18, 14)), C_TEXT, true)
		top.add_child(nm)
		v.add_child(top)
		if not _c:
			var sub: Label = _label(Themes.tower_short(id), 12, C_DIM)
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(sub)
		var cost_row: HBoxContainer = HBoxContainer.new()
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_row.add_theme_constant_override("separation", 5)
		cost_row.add_child(IconCtrl.make("coin", _k(20, 18), C_GOLD))
		var cl: Label = _label(str(Cfg.tower_cost(id)), int(_k(20, 18)), C_GOLD, true)
		cost_row.add_child(cl)
		v.add_child(cost_row)
		b.add_child(v)
		if not _c:
			var hk: Label = _label("[%s]" % spec["hotkey"], 12, C_DIM)
			hk.position = Vector2(8, 4)
			b.add_child(hk)
		b.pressed.connect(func(): request_build.emit(id))
		b.tooltip_text = "%s – %s\n%s" % [Themes.tower_name(id), Themes.tower_short(id), Themes.tower_desc(id)]
		h.add_child(b)
		_cards[id] = {"btn": b, "cost": cl, "name": nm}
		_ui["card_" + id] = b
	_root.add_child(h)
	_place(h, Vector2(0.5, 1), Vector2(0, _k(12, 8)))


func _build_wave_panel() -> void:
	var p: PanelContainer = _panel(C_BG, 14, Vector4(_k(12, 10), _k(10, 7), _k(12, 10), _k(10, 7)))
	_wave_panel = p
	_ui["wave_panel"] = p
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(6, 4)))
	v.custom_minimum_size = Vector2(_k(230, 188), 0)
	p.add_child(v)
	_wave_title = _label("Další vlna", int(_k(17, 15)), C_GOLD, true)
	v.add_child(_wave_title)
	_wave_rows = VBoxContainer.new()
	_wave_rows.add_theme_constant_override("separation", 3)
	v.add_child(_wave_rows)
	_wave_btn = Button.new()
	_wave_btn.custom_minimum_size = Vector2(0, _k(46, 52))
	_style_button(_wave_btn, C_GREEN, 12)
	_wave_btn.text = _wave_btn_text(true)
	_wave_btn.add_theme_font_size_override("font_size", int(_k(17, 17)))
	_wave_btn.pressed.connect(func(): request_start_wave.emit())
	v.add_child(_wave_btn)
	_root.add_child(p)
	_place(p, Vector2(1, 1), Vector2(_k(12, 8), _k(12, 8)))


func _wave_btn_text(can: bool) -> String:
	if not can:
		return "Vlna se spouští…"
	return "Spustit vlnu" if _c else "Spustit vlnu  [mezerník]"


func _build_tower_panel() -> void:
	_tower_panel = _panel(C_BG, 14, Vector4(_k(14, 10), _k(12, 8), _k(14, 10), _k(12, 8)))
	_tower_panel.visible = false
	_ui["tower_panel"] = _tower_panel
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(6, 4)))
	v.custom_minimum_size = Vector2(_k(300, 252), 0)
	_tower_panel.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var ic: IconCtrl = IconCtrl.make("archer", _k(38, 32), C_TEXT)
	head.add_child(ic)
	_tp["icon"] = ic
	var title_v: VBoxContainer = VBoxContainer.new()
	title_v.add_theme_constant_override("separation", 0)
	title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = _label("Věž", int(_k(22, 18)), C_TEXT, true)
	title_v.add_child(title)
	_tp["title"] = title
	var stars: HBoxContainer = HBoxContainer.new()
	stars.add_theme_constant_override("separation", 2)
	var star_list: Array = []
	for i in range(Cfg.MAX_LEVEL):
		var s: IconCtrl = IconCtrl.make("star", _k(18, 15), C_GOLD)
		stars.add_child(s)
		star_list.append(s)
	_tp["stars"] = star_list
	var lvl: Label = _label("Úroveň 1 / 4", int(_k(14, 12)), C_DIM)
	stars.add_child(lvl)
	_tp["level"] = lvl
	title_v.add_child(stars)
	head.add_child(title_v)
	if _c:
		# bez klávesy Esc: zavírací tlačítko přímo v panelu
		var close: Button = _icon_button("cross", "Zavřít panel", C_TEXT, 44)
		close.pressed.connect(func(): request_cancel.emit())
		head.add_child(close)
		_ui["tower_close"] = close
	v.add_child(head)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(_k(10, 8)))
	grid.add_theme_constant_override("v_separation", int(_k(2, 0)))
	v.add_child(grid)
	_tp["grid"] = grid

	var note: Label = _label("", int(_k(14, 12)), C_GREEN)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(_k(300, 252), 0)
	v.add_child(note)
	_tp["note"] = note
	var stat: Label = _label("", int(_k(13, 11)), C_DIM)
	v.add_child(stat)
	_tp["stat"] = stat

	var up: Button = Button.new()
	up.custom_minimum_size = Vector2(0, _k(44, 50))
	_style_button(up, C_GREEN, 12)
	up.add_theme_font_size_override("font_size", int(_k(17, 15)))
	up.pressed.connect(func(): request_upgrade.emit())
	v.add_child(up)
	_tp["upgrade"] = up
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tgt: Button = Button.new()
	tgt.custom_minimum_size = Vector2(0, _k(36, 46))
	tgt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(tgt)
	tgt.add_theme_font_size_override("font_size", int(_k(14, 13)))
	tgt.pressed.connect(func(): request_cycle_target.emit())
	row.add_child(tgt)
	_tp["target"] = tgt
	var sell: Button = Button.new()
	sell.custom_minimum_size = Vector2(0, _k(36, 46))
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(sell, C_RED)
	sell.add_theme_font_size_override("font_size", int(_k(14, 13)))
	sell.pressed.connect(func(): request_sell.emit())
	row.add_child(sell)
	_tp["sell"] = sell
	v.add_child(row)
	if not _c:
		var hint: Label = _label("[U] vylepšit   [X] prodat   [T] cíl   [Esc] zavřít", 11, C_DIM)
		v.add_child(hint)
	_root.add_child(_tower_panel)
	if _c:
		_place(_tower_panel, Vector2(1, 0), Vector2(8, 8 + 60))
	else:
		_place(_tower_panel, Vector2(0, 0), Vector2(12, 84))


func _build_toast() -> void:
	_toast_panel = _panel(Color(0.05, 0.07, 0.12, 0.92), 12, Vector4(_k(18, 14), _k(8, 5), _k(18, 14), _k(8, 5)))
	_toast_lbl = _label("", int(_k(18, 15)), C_TEXT, true)
	_toast_panel.add_child(_toast_lbl)
	_toast_panel.modulate.a = 0.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_panel)
	_place(_toast_panel, Vector2(0.5, 0), Vector2(0, _k(76, 8)))


## Potvrzovací lišta pro dotyk (stavba věže, meteor): „Postavit“ a zrušení, nad kartami věží.
func _build_confirm() -> void:
	_confirm_bar = _panel(C_BG, 16, Vector4(8, 6, 8, 6))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_confirm_bar.add_child(h)
	_confirm_ok = Button.new()
	_confirm_ok.custom_minimum_size = Vector2(_k(220, 200), _k(54, 52))
	_style_button(_confirm_ok, C_GREEN, 12)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.add_child(IconCtrl.make("check", 26, C_GREEN))
	_confirm_lbl = _label("Postavit", 18, C_TEXT, true)
	row.add_child(_confirm_lbl)
	_confirm_ok.add_child(row)
	_confirm_ok.pressed.connect(func(): request_confirm.emit())
	h.add_child(_confirm_ok)
	var cancel: Button = _icon_button("cross", "Zrušit", C_RED, int(_k(54, 52)))
	cancel.pressed.connect(func(): request_cancel.emit())
	h.add_child(cancel)
	_confirm_bar.visible = false
	_root.add_child(_confirm_bar)
	_place(_confirm_bar, Vector2(0.5, 1), Vector2(0, _k(12 + 96 + 8, 8 + 68 + 8)))
	_ui["confirm_ok"] = _confirm_ok
	_ui["confirm_cancel"] = cancel


func show_confirm(text: String, enabled: bool) -> void:
	_confirm_lbl.text = text
	_confirm_ok.disabled = not enabled
	_confirm_bar.visible = true


func hide_confirm() -> void:
	if _confirm_bar != null:
		_confirm_bar.visible = false


func set_confirm_enabled(on: bool) -> void:
	if _confirm_ok != null:
		_confirm_ok.disabled = not on


func confirm_visible() -> bool:
	return _confirm_bar != null and _confirm_bar.visible


## Je bod (v souřadnicích obrazovky) nad ovládacím prvkem rozhraní? Takový dotyk neovládá kameru ani mapu.
func point_over_ui(pos: Vector2) -> bool:
	return _over_ui_rec(_root, pos)


func _over_ui_rec(n: Node, pos: Vector2) -> bool:
	for ch in n.get_children():
		if ch is Control:
			var c: Control = ch
			if not c.visible:
				continue
			if c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_global_rect().has_point(pos):
				return true
			if _over_ui_rec(c, pos):
				return true
	return false


func _toggle_fullscreen() -> void:
	var m: int = DisplayServer.window_get_mode()
	if m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _modal(title: String, body: String, button_text: String, title_color: Color = C_GOLD) -> Dictionary:
	var ov: Control = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var p: PanelContainer = _panel(Color(0.08, 0.11, 0.19, 0.96), 20, Vector4(_k(32, 24), _k(24, 14), _k(32, 24), _k(24, 14)))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(12, 8)))
	v.custom_minimum_size = Vector2(_k(560, 660), 0)
	p.add_child(v)
	var t: Label = _label(title, int(_k(38, 28)), title_color, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b: Label = _label(body, int(_k(17, 13)), C_TEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(_k(540, 636), 0)
	v.add_child(b)
	var btn: Button = Button.new()
	btn.text = button_text
	btn.custom_minimum_size = Vector2(0, _k(52, 50))
	_style_button(btn, C_GREEN, 14)
	btn.add_theme_font_size_override("font_size", int(_k(22, 20)))
	v.add_child(btn)
	ov.add_child(p)
	_place(p, Vector2(0.5, 0.5), Vector2(0, 0))
	return {"root": ov, "title": t, "body": b, "button": btn}


func _toggle_row(items: Array, selected: String, on_pick: Callable, store: Dictionary, ui_prefix: String) -> HBoxContainer:
	## Řada přepínačů (vždy je zvolen právě jeden). items: [[id, text], ...]
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for it in items:
		var id: String = str(it[0])
		var b: Button = Button.new()
		b.text = str(it[1])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, _k(40, 46))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(b, C_GOLD, 10)
		b.add_theme_font_size_override("font_size", int(_k(16, 15)))
		b.set_pressed_no_signal(id == selected)
		b.pressed.connect(func(): on_pick.call(id))
		row.add_child(b)
		store[id] = b
		_ui[ui_prefix + id] = b
	return row


func _menu_refresh() -> void:
	for id in _menu_mode_btns.keys():
		(_menu_mode_btns[id] as Button).set_pressed_no_signal(id == _menu_mode)
	for id2 in _menu_diff_btns.keys():
		(_menu_diff_btns[id2] as Button).set_pressed_no_signal(id2 == _menu_diff)
	_menu_mode_desc.text = Themes.t("mode_campaign") % Cfg.TOTAL_WAVES if _menu_mode == "campaign" else "Vlny nikdy nekončí a stále sílí. Jak daleko to dotáhneš? Rekord se ukládá."
	var d: Dictionary = Cfg.DIFFICULTIES[_menu_diff]
	_menu_diff_desc.text = "%s  (start: %d %s, %d životů, nepřátelé %d %% zdraví)" % [d["desc"], int(d["gold"]), Themes.peek(_menu_theme).text("gold_gen"), int(d["lives"]), int(round(float(d["hp"]) * 100.0))]
	var pth: GameTheme = Themes.peek(_menu_theme)
	for tid in _menu_theme_btns.keys():
		(_menu_theme_btns[tid] as Button).set_pressed_no_signal(tid == _menu_theme)
	if _menu_theme_desc != null:
		_menu_theme_desc.text = str(Themes.info(_menu_theme)["desc"])
	_menu_title.text = pth.text("title")
	_menu_sub.text = pth.text("intro_sub")
	_menu_place.text = pth.text("place")
	_menu_island_name.text = Islands.display_name(_menu_island, pth)
	_menu_island_desc.text = Islands.display_desc(_menu_island, pth)
	var key: String = "%s_%s_%d" % [_menu_mode, _menu_diff, _menu_island]
	_menu_rec.text = "Rekord: " + GameSettings.record_text(key)


func _menu_pick_theme(id: String) -> void:
	_menu_theme = id
	request_sound.emit("ui_click")
	_menu_refresh()


func _menu_pick_mode(id: String) -> void:
	_menu_mode = id
	_menu_refresh()


func _menu_pick_diff(id: String) -> void:
	_menu_diff = id
	_menu_refresh()


func _menu_step_island(dir: int) -> void:
	_menu_island = (_menu_island + dir + Islands.choices()) % Islands.choices()
	_menu_refresh()


func _build_intro() -> void:
	var ov: Control = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var p: PanelContainer = _panel(Color(0.08, 0.11, 0.19, 0.97), 20, Vector4(_k(32, 24), _k(22, 12), _k(32, 24), _k(22, 12)))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", int(_k(9, 6)))
	v.custom_minimum_size = Vector2(_k(640, 0), 0)
	p.add_child(v)
	var t: Label = _label(Themes.t("title"), int(_k(38, 30)), C_GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_menu_title = t
	var sub: Label = _label(Themes.t("intro_sub"), int(_k(16, 14)), C_TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_menu_sub = sub

	# počítač: vše pod sebou; telefon: levý sloupec = režim a obtížnost, pravý = ostrov a start
	var left: VBoxContainer = v
	var right: VBoxContainer = v
	var colw: float = _k(600, 330)
	if _c:
		var cols: HBoxContainer = HBoxContainer.new()
		cols.add_theme_constant_override("separation", 26)
		v.add_child(cols)
		left = VBoxContainer.new()
		right = VBoxContainer.new()
		for cv in [left, right]:
			(cv as VBoxContainer).add_theme_constant_override("separation", 5)
			(cv as VBoxContainer).custom_minimum_size = Vector2(colw, 0)
			cols.add_child(cv)

	left.add_child(_label("Prostředí", 15, C_DIM))
	var trow: Array = []
	for td in Themes.LIST:
		trow.append([td["id"], td["short"]])
	left.add_child(_toggle_row(trow, _menu_theme, _menu_pick_theme, _menu_theme_btns, "menu_theme_"))
	_menu_theme_desc = _label("", int(_k(13, 12)), C_DIM)
	_menu_theme_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_theme_desc.custom_minimum_size = Vector2(colw, 0)
	left.add_child(_menu_theme_desc)

	left.add_child(_label("Režim", 15, C_DIM))
	left.add_child(_toggle_row([["campaign", "Příběh (12 vln)"], ["endless", "Nekonečný"]], _menu_mode, _menu_pick_mode, _menu_mode_btns, "menu_mode_"))
	_menu_mode_desc = _label("", int(_k(13, 12)), C_DIM)
	_menu_mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_mode_desc.custom_minimum_size = Vector2(colw, 0)
	left.add_child(_menu_mode_desc)

	left.add_child(_label("Obtížnost", 15, C_DIM))
	var drow: Array = []
	for id in Cfg.DIFFICULTY_ORDER:
		drow.append([id, Cfg.DIFFICULTIES[id]["name"]])
	left.add_child(_toggle_row(drow, _menu_diff, _menu_pick_diff, _menu_diff_btns, "menu_diff_"))
	_menu_diff_desc = _label("", int(_k(13, 12)), C_DIM)
	_menu_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_diff_desc.custom_minimum_size = Vector2(colw, 0)
	left.add_child(_menu_diff_desc)

	_menu_place = _label(Themes.t("place"), 15, C_DIM)
	right.add_child(_menu_place)
	var irow: HBoxContainer = HBoxContainer.new()
	irow.add_theme_constant_override("separation", 8)
	var prev: Button = Button.new()
	prev.text = "‹"
	prev.custom_minimum_size = Vector2(_k(46, 52), _k(40, 46))
	_style_button(prev)
	prev.add_theme_font_size_override("font_size", 24)
	prev.pressed.connect(func(): _menu_step_island(-1))
	irow.add_child(prev)
	_ui["menu_island_prev"] = prev
	_menu_island_name = _label("", int(_k(21, 18)), C_TEXT, true)
	_menu_island_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_island_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	irow.add_child(_menu_island_name)
	var nxt: Button = Button.new()
	nxt.text = "›"
	nxt.custom_minimum_size = Vector2(_k(46, 52), _k(40, 46))
	_style_button(nxt)
	nxt.add_theme_font_size_override("font_size", 24)
	nxt.pressed.connect(func(): _menu_step_island(1))
	irow.add_child(nxt)
	_ui["menu_island_next"] = nxt
	right.add_child(irow)
	_menu_island_desc = _label("", int(_k(13, 12)), C_DIM)
	_menu_island_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_island_desc.custom_minimum_size = Vector2(colw, 0)
	right.add_child(_menu_island_desc)
	_menu_rec = _label("", int(_k(15, 14)), C_GREEN)
	_menu_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_menu_rec)

	var btn: Button = Button.new()
	btn.text = "Začít hru"
	btn.custom_minimum_size = Vector2(0, _k(52, 52))
	_style_button(btn, C_GREEN, 14)
	btn.add_theme_font_size_override("font_size", int(_k(22, 20)))
	btn.pressed.connect(func():
		_intro.visible = false
		request_new_game.emit(_menu_mode, _menu_diff, _menu_island, _menu_theme))
	right.add_child(btn)
	_menu_start_btn = btn
	_intro_btn = btn
	_ui["menu_start"] = btn
	var back: Button = Button.new()
	back.text = "Zpět do rozehrané hry"
	back.custom_minimum_size = Vector2(0, _k(38, 44))
	_style_button(back)
	back.add_theme_font_size_override("font_size", 15)
	back.pressed.connect(func(): show_intro(false))
	right.add_child(back)
	_menu_back_btn = back
	_ui["menu_back"] = back
	var hint: Label = _label("Ovládání a pravidla: tlačítko ? nahoře." if _c else "Ovládání a pravidla: tlačítko ? nahoře (nebo klávesa H).", 12, C_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	ov.add_child(p)
	_place(p, Vector2(0.5, 0.5), Vector2(0, 0))
	_intro = ov
	_intro.visible = false
	_root.add_child(_intro)


func _build_help() -> void:
	var body: String = Themes.t("help_intro") + "\n\n"
	if _c:
		body += "• Věž postavíš klepnutím na kartu dole a pak na zvýrazněné pole vedle cesty. Pole se označí a stavbu potvrdíš tlačítkem Postavit (křížek stavbu zruší).\n"
		body += "• Klepnutím na postavenou věž otevřeš její panel: vylepšení, prodej a cíl. Každá úroveň mění vzhled i sílu.\n"
		body += "• Vlnu spustíš tlačítkem vpravo dole. " + Themes.t("help_units") + "\n"
		body += "• Minimapa vlevo ukazuje celý ostrov: klepnutím nebo tažením po ní přesuneš kameru, knoflíkem v rohu ji sbalíš.\n"
		body += "• Zlatá pole na kopcích jsou lepší místa: věž tam dohlédne o 15 % dál, na vrcholu o 30 %.\n"
		body += "• " + Themes.t("help_enemies") + "\n"
		body += "• " + Themes.t("help_abilities_touch") + "\n\n"
		body += "Kamera: jeden prst posouvá, dva prsty přibližují a otáčejí. Zvuk, kvalita, celá obrazovka a nová hra jsou pod tlačítkem „…“ nahoře."
	else:
		body += "• Věže stavíš na zvýrazněná pole vedle cesty – klikni na kartu dole (klávesy 1–4) a pak na pole.\n"
		body += "• Klikni na postavenou věž a vylepši ji. Každá úroveň mění vzhled i sílu (dosah, poškození, rychlost, speciální schopnost).\n"
		body += "• Vlnu spustíš tlačítkem vpravo dole nebo mezerníkem.\n"
		body += "• Minimapa vlevo ukazuje celý ostrov: klikni nebo táhni po ní a kamera se přesune (N ji sbalí).\n"
		body += "• Zlatá pole na kopcích jsou lepší místa: věž tam dohlédne o 15 % dál, na vrcholu (dva kroužky) o 30 %.\n"
		body += "• " + Themes.t("help_units") + "\n"
		body += "• " + Themes.t("help_enemies") + "\n"
		body += "• " + Themes.t("help_abilities") + "\n\n"
		body += "Kamera: pravé tlačítko myši = otáčení, kolečko = zoom, W/A/S/D = posun, Q/E = otáčení, F = rychlost, P = pauza, M = zvuk, F3 = přehled výkonu.\n"
		body += "Na dotykové obrazovce: jeden prst posouvá kameru, dva prsty přibližují a otáčejí; stavbu potvrdíš tlačítkem Postavit."
	var m: Dictionary = _modal("Jak hrát", body, "Zavřít", C_GOLD)
	_help = m["root"]
	(m["button"] as Button).pressed.connect(func(): show_help(false))
	_ui["help_close"] = m["button"]
	_help.visible = false
	_root.add_child(_help)


## Přehled výkonu (klávesa F3): snímky za vteřinu, volání vykreslení, objekty a počty herních prvků.
func _build_stats() -> void:
	_stats_lbl = _label("", 13, Color(0.75, 1.0, 0.8), true)
	_stats_lbl.visible = false
	_stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_stats_lbl, Vector2(0.0, 0.0), Vector2(14, 100))
	_ui["stats"] = _stats_lbl
	_root.add_child(_stats_lbl)


## Tlačítko kvality ukazuje skutečný stav (i když se kvalita nastavila automaticky při startu nebo z testu).
func set_quality_state(high: bool) -> void:
	_high_quality = high
	if _quality_btn != null:
		_quality_btn.text = "Kvalita: vysoká" if high else "Kvalita: nízká"


func toggle_stats() -> void:
	_stats_lbl.visible = not _stats_lbl.visible


func stats_visible() -> bool:
	return _stats_lbl != null and _stats_lbl.visible


func set_stats_text(text: String) -> void:
	if _stats_lbl != null:
		_stats_lbl.text = text


## Panel aktivních schopností vlevo dole: tlačítko s ikonou, klávesou a ukazatelem nabíjení.
func _build_abilities() -> void:
	# počítač: sloupec tlačítek s názvem; telefon: řada malých tlačítek jen s ikonou
	var v: BoxContainer = HBoxContainer.new() if _c else VBoxContainer.new()
	v.add_theme_constant_override("separation", 8 if _c else 6)
	var icons: Dictionary = {}
	for aid in Cfg.ABILITY_ORDER:
		icons[aid] = Themes.ability_icon(aid)
	var cols: Dictionary = {"meteor": Color(1.0, 0.55, 0.25), "blizzard": Color(0.6, 0.88, 1.0), "gold": C_GOLD}
	for id in Cfg.ABILITY_ORDER:
		var spec: Dictionary = Cfg.ABILITIES[id]
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(60, 60) if _c else Vector2(178, 50)
		_style_button(b, cols[id], 12)
		b.tooltip_text = "%s [%s]\n%s\nNabíjení: %d s" % [Themes.ability_name(id), spec["hotkey"], Themes.ability_desc(id), int(spec["cooldown"])]
		var cd: ColorRect = ColorRect.new()
		cd.color = Color(0.0, 0.0, 0.0, 0.55)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd.position = Vector2(2, 2)
		cd.size = Vector2(0, 46)
		b.add_child(cd)
		var h: HBoxContainer = HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER if _c else BoxContainer.ALIGNMENT_BEGIN
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 8)
		h.offset_left = 0 if _c else 10
		h.add_child(IconCtrl.make(icons[id], 34 if _c else 30, cols[id]))
		if not _c:
			var nm: Label = _label(Themes.ability_name(id), 15, C_TEXT, true)
			nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(nm)
		b.add_child(h)
		if not _c:
			var hk: Label = _label("[%s]" % spec["hotkey"], 11, C_DIM)
			hk.position = Vector2(6, 2)
			b.add_child(hk)
		var tl: Label = _label("", 17 if _c else 15, C_GOLD, true)
		if _c:
			tl.set_anchors_preset(Control.PRESET_CENTER)
			tl.grow_horizontal = Control.GROW_DIRECTION_BOTH
			tl.grow_vertical = Control.GROW_DIRECTION_BOTH
		else:
			tl.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			tl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			tl.offset_right = -10
		b.add_child(tl)
		b.pressed.connect(func(): request_ability.emit(id))
		v.add_child(b)
		_ab[id] = {"btn": b, "cd": cd, "lbl": tl, "color": cols[id]}
		_ui["ability_" + id] = b
	_root.add_child(v)
	_place(v, Vector2(0, 1), Vector2(_k(12, 8), _k(12, 8)))
	_ab_box = v
	_ui["ability_box"] = v
	get_viewport().size_changed.connect(_layout_abilities)
	_layout_abilities()


## Na úzké obrazovce by panel schopností zasahoval do karet věží, proto se zvedne nad ně.
func _layout_abilities() -> void:
	if _ab_box == null:
		return
	var lift: float = 112.0 if (not _c and get_viewport().get_visible_rect().size.x < 1020.0) else 0.0
	_ab_box.offset_top = -(_k(12.0, 8.0) + lift)
	_ab_box.offset_bottom = -(_k(12.0, 8.0) + lift)


func _build_end() -> void:
	var m: Dictionary = _modal("Konec hry", "", "Hrát znovu")
	_end = m["root"]
	_end_btn = m["button"]
	_end_title = m["title"]
	_end_body = m["body"]
	(m["button"] as Button).pressed.connect(func():
		_end.visible = false
		request_restart.emit())
	var vb: VBoxContainer = (m["button"] as Button).get_parent()
	_end_menu_btn = Button.new()
	_end_menu_btn.text = Themes.t("menu_change")
	_end_menu_btn.custom_minimum_size = Vector2(0, 42)
	_style_button(_end_menu_btn)
	_end_menu_btn.add_theme_font_size_override("font_size", 16)
	_end_menu_btn.pressed.connect(func():
		_end.visible = false
		show_intro(true))
	vb.add_child(_end_menu_btn)
	_ui["end_menu_btn"] = _end_menu_btn
	_end.visible = false
	_root.add_child(_end)


func _build_pause() -> void:
	var m: Dictionary = _modal("Pozastaveno", "Hra je pozastavena.", "Pokračovat", C_TEXT)
	_pause_ov = m["root"]
	(m["button"] as Button).pressed.connect(func(): request_pause.emit(false))
	_pause_ov.visible = false
	_root.add_child(_pause_ov)


func _build_loading() -> void:
	var ov: ColorRect = ColorRect.new()
	ov.color = Themes.cur().loading_color
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var l: Label = _label(Themes.t("loading"), 34, Color(1, 1, 1), true)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	ov.add_child(l)
	_loading = ov
	_root.add_child(ov)


# ================================================================== veřejné API
## Telefon na výšku: hra by se nedala ovládat, proto se pozastaví a ukáže výzvu k otočení.
func _build_rotate() -> void:
	_rotate_ov = ColorRect.new()
	(_rotate_ov as ColorRect).color = Color(0.05, 0.08, 0.15, 0.96)
	_rotate_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 18)
	var ic: IconCtrl = IconCtrl.make("rotr", 140, C_GOLD)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var l1: Label = _label("Otoč telefon na šířku", 44, C_GOLD, true)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l1)
	var l2: Label = _label("Hra se ovládá na šířku. Mezitím je pozastavená.", 26, C_TEXT)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l2)
	_rotate_ov.add_child(col)
	_rotate_ov.visible = false
	_ui["rotate_overlay"] = _rotate_ov
	_root.add_child(_rotate_ov)


func _update_rotate() -> void:
	if not _c or _rotate_ov == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = vs.y > vs.x
	if _rotate_ov.visible != portrait:
		_rotate_ov.visible = portrait
		if not portrait and _rot_paused:
			_rot_paused = false
			request_pause.emit(false)
	# hra, která běží (nebo se rozběhne po načtení) pod výzvou, se pozastaví; po otočení se zase pustí
	if portrait and not _rot_paused and game != null and not game.paused and not _loading.visible and not _intro.visible and not _end.visible:
		_rot_paused = true
		request_pause.emit(true)


func set_loading(on: bool) -> void:
	_loading.visible = on


## Menu „Nová hra“. Při otevření uprostřed hry nabídne i návrat do rozehrané hry.
func _close_more() -> void:
	if _more_btn != null:
		_more_btn.set_pressed_no_signal(false)
	if _more_panel != null:
		_more_panel.visible = false


func show_intro(on: bool) -> void:
	if on:
		_close_more()
		_menu_mode = GameSettings.mode
		_menu_diff = GameSettings.difficulty
		_menu_island = GameSettings.island
		_menu_theme = GameSettings.theme
		_menu_refresh()
		var in_progress: bool = game != null and (game.waves_started > 0 or game.time > 0.5) and game.state == Game.State.PLAYING
		_menu_back_btn.visible = in_progress
		_menu_start_btn.text = "Nová hra" if in_progress else "Začít hru"
	_intro.visible = on
	if on:
		_help.visible = false
	request_pause.emit(on)


func show_help(on: bool) -> void:
	_close_more()
	_help.visible = on
	if on:
		_intro.visible = false
	request_pause.emit(on)


func refresh_info() -> void:
	if game == null:
		return
	var nm: String = str(_island_def.get("name", ""))
	_info_lbl.text = "%s · %s · %s" % [nm, Cfg.DIFFICULTIES[game.diff_id]["name"], "Nekonečný" if game.is_endless() else "Příběh"]


## Zvýraznění tlačítka Meteor, dokud hráč vybírá místo dopadu.
func set_aim(on: bool) -> void:
	_aiming = on


func set_paused(on: bool) -> void:
	_paused_ui = on
	_pause_icon.set_kind("play" if on else "pause", C_TEXT)
	_pause_ov.visible = on and not _intro.visible and not _end.visible and not _help.visible


func set_speed_label(mult: float) -> void:
	_speed_lbl.text = "%d×" % int(mult)


func _sync_audio_icons() -> void:
	(_sfx_btn.get_meta("icon") as IconCtrl).set_kind("speaker" if _sfx_btn.button_pressed else "speaker_off", C_TEXT)
	(_music_btn.get_meta("icon") as IconCtrl).set_kind("note" if _music_btn.button_pressed else "note_off", C_TEXT)


func set_audio_state(sfx_on: bool, music_on: bool) -> void:
	_sfx_btn.set_pressed_no_signal(sfx_on)
	_music_btn.set_pressed_no_signal(music_on)
	_sync_audio_icons()


func set_auto(on: bool) -> void:
	_auto_on = on
	_auto_btn.set_pressed_no_signal(on)


func set_build_type(type: String) -> void:
	_build_type = type
	for id in _cards.keys():
		(_cards[id]["btn"] as Button).set_pressed_no_signal(id == type)


func show_toast(text: String, kind: String = "info") -> void:
	var col: Color = C_TEXT
	match kind:
		"warn":
			col = Color(1.0, 0.72, 0.4)
		"good":
			col = C_GREEN
	_toast_lbl.text = text
	_toast_lbl.add_theme_color_override("font_color", col)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)


func is_modal_open() -> bool:
	return _intro.visible or _end.visible or _loading.visible or _help.visible or (_rotate_ov != null and _rotate_ov.visible)


# ================================================================== aktualizace
func _on_gold(v: int) -> void:
	_gold_lbl.text = str(v)
	refresh_cards()
	if _selected != null:
		refresh_tower_panel()


func _on_lives(v: int) -> void:
	_lives_lbl.text = str(v)
	_lives_lbl.add_theme_color_override("font_color", C_RED if v <= 5 else C_TEXT)


func _on_wave(started: int, total: int) -> void:
	_wave_lbl.text = ("Vlna %d / %d" % [started, total]) if total > 0 else ("Vlna %d" % started)
	_refresh_wave_panel()


func _on_state(st: int) -> void:
	if st == Game.State.WON:
		_end_title.text = "Vítězství!"
		_end_title.add_theme_color_override("font_color", C_GREEN)
		_end_body.text = _end_stats(Themes.t("won") % game.total_waves)
		_end.visible = true
	elif st == Game.State.LOST:
		_end_title.text = "Konec hry"
		_end_title.add_theme_color_override("font_color", C_RED)
		if game.is_endless():
			_end_body.text = _end_stats("%s Nekonečný režim: došel jsi do vlny %d." % [Themes.t("base_fell"), maxi(game.waves_started, 1)])
		else:
			_end_body.text = _end_stats(Themes.t("base_fell") + " Zkus to znovu s jinou strategií.")
		_end.visible = true


func _end_stats(headline: String) -> String:
	var cleared: int = game.best_wave
	var waves_txt: String = ("%d / %d" % [cleared, game.total_waves]) if game.total_waves > 0 else str(cleared)
	var rec: String = GameSettings.record_text("%s_%s_%d" % [game.mode_id, game.diff_id, GameSettings.island])
	return "%s\n\nZvládnuté vlny: %s\nPoražení nepřátelé: %d\nUplynulý herní čas: %d s\nPostavené věže: %d\nSchopnosti použity: %d×\nRekord (%s, %s): %s" % [
		headline, waves_txt, game.kills, int(game.time), game.towers_built, _abilities_total(),
		Cfg.DIFFICULTIES[game.diff_id]["name"], "nekonečný" if game.is_endless() else "příběh", rec]


func _abilities_total() -> int:
	var n: int = 0
	for k in game.abilities_used.keys():
		n += int(game.abilities_used[k])
	return n


## Pro testy: názvy na kartách věží a popisky schopností (podle aktivního motivu).
func card_names() -> Dictionary:
	var out: Dictionary = {}
	for id in _cards.keys():
		out[id] = (_cards[id]["name"] as Label).text
	return out


func ability_tips() -> Dictionary:
	var out: Dictionary = {}
	for id in _ab.keys():
		out[id] = (_ab[id]["btn"] as Button).tooltip_text
	return out


func refresh_cards() -> void:
	if game == null:
		return
	for id in _cards.keys():
		var cost: int = Cfg.tower_cost(id)
		var ok: bool = game.gold >= cost
		(_cards[id]["cost"] as Label).add_theme_color_override("font_color", C_GOLD if ok else C_RED)
		(_cards[id]["btn"] as Button).modulate = Color(1, 1, 1, 1) if ok else Color(0.78, 0.78, 0.85, 0.9)


func _refresh_wave_panel() -> void:
	if game == null:
		return
	for c in _wave_rows.get_children():
		c.queue_free()
	var next_idx: int = game.waves_started
	if game.total_waves > 0 and next_idx >= game.total_waves:
		_wave_title.text = "Všechny vlny spuštěny"
		_wave_btn.disabled = true
		_wave_btn.text = "Poslední vlna probíhá"
		return
	_wave_title.text = ("Další: vlna %d / %d" % [next_idx + 1, game.total_waves]) if game.total_waves > 0 else ("Další: vlna %d" % (next_idx + 1))
	var has_air: bool = false
	for it in game.wave_preview(next_idx):
		var spec: Dictionary = Cfg.ENEMIES[it["type"]]
		var r: HBoxContainer = HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.add_child(IconCtrl.make("dot", _k(16, 13), Themes.enemy_color(str(it["type"]))))
		r.add_child(_label("%s × %d" % [Themes.enemy_name(str(it["type"])), it["count"]], int(_k(14, 12)), C_TEXT))
		if spec.has("tip") and not _c:
			r.tooltip_text = "%s: %s" % [Themes.enemy_name(str(it["type"])), Themes.enemy_tip(str(it["type"]))]
			r.mouse_filter = Control.MOUSE_FILTER_STOP
		if bool(spec["flying"]):
			has_air = true
		_wave_rows.add_child(r)
	if has_air:
		var w: HBoxContainer = HBoxContainer.new()
		w.add_theme_constant_override("separation", 6)
		w.add_child(IconCtrl.make("warn", _k(16, 13), Color(1.0, 0.72, 0.3)))
		w.add_child(_label("Létající – %s je nezasáhne" % Themes.tower_name("cannon").to_lower(), int(_k(13, 11)), Color(1.0, 0.72, 0.3)))
		_wave_rows.add_child(w)
	# víc bran / rozcestí: připomenutí, že nepřátelé přicházejí z více stran
	var gates: int = game.map.portals.size()
	var forks: int = 0
	for pt in game.map.portals:
		if (pt["lanes"] as Array).size() > 1:
			forks += 1
	if gates > 1 or forks > 0:
		var gl: HBoxContainer = HBoxContainer.new()
		gl.add_theme_constant_override("separation", 6)
		gl.add_child(IconCtrl.make("dot", _k(16, 13), Color(0.75, 0.55, 1.0)))
		var gtxt: String = "Vchody: %d" % gates
		if forks > 0:
			gtxt += ", rozcestí"
		elif game.map.lane_count() > gates:
			gtxt += ", cesty se větví"
		gl.add_child(_label(gtxt, int(_k(13, 11)), Color(0.78, 0.66, 1.0)))
		_wave_rows.add_child(gl)
	_wave_btn.disabled = not game.can_start_wave()
	_wave_btn.text = _wave_btn_text(game.can_start_wave())


func show_tower(t: Tower) -> void:
	_selected = t
	_tower_panel.visible = t != null
	if _c and _wave_panel != null:
		_wave_panel.visible = t == null          # na telefonu je panel věže na stejném místě jako panel vlny
	refresh_tower_panel()


func _rows_for(type: String, level: int, elev: int = 0) -> Array:
	## Řádky statistik: [název, text, číselná hodnota (pro porovnání)]; dosah zahrnuje bonus výšky pole (0 rovina, 1 kopec, 2 vrchol)
	var st: Dictionary = Cfg.tower_level(type, level).duplicate()
	st["range"] = float(st["range"]) * float(Cfg.ELEV_RANGE[elev])
	var rng_note: String = "" if elev == 0 else " (%s +%d %%)" % [Cfg.ELEV_NAMES[elev], int(round((float(Cfg.ELEV_RANGE[elev]) - 1.0) * 100.0))]
	var rows: Array = []
	var cd: float = float(st["cooldown"])
	match type:
		"archer":
			rows.append(["Poškození", "%d × %d" % [int(st["damage"]), int(st["shots"])], float(st["damage"]) * float(st["shots"])])
			rows.append(["Dosah", Cfg.fmt(float(st["range"])) + " m" + rng_note, float(st["range"])])
			rows.append(["Rychlost", Cfg.fmt(1.0 / cd, 2) + " /s", 1.0 / cd])
			rows.append(["Kritický zásah", "%d %%" % int(round(float(st["crit"]) * 100.0)), float(st["crit"])])
			rows.append(["Probití brnění", "%d %%" % int(round(float(st["pierce"]) * 100.0)), float(st["pierce"])])
		"cannon":
			rows.append(["Poškození", str(int(st["damage"])), float(st["damage"])])
			rows.append(["Výbuch", Cfg.fmt(float(st["splash"])) + " m", float(st["splash"])])
			rows.append(["Dosah", Cfg.fmt(float(st["range"])) + " m" + rng_note, float(st["range"])])
			rows.append(["Rychlost", Cfg.fmt(1.0 / cd, 2) + " /s", 1.0 / cd])
			rows.append(["Hoření", ("%d /s" % int(st["burn"])) if float(st["burn"]) > 0.0 else "–", float(st["burn"])])
			rows.append(["Omráčení", (Cfg.fmt(float(st["stun"])) + " s") if float(st["stun"]) > 0.0 else "–", float(st["stun"])])
		"mage":
			rows.append(["Poškození", str(int(st["damage"])), float(st["damage"])])
			rows.append(["Dosah", Cfg.fmt(float(st["range"])) + " m" + rng_note, float(st["range"])])
			rows.append(["Rychlost", Cfg.fmt(1.0 / cd, 2) + " /s", 1.0 / cd])
			rows.append(["Řetězení", ("%d cílů" % int(st["chain"])) if int(st["chain"]) > 0 else "–", float(st["chain"])])
		_:
			rows.append(["Poškození / pulz", str(int(st["damage"])), float(st["damage"])])
			rows.append(["Dosah", Cfg.fmt(float(st["range"])) + " m" + rng_note, float(st["range"])])
			rows.append(["Pulz každých", Cfg.fmt(cd) + " s", 1.0 / cd])
			rows.append(["Zpomalení", "%d %%" % int(round(float(st["slow"]) * 100.0)), float(st["slow"])])
			rows.append(["Zmrazení", ("%s s / každý %d." % [Cfg.fmt(float(st["freeze_time"])), int(st["freeze_every"])]) if int(st["freeze_every"]) > 0 else "–", float(st["freeze_time"])])
	rows.append(["DPS (orient.)", str(int(round(Cfg.dps_of(type, level)))), Cfg.dps_of(type, level)])
	return rows


func refresh_tower_panel() -> void:
	if _selected == null or not is_instance_valid(_selected):
		_tower_panel.visible = false
		if _c and _wave_panel != null:
			_wave_panel.visible = true
		return
	var t: Tower = _selected
	var spec: Dictionary = Cfg.TOWERS[t.type]
	(_tp["icon"] as IconCtrl).set_kind(Themes.tower_icon(t.type), Themes.tower_color(t.type))
	(_tp["title"] as Label).text = Themes.tower_name(t.type)
	(_tp["level"] as Label).text = "Úroveň %d / %d" % [t.level, Cfg.MAX_LEVEL]
	var stars: Array = _tp["stars"]
	for i in range(stars.size()):
		(stars[i] as IconCtrl).set_kind("star", C_GOLD if i < t.level else Color(0.3, 0.33, 0.4))
	var grid: GridContainer = _tp["grid"]
	for c in grid.get_children():
		c.queue_free()
	var cur: Array = _rows_for(t.type, t.level, t.elev)
	var nxt: Array = _rows_for(t.type, t.level + 1, t.elev) if t.can_upgrade() else []
	for i2 in range(cur.size()):
		grid.add_child(_label(str(cur[i2][0]), int(_k(14, 12)), C_DIM))
		grid.add_child(_label(str(cur[i2][1]), int(_k(15, 13)), C_TEXT))
		if nxt.size() > i2 and not is_equal_approx(float(cur[i2][2]), float(nxt[i2][2])):
			grid.add_child(_label("› " + str(nxt[i2][1]), int(_k(15, 13)), C_GREEN))
		else:
			grid.add_child(_label("", int(_k(14, 12)), C_DIM))
	var note: Label = _tp["note"]
	if t.can_upgrade():
		note.text = "Další úroveň: " + Themes.level_note(t.type, t.level + 1)
	else:
		note.text = "Maximální úroveň. " + Themes.level_note(t.type, t.level)
	(_tp["stat"] as Label).text = "Zabito: %d   ·   Způsobeno poškození: %d" % [t.kills, int(t.damage_dealt)]
	var up: Button = _tp["upgrade"]
	if t.can_upgrade():
		var cost: int = t.upgrade_cost()
		up.text = ("Vylepšit  (%d %s)" % [cost, Themes.t("gold_gen")]) if _c else ("Vylepšit na úroveň %d  (%d %s)" % [t.level + 1, cost, Themes.t("gold_gen")])
		up.disabled = game.gold < cost
	else:
		up.text = "Maximální úroveň"
		up.disabled = true
	(_tp["sell"] as Button).text = "Prodat (+%d)" % t.sell_value()
	(_tp["target"] as Button).text = "Cíl: " + str(Cfg.TARGET_NAMES[t.target_mode])


func _cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % 3
	var m: float = [1.0, 2.0, 3.0][_speed_idx]
	set_speed_label(m)
	request_speed.emit(m)


func cycle_speed() -> void:
	_cycle_speed()


func _update_abilities() -> void:
	if game == null:
		return
	for id in _ab.keys():
		var e: Dictionary = _ab[id]
		var spec: Dictionary = Cfg.ABILITIES[id]
		var cd: float = float(game.ability_cd.get(id, 0.0))
		var frac: float = clampf(cd / float(spec["cooldown"]), 0.0, 1.0)
		var btn: Button = e["btn"]
		(e["cd"] as ColorRect).size = Vector2(btn.size.x - 4.0, (btn.size.y - 4.0) * frac)
		var lbl: Label = e["lbl"]
		if id == "gold" and game.gold_boost_t > 0.0:
			lbl.text = "%d s" % int(ceil(game.gold_boost_t))
			lbl.add_theme_color_override("font_color", C_GREEN)
		elif cd > 0.0:
			lbl.text = "%d" % int(ceil(cd))
			lbl.add_theme_color_override("font_color", C_GOLD)
		else:
			lbl.text = ""
		btn.modulate = Color(1, 1, 1, 1) if cd <= 0.0 else Color(0.85, 0.85, 0.92, 0.95)
		if id == "meteor" and _aiming:
			btn.modulate = Color(1.0, 0.8, 0.6, 1.0)


func _process(delta: float) -> void:
	_update_rotate()
	_update_abilities()
	_refresh_t += delta
	if _refresh_t >= 0.25:
		_refresh_t = 0.0
		if game != null:
			if _selected != null and is_instance_valid(_selected):
				(_tp["stat"] as Label).text = "Zabito: %d   ·   Způsobeno poškození: %d" % [_selected.kills, int(_selected.damage_dealt)]
			var can: bool = game.can_start_wave()
			if _wave_btn != null and (game.total_waves == 0 or game.waves_started < game.total_waves):
				_wave_btn.disabled = not can
				_wave_btn.text = _wave_btn_text(can)


## Obdélník ovládacího prvku v souřadnicích viewportu (pro automatické testy klikáním).
func ui_rect(nm: String) -> Rect2:
	var c: Control = null
	if _ui.has(nm):
		c = _ui[nm]
	match nm:
		"intro_btn":
			c = _intro_btn
		"end_btn":
			c = _end_btn
		"wave_btn":
			c = _wave_btn
		"upgrade_btn":
			c = _tp["upgrade"]
		"sell_btn":
			c = _tp["sell"]
		"target_btn":
			c = _tp["target"]
		"speed_btn":
			c = _speed_btn
		"pause_btn":
			c = _pause_btn
		"sfx_btn":
			c = _sfx_btn
		"music_btn":
			c = _music_btn
		_:
			if nm.begins_with("card_") and _cards.has(nm.substr(5)):
				c = _cards[nm.substr(5)]["btn"]
	if c == null or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()
