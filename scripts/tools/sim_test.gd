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
	if main.args.has("mech"):
		_mech_run(main)
		return
	if main.args.has("islands"):
		_islands_run(main)
		return
	var report: Dictionary = {}
	report["map"] = _map_report(g)
	if not main.args.has("noup"):
		report["upgrade_test"] = _upgrade_experiment(g)
	else:
		report["upgrade_test"] = {}
	var bots: Dictionary = {}
	var ok: bool = true
	for pol in POLICIES.keys():
		if main.args.has("pol") and str(main.args["pol"]) != str(pol):
			continue
		var bot: Dictionary = _bot_game(g, str(pol), 30, main.args.has("abil"))
		bots[pol] = bot
		ok = ok and bool(bot.get("physics_ok", false))
	report["bots"] = bots
	print("SIMTEST_JSON " + JSON.stringify(report))
	main.get_tree().quit(0 if ok else 1)


# ------------------------------------------------------------------ mapa
static func _map_report(g: Game) -> Dictionary:
	var free: int = 0
	var counts: Dictionary = {}
	var elev_counts: Dictionary = {}
	for i in range(g.map.cells.size()):
		var c: int = g.map.cells[i]
		counts[c] = int(counts.get(c, 0)) + 1
		if c == GameMap.Cell.FREE:
			free += 1
			var ev: int = int(g.map.elev[i])
			elev_counts[ev] = int(elev_counts.get(ev, 0)) + 1
	var min_obs: float = 1e9
	for ob in g.map.obstacles:
		var pos: Vector3 = ob["pos"]
		for p in g.map.lanes:
			var s: float = 0.0
			while s <= (p as PathData).length:
				min_obs = minf(min_obs, (p as PathData).xz_at(s).distance_to(Vector2(pos.x, pos.z)))
				s += 0.5
	var lens: Array = []
	var br: Array = []
	for li in range(g.map.lane_count()):
		lens.append(snappedf((g.map.lanes[li] as PathData).length, 0.1))
		br.append(g.map.lane_bridges[li].duplicate())
	var sp: Array = []
	for pt in g.map.portals:
		var pp: Vector3 = pt["pos"]
		sp.append([snappedf(pp.x, 0.1), snappedf(pp.z, 0.1)])
	return {
		"free_cells": free, "cell_counts": counts, "elev_cells": elev_counts, "obstacles": g.map.obstacles.size(),
		"lanes": g.map.lane_count(), "lane_lengths": lens, "lane_bridges": br, "bridges_built": g.map.bridges.size(),
		"min_obstacle_to_path": snappedf(min_obs, 0.01), "fly_alt": snappedf(g.fly_altitude, 0.1),
		"portals": sp, "base": [snappedf(g.map.base_pos.x, 0.1), snappedf(g.map.base_pos.z, 0.1)],
	}


## Kolik bodů tras (vážených podle podílu nepřátel na trase) leží v dosahu pole; dosah zahrnuje bonus výšky pole.
static func _coverage(g: Game, c: Vector2i, rng: float) -> float:
	var w: Vector2 = Cfg.cell_center(c.x, c.y)
	var r: float = rng * float(Cfg.ELEV_RANGE[g.map.elev_at(c)])
	var wsum: float = 0.0
	for lw in g.map.lane_weights:
		wsum += float(lw)
	var n: float = 0.0
	for li in range(g.map.lane_count()):
		var p: PathData = g.map.lanes[li]
		var share: float = float(g.map.lane_weights[li]) / wsum
		var s: float = 0.0
		var k: float = 0.0
		while s <= p.length:
			if p.xz_at(s).distance_to(w) <= r:
				k += 1.0
			s += 1.0
		n += k * share
	return n * float(g.map.lane_count())


static func _free_cells(g: Game) -> Array:
	var out: Array = []
	for cz in range(Cfg.GRID_H):
		for cx in range(Cfg.GRID_W):
			var c: Vector2i = Vector2i(cx, cz)
			if g.map.can_build(c):
				out.append(c)
	return out


