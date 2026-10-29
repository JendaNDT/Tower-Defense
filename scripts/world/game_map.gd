class_name GameMap
extends RefCounted
## Herní mapa: terén + trasa + mřížka stavitelných buněk + překážky (stromy, skály).
## Mapa je nezávislá na grafice – stejná data používá hra i vykreslení světa.

enum Cell { FREE, PATH, WATER, BLOCKED, VOID, BASE, TOWER }

var terrain: Terrain
var cells: PackedInt32Array = PackedInt32Array()
var elev: PackedByteArray = PackedByteArray()     # výškový stupeň pole: 0 rovina, 1 kopec, 2 vrchol
var obstacles: Array = []          # {cell: Vector2i, pos: Vector3, kind: String, biome: int}
var lanes: Array = []              # PathData jednotlivých tras (od portálu k Srdci)
var lane_weights: Array = []       # váhy tras při rozdělování nepřátel
var portals: Array = []            # {pos: Vector3, dir: Vector2, lanes: Array} – jeden portál pro všechny trasy z téže buňky
var lane_portal: Array = []        # index portálu každé trasy
var spawn_pos: Vector3 = Vector3.ZERO     # první portál (pro zjednodušení)
var base_pos: Vector3 = Vector3.ZERO
var bridges: Array = []            # mosty k vykreslení (bez duplicit): {lane, s0, s1}
var lane_bridges: Array = []       # pro každou trasu úseky přes řeku: [[s0, s1], ...] (vzdálenost podél trasy)
var map_seed: int = 7
var def: Dictionary = {}           # rozložení ostrova (viz Islands)
var base_cell: Vector2i = Vector2i(22, 4)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_in: int = 7, island_def: Dictionary = {}) -> void:
	map_seed = seed_in
	def = island_def if not island_def.is_empty() else Islands.LIST[0]
	base_cell = def["base"]
	_rng.seed = seed_in * 7919 + 13


func lane_count() -> int:
	return lanes.size()


## Poloha portálu, odkud trasa začíná.
func lane_spawn(lane: int) -> Vector3:
	return (portals[lane_portal[lane]] as Dictionary)["pos"]


## Nejdelší trasa (pro odhady časů).
func longest_lane() -> PathData:
	var best: PathData = lanes[0]
	for l in lanes:
		if (l as PathData).length > best.length:
			best = l
	return best


func build() -> void:
	terrain = Terrain.new(map_seed, def["biomes"])
	var polys: Array = []
	for li in range(Islands.lane_count(def)):
		polys.append(_lane_poly(Islands.lane_cells(def, li)))
	var hill_defs: Array = []
	for hl in def.get("hills", []):
		var hc: Vector2 = Cfg.cell_center(hl["c"].x, hl["c"].y)
		hill_defs.append({"x": hc.x, "z": hc.y, "r": float(hl["r"]), "tier": int(hl["tier"])})

	terrain.generate(polys, def["river"], hill_defs)

	lanes.clear()
	lane_weights.clear()
	for li in range(polys.size()):
		lanes.append(terrain.paths[li])
		lane_weights.append(Islands.lane_weight(def, li))
	_find_portals()
	spawn_pos = (portals[0] as Dictionary)["pos"]
	base_pos = (lanes[0] as PathData).pos_at((lanes[0] as PathData).length)

	_find_bridges()
	_classify_cells()
	_place_obstacles()


## Polyline jedné trasy ve světových souřadnicích: portál u okraje ostrova, vedení po středech buněk, konec u hrany buňky Srdce.
func _lane_poly(cells_path: Array) -> Array:
	var poly: Array = []
	var first: Vector2 = Cfg.cell_center(cells_path[0].x, cells_path[0].y)
	var second: Vector2 = Cfg.cell_center(cells_path[1].x, cells_path[1].y)
	var out_dir: Vector2 = (first - second).normalized()      # směr ven z ostrova (portál stojí u okraje)
	var p0: Vector2 = first
	var guard: int = 0
	while terrain.edge_dist(p0.x, p0.y) > 1.6 and guard < 300:
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
	return poly


