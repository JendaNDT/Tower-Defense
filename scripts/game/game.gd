class_name Game
extends Node
## Herní jádro: ekonomika, vlny, spawn nepřátel, věže, projektily a krok simulace.
## Simulace je nezávislá na vykreslení (tick(dt)), takže ji jde rychle spouštět i bez grafiky (testy).

signal gold_changed(value: int)
signal lives_changed(value: int)
signal wave_changed(started: int, total: int)
signal state_changed(state: int)
signal toast(text: String, kind: String)
signal tower_built(tower)
signal tower_removed(tower)
signal tower_upgraded(tower)
signal wave_cleared(wave_number: int, bonus: int)
signal enemy_killed(enemy)
signal ability_used(id: String)

enum State { PLAYING, WON, LOST }

const STEP_MAX: float = 1.0 / 30.0
const TEST_WAVE: int = -1            # vyhrazený index pro testovací nepřátele (neovlivní skutečné vlny)

var max_frame_dt: float = 0.1       # horní mez délky snímku (na pomalých strojích se hra raději zpomalí)

var map: GameMap = null
var path: PathData = null
var theme: GameTheme = null
var fx: Fx = null
var world: Node3D = null
var camera_rig = null
var ambient = null
var audio = null                    # AudioManager (v headless testech není)

var mode_id: String = "campaign"   # campaign | endless
var diff_id: String = "normal"
var diff: Dictionary = {}
var island_hp: float = 1.0                # úprava zdraví nepřátel podle ostrova (kratší cesta = slabší nepřátelé)
var total_waves: int = Cfg.TOTAL_WAVES    # 0 = nekonečný režim
var persist_records: bool = false         # zapisovat rekordy na disk (jen v normální hře, ne v testech)
var best_wave: int = 0                    # nejvyšší zvládnutá vlna v této hře

var gold: int = 0
var lives: int = 0
var waves_started: int = 0
var state: int = State.PLAYING
var time: float = 0.0
var speed_mul: float = 1.0
var paused: bool = false
var auto_wave: bool = false
var fly_altitude: float = 7.0

var towers: Array = []
var enemies: Array = []            # živí, zaměřitelní
var dying: Array = []              # právě umírající (jen animace)
var projectiles: Array = []

var kills: int = 0
var leaked: int = 0
var leak_types: Dictionary = {}     # kdo proklouzl: typ -> počet
var proj_hits: int = 0              # statistika projektilů: zásahy cíle
var proj_fizzles: int = 0           # cíl zemřel dřív, než projektil dorazil (nevznikla škoda)
var total_damage: float = 0.0
var gold_earned: int = 0
var towers_built: int = 0

var ability_cd: Dictionary = {}     # schopnost -> zbývající čas do dalšího použití (s)
var gold_boost_t: float = 0.0       # zbývající čas zlaté horečky (s)
var abilities_used: Dictionary = {}
var seen_types: Dictionary = {}     # typy nepřátel, které už hráč viděl (upozornění při prvním výskytu)

var _spawn_queue: Array = []
var _wave_spawn_left: Dictionary = {}
var _wave_alive: Dictionary = {}
var _wave_done: Dictionary = {}
var _strikes: Array = []
var _uid: int = 1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _auto_timer: float = 0.0


func setup(map_ref: GameMap, theme_ref: GameTheme, world_node: Node3D, fx_node: Fx) -> void:
	map = map_ref
	path = map.terrain.path
	theme = theme_ref
	world = world_node
	fx = fx_node
	fx.map = map
	_rng.seed = 31337
	# výška letu: nad nejvyšší překážkou na přímce portál → Srdce
	var a: Vector3 = map.spawn_pos
	var b: Vector3 = map.base_pos
	var hmax: float = maxf(a.y, b.y)
	for i in range(0, 41):
		var p: Vector3 = a.lerp(b, float(i) / 40.0)
		hmax = maxf(hmax, map.height_at(p.x, p.z))
	fly_altitude = hmax + 6.6
	configure(mode_id, diff_id)


## Nastaví režim ("campaign" | "endless") a obtížnost ("easy" | "normal" | "hard") a začne novou hru.
func configure(mode_in: String, diff_in: String) -> void:
	mode_id = mode_in if (mode_in == "campaign" or mode_in == "endless") else "campaign"
	diff_id = diff_in if Cfg.DIFFICULTIES.has(diff_in) else "normal"
	reset()