static func _air_coverage(g: Game, c: Vector2i, rng: float) -> float:
	## Kolik bodů přímých letových čar (portál → Srdce ostrova) leží v dosahu pole.
	var w: Vector2 = Cfg.cell_center(c.x, c.y)
	var r: float = rng * float(Cfg.ELEV_RANGE[g.map.elev_at(c)])
	var b: Vector2 = Vector2(g.map.base_pos.x, g.map.base_pos.z)
	var total: float = 0.0
	for pt in g.map.portals:
		var a: Vector2 = Vector2((pt["pos"] as Vector3).x, (pt["pos"] as Vector3).z)
		var n: float = 0.0
		var len: float = a.distance_to(b)
		var t: float = 0.0
		while t <= len:
			if a.lerp(b, t / len).distance_to(w) <= r:
				n += 1.0
			t += 1.0
		total += n
	return total / float(g.map.portals.size())


static func _best_cell(g: Game, rng: float, avoid: Array = [], air_w: float = 0.0) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -1e9
	for c in _free_cells(g):
		var sc: float = _coverage(g, c, rng)
		if air_w > 0.0:
			sc += air_w * _air_coverage(g, c, rng)
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
			_queue(g, "goblin", 10, 1.0, 0.0, 5.0)
			_queue(g, "golem", 4, 2.0, 14.0, 4.0)
			_queue(g, "wolf", 6, 0.8, 26.0, 5.0)
			_queue(g, "drake", 4, 1.2, 36.0, 5.0)
			_run_until_clear(g, 400.0)
			rows.append({
				"level": level, "damage": snappedf(t.damage_dealt, 0.1), "kills": t.kills, "leaked": g.leaked,
				"dps_listed": snappedf(Cfg.dps_of(type, level), 0.1), "range": float(Cfg.tower_level(type, level)["range"]),
			})
		result[type] = {"cell": [cell.x, cell.y], "levels": rows}
	g.reset()
	return result


# ------------------------------------------------------------------ B) bot hraje celou hru
const POLICIES: Dictionary = {
	"siroka": {"air": 0.0, "base": 3, "per_wave": 1.0, "max": 14, "order": ["archer", "archer", "cannon", "mage", "archer", "frost", "cannon", "mage", "cannon", "mage", "frost", "archer", "cannon", "mage"],
		"prio": {"mage": 0, "cannon": 1, "archer": 2, "frost": 3}},
	"vysoka": {"air": 1.0, "base": 3, "per_wave": 0.5, "max": 9, "order": ["archer", "mage", "cannon", "archer", "frost", "mage", "archer", "cannon", "mage"],
		"prio": {"archer": 0, "mage": 1, "cannon": 2, "frost": 3}},
	"mix": {"air": 1.0, "base": 4, "per_wave": 0.9, "max": 14, "order": ["archer", "mage", "cannon", "archer", "frost", "mage", "cannon", "archer", "mage", "frost", "cannon", "archer", "mage", "cannon"],
		"prio": {"mage": 0, "archer": 1, "cannon": 2, "frost": 3}},
	"vzduch": {"air": 1.6, "base": 3, "per_wave": 0.7, "max": 10, "order": ["archer", "archer", "mage", "cannon", "frost", "archer", "mage", "cannon", "archer", "mage"],
		"prio": {"archer": 0, "mage": 1, "frost": 2, "cannon": 3}},
}


static func _bot_spend(g: Game, wave_no: int, pol: Dictionary) -> void:
	var order: Array = pol["order"]
	var prio: Dictionary = pol["prio"]
	var target_count: int = mini(int(pol["base"]) + int(float(wave_no) * float(pol["per_wave"])), int(pol["max"]))
	var guard: int = 0
	while guard < 60:
		guard += 1
		if g.towers.size() < target_count:
			var type: String = order[g.towers.size() % order.size()]
			if g.gold < Cfg.tower_cost(type):
				return
			var avoid: Array = []
			for t in g.towers:
				avoid.append(t.cell)
			var air_w: float = float(pol.get("air", 0.0)) if (type != "cannon") else 0.0
			var c: Vector2i = _best_cell(g, float(Cfg.tower_level(type, 1)["range"]), avoid, air_w)
			if c.x < 0:
				return
			g.build_tower(type, c)
		else:
			var cand: Tower = null
			for t2 in g.towers:
				if not t2.can_upgrade():
					continue
				if cand == null or t2.level < cand.level or (t2.level == cand.level and int(prio[t2.type]) < int(prio[cand.type])):
					cand = t2
			if cand == null or g.gold < cand.upgrade_cost():
				return
			g.upgrade_tower(cand)


