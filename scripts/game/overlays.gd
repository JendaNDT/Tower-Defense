class_name Overlays
extends Node3D
## Pomocná vizualizace při hraní: mřížka stavitelných polí, kruh dosahu věže a „duch“ věže při stavění.

const SH_GRID: Shader = preload("res://shaders/grid.gdshader")

var map: GameMap = null
var theme: GameTheme = null

var _grid: MeshInstance3D = null
var _range: MeshInstance3D = null
var _range_mat: ShaderMaterial = null
var _ghost: TowerVisual = null
var _ghost_type: String = ""
var _ghost_mat: ShaderMaterial = null
var _sel: MeshInstance3D = null
var _last_range_key: String = ""
var _last_sel_key: String = ""
var _grid_build: bool = false       # mřížku chce stavební režim
var _grid_pinned: bool = false      # mřížku si hráč zapnul trvale (G / tlačítko)


func setup(map_ref: GameMap, theme_ref: GameTheme) -> void:
	map = map_ref
	theme = theme_ref
	name = "Overlays"
	_grid = MeshInstance3D.new()
	var gm: ShaderMaterial = ShaderMaterial.new()
	gm.shader = SH_GRID
	_grid.material_override = gm
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.visible = false
	add_child(_grid)
	_range = MeshInstance3D.new()
	_range_mat = ShaderMaterial.new()
	_range_mat.shader = Gfx.SH_GHOST
	_range.material_override = _range_mat
	_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range.visible = false
	add_child(_range)
	_sel = MeshInstance3D.new()
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = Gfx.SH_GHOST
	sm.set_shader_parameter("color", Themes.pal("select_ring"))
	sm.set_shader_parameter("fill_alpha", 0.0)
	sm.set_shader_parameter("ring_alpha", 0.95)
	sm.set_shader_parameter("ring_w", 0.1)
	_sel.material_override = sm
	_sel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sel.visible = false
	add_child(_sel)
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = Gfx.SH_MODEL
	_ghost_mat.set_shader_parameter("roughness_v", 0.8)
	rebuild_grid()


# ------------------------------------------------------------------ mřížka
func rebuild_grid() -> void:
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	var sub: int = 3
	var inset: float = 0.05
	for cz in range(Cfg.GRID_H):
		for cx in range(Cfg.GRID_W):
			if map.cell_state(Vector2i(cx, cz)) != GameMap.Cell.FREE:
				continue
			var c: Vector2 = Cfg.cell_center(cx, cz)
			var base: int = verts.size()
			var tier: int = map.elev_at(Vector2i(cx, cz))
			var tcol: Color = Color(1.0, 1.0, 1.0, float(tier) * 0.5)       # alfa = výškový stupeň (0, 0.5, 1) pro shader mřížky
			var half: float = Cfg.CELL * 0.5 - inset
			for iz in range(sub + 1):
				for ix in range(sub + 1):
					var u: float = float(ix) / float(sub)
					var v: float = float(iz) / float(sub)
					var x: float = c.x - half + u * half * 2.0
					var z: float = c.y - half + v * half * 2.0
					verts.append(Vector3(x, map.height_at(x, z) + 0.07, z))
					uvs.append(Vector2(u, v))
					cols.append(tcol)
			for iz2 in range(sub):
				for ix2 in range(sub):
					var a: int = base + iz2 * (sub + 1) + ix2
					var b: int = a + 1
					var cc: int = a + (sub + 1)
					var d: int = cc + 1
					WorldMeshes._append_up_tri(verts, idx, a, b, cc)
					WorldMeshes._append_up_tri(verts, idx, b, d, cc)
	if verts.size() == 0:
		_grid.mesh = null
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_grid.mesh = mesh


func show_grid(on: bool) -> void:
	_grid_build = on
	_grid.visible = _grid_build or _grid_pinned


## Trvale zapnutá mřížka (hráč ji vidí i mimo stavbu).
func set_grid_pinned(on: bool) -> void:
	_grid_pinned = on
	_grid.visible = _grid_build or _grid_pinned


func is_grid_pinned() -> bool:
	return _grid_pinned


# ------------------------------------------------------------------ dosah
func _disc_mesh(center: Vector3, radius: float) -> ArrayMesh:
	var segs: int = 72
	var rings: int = 8
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	for r in range(rings + 1):
		var u: float = float(r) / float(rings)
		for i in range(segs):
			var a: float = TAU * float(i) / float(segs)
			var x: float = center.x + cos(a) * radius * u
			var z: float = center.z + sin(a) * radius * u
			verts.append(Vector3(x, map.height_at(x, z) + 0.1, z))
			uvs.append(Vector2(u, 0.0))
	for r2 in range(rings):
		for i2 in range(segs):
			var i3: int = (i2 + 1) % segs
			var a0: int = r2 * segs + i2
			var b0: int = r2 * segs + i3
			var c0: int = (r2 + 1) * segs + i2
			var d0: int = (r2 + 1) * segs + i3
			WorldMeshes._append_up_tri(verts, idx, a0, b0, c0)
			WorldMeshes._append_up_tri(verts, idx, b0, d0, c0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func show_range(center: Vector3, radius: float, color: Color) -> void:
	var key: String = "%.2f_%.2f_%.2f" % [center.x, center.z, radius]
	if key != _last_range_key:
		_last_range_key = key
		_range.mesh = _disc_mesh(center, radius)
	_range_mat.set_shader_parameter("color", color)
	_range.visible = true


func hide_range() -> void:
	_range.visible = false
	_last_range_key = ""


func show_selection(center: Vector3) -> void:
	var key: String = "%.2f_%.2f" % [center.x, center.z]
	if key != _last_sel_key:
		_last_sel_key = key
		_sel.mesh = _disc_mesh(center, 1.15)
	_sel.visible = true


func hide_selection() -> void:
	_sel.visible = false
	_last_sel_key = ""


# ------------------------------------------------------------------ duch věže
func show_ghost(type: String, pos: Vector3, valid: bool) -> void:
	if _ghost == null or _ghost_type != type:
		if _ghost != null:
			_ghost.queue_free()
		_ghost = theme.make_tower_visual(type, 1)
		_ghost_type = type
		add_child(_ghost)
		_apply_ghost_material(_ghost)
	_ghost.visible = true
	_ghost.position = pos
	var col: Color = Color(0.45, 1.0, 0.55, 0.55) if valid else Color(1.0, 0.35, 0.3, 0.6)
	_ghost_mat.set_shader_parameter("tint", col)


func hide_ghost() -> void:
	if _ghost != null:
		_ghost.visible = false


func _apply_ghost_material(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).material_override = _ghost_mat
			(ch as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_ghost_material(ch)