## Trasy začínající ve stejném místě sdílejí jeden portál.
func _find_portals() -> void:
	portals.clear()
	lane_portal.clear()
	for li in range(lanes.size()):
		var p: PathData = lanes[li]
		var pos: Vector3 = p.pos_at(0.0)
		var found: int = -1
		for pi in range(portals.size()):
			if (portals[pi]["pos"] as Vector3).distance_to(pos) < 1.0:
				found = pi
				break
		if found < 0:
			portals.append({"pos": pos, "dir": p.dir_at(0.0), "lanes": [li]})
			found = portals.size() - 1
		else:
			(portals[found]["lanes"] as Array).append(li)
		lane_portal.append(found)


## Souvislé úseky tras, kde vedou přes řeku => mosty. Pro vykreslení se stejný most sdílený více trasami postaví jednou.
func _find_bridges() -> void:
	bridges.clear()
	lane_bridges.clear()
	for li in range(lanes.size()):
		var p: PathData = lanes[li]
		var list: Array = []
		var i0: int = -1
		var i1: int = -1
		for i in range(p.pts.size()):
			var sd: float = terrain.river_sd_at(p.pts[i].x, p.pts[i].y)
			if sd < 1.3:
				if i0 < 0:
					i0 = i
				i1 = i
			elif i0 >= 0:
				list.append([maxf(float(i0) * PathData.STEP - 1.0, 0.0), minf(float(i1) * PathData.STEP + 1.0, p.length)])
				i0 = -1
		if i0 >= 0:
			list.append([maxf(float(i0) * PathData.STEP - 1.0, 0.0), minf(float(i1) * PathData.STEP + 1.0, p.length)])
		lane_bridges.append(list)
		for br in list:
			var a: Vector3 = p.pos_at(float(br[0]))
			var b: Vector3 = p.pos_at(float(br[1]))
			var dup: bool = false
			for ex in bridges:
				var q: PathData = lanes[int(ex["lane"])]
				if q.pos_at(float(ex["s0"])).distance_to(a) < 2.5 and q.pos_at(float(ex["s1"])).distance_to(b) < 2.5:
					dup = true
					break
			if not dup:
				bridges.append({"lane": li, "s0": float(br[0]), "s1": float(br[1])})


func is_on_bridge(lane: int, s: float) -> bool:
	for b in lane_bridges[lane]:
		if s >= float(b[0]) and s <= float(b[1]):
			return true
	return false


func _classify_cells() -> void:
	cells.resize(Cfg.GRID_W * Cfg.GRID_H)
	elev.resize(Cfg.GRID_W * Cfg.GRID_H)
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
			elev[cz * Cfg.GRID_W + cx] = terrain.tier_at(c.x, c.y) if st == Cell.FREE else 0
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
			if cells[cz * Cfg.GRID_W + cx] != Cell.FREE or elev[cz * Cfg.GRID_W + cx] > 0:
				continue
			var c: Vector2 = Cfg.cell_center(cx, cz)
			var bw: Color = terrain.biome_weights(c.x, c.y)
			var prob: float = bw.r * 0.22 + bw.g * 0.08 + bw.b * 0.12 + bw.a * 0.15
			if _near_path_cell(cx, cz):
				prob *= 0.55
			# paty kopců: skalní výchozy (kopec se tak pozná i bez mřížky), pole na plošině zůstávají volná
			var on_hill: bool = not terrain.hills.is_empty() and terrain.hill_weights(c.x, c.y).x > 0.12
			if on_hill:
				prob = 0.34
			if _rng.randf() > prob:
				continue
			var biome: int = terrain.dominant_biome(c.x, c.y)
			var kind: String = "rock" if on_hill else _obstacle_kind(biome)
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


## Výškový stupeň pole (0 rovina, 1 kopec, 2 vrchol).
func elev_at(c: Vector2i) -> int:
	if not Cfg.cell_valid(c):
		return 0
	return int(elev[c.y * Cfg.GRID_W + c.x])


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
	for pt in portals:
		var pp: Vector3 = pt["pos"]
		if Vector2(x, z).distance_to(Vector2(pp.x, pp.z)) < 3.5:
			return false
	return true
