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
var bridges: Array = []            # úseky trasy vedoucí přes řeku: [[s0, s1], ...] (vzdálenost podél trasy)
var map_seed: int = 7
var def: Dictionary = {}           # rozložení ostrova (viz Islands)
var base_cell: Vector2i = Vector2i(22, 4)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_in: int = 7, island_def: Dictionary = {}) -> void:
	map_seed = seed_in
	def = island_def if not island_def.is_empty() else Islands.LIST[0]
	base_cell = def["base"]
	_rng.seed = seed_in * 7919 + 13


func path() -> PathData:
	return terrain.path


func build() -> void:
	terrain = Terrain.new(map_seed, def["biomes"])
	var cells_path: Array = def["path"]

	# --- polyline trasy ve světových souřadnicích
	var poly: Array = []
	var first: Vector2 = Cfg.cell_center(cells_path[0].x, cells_path[0].y)
	var second: Vector2 = Cfg.cell_center(cells_path[1].x, cells_path[1].y)
	var out_dir: Vector2 = (first - second).normalized()      # směr ven z ostrova (portál stojí u okraje)
	var p0: Vector2 = first
	var guard: int = 0
	while terrain.edge_dist(p0.x, p0.y) > 1.6 and guard < 200:
		p0 += out_dir * 0.25
		guard += 1
	poly.append(p0)
	for i in range(cells_path.size()):
		var cc: Vector2i = cells_path[i]
		var w: Vector2 = Cfg.cell_center(cc.x, cc.y)
		if i == cells_path.size() - 1:
			# trasa končí u hrany buňky se Srdcem ostrova
			var bc: Vector2 = Cfg.cell_center(base_cell.x, base_cell.y)
			var dir_b: Vector2 = (bc - w).normalized()
			w = bc - dir_b * (Cfg.CELL * 0.5 - 0.4)
		poly.append(w)

	terrain.generate(poly, def["river"])

	var p: PathData = terrain.path
	spawn_pos = p.pos_at(0.0)
	base_pos = p.pos_at(p.length)

	_find_bridges()
	_classify_cells()
	_place_obstacles()


## Souvislé úseky trasy, kde vede přes řeku => mosty.
func _find_bridges() -> void:
	bridges.clear()
	var p: PathData = terrain.path
	var i0: int = -1
	var i1: int = -1
	for i in range(p.pts.size()):
		var sd: float = terrain.river_sd_at(p.pts[i].x, p.pts[i].y)
		if sd < 1.3:
			if i0 < 0:
				i0 = i
			i1 = i
		elif i0 >= 0:
			bridges.append([maxf(float(i0) * PathData.STEP - 1.0, 0.0), minf(float(i1) * PathData.STEP + 1.0, p.length)])
			i0 = -1
	if i0 >= 0:
		bridges.append([maxf(float(i0) * PathData.STEP - 1.0, 0.0), minf(float(i1) * PathData.STEP + 1.0, p.length)])


func is_on_bridge(s: float) -> bool:
	for b in bridges:
		if s >= float(b[0]) and s <= float(b[1]):
			return true
	return false


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
	cells[base_cell.y * Cfg.GRID_W + base_cell.x] = Cell.BASE


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