func is_endless() -> bool:
	return mode_id == "endless"


func reset() -> void:
	for t in towers:
		(t as Node).queue_free()
	towers.clear()
	for e in enemies:
		(e as Node).queue_free()
	enemies.clear()
	for e2 in dying:
		(e2 as Node).queue_free()
	dying.clear()
	for p in projectiles:
		(p as Node).queue_free()
	projectiles.clear()
	for st in _strikes:
		(st as Node).queue_free()
	_strikes.clear()
	if fx != null:
		fx.clear_all()
	# uvolnit buňky se věžemi
	for i in range(map.cells.size()):
		if map.cells[i] == GameMap.Cell.TOWER:
			map.cells[i] = GameMap.Cell.FREE
	_spawn_queue.clear()
	_wave_spawn_left.clear()
	_wave_alive.clear()
	_wave_done.clear()
	_wave_spawn_left = {}
	_wave_alive = {}
	_wave_done = {TEST_WAVE: true}
	diff = Cfg.DIFFICULTIES[diff_id]
	total_waves = 0 if is_endless() else Cfg.TOTAL_WAVES
	gold = int(diff["gold"])
	lives = int(diff["lives"])
	waves_started = 0
	best_wave = 0
	gold_boost_t = 0.0
	abilities_used = {}
	seen_types = {}
	ability_cd = {}
	for id in Cfg.ABILITY_ORDER:
		ability_cd[id] = 0.0
	time = 0.0
	kills = 0
	leaked = 0
	leak_types = {}
	proj_hits = 0
	proj_fizzles = 0
	total_damage = 0.0
	gold_earned = 0
	towers_built = 0
	state = State.PLAYING
	_auto_timer = 0.0
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	wave_changed.emit(waves_started, total_waves)
	state_changed.emit(state)


# ------------------------------------------------------------------ vlny
func can_start_wave() -> bool:
	return state == State.PLAYING and (total_waves == 0 or waves_started < total_waves) and _spawn_queue.is_empty()


func start_next_wave() -> bool:
	if not can_start_wave():
		return false
	var idx: int = waves_started
	var w: Dictionary = Cfg.wave_def(idx)
	var hp_mul: float = float(w["hp"]) * float(diff["hp"]) * island_hp
	var count: int = 0
	for g in w["groups"]:
		var typ: String = g[0]
		var n: int = int(g[1])
		var interval: float = float(g[2])
		var delay: float = float(g[3])
		for i in range(n):
			_spawn_queue.append({"at": time + delay + float(i) * interval, "type": typ, "wave": idx, "hp": hp_mul})
			count += 1
	_spawn_queue.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))
	_wave_spawn_left[idx] = count
	_wave_alive[idx] = 0
	_wave_done[idx] = false
	waves_started += 1
	wave_changed.emit(waves_started, total_waves)
	toast.emit("Vlna %d začíná!" % waves_started, "info")
	sfx("wave_horn")
	_announce_new_types(idx)
	return true


## Při prvním výskytu nového typu nepřítele vypíše jeho vlastnost.
func _announce_new_types(idx: int) -> void:
	for it in wave_preview(idx):
		var typ: String = str(it["type"])
		if seen_types.has(typ):
			continue
		seen_types[typ] = true
		var d: Dictionary = Cfg.ENEMIES[typ]
		if d.has("tip") and waves_started > 1:
			toast.emit("Nový nepřítel – %s: %s" % [Themes.enemy_name(typ), Themes.enemy_tip(typ)], "warn")


func wave_preview(idx: int) -> Array:
	## Souhrn nadcházející vlny: [{type, count}] seřazeno podle prvního výskytu.
	if idx < 0 or (total_waves > 0 and idx >= total_waves):
		return []
	var counts: Dictionary = {}
	var order: Array = []
	for g in Cfg.wave_def(idx)["groups"]:
		var typ: String = g[0]
		if not counts.has(typ):
			counts[typ] = 0
			order.append(typ)
		counts[typ] = int(counts[typ]) + int(g[1])
	var out: Array = []
	for typ2 in order:
		out.append({"type": typ2, "count": counts[typ2]})
	return out


