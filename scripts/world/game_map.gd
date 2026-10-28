class_name GameMap
extends RefCounted
## Herní mapa: terén + trasa + mřížka stavitelných buněk + překážky (stromy, skály).
## Mapa je nezávislá na grafice – stejná data používá hra i vykreslení světa.

enum Cell { FREE, PATH, WATER, BLOCKED, VOID, BASE, TOWER }

var terrain: Terrain
var cells: PackedInt32Array = PackedInt32Array()
var obstacles: Array = []          # {cell: Vector2i, pos: Vector3, kind: String, biome: int}
var spawn_pos: Vector3 = Vector3.ZERO
var base_pos: Vector3 = Vector3.ZERO
var bridge_s0: float = -1.0        # úsek trasy, který vede přes řeku (vzdálenost podél trasy)
var bridge_s1: float = -1.0
var map_seed: int = 7
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_in: int = 7) -> void:
	map_seed = seed_in
	_rng.seed = seed_in * 7919 + 13


func path() -> PathData:
	return terrain.path


func build() -> void:
	terrain = Terrain.new(map_seed)

	# --- polyline trasy ve světových souřadnicích
	var poly: Array = []
	var first: Vector2 = Cfg.cell_center(Cfg.PATH_CELLS[0].x, Cfg.PATH_CELLS[0].y)
	var px: float = first.x
	while terrain.edge_dist(px, first.y) > 1.6 and px > -Terrain.HALF + 1.0:
		px -= 0.25
	poly.append(Vector2(px, first.y))
	for i in range(Cfg.PATH_CELLS.size()):
		var cc: Vector2i = Cfg.PATH_CELLS[i]
		var w: Vector2 = Cfg.cell_center(cc.x, cc.y)
		if i == Cfg.PATH_CELLS.size() - 1:
			w = Vector2(Cfg.cell_center(Cfg.BASE_CELL.x, Cfg.BASE_CELL.y).x - Cfg.CELL * 0.5 + 0.4, w.y)
		poly.append(w)

	terrain.generate(poly, Cfg.RIVER_POINTS)

	var p: PathData = terrain.path
	spawn_pos = p.pos_at(0.0)
	base_pos = p.pos_at(p.length)

	_find_bridge()
	_classify_cells()
	_place_obstacles()


func _find_bridge() -> void:
	var p: PathData = terrain.path
	var i0: int = -1
	var i1: int = -1
	for i in range(p.pts.size()):
		var sd: float = terrain.river_sd_at(p.pts[i].x, p.pts[i].y)
		if sd < 1.3:
			if i0 < 0:
				i0 = i
			i1 = i
	if i0 >= 0:
		bridge_s0 = maxf(float(i0) * PathData.STEP - 1.0, 0.0)
		bridge_s1 = minf(float(i1) * PathData.STEP + 1.0, p.length)


func is_on_bridge(s: float) -> bool:
	return bridge_s0 >= 0.0 and s >= bridge_s0 and s <= bridge_s1


func _classify_cells() -> void:
	cells.resize(Cfg.GRID_W * Cfg.GRID_H)
	for cz in range(Cfg.GRID_H):
		for cx in range(Cfg.GRID_W):
			var c: Vector2 = Cfg.cell_center(cx, cz)
			var st: int = Cell.FREE
			if terrain.edge_dist(c.x, c.y) < 3.2:
				st = Cell.VOID
			elif terrain.river_sd_at(c.x, c.y) < 1.5:
				st = Cell.WATER
			elif terrain.path_dist_at(c.x, c.y) < 1.45:
				st = Cell.PATH
			cells[cz * Cfg.GRID_W + cx] = st
	cells[Cfg.BASE_CELL.y * Cfg.GRID_W + Cfg.BASE_CELL.x] = Cell.BASE


