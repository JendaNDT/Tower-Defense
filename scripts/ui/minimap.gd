class_name Minimap
extends Control
## Kruhová minimapa ostrova: terén, cesty, řeka, kopce, portály, Srdce, věže a nepřátelé, plus výřez kamery.
## Otáčí se spolu s kamerou (nahoře je směr pohledu, takže odpovídá obrazu). Klepnutí nebo tažení přesune kameru.
## Obrázek terénu se vyrobí jednou z dat mapy; věže a nepřátelé se kreslí každý okamžik jako body.

signal jump_requested(world_xz: Vector2)

const WORLD_R: float = 48.0          # poloměr zobrazené oblasti světa (m)
const IMG: int = 128                 # rozlišení obrázku terénu

var game: Game = null
var rig = null
var collapsed: bool = false

var _tex: ImageTexture = null
var _full: float = 180.0             # velikost rozbalené minimapy (px)
var _ppm: float = 1.0                # pixelů na metr
var _t: float = 0.0
var _dragging: bool = false
var _c_bg: Color
var _c_edge: Color
var _c_portal: Color
var _c_view: Color = Color(1.0, 1.0, 1.0, 0.9)


func setup(g: Game, size_px: float) -> void:
	game = g
	rig = g.camera_rig
	_full = size_px
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_c_bg = Themes.pal("mm_bg")
	_c_edge = Themes.pal("mm_edge")
	_c_portal = Themes.pal("mm_portal")
	_tex = ImageTexture.create_from_image(_make_image(g.map))
	_apply_size()


func _apply_size() -> void:
	var s: float = 34.0 if collapsed else _full
	custom_minimum_size = Vector2(s, s)
	size = Vector2(s, s)
	_ppm = (_full * 0.5 - 2.0) / WORLD_R
	queue_redraw()


func toggle() -> void:
	collapsed = not collapsed
	_apply_size()


# ------------------------------------------------------------------ obrázek terénu
func _make_image(map: GameMap) -> Image:
	var t: Terrain = map.terrain
	var forest: Color = Themes.pal("mm_forest")
	var meadow: Color = Themes.pal("mm_meadow")
	var desert: Color = Themes.pal("mm_desert")
	var snow: Color = Themes.pal("mm_snow")
	var path_c: Color = Themes.pal("mm_path")
	var water_c: Color = Themes.pal("mm_water")
	var hill_c: Color = Themes.pal("mm_hill")
	var img: Image = Image.create(IMG, IMG, false, Image.FORMAT_RGBA8)
	for iy in range(IMG):
		for ix in range(IMG):
			var x: float = (float(ix) + 0.5) / float(IMG) * 2.0 * WORLD_R - WORLD_R
			var z: float = (float(iy) + 0.5) / float(IMG) * 2.0 * WORLD_R - WORLD_R
			var ed: float = t.edge_dist(x, z)
			if ed < -0.4:
				img.set_pixel(ix, iy, Color(0, 0, 0, 0))
				continue
			var bw: Color = t.biome_weights(x, z)
			var col: Color = forest * bw.r + meadow * bw.g + desert * bw.b + snow * bw.a
			col.a = 1.0
			var h: float = t.height_at(x, z)
			var shade: float = 0.9 + 0.07 * clampf(h, -0.5, 2.6)
			col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
			var wk: float = t.hill_weights(x, z).x if not t.hills.is_empty() else 0.0
			if wk > 0.0:
				col = col.lerp(hill_c, smoothstep(0.35, 0.95, wk) * 0.55)
			var rsd: float = t.river_sd_at(x, z)
			if rsd < 1.2:
				col = col.lerp(water_c, 1.0 - smoothstep(0.0, 1.2, rsd))
			var pd: float = t.path_dist_at(x, z)
			if pd < 1.9:
				col = col.lerp(path_c, 1.0 - smoothstep(1.0, 1.9, pd))
			var rim: float = 1.0 - smoothstep(0.0, 1.6, ed)
			col = col.lerp(col.darkened(0.45), rim * 0.7)
			col.a = clampf((ed + 0.4) / 0.8, 0.0, 1.0)
			img.set_pixel(ix, iy, col)
	return img


# ------------------------------------------------------------------ kreslení
func _process(delta: float) -> void:
	if not visible or game == null:
		return
	_t += delta
	if _t >= 0.08:
		_t = 0.0
		queue_redraw()


## Světový bod (x, z) -> bod v obrazovce minimapy (kruh se středem `c`, otočený podle kamery).
func _to_px(wp: Vector2, yaw: float, c: Vector2) -> Vector2:
	var cs: float = cos(yaw)
	var sn: float = sin(yaw)
	return c + Vector2(wp.x * cs - wp.y * sn, wp.x * sn + wp.y * cs) * _ppm


func _from_px(p: Vector2, yaw: float, c: Vector2) -> Vector2:
	var v: Vector2 = (p - c) / _ppm
	var cs: float = cos(yaw)
	var sn: float = sin(yaw)
	return Vector2(v.x * cs + v.y * sn, -v.x * sn + v.y * cs)


