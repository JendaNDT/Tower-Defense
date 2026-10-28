class_name SimTest
extends RefCounted
## Automatické ověření bez grafiky (spouští se: godot --headless --path . -- --simtest).
##  A) Síla věží po úrovních na stejném scénáři (způsobené poškození, zabití, uniklí nepřátelé).
##  B) Celá hra odehraná jednoduchým botem + kontroly fyziky:
##     skoky pozice, uvíznutí, vzdálenost od překážek, zásahy projektilů.

const DT: float = 1.0 / 30.0


static func run(main) -> void:
	var g: Game = main.game
	g.paused = false
	var report: Dictionary = {}
	report["map"] = _map_report(g)
	report["upgrade_test"] = _upgrade_experiment(g)
	var bot: Dictionary = _bot_game(g)
	report["bot"] = bot
	print("SIMTEST_JSON " + JSON.stringify(report))
	var ok: bool = bool(bot.get("physics_ok", false))
	main.get_tree().quit(0 if ok else 1)


# ------------------------------------------------------------------ mapa
static func _map_report(g: Game) -> Dictionary:
	var free: int = 0
	var counts: Dictionary = {}
	for c in g.map.cells:
		counts[c] = int(counts.get(c, 0)) + 1
		if c == GameMap.Cell.FREE:
			free += 1
	var min_obs: float = 1e9
	var p: PathData = g.path
	for ob in g.map.obstacles:
		var pos: Vector3 = ob["pos"]
		var s: float = 0.0
		while s <= p.length:
			min_obs = minf(min_obs, p.xz_at(s).distance_to(Vector2(pos.x, pos.z)))
			s += 0.5
	return {
		"free_cells": free, "cell_counts": counts, "obstacles": g.map.obstacles.size(),
		"path_length": snappedf(p.length, 0.1), "bridge": [snappedf(g.map.bridge_s0, 0.1), snappedf(g.map.bridge_s1, 0.1)],
		"min_obstacle_to_path": snappedf(min_obs, 0.01), "fly_alt": snappedf(g.fly_altitude, 0.1),
		"spawn": [snappedf(g.map.spawn_pos.x, 0.1), snappedf(g.map.spawn_pos.z, 0.1)],
		"base": [snappedf(g.map.base_pos.x, 0.1), snappedf(g.map.base_pos.z, 0.1)],
	}


static func _coverage(g: Game, c: Vector2i, rng: float) -> float:
	var w: Vector2 = Cfg.cell_center(c.x, c.y)
	var n: float = 0.0
	var s: float = 0.0
	while s <= g.path.length:
		if g.path.xz_at(s).distance_to(w) <= rng:
			n += 1.0
		s += 1.0
	return n


static func _free_cells(g: Game) -> Array:
	var out: Array = []
	for cz in range(Cfg.GRID_H):
		for cx in range(Cfg.GRID_W):
			var c: Vector2i = Vector2i(cx, cz)
			if g.map.can_build(c):
				out.append(c)
	return out


static func _best_cell(g: Game, rng: float, avoid: Array = []) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -1e9
	for c in _free_cells(g):
		var sc: float = _coverage(g, c, rng)
		var w: Vector2 = Cfg.cell_center(c.x, c.y)
		for a in avoid:
			if Cfg.cell_center(a.x, a.y).distance_to(w) < 4.5:
				sc -= 3.0
		if sc > best_score:
			best_score = sc
			best = c
	return best


# ------------------------------------------------------------------ A) experiment s vylepšením
static func _run_until_clear(g: Game, max_time: float) -> void:
	var t0: float = g.time
	while (not g._spawn_queue.is_empty() or not g.enemies.is_empty() or not g.projectiles.is_empty()) and g.time - t0 < max_time:
		g.tick(DT)


static func _queue(g: Game, typ: String, n: int, interval: float, delay: float, hp: float) -> void:
	for i in range(n):
		g._spawn_queue.append({"at": g.time + delay + float(i) * interval, "type": typ, "wave": Game.TEST_WAVE, "hp": hp})
	g._spawn_queue.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))


static func _upgrade_experiment(g: Game) -> Dictionary:
	var result: Dictionary = {}
	for type in Cfg.TOWER_ORDER:
		var rows: Array = []
		var cell: Vector2i = Vector2i.ZERO
		for level in range(1, Cfg.MAX_LEVEL + 1):
			g.reset()
			g.gold = 999999
			g.lives = 99999
			cell = _best_cell(g, float(Cfg.tower_level(type, 1)["range"]))
			var t: Tower = g.build_tower(type, cell)
			for l in range(1, level):
				g.upgrade_tower(t)
			# stejný scénář pro všechny úrovně
			_queue(g, "goblin", 10, 1.0, 0.0, 1.0)
			_queue(g, "golem", 4, 2.0, 14.0, 1.0)
			_queue(g, "wolf", 6, 0.8, 26.0, 1.0)
			_queue(g, "drake", 4, 1.2, 36.0, 1.0)
			_run_until_clear(g, 400.0)
			rows.append({
				"level": level, "damage": snappedf(t.damage_dealt, 0.1), "kills": t.kills, "leaked": g.leaked,
				"dps_listed": snappedf(Cfg.dps_of(type, level), 0.1), "range": float(Cfg.tower_level(type, level)["range"]),
			})
		result[type] = {"cell": [cell.x, cell.y], "levels": rows}
	g.reset()
	return result