func _spawn_enemy(entry: Dictionary) -> void:
	var e: Enemy = Enemy.new()
	e.uid = _uid
	_uid += 1
	var lat: float = _rng.randf_range(-0.32, 0.32) if not Cfg.ENEMIES[entry["type"]]["flying"] else 0.0
	if entry["type"] == "boss":
		lat = 0.0
	world.add_child(e)
	e.setup(self, str(entry["type"]), int(entry["wave"]), float(entry["hp"]), lat)
	enemies.append(e)
	var wi: int = int(entry["wave"])
	_wave_spawn_left[wi] = int(_wave_spawn_left.get(wi, 0)) - 1
	_wave_alive[wi] = int(_wave_alive.get(wi, 0)) + 1
	# záblesk portálu
	var sp: Vector3 = map.spawn_pos
	fx.burst_puffs(sp + Vector3(0.0, 1.0, 0.0), Themes.pal("spawn_puff"), 4, 0.8, 0.5, 0.5, 2.0)
	sfx("spawn", sp)


func on_enemy_killed(e: Enemy, source) -> void:
	enemies.erase(e)
	dying.append(e)
	kills += 1
	var reward: int = e.reward
	if gold_boost_t > 0.0:
		reward = int(round(float(reward) * float(Cfg.ABILITIES["gold"]["mult"])))
	gold += reward
	gold_earned += reward
	gold_changed.emit(gold)
	if source != null and is_instance_valid(source):
		source.kills += 1
	var big: bool = e.type == "boss" or e.type == "golem"
	fx.death_burst(e.position + Vector3(0, e.visual.aim_height * 0.6, 0), Themes.enemy_color(e.type), big)
	fx.text(e.position + Vector3(0.0, e.visual.height + 1.0, 0.0), "+%d" % reward, Color(1.0, 0.85, 0.2) if gold_boost_t <= 0.0 else Color(1.0, 0.95, 0.4), 1.45 if big else 1.15, 1.1)
	sfx("death_" + e.type, e.position)
	sfx("coin", e.position, -2.0)
	if e.type == "boss":
		camera_shake(0.35)
	enemy_killed.emit(e)
	# rozpad (slizák): potomci dědí vlnu, takže se vlna nedokončí, dokud žijí
	if e.def.has("split"):
		for k in range(int(e.def["split"])):
			_spawn_child(e, k)
		sfx("slime_split", e.position)
	_wave_alive[e.wave_index] = int(_wave_alive.get(e.wave_index, 0)) - 1
	_check_wave_done(e.wave_index)


func _spawn_child(parent: Enemy, k: int) -> void:
	var ctype: String = str(parent.def["split_type"])
	var cdef: Dictionary = Cfg.ENEMIES[ctype]
	var c: Enemy = Enemy.new()
	c.uid = _uid
	c.spawn_style = "pop"
	_uid += 1
	world.add_child(c)
	var hp_abs: float = parent.max_hp * float(parent.def["split_hp"])
	var lat: float = clampf(parent.lateral + (-0.28 if k % 2 == 0 else 0.28), -0.4, 0.4)
	c.setup(self, ctype, parent.wave_index, hp_abs / float(cdef["hp"]), lat, parent.s)
	enemies.append(c)
	_wave_alive[parent.wave_index] = int(_wave_alive.get(parent.wave_index, 0)) + 1
	fx.burst_puffs(c.position + Vector3(0.0, 0.5, 0.0), Themes.enemy_color(ctype), 4, 0.7, 0.4, 0.5, 0.6)


func on_enemy_reached(e: Enemy) -> void:
	enemies.erase(e)
	dying.append(e)
	leaked += 1
	leak_types[e.type] = int(leak_types.get(e.type, 0)) + 1
	lives = maxi(lives - e.lives_cost, 0)
	lives_changed.emit(lives)
	toast.emit(Themes.t("base_hit") % e.lives_cost, "warn")
	fx.burst_puffs(e.position + Vector3(0, 0.8, 0), Themes.pal("base_hit"), 8, 1.2, 0.7, 0.6, 2.0)
	camera_shake(0.3)
	sfx("base_hit", e.position)
	if ambient != null:
		ambient.flash_heart(1.0)
	_wave_alive[e.wave_index] = int(_wave_alive.get(e.wave_index, 0)) - 1
	if lives <= 0 and state == State.PLAYING:
		state = State.LOST
		_record_result(false)
		state_changed.emit(state)
		sfx("defeat")
		return
	_check_wave_done(e.wave_index)