func _draw() -> void:
	if game == null:
		return
	if collapsed:
		var cc: Vector2 = size * 0.5
		draw_circle(cc, 15.0, _c_bg)
		draw_arc(cc, 15.0, 0.0, TAU, 28, _c_edge, 2.0)
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -7), cc + Vector2(7, 0), cc + Vector2(0, 7), cc + Vector2(-7, 0)]), _c_edge)
		return
	var c: Vector2 = size * 0.5
	var r: float = _full * 0.5 - 1.0
	var yaw: float = deg_to_rad(rig.yaw_deg) if rig != null else 0.0
	draw_circle(c, r, _c_bg)
	# terén (obrázek je ve světových osách; otočí se podle kamery)
	draw_set_transform(c, yaw, Vector2.ONE)
	var half: float = WORLD_R * _ppm
	draw_texture_rect(_tex, Rect2(-half, -half, half * 2.0, half * 2.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# portály a Srdce
	for pt in game.map.portals:
		var pp: Vector3 = pt["pos"]
		var q: Vector2 = _to_px(Vector2(pp.x, pp.z), yaw, c)
		draw_circle(q, 4.2, Color(0.1, 0.05, 0.2, 0.9))
		draw_arc(q, 4.2, 0.0, TAU, 16, _c_portal, 2.0)
	var bp: Vector3 = game.map.base_pos
	var bq: Vector2 = _to_px(Vector2(bp.x, bp.z), yaw, c)
	draw_colored_polygon(PackedVector2Array([bq + Vector2(0, -6), bq + Vector2(5, 0), bq + Vector2(0, 6), bq + Vector2(-5, 0)]), Color(1.0, 0.45, 0.8))
	draw_polyline(PackedVector2Array([bq + Vector2(0, -6), bq + Vector2(5, 0), bq + Vector2(0, 6), bq + Vector2(-5, 0), bq + Vector2(0, -6)]), Color(1, 1, 1), 1.2)
	# věže
	for t in game.towers:
		var tw: Tower = t
		var tq: Vector2 = _to_px(Vector2(tw.position.x, tw.position.z), yaw, c)
		draw_circle(tq, 3.0, Color(0.05, 0.07, 0.12))
		draw_circle(tq, 2.2, Themes.tower_color(tw.type))
	# nepřátelé
	for e in game.enemies:
		var en: Enemy = e
		var eq: Vector2 = _to_px(Vector2(en.position.x, en.position.z), yaw, c)
		var big: bool = en.type == "boss" or en.type == "golem"
		draw_circle(eq, 2.6 if big else 1.8, Color(1.0, 0.82, 0.3) if en.flying else Color(1.0, 0.28, 0.24))
	# výřez kamery
	if rig != null:
		var piv: Vector2 = Vector2(rig.position.x, rig.position.z)
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var aspect: float = vp.x / maxf(vp.y, 1.0)
		var hw: float = float(rig.zoom_size) * aspect * 0.5
		var hh: float = float(rig.zoom_size) * 0.5 / sin(deg_to_rad(CameraRig.PITCH_DEG))
		var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
		var fwd: Vector2 = Vector2(-sin(yaw), -cos(yaw))
		var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]
		var prev: Vector2 = Vector2.ZERO
		var have_prev: bool = false
		for ci in range(corners.size() - 1):
			var ca: Vector2 = corners[ci]
			var cb: Vector2 = corners[ci + 1]
			for k in range(0, 41):
				var tk: Vector2 = ca.lerp(cb, float(k) / 40.0)
				var q: Vector2 = _to_px(piv + right * hw * tk.x + fwd * hh * tk.y, yaw, c)
				var inside: bool = q.distance_to(c) < r - 1.5
				if inside and have_prev:
					draw_line(prev, q, Color(0.0, 0.0, 0.0, 0.5), 3.0)
					draw_line(prev, q, _c_view, 1.5)
				prev = q
				have_prev = inside
	draw_arc(c, r, 0.0, TAU, 64, _c_edge, 2.5)
	# knoflík pro sbalení
	var kc: Vector2 = Vector2(size.x - 13.0, 13.0)
	draw_circle(kc, 10.0, _c_bg)
	draw_arc(kc, 10.0, 0.0, TAU, 20, _c_edge, 1.5)
	draw_line(kc + Vector2(-4.0, 0.0), kc + Vector2(4.0, 0.0), _c_edge, 2.0)
	# značka „sever“ není potřeba (mapa se otáčí podle pohledu); malá šipka nahoře ukazuje směr pohledu kamery
	draw_colored_polygon(PackedVector2Array([Vector2(c.x, 2.0), Vector2(c.x - 4.0, 9.0), Vector2(c.x + 4.0, 9.0)]), _c_edge)


# ------------------------------------------------------------------ ovládání
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if collapsed:
				toggle()
				accept_event()
				return
			# rohový „knoflík“ vpravo nahoře sbalí minimapu
			if mb.position.distance_to(Vector2(size.x - 14.0, 14.0)) < 13.0:
				toggle()
				accept_event()
				return
			_dragging = true
			_jump(mb.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_jump((event as InputEventMouseMotion).position)
		accept_event()


func _jump(p: Vector2) -> void:
	var c: Vector2 = size * 0.5
	if p.distance_to(c) > _full * 0.5:
		return
	var yaw: float = deg_to_rad(rig.yaw_deg) if rig != null else 0.0
	jump_requested.emit(_from_px(p, yaw, c))