## Bot používá schopnosti jako rozumný hráč: meteor na největší hlouček, poryv na nepřátele blízko cíle, horečku při velké vlně.
static func _bot_abilities(g: Game) -> void:
	if g.enemies.is_empty():
		return
	if g.ability_ready("meteor") and g.enemies.size() >= 4:
		var best_n: int = 0
		var best_pos: Vector3 = Vector3.ZERO
		for e in g.enemies:
			var n: int = 0
			var sum: Vector3 = Vector3.ZERO
			for o in g.enemies:
				if Vector2(e.position.x - o.position.x, e.position.z - o.position.z).length() <= 3.0:
					n += 1
					sum += o.position
			if n > best_n:
				best_n = n
				best_pos = sum / float(n)
		if best_n >= 4:
			g.cast_meteor(best_pos)
	if g.ability_ready("blizzard"):
		var near_end: int = 0
		for e2 in g.enemies:
			if e2.progress() > 0.7:
				near_end += 1
		if near_end >= 3:
			g.cast_blizzard()
	if g.ability_ready("gold") and g.enemies.size() >= 5:
		g.cast_gold()


static func _bot_game(g: Game, policy: String, max_waves: int = 30, use_abilities: bool = false) -> Dictionary:
	var pol: Dictionary = POLICIES[policy]
	g.configure(g.mode_id, g.diff_id)
	var p: PathData = g.map.longest_lane()
	var last_pos: Dictionary = {}
	var age: Dictionary = {}
	var max_jump: float = 0.0          # největší překročení povolené vodorovné rychlosti za krok
	var max_dy_ground: float = 0.0     # největší svislá změna pozemního nepřítele za krok
	var max_dy_fly: float = 0.0
	var max_age: float = 0.0
	var min_obs: float = 1e9
	var ground_off: float = 0.0
	var waves: Array = []
	var tick_guard: int = 0
	var max_ticks: int = int(60.0 * 60.0 * 40.0 / DT / 60.0)   # 40 min herního času
	var spend_timer: float = 0.0
	var n_waves: int = g.total_waves if g.total_waves > 0 else max_waves
	for w in range(n_waves):
		_bot_spend(g, w + 1, pol)
		if not g.start_next_wave():
			break
		var kills0: int = g.kills
		var leaked0: int = g.leaked
		var wave_t0: float = g.time
		while (not g._spawn_queue.is_empty() or not g.enemies.is_empty()) and g.state == Game.State.PLAYING:
			g.tick(DT)
			tick_guard += 1
			spend_timer += DT
			if use_abilities and tick_guard % 15 == 0:
				_bot_abilities(g)
			if spend_timer > 8.0:
				spend_timer = 0.0
				_bot_spend(g, w + 1, pol)
			for e in g.enemies:
				var id: int = e.uid
				if last_pos.has(id):
					var lp: Vector3 = last_pos[id]
					var j: float = Vector2(lp.x - e.position.x, lp.z - e.position.z).length()
					var allowed: float = (e.base_speed * 1.3 * DT) + 0.005   # vnější strana pruhu v zatáčce je delší (až +30 %)
					max_jump = maxf(max_jump, j - allowed)
					var dy: float = absf(lp.y - e.position.y)
					if e.flying:
						max_dy_fly = maxf(max_dy_fly, dy)
					else:
						max_dy_ground = maxf(max_dy_ground, dy)
				last_pos[id] = e.position
				age[id] = float(age.get(id, 0.0)) + DT
				max_age = maxf(max_age, float(age[id]))
				if not e.flying:
					if not g.map.is_on_bridge(e.lane, e.s):
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
	var physics_ok: bool = max_jump <= 0.0 and max_dy_ground <= 0.1 and max_age <= slowest * 1.8 and ground_off <= 0.5
	return {
		"state": g.state, "lives": g.lives, "waves_started": g.waves_started, "kills": g.kills, "leaked": g.leaked,
		"towers": g.towers.size(), "game_time": snappedf(g.time, 0.1), "waves": waves,
		"max_jump_over_allowed": snappedf(max_jump, 0.0001), "max_dy_ground": snappedf(max_dy_ground, 0.001), "max_dy_fly": snappedf(max_dy_fly, 0.001),
		"leak_types": g.leak_types, "max_enemy_age": snappedf(max_age, 0.1),
		"min_dist_enemy_to_obstacle": snappedf(min_obs, 0.01), "max_ground_offset": snappedf(ground_off, 0.01),
		"proj_hits": g.proj_hits, "proj_fizzles": g.proj_fizzles, "total_damage": snappedf(g.total_damage, 1.0),
		"physics_ok": physics_ok, "best_wave": g.best_wave, "mode": g.mode_id, "difficulty": g.diff_id,
		"abilities_used": g.abilities_used.duplicate(),
	}


