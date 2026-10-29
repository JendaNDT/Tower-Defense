class_name Tower
extends Node3D
## Věž: hledá cíle podle priority, natáčí se a střílí. Chování dle typu:
##  archer – rychlé šípy (od L3 dva najednou, od L4 kritické zásahy a probití brnění)
##  cannon – dělová koule po balistické křivce s výbuchem (od L3 hoření, od L4 omráčení), jen pozemní cíle
##  mage   – naváděná magická koule ignorující brnění, od L3 řetězový blesk
##  frost  – kruhový pulz, zpomalí všechny nepřátele v dosahu, od L4 každý 3. pulz zmrazí

const PULSE_SPEED: float = 15.0

var game = null
var type: String = "archer"
var level: int = 1
var cell: Vector2i = Vector2i.ZERO
var uid: int = 0
var cooldown: float = 0.3
var target_mode: String = "first"
var visual: TowerVisual = null
var elev: int = 0                 # výškový stupeň pole (0 rovina, 1 kopec, 2 vrchol): násobí dosah
var damage_dealt: float = 0.0
var kills: int = 0
var shots_fired: int = 0

var _stats_cache: Dictionary = {}
var _stats_level: int = 0
var _pending: Array = []          # mrazové pulzy čekající na dosažení nepřítele vlnou
var _pulse_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(game_ref, type_id: String, c: Vector2i, world_pos: Vector3, id: int) -> void:
	game = game_ref
	type = type_id
	cell = c
	uid = id
	position = world_pos
	name = "Tower_%s_%d" % [type_id, id]
	_rng.seed = 1000 + id
	elev = game.map.elev_at(c)
	_build_visual("build")


## Statistiky podle úrovně; dosah je zvětšený podle výšky pole (kopec +15 %, vrchol +30 %).
func stats() -> Dictionary:
	if _stats_level != level or _stats_cache.is_empty():
		_stats_level = level
		_stats_cache = Cfg.tower_level(type, level).duplicate()
		_stats_cache["range"] = float(_stats_cache["range"]) * float(Cfg.ELEV_RANGE[elev])
	return _stats_cache


func spec() -> Dictionary:
	return Cfg.TOWERS[type]


func total_invested() -> int:
	return Cfg.invested(type, level)


func sell_value() -> int:
	return Cfg.sell_value(type, level)


func can_upgrade() -> bool:
	return level < Cfg.MAX_LEVEL


func upgrade_cost() -> int:
	return Cfg.upgrade_cost(type, level)


func upgrade() -> void:
	level += 1
	_build_visual("upgrade")
	# efekt vylepšení
	var p: Vector3 = position
	game.fx.ring(Vector3(p.x, p.y + 0.3, p.z), Themes.pal("upgrade_ring"), 2.6, 0.55, 0.16, 0.25, 1.0)
	game.fx.burst_puffs(p + Vector3(0.0, 1.0, 0.0), Themes.pal("upgrade_puff"), 10, 1.4, 0.5, 0.7, 2.0)
	game.fx.text(p + Vector3(0.0, 3.4, 0.0), "Úroveň %d" % level, Color(1.0, 0.9, 0.4), 1.5, 1.2)


## Prodej: model se zmenší a zmizí, pak se uzel uvolní (věž už není v seznamu věží, nestřílí).
func retire_and_free() -> void:
	if visual != null and is_instance_valid(visual):
		visual.retire()
	var tw: Tween = create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(queue_free)


func _build_visual(animate: String = "") -> void:
	if visual != null:
		if animate == "upgrade":
			visual.retire()                 # starý model se zmenší a zmizí, nový se „nafoukne“
		else:
			remove_child(visual)
			visual.queue_free()
	visual = game.theme.make_tower_visual(type, level)
	add_child(visual)
	if animate == "build":
		visual.play_build()
	elif animate == "upgrade":
		visual.play_upgrade()


func is_valid_target(e) -> bool:
	if not e.is_targetable():
		return false
	var sp: Dictionary = spec()
	if e.flying:
		return bool(sp["air"])
	return bool(sp["ground"])


func _update_pending(dt: float) -> void:
	var i: int = _pending.size() - 1
	while i >= 0:
		var pd: Dictionary = _pending[i]
		pd["delay"] = float(pd["delay"]) - dt
		if float(pd["delay"]) <= 0.0:
			var e = pd["enemy"]
			if e != null and is_instance_valid(e) and e.is_targetable():
				e.apply_slow(float(pd["slow"]), float(pd["slow_time"]))
				if float(pd["freeze"]) > 0.0:
					e.apply_freeze(float(pd["freeze"]))
					game.sfx("freeze_hit", e.aim_pos())
				e.take_damage(float(pd["damage"]), "magic", self)
				game.fx.hit_spark(e.aim_pos(), Themes.pal("frost_hit"))
			_pending.remove_at(i)
		i -= 1