func _check_wave_done(wi: int) -> void:
	if bool(_wave_done.get(wi, false)):
		return
	if int(_wave_spawn_left.get(wi, 0)) > 0 or int(_wave_alive.get(wi, 0)) > 0:
		return
	_wave_done[wi] = true
	var bonus: int = int(round(float(Cfg.wave_def(wi)["bonus"]) * float(diff["bonus"])))
	if bonus > 0:
		gold += bonus
		gold_earned += bonus
		gold_changed.emit(gold)
	best_wave = maxi(best_wave, wi + 1)
	wave_cleared.emit(wi + 1, bonus)
	if total_waves > 0 and wi + 1 >= total_waves:
		if state == State.PLAYING:
			state = State.WON
			_record_result(true)
			state_changed.emit(state)
			toast.emit("Vítězství! Ostrov je zachráněn!", "good")
			sfx("victory")
	else:
		_record_result(false)
		toast.emit("Vlna %d zvládnuta!%s" % [wi + 1, (" +%d %s" % [bonus, Themes.t("gold_gen")]) if bonus > 0 else ""], "good")
		sfx("wave_clear")


## Zapíše rekord (nejlepší zvládnutá vlna), jen v normální hře.
func _record_result(won: bool) -> void:
	if persist_records and best_wave > 0:
		GameSettings.submit(best_wave, won, lives)


# ------------------------------------------------------------------ věže
func tower_at(c: Vector2i) -> Tower:
	for t in towers:
		if (t as Tower).cell == c:
			return t
	return null


func build_tower(type: String, c: Vector2i) -> Tower:
	if state != State.PLAYING:
		return null
	if not map.can_build(c):
		toast.emit("Sem se stavět nedá.", "warn")
		sfx("ui_error")
		return null
	var cost: int = Cfg.tower_cost(type)
	if gold < cost:
		toast.emit("Nedostatek %s (potřeba %d)." % [Themes.t("gold_gen"), cost], "warn")
		sfx("ui_error")
		return null
	gold -= cost
	gold_changed.emit(gold)
	var t: Tower = Tower.new()
	var pos: Vector3 = map.cell_world(c)
	world.add_child(t)
	t.setup(self, type, c, pos, _uid)
	_uid += 1
	towers.append(t)
	towers_built += 1
	map.set_cell_state(c, GameMap.Cell.TOWER)
	fx.ring(Vector3(pos.x, pos.y + 0.3, pos.z), Themes.pal("build_ring"), 2.2, 0.45, 0.16, 0.2, 0.6)
	fx.burst_puffs(pos + Vector3(0.0, 0.6, 0.0), Themes.pal("build_puff"), 8, 1.2, 0.7, 0.6)
	fx.dust_ring(Vector3(pos.x, pos.y - 0.2, pos.z), Themes.pal("build_dust"), 10, 1.2, 0.55)
	sfx("build", pos)
	tower_built.emit(t)
	return t


func upgrade_tower(t: Tower) -> bool:
	if state != State.PLAYING or t == null or not t.can_upgrade():
		return false
	var cost: int = t.upgrade_cost()
	if gold < cost:
		toast.emit("Nedostatek %s (potřeba %d)." % [Themes.t("gold_gen"), cost], "warn")
		sfx("ui_error")
		return false
	gold -= cost
	gold_changed.emit(gold)
	t.upgrade()
	sfx("upgrade", t.position)
	tower_upgraded.emit(t)
	return true


func sell_tower(t: Tower) -> void:
	if t == null:
		return
	var value: int = t.sell_value()
	gold += value
	gold_changed.emit(gold)
	map.set_cell_state(t.cell, GameMap.Cell.FREE)
	fx.burst_puffs(t.position + Vector3(0, 0.8, 0), Themes.pal("sell_puff"), 8, 1.2, 0.7, 0.6)
	fx.text(t.position + Vector3(0.0, 2.2, 0.0), "+%d" % value, Themes.pal("gold_text"), 1.3, 1.0)
	sfx("sell", t.position)
	towers.erase(t)
	tower_removed.emit(t)
	t.retire_and_free()