# ------------------------------------------------------------------ C) mechaniky: nepřátelé, schopnosti, režimy, rekordy
static func _spawn_at(g: Game, type: String, s: float, hp_mult: float = 1.0, lane: int = 0) -> Enemy:
	g._spawn_enemy({"at": 0.0, "type": type, "wave": Game.TEST_WAVE, "hp": hp_mult, "lane": lane})
	var e: Enemy = g.enemies[g.enemies.size() - 1]
	e.s = s
	e.update(0.0)
	return e


static func _run_for(g: Game, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		g.tick(DT)
		t += DT


static func _mech_run(main) -> void:
	var g: Game = main.game
	var checks: Array = []
	var add: Callable = func(name: String, ok: bool, detail: String = "") -> void:
		checks.append({"name": name, "ok": ok, "detail": detail})

	# --- data: všichni nepřátelé a vlny jsou konzistentní
	var data_ok: bool = true
	var bad: String = ""
	for i in range(0, 80):
		for grp in Cfg.wave_def(i)["groups"]:
			if not Cfg.ENEMIES.has(str(grp[0])) or int(grp[1]) <= 0:
				data_ok = false
				bad = "vlna %d: %s" % [i, str(grp)]
	add.call("data: každá vlna (0–79) obsahuje jen existující nepřátele a kladné počty", data_ok, bad)
	add.call("data: obtížnosti seřazené (lehká < normální < těžká podle zdraví)",
		float(Cfg.DIFFICULTIES["easy"]["hp"]) < float(Cfg.DIFFICULTIES["normal"]["hp"]) and float(Cfg.DIFFICULTIES["normal"]["hp"]) < float(Cfg.DIFFICULTIES["hard"]["hp"]))

	# --- prostředí (motivy): úplnost textů, jmen, barev a paleta bez překlepů v klíčích
	for tid in Themes.ids():
		var th: GameTheme = Themes.create(str(tid))
		var miss: Array = []
		for tw in Cfg.TOWER_ORDER:
			var ttx: Dictionary = th.tower_text.get(tw, {})
			if th.theme_id != "sky_island" and (str(ttx.get("name", "")) == "" or str(ttx.get("short", "")) == "" or str(ttx.get("desc", "")) == "" or (ttx.get("notes", []) as Array).size() != Cfg.MAX_LEVEL):
				miss.append("věž " + str(tw))
		for en in Cfg.ENEMIES.keys():
			if th.theme_id != "sky_island" and str((th.enemy_text.get(en, {}) as Dictionary).get("name", "")) == "":
				miss.append("nepřítel " + str(en))
			if th.theme_id != "sky_island" and Cfg.ENEMIES[en].has("tip") and str((th.enemy_text.get(en, {}) as Dictionary).get("tip", "")) == "":
				miss.append("tip " + str(en))
		for ab in Cfg.ABILITY_ORDER:
			if th.theme_id != "sky_island" and (str((th.ability_text.get(ab, {}) as Dictionary).get("name", "")) == "" or str((th.ability_text.get(ab, {}) as Dictionary).get("desc", "")) == ""):
				miss.append("schopnost " + str(ab))
		for pk in th.palette.keys():
			if not GameTheme.DEFAULT_PALETTE.has(pk):
				miss.append("barva " + str(pk))
		for sk in th.strings.keys():
			if not GameTheme.DEFAULT_STRINGS.has(sk):
				miss.append("text " + str(sk))
		var uniq: Dictionary = {}
		for tw2 in Cfg.TOWER_ORDER:
			uniq[Themes.create(str(tid)).tower_text.get(tw2, {}).get("name", Cfg.TOWERS[tw2]["name"])] = true
		if uniq.size() != Cfg.TOWER_ORDER.size():
			miss.append("jména věží nejsou různá")
		add.call("prostředí %s: jména věží, nepřátel a schopností, texty a paleta jsou úplné a bez překlepů v klíčích" % str(tid), miss.is_empty(), ", ".join(miss))

	# --- obtížnosti: start a zdraví/rychlost nepřátel
	for did in Cfg.DIFFICULTY_ORDER:
		g.configure("campaign", did)
		var d: Dictionary = Cfg.DIFFICULTIES[did]
		g.start_next_wave()
		_run_for(g, 1.0)
		var gob: Enemy = null
		for e in g.enemies:
			if e.type == "goblin":
				gob = e
				break
		var ok_d: bool = g.gold == int(d["gold"]) and g.lives == int(d["lives"]) and gob != null \
			and is_equal_approx(gob.max_hp, 45.0 * float(d["hp"])) and is_equal_approx(gob.base_speed, 2.0 * float(d["speed"]))
		add.call("obtížnost %s: zlato %d, životy %d, zdraví skřeta %.1f, rychlost %.2f" % [did, g.gold, g.lives, gob.max_hp if gob != null else -1.0, gob.base_speed if gob != null else -1.0], ok_d)

	# --- léčitel léčí okolní nepřátele
	g.configure("campaign", "normal")
	var gob2: Enemy = _spawn_at(g, "goblin", 20.0, 10.0)
	var hl: Enemy = _spawn_at(g, "healer", 20.8, 1.0)
	gob2.take_damage(300.0, "magic", null)
	var hp_before: float = gob2.hp
	_run_for(g, 2.0)
	add.call("léčitel: skřet s %d zdraví po 2 s léčení má %d (má vzrůst)" % [int(hp_before), int(gob2.hp)], gob2.hp > hp_before + 20.0)
	# a nevyléčí sebe ani mrtvého
	g.configure("campaign", "normal")

	# --- štítonoš: štít pohlcuje, praskne, po klidu se částečně obnoví
	var sh: Enemy = _spawn_at(g, "shield", 20.0, 1.0)
	var hp0: float = sh.hp
	var d1: float = sh.take_damage(100.0, "magic", null)
	var ok1: bool = is_equal_approx(sh.hp, hp0) and sh.shield > 0.0 and sh.shield < sh.max_shield
	sh.take_damage(60.0, "magic", null)
	var ok2: bool = sh.shield <= 0.0 and sh.hp < hp0
	add.call("štítonoš: štít pohlcuje zásahy (zdraví %.0f -> %.0f), pak praskne" % [hp0, sh.hp], ok1 and ok2)
	g.configure("campaign", "normal")
	var sh2: Enemy = _spawn_at(g, "shield", 20.0, 1.0)
	sh2.take_damage(60.0, "magic", null)
	var sh_low: float = sh2.shield
	_run_for(g, 4.5)
	add.call("štítonoš: nepoškozený štít se po 3 s klidu obnovuje (%.0f -> %.0f)" % [sh_low, sh2.shield], sh2.shield > sh_low + 10.0)

	# --- slizák: rozpad na dva slizánky; vlna není hotová, dokud žijí
	g.configure("endless", "normal")
	g._wave_spawn_left[99] = 1
	g._wave_alive[99] = 0
	g._wave_done[99] = false
	g._spawn_queue.append({"at": g.time, "type": "slime", "wave": 99, "hp": 1.0})
	g.tick(DT)
	var sl: Enemy = g.enemies[0]
	sl.take_damage(100000.0, "magic", null)
	var kids: Array = []
	for e2 in g.enemies:
		if e2.type == "slimeling":
			kids.append(e2)
	var kid_ok: bool = kids.size() == 2 and absf(kids[0].s - sl.s) < 0.5 and is_equal_approx(kids[0].max_hp, 80.0 * 0.3)
	add.call("slizák: po smrti vzniknou 2 slizánci se 30 %% zdraví (vzniklo %d)" % kids.size(), kid_ok)
	add.call("slizák: vlna se nedokončí, dokud potomci žijí", not bool(g._wave_done[99]))
	for k in kids:
		k.take_damage(100000.0, "magic", null)
	add.call("slizák: po zabití potomků je vlna dokončena", bool(g._wave_done[99]))

	# --- meteor
	g.configure("campaign", "normal")
	var pos0: Vector3 = g.map.lanes[0].pos_at(40.0)
	var cluster: Array = []
	for i in range(5):
		cluster.append(_spawn_at(g, "goblin", 40.0 + float(i) * 0.4, 10.0))
	var far: Enemy = _spawn_at(g, "goblin", 60.0, 10.0)
	var all_full: float = cluster[0].max_hp
	var cast_ok: bool = g.cast_meteor(pos0)
	var again_ok: bool = g.cast_meteor(pos0)
	_run_for(g, 1.6)
	var hit_n: int = 0
	for e3 in cluster:
		if is_instance_valid(e3) and (e3.hp < all_full or not e3.alive):
			hit_n += 1
	add.call("meteor: zasáhne všech 5 nepřátel v okruhu (%d), vzdálený nezasáhne, druhé seslání hned selže" % hit_n,
		cast_ok and not again_ok and hit_n == 5 and far.hp >= far.max_hp - 0.01 and float(g.ability_cd["meteor"]) > 20.0)
	g.configure("campaign", "normal")
	add.call("meteor: po restartu hry je schopnost zase připravena", float(g.ability_cd["meteor"]) == 0.0)

	# --- mrazivý poryv
	var bz1: Enemy = _spawn_at(g, "goblin", 30.0, 3.0)
	var bz2: Enemy = _spawn_at(g, "drake", 5.0, 3.0)
	var s_before: float = bz1.s
	var ok_bz: bool = g.cast_blizzard()
	_run_for(g, 1.0)
	add.call("mrazivý poryv: zmrazí pozemního i létajícího (stojí na místě)", ok_bz and absf(bz1.s - s_before) < 0.05 and bz2.frozen_t > 0.0)

	# --- zlatá horečka: dvojnásobné zlato
	g.configure("campaign", "normal")
	var g1: Enemy = _spawn_at(g, "goblin", 30.0)
	var gold_a: int = g.gold
	g1.take_damage(100000.0, "magic", null)
	var plain: int = g.gold - gold_a
	var g2: Enemy = _spawn_at(g, "goblin", 30.0)
	var cast_g: bool = g.cast_gold()
	var gold_b: int = g.gold
	g2.take_damage(100000.0, "magic", null)
	var boosted: int = g.gold - gold_b
	add.call("zlatá horečka: odměna %d -> %d (dvojnásobek)" % [plain, boosted], cast_g and boosted == plain * 2)

	# --- nekonečný režim: vlny pokračují, nikdy nevyhraje, rostou
	g.configure("endless", "normal")
	var w_ok: bool = g.total_waves == 0 and g.can_start_wave()
	g.waves_started = 40
	add.call("nekonečný režim: bez limitu vln (po vlně 40 se dá spustit další)", w_ok and g.can_start_wave() and not g.wave_preview(40).is_empty())
	var hp12: float = float(Cfg.wave_def(11)["hp"])
	var hp20: float = float(Cfg.wave_def(19)["hp"])
	var hp30: float = float(Cfg.wave_def(29)["hp"])
	add.call("nekonečný režim: zdraví nepřátel roste (vlna 12: %.1f, 20: %.1f, 30: %.1f)" % [hp12, hp20, hp30], hp12 < hp20 and hp20 < hp30)
	g.configure("campaign", "normal")
	g.waves_started = 12
	add.call("příběh: po 12 vlnách se další nespustí", not g.can_start_wave())

	# --- rekordy (do dočasného souboru)
	var old_path: String = GameSettings.path
	GameSettings.path = "user://rekordy_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	GameSettings.records = {}
	GameSettings.mode = "endless"
	GameSettings.difficulty = "normal"
	GameSettings.island = 0
	var r1: bool = GameSettings.submit(5, false, 3)
	var r2: bool = GameSettings.submit(3, false, 9)
	var r3: bool = GameSettings.submit(8, false, 1)
	GameSettings.mode = "campaign"
	var r4: bool = GameSettings.submit(12, true, 5)
	var r5: bool = GameSettings.submit(12, true, 9)
	var r6: bool = GameSettings.submit(12, true, 2)
	GameSettings.loaded = false
	GameSettings.records = {}
	GameSettings.load_all()
	var re: Dictionary = GameSettings.get_record("endless_normal_0")
	var rc: Dictionary = GameSettings.get_record("campaign_normal_0")
	add.call("rekordy: zlepšení se zapíše, zhoršení ne (%s %s %s | %s %s %s)" % [r1, r2, r3, r4, r5, r6], r1 and not r2 and r3 and r4 and r5 and not r6)
	add.call("rekordy: po novém načtení ze souboru zůstaly (nekonečný vlna %d, příběh vítězství se %d životy)" % [int(re["waves"]), int(rc["lives"])],
		int(re["waves"]) == 8 and bool(rc["won"]) and int(rc["lives"]) == 9)
	GameSettings.path = old_path

	# --- hra s botem v nekonečném režimu: nepadá, vlny se počítají
	GameSettings.mode = "campaign"
	var endless_bot: Dictionary = {}
	g.configure("endless", "normal")
	endless_bot = _bot_game(g, "mix", 16)
	add.call("nekonečný režim: bot (mix) došel do vlny %d" % int(endless_bot.get("best_wave", 0)), int(endless_bot.get("best_wave", 0)) >= 8 and bool(endless_bot.get("physics_ok", false)))

	var failed: int = 0
	for c in checks:
		if not bool(c["ok"]):
			failed += 1
	print("MECH_JSON " + JSON.stringify({"checks": checks, "failed": failed, "endless_bot": endless_bot}))
	main.get_tree().quit(0 if failed == 0 else 1)


# ------------------------------------------------------------------ D) kontrola rozložení ostrovů (mapa bez hry)
## Nejmenší vzdálenost mezi dvěma trasami mimo jejich společné úseky a okolí rozcestí/splynutí (9 m od společného bodu).
static func _lane_separation(a: PathData, b: PathData) -> float:
	var n: int = a.pts.size()
	var shared: PackedByteArray = PackedByteArray()
	shared.resize(n)
	var dists: PackedFloat32Array = PackedFloat32Array()
	dists.resize(n)
	var any_shared: bool = false
	for i in range(0, n):
		var best: float = 1e9
		var j: int = 0
		while j < b.pts.size():
			best = minf(best, a.pts[i].distance_to(b.pts[j]))
			j += 2
		dists[i] = best
		if best < 2.4:
			shared[i] = 1
			any_shared = true
	var guard: int = int(9.0 / PathData.STEP)
	var res: float = 1e9
	for i2 in range(0, n):
		if any_shared:
			var near_shared: bool = false
			for k in range(maxi(i2 - guard, 0), mini(i2 + guard, n - 1) + 1, 4):
				if shared[k] == 1:
					near_shared = true
					break
			if near_shared:
				continue
		res = minf(res, dists[i2])
	return res


static func _island_stats(def: Dictionary, seed_in: int) -> Dictionary:
	var m: GameMap = GameMap.new(seed_in, def)
	var t0: int = Time.get_ticks_msec()
	m.build()
	var build_ms: int = Time.get_ticks_msec() - t0
	var free: int = 0
	var near_free: int = 0
	var counts: Dictionary = {}
	var elev_counts: Dictionary = {}
	for cz in range(Cfg.GRID_H):
		for cx in range(Cfg.GRID_W):
			var st: int = m.cell_state(Vector2i(cx, cz))
			counts[st] = int(counts.get(st, 0)) + 1
			if st == GameMap.Cell.FREE:
				free += 1
				var ev: int = m.elev_at(Vector2i(cx, cz))
				elev_counts[ev] = int(elev_counts.get(ev, 0)) + 1
				var w: Vector2 = Cfg.cell_center(cx, cz)
				var best: float = 1e9
				for p in m.lanes:
					var sv: float = 0.0
					while sv <= (p as PathData).length:
						best = minf(best, (p as PathData).xz_at(sv).distance_to(w))
						sv += 1.0
				if best <= 7.0:
					near_free += 1
	var lens: Array = []
	var self_min: float = 1e9
	var edge_min: float = 1e9
	var bad_path_cells: int = 0
	var min_obs: float = 1e9
	var max_ys_err: float = 0.0
	var max_slope: float = 0.0
	for li in range(m.lane_count()):
		var p2: PathData = m.lanes[li]
		lens.append(snappedf(p2.length, 0.1))
		# nejmenší vzdálenost trasy od sebe samé (body, které jsou po trase aspoň 14 m od sebe)
		var a: float = 0.0
		while a <= p2.length:
			var pa: Vector2 = p2.xz_at(a)
			var b: float = a + 14.0
			while b <= p2.length:
				self_min = minf(self_min, pa.distance_to(p2.xz_at(b)))
				b += 1.0
			a += 1.0
		var sv2: float = 4.0
		while sv2 <= p2.length - 1.0:
			var q: Vector2 = p2.xz_at(sv2)
			edge_min = minf(edge_min, m.terrain.edge_dist(q.x, q.y))
			sv2 += 0.5
		sv2 = 0.0
		var prev_y: float = p2.y_at(0.0)
		while sv2 <= p2.length:
			var q2: Vector2 = p2.xz_at(sv2)
			if m.cell_state(Cfg.world_to_cell(q2.x, q2.y)) == GameMap.Cell.VOID:
				bad_path_cells += 1
			var ypath: float = p2.y_at(sv2)
			if not m.is_on_bridge(li, sv2):
				max_ys_err = maxf(max_ys_err, absf(ypath - m.height_at(q2.x, q2.y)))
			max_slope = maxf(max_slope, absf(ypath - prev_y) / 1.0)
			prev_y = ypath
			sv2 += 1.0
		for ob in m.obstacles:
			var op: Vector3 = ob["pos"]
			var s3: float = 0.0
			while s3 <= p2.length:
				min_obs = minf(min_obs, p2.xz_at(s3).distance_to(Vector2(op.x, op.z)))
				s3 += 0.5
	var lane_sep: float = 1e9
	var sep_pairs: Array = []
	for i in range(m.lane_count()):
		for j in range(i + 1, m.lane_count()):
			var sp: float = _lane_separation(m.lanes[i], m.lanes[j])
			sep_pairs.append("%d-%d: %.1f" % [i, j, sp])
			lane_sep = minf(lane_sep, sp)
	var portal_edge: float = 1e9
	for pt in m.portals:
		var pp: Vector3 = pt["pos"]
		portal_edge = minf(portal_edge, m.terrain.edge_dist(pp.x, pp.z))
	var river_inside: float = 0.0
	var rv: RiverData = m.terrain.river
	for pt in rv.pts:
		if m.terrain.edge_dist(pt.x, pt.y) > 0.0:
			river_inside += RiverData.STEP
	var bridges_per_lane: Array = []
	for li2 in range(m.lane_count()):
		bridges_per_lane.append((m.lane_bridges[li2] as Array).size())
	# výška na vrcholcích a poloha kopců
	var hill_info: Array = []
	for hl in m.terrain.hills:
		hill_info.append({"tier": int(hl["tier"]), "r": float(hl["r"]), "y": snappedf(m.height_at(float(hl["x"]), float(hl["z"])), 0.01),
			"edge": snappedf(m.terrain.edge_dist(float(hl["x"]), float(hl["z"])), 0.1)})
	return {
		"name": str(def["name"]), "seed": seed_in, "build_ms": build_ms, "lanes": m.lane_count(), "portals": m.portals.size(),
		"lane_lengths": lens, "bridges_built": m.bridges.size(), "bridges_per_lane": bridges_per_lane,
		"free_cells": free, "free_near_path": near_free, "elev_cells": elev_counts, "self_distance_min": snappedf(self_min, 0.1),
		"lane_separation_min": snappedf(lane_sep, 0.1), "lane_sep_pairs": sep_pairs,
		"path_edge_dist_min": snappedf(edge_min, 0.1), "portal_edge_dist": snappedf(portal_edge, 0.1),
		"river_length_inside": snappedf(river_inside, 0.1), "path_points_in_void": bad_path_cells,
		"min_obstacle_to_path": snappedf(min_obs, 0.01), "cells": counts,
		"path_y_error_max": snappedf(max_ys_err, 0.001), "path_slope_max": snappedf(max_slope, 0.001), "hills": hill_info,
		"base": [snappedf(m.base_pos.x, 0.1), snappedf(m.base_pos.z, 0.1)],
	}


static func _islands_run(main) -> void:
	var rep: Array = []
	var only: int = int(main.args["only"]) if main.args.has("only") else -1
	for i in range(Islands.LIST.size()):
		if only >= 0 and i != only:
			continue
		rep.append(_island_stats(Islands.LIST[i], int(Islands.LIST[i]["seed"])))
	if only >= 0:
		print("ISLANDS_JSON " + JSON.stringify(rep))
		main.get_tree().quit(0)
		return
	# všechny převrácené/otočené varianty (náhodný ostrov je používá)
	for i2 in range(Islands.LIST.size()):
		for mode in range(1, 8):
			var d2: Dictionary = Islands.transformed(Islands.LIST[i2], mode)
			var st2: Dictionary = _island_stats(d2, int(d2["seed"]))
			st2["layout_name"] = "%s [varianta %d]" % [str(d2["name"]), mode]
			rep.append(st2)
	for sd in [1001, 1002, 1003, 1004, 1005, 1006]:
		var d: Dictionary = Islands.resolve(Islands.RANDOM_ID, sd)
		var st: Dictionary = _island_stats(d, sd)
		st["layout_name"] = str(d["name"])
		rep.append(st)
	print("ISLANDS_JSON " + JSON.stringify(rep))
	main.get_tree().quit(0)