# ------------------------------------------------------------------ B) bot hraje celou hru
const BUILD_ORDER: Array = ["archer", "archer", "cannon", "mage", "archer", "frost", "cannon", "mage", "cannon", "mage", "frost", "archer", "cannon", "mage"]
const UP_PRIORITY: Dictionary = {"mage": 0, "cannon": 1, "archer": 2, "frost": 3}


static func _bot_spend(g: Game, wave_no: int) -> void:
	var target_count: int = mini(3 + wave_no, 14)
	var guard: int = 0
	while guard < 60:
		guard += 1
		if g.towers.size() < target_count:
			var type: String = BUILD_ORDER[g.towers.size() % BUILD_ORDER.size()]
			if g.gold < Cfg.tower_cost(type):
				return
			var avoid: Array = []
			for t in g.towers:
				avoid.append(t.cell)
			var c: Vector2i = _best_cell(g, float(Cfg.tower_level(type, 1)["range"]), avoid)
			if c.x < 0:
				return
			g.build_tower(type, c)
		else:
			var cand: Tower = null
			for t2 in g.towers:
				if not t2.can_upgrade():
					continue
				if cand == null or t2.level < cand.level or (t2.level == cand.level and int(UP_PRIORITY[t2.type]) < int(UP_PRIORITY[cand.type])):
					cand = t2
			if cand == null or g.gold < cand.upgrade_cost():
				return
			g.upgrade_tower(cand)


static func _bot_game(g: Game) -> Dictionary:
	g.reset()
	var p: PathData = g.path
	var last_pos: Dictionary = {}
	var age: Dictionary = {}
	var max_jump: float = 0.0
	var max_age: float = 0.0
	var min_obs: float = 1e9
	var ground_off: float = 0.0
	var waves: Array = []
	var tick_guard: int = 0
	var max_ticks: int = int(60.0 * 60.0 * 40.0 / DT / 60.0)   # 40 min herního času
	var spend_timer: float = 0.0
	for w in range(Cfg.TOTAL_WAVES):
		_bot_spend(g, w + 1)
		if not g.start_next_wave():
			break
		var kills0: int = g.kills
		var leaked0: int = g.leaked
		var wave_t0: float = g.time
		while (not g._spawn_queue.is_empty() or not g.enemies.is_empty()) and g.state == Game.State.PLAYING:
			g.tick(DT)
			tick_guard += 1
			spend_timer += DT
			if spend_timer > 8.0:
				spend_timer = 0.0
				_bot_spend(g, w + 1)
			for e in g.enemies:
				var id: int = e.uid
				if last_pos.has(id):
					var lp: Vector3 = last_pos[id]
					var j: float = lp.distance_to(e.position)
					var allowed: float = (e.base_speed * 1.01 * DT) + 0.03
					max_jump = maxf(max_jump, j - allowed)
				last_pos[id] = e.position
				age[id] = float(age.get(id, 0.0)) + DT
				max_age = maxf(max_age, float(age[id]))
				if not e.flying:
					ground_off = maxf(ground_off, absf(e.position.y - g.map.height_at(e.position.x, e.position.z)))
					for ob in g.map.obstacles:
						var op: Vector3 = ob["pos"]
						var d: float = Vector2(op.x - e.position.x, op.z - e.position.z).length()
						if d < min_obs:
							min_obs = d
			if g.time - wave_t0 > 600.0 or tick_guard > max_ticks:
				break
		var comp: Dictionary = {}
		for t in g.towers:
			var key: String = "%s%d" % [t.type[0], t.level]
			comp[key] = int(comp.get(key, 0)) + 1
		waves.append({"wave": w + 1, "lives": g.lives, "gold": g.gold, "kills": g.kills - kills0, "leaked": g.leaked - leaked0,
			"time": snappedf(g.time - wave_t0, 0.1), "towers": comp})
		if g.state != Game.State.PLAYING:
			break
	var slowest: float = p.length / 1.1 + 20.0      # nejpomalejší (boss) + rezerva
	var physics_ok: bool = max_jump <= 0.0 and max_age <= slowest * 1.8
	return {
		"state": g.state, "lives": g.lives, "waves_started": g.waves_started, "kills": g.kills, "leaked": g.leaked,
		"towers": g.towers.size(), "game_time": snappedf(g.time, 0.1), "waves": waves,
		"max_jump_over_allowed": snappedf(max_jump, 0.0001), "max_enemy_age": snappedf(max_age, 0.1),
		"min_dist_enemy_to_obstacle": snappedf(min_obs, 0.01), "max_ground_offset": snappedf(ground_off, 0.01),
		"proj_hits": g.proj_hits, "proj_fizzles": g.proj_fizzles, "total_damage": snappedf(g.total_damage, 1.0),
		"physics_ok": physics_ok,
	}