# ------------------------------------------------------------------ cílení
func targets_in_range(tower: Tower, rng: float, mode: String) -> Array:
	var out: Array = []
	var p: Vector3 = tower.position
	for e in enemies:
		if not tower.is_valid_target(e):
			continue
		var dx: float = e.position.x - p.x
		var dz: float = e.position.z - p.z
		var r: float = rng + e.radius * 0.4
		if dx * dx + dz * dz <= r * r:
			out.append(e)
	if out.size() > 1:
		match mode:
			"first":
				out.sort_custom(func(a, b): return a.progress() > b.progress())
			"last":
				out.sort_custom(func(a, b): return a.progress() < b.progress())
			"strong":
				out.sort_custom(func(a, b): return a.hp > b.hp)
			_:
				out.sort_custom(func(a, b):
					var da: float = Vector2(a.position.x - p.x, a.position.z - p.z).length_squared()
					var db: float = Vector2(b.position.x - p.x, b.position.z - p.z).length_squared()
					return da < db)
	return out


func spawn_projectile(kind: String, from_tower: Tower, tgt, params: Dictionary) -> void:
	var pr: Projectile = Projectile.new()
	world.add_child(pr)
	pr.setup(self, kind, from_tower, tgt, params)
	projectiles.append(pr)


func sfx(sound: String, pos = null, vol_db: float = 0.0) -> void:
	if audio != null:
		audio.play(sound, pos, vol_db)


func is_wave_active() -> bool:
	return not _spawn_queue.is_empty() or not enemies.is_empty()


func camera_shake(amount: float) -> void:
	if camera_rig != null:
		camera_rig.add_shake(amount)


# ------------------------------------------------------------------ krok simulace
func advance(real_dt: float) -> void:
	if paused or state != State.PLAYING:
		return
	var dt_total: float = minf(real_dt, max_frame_dt) * speed_mul
	var n: int = maxi(int(ceil(dt_total / STEP_MAX)), 1)
	var h: float = dt_total / float(n)
	for i in range(n):
		tick(h)


func tick(dt: float) -> void:
	time += dt
	# spawn
	while not _spawn_queue.is_empty() and float(_spawn_queue[0]["at"]) <= time:
		var entry: Dictionary = _spawn_queue.pop_front()
		_spawn_enemy(entry)
	# nepřátelé
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			e.update(dt)
	# umírající
	var i: int = dying.size() - 1
	while i >= 0:
		var d: Enemy = dying[i]
		d.update(dt)
		if d._death_t >= d.death_duration():
			d.queue_free()
			dying.remove_at(i)
		i -= 1
	# věže
	for t in towers:
		t.update(dt)
	# projektily
	var j: int = projectiles.size() - 1
	while j >= 0:
		var pr: Projectile = projectiles[j]
		pr.update(dt)
		if pr.done:
			projectiles.remove_at(j)
		j -= 1
	fx.tick(dt)
	# schopnosti: čas do dalšího použití, zlatá horečka, meteory za letu
	for id in ability_cd.keys():
		var was: float = float(ability_cd[id])
		ability_cd[id] = maxf(was - dt, 0.0)
		if was > 0.0 and float(ability_cd[id]) <= 0.0 and state == State.PLAYING:
			sfx("ability_ready")
	gold_boost_t = maxf(gold_boost_t - dt, 0.0)
	var m: int = _strikes.size() - 1
	while m >= 0:
		var st: MeteorStrike = _strikes[m]
		st.update(dt)
		if st.done:
			st.queue_free()
			_strikes.remove_at(m)
		m -= 1
	# automatické spuštění další vlny
	if auto_wave and state == State.PLAYING and can_start_wave() and enemies.is_empty():
		_auto_timer += dt
		if _auto_timer > 4.0:
			_auto_timer = 0.0
			start_next_wave()
	else:
		_auto_timer = 0.0


# ------------------------------------------------------------------ aktivní schopnosti hráče
func ability_ready(id: String) -> bool:
	return state == State.PLAYING and not paused and float(ability_cd.get(id, 0.0)) <= 0.0


## Síla meteoru roste s vlnou (stejně jako zdraví nepřátel), ať zůstane užitečný.
func ability_power() -> float:
	return float(Cfg.wave_def(maxi(waves_started - 1, 0))["hp"])