func _near_path_cell(cx: int, cz: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = Vector2i(cx + dx, cz + dz)
			if Cfg.cell_valid(c) and cells[c.y * Cfg.GRID_W + c.x] == Cell.PATH:
				return true
	return false


func _place_obstacles() -> void:
	obstacles.clear()
	for cz in range(Cfg.GRID_H):
		for cx in range(Cfg.GRID_W):
			if cells[cz * Cfg.GRID_W + cx] != Cell.FREE:
				continue
			var c: Vector2 = Cfg.cell_center(cx, cz)
			var bw: Color = terrain.biome_weights(c.x, c.y)
			var prob: float = bw.r * 0.22 + bw.g * 0.08 + bw.b * 0.12 + bw.a * 0.15
			if _near_path_cell(cx, cz):
				prob *= 0.55
			if _rng.randf() > prob:
				continue
			var biome: int = terrain.dominant_biome(c.x, c.y)
			var kind: String = _obstacle_kind(biome)
			var off: Vector2 = Vector2(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.25, 0.25))
			var wx: float = c.x + off.x
			var wz: float = c.y + off.y
			cells[cz * Cfg.GRID_W + cx] = Cell.BLOCKED
			obstacles.append({
				"cell": Vector2i(cx, cz),
				"pos": Vector3(wx, terrain.height_at(wx, wz), wz),
				"kind": kind,
				"biome": biome,
			})


func _obstacle_kind(biome: int) -> String:
	var r: float = _rng.randf()
	match biome:
		0:  # les
			if r < 0.45:
				return "pine"
			if r < 0.80:
				return "oak"
			return "rock"
		1:  # louka
			if r < 0.5:
				return "oak"
			if r < 0.8:
				return "bush"
			return "rock"
		2:  # poušť
			if r < 0.45:
				return "cactus"
			if r < 0.65:
				return "palm"
			return "rock"
		_:  # sníh
			if r < 0.6:
				return "pine_snow"
			return "rock"


# ------------------------------------------------------------------ dotazy
func height_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


func cell_state(c: Vector2i) -> int:
	if not Cfg.cell_valid(c):
		return Cell.VOID
	return cells[c.y * Cfg.GRID_W + c.x]


func set_cell_state(c: Vector2i, st: int) -> void:
	if Cfg.cell_valid(c):
		cells[c.y * Cfg.GRID_W + c.x] = st


func can_build(c: Vector2i) -> bool:
	return cell_state(c) == Cell.FREE


## Výška základny věže v buňce (průměr středu a okolí => stabilní i na mírném svahu).
func cell_height(c: Vector2i) -> float:
	var w: Vector2 = Cfg.cell_center(c.x, c.y)
	var sum: float = terrain.height_at(w.x, w.y)
	var o: float = 0.7
	sum += terrain.height_at(w.x + o, w.y)
	sum += terrain.height_at(w.x - o, w.y)
	sum += terrain.height_at(w.x, w.y + o)
	sum += terrain.height_at(w.x, w.y - o)
	return sum / 5.0


func cell_world(c: Vector2i) -> Vector3:
	var w: Vector2 = Cfg.cell_center(c.x, c.y)
	return Vector3(w.x, cell_height(c), w.y)


## Smí se na bod (x, z) umístit náhodná dekorace (strom, skála...)? Stavitelná pole zůstávají volná.
func decor_ok(x: float, z: float, path_margin: float = 2.3, river_margin: float = 1.6) -> bool:
	if terrain.edge_dist(x, z) < 0.9:
		return false
	if terrain.path_dist_at(x, z) < path_margin:
		return false
	if terrain.river_sd_at(x, z) < river_margin:
		return false
	var c: Vector2i = Cfg.world_to_cell(x, z)
	if Cfg.cell_valid(c):
		if cell_state(c) != Cell.VOID:
			return false
	# ani u Srdce ostrova a u portálu
	if Vector2(x, z).distance_to(Vector2(base_pos.x, base_pos.z)) < 4.0:
		return false
	if Vector2(x, z).distance_to(Vector2(spawn_pos.x, spawn_pos.z)) < 3.5:
		return false
	return true