func update(dt: float) -> void:
	cooldown = maxf(cooldown - dt, 0.0)
	_update_pending(dt)
	var st: Dictionary = stats()
	var targets: Array = game.targets_in_range(self, float(st["range"]), target_mode)
	if targets.is_empty():
		return
	var primary = targets[0]
	var aim: Vector3 = primary.aim_pos()
	visual.aim_at(aim, dt)
	if cooldown > 0.0:
		return
	if type != "frost" and not visual.is_aimed(aim, 0.35):
		return
	_fire(targets, st)
	cooldown = float(st["cooldown"])
	shots_fired += 1


func _fire(targets: Array, st: Dictionary) -> void:
	visual.play_fire()
	var from: Vector3 = visual.muzzle_pos()
	var fdir: Vector3 = (targets[0].aim_pos() - from).normalized()
	match type:
		"archer":
			game.fx.muzzle_flash(from, fdir, Themes.pal("muzzle_archer"), 0.22, 2)
		"cannon":
			game.fx.muzzle_flash(from, fdir, Themes.pal("muzzle_cannon"), 0.9, 5)
		"mage":
			game.fx.muzzle_flash(from, fdir, Themes.pal("muzzle_mage"), 0.45, 3)
	match type:
		"archer":
			var n: int = int(st["shots"])
			for i in range(n):
				var tgt = targets[mini(i, targets.size() - 1)]
				var crit: bool = _rng.randf() < float(st["crit"])
				var dmg: float = float(st["damage"]) * (2.0 if crit else 1.0)
				game.spawn_projectile("arrow", self, tgt, {"damage": dmg, "pierce": float(st["pierce"]), "crit": crit, "delay": 0.09 * float(i)})
			game.fx.puff(from, Themes.pal("archer_puff"), 0.1, 0.3, 0.2, 0.0, 0.0, 0.5)
			game.sfx("archer_shot", from)
		"cannon":
			game.spawn_projectile("ball", self, targets[0], {
				"damage": float(st["damage"]), "splash": float(st["splash"]),
				"burn": float(st["burn"]), "burn_time": float(st["burn_time"]), "stun": float(st["stun"]),
			})
			game.sfx("cannon_shot", from)
			game.fx.burst_puffs(from, Themes.pal("cannon_smoke"), 4, 0.8, 0.6, 0.7, 0.0)
			game.fx.burst_puffs(from, Themes.pal("cannon_fire"), 3, 0.5, 0.45, 0.25, 2.0)
		"mage":
			game.spawn_projectile("orb", self, targets[0], {
				"damage": float(st["damage"]), "chain": int(st["chain"]),
				"chain_falloff": float(st["chain_falloff"]), "chain_range": float(st["chain_range"]),
			})
			game.sfx("mage_cast", from)
			game.fx.burst_puffs(from, Themes.pal("mage_puff"), 4, 0.5, 0.3, 0.3, 2.5)
		_:
			_pulse_count += 1
			var freeze: float = 0.0
			var fe: int = int(st["freeze_every"])
			if fe > 0 and _pulse_count % fe == 0:
				freeze = float(st["freeze_time"])
			var origin: Vector3 = position
			game.sfx("frost_pulse", origin + Vector3(0.0, 1.0, 0.0))
			var rng: float = float(st["range"])
			var col: Color = Themes.pal("frost_ring") if freeze <= 0.0 else Themes.pal("frost_ring_freeze")
			game.fx.ring(Vector3(origin.x, origin.y + 0.35, origin.z), col, rng, rng / PULSE_SPEED + 0.1, 0.12, 0.18, 1.0)
			game.fx.burst_puffs(origin + Vector3(0.0, 1.0, 0.0), Themes.pal("frost_puff"), 6, 1.0, 0.45, 0.6, 1.5)
			for e in game.enemies:
				if not is_valid_target(e):
					continue
				var d: float = Vector2(e.position.x - origin.x, e.position.z - origin.z).length()
				if d <= rng + e.radius * 0.4:
					_pending.append({
						"enemy": e, "delay": d / PULSE_SPEED,
						"slow": float(st["slow"]), "slow_time": float(st["slow_time"]),
						"damage": float(st["damage"]), "freeze": freeze,
					})