func _use_ability(id: String) -> void:
	ability_cd[id] = float(Cfg.ABILITIES[id]["cooldown"])
	abilities_used[id] = int(abilities_used.get(id, 0)) + 1
	ability_used.emit(id)


func cast_meteor(pos: Vector3) -> bool:
	if not ability_ready("meteor"):
		return false
	var ab: Dictionary = Cfg.ABILITIES["meteor"]
	var st: MeteorStrike = MeteorStrike.new()
	world.add_child(st)
	st.setup(self, Vector3(pos.x, map.height_at(pos.x, pos.z), pos.z), float(ab["damage"]) * ability_power(), float(ab["radius"]))
	_strikes.append(st)
	_use_ability("meteor")
	sfx("meteor_fall", pos)
	return true


func cast_blizzard() -> bool:
	if not ability_ready("blizzard"):
		return false
	var ab: Dictionary = Cfg.ABILITIES["blizzard"]
	for e in enemies:
		var en: Enemy = e
		if not en.is_targetable():
			continue
		en.apply_freeze(float(ab["freeze"]))
		en.apply_slow(float(ab["slow"]), float(ab["slow_time"]) + float(ab["freeze"]))
		fx.burst_puffs(en.position + Vector3(0.0, en.visual.aim_height, 0.0), Themes.pal("blizzard_puff"), 5, 0.8, 0.5, 0.6, 1.2)
	var c: Vector3 = Vector3(0.0, map.height_at(0.0, 0.0) + 0.4, 0.0)
	fx.ring(c, Themes.pal("blizzard_ring"), 48.0, 1.1, 0.07, 0.12, 1.0)
	fx.ring(c, Color(1.0, 1.0, 1.0), 40.0, 0.9, 0.04, 0.0, 1.4)
	camera_shake(0.12)
	_use_ability("blizzard")
	sfx("blizzard")
	toast.emit(Themes.t("blizzard_toast"), "good")
	return true


func cast_gold() -> bool:
	if not ability_ready("gold"):
		return false
	gold_boost_t = float(Cfg.ABILITIES["gold"]["duration"])
	var bp: Vector3 = map.base_pos
	fx.ring(Vector3(bp.x, bp.y + 0.3, bp.z), Themes.pal("gold_ring"), 4.5, 0.9, 0.12, 0.2, 1.4)
	fx.burst_puffs(bp + Vector3(0.0, 1.5, 0.0), Themes.pal("gold_ring"), 12, 2.0, 0.6, 0.9, 2.0)
	_use_ability("gold")
	sfx("gold_rush")
	toast.emit(Themes.t("gold_toast") % int(gold_boost_t), "good")
	return true


# ------------------------------------------------------------------ pro testy a statistiky
func snapshot() -> Dictionary:
	var ts: Array = []
	for t in towers:
		ts.append({"id": t.uid, "type": t.type, "level": t.level, "cx": t.cell.x, "cz": t.cell.y,
			"damage": snappedf(t.damage_dealt, 0.1), "kills": t.kills, "mode": t.target_mode})
	var es: Array = []
	for e in enemies:
		es.append({"id": e.uid, "type": e.type, "hp": snappedf(e.hp, 0.1), "max_hp": snappedf(e.max_hp, 0.1), "shield": snappedf(e.shield, 0.1),
			"frozen": e.frozen_t > 0.0, "s": snappedf(e.s, 0.01),
			"x": snappedf(e.position.x, 0.01), "z": snappedf(e.position.z, 0.01), "y": snappedf(e.position.y, 0.01)})
	return {
		"gold": gold, "lives": lives, "wave": waves_started, "total_waves": total_waves, "mode": mode_id, "difficulty": diff_id,
		"ability_cd": ability_cd.duplicate(), "gold_boost": snappedf(gold_boost_t, 0.01), "best_wave": best_wave,
		"state": state, "time": snappedf(time, 0.01), "kills": kills, "leaked": leaked,
		"enemies": es, "towers": ts, "projectiles": projectiles.size(), "spawn_left": _spawn_queue.size(),
		"paused": paused, "speed": speed_mul, "total_damage": snappedf(total_damage, 0.1),
	}
