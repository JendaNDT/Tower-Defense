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
var damage_dealt: float = 0.0
var kills: int = 0
var shots_fired: int = 0

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
	_build_visual()


func stats() -> Dictionary:
	return Cfg.tower_level(type, level)


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
	_build_visual()
	# efekt vylepšení
	var p: Vector3 = position
	game.fx.ring(Vector3(p.x, p.y + 0.3, p.z), Color(1.0, 0.85, 0.4), 2.6, 0.55, 0.16, 0.25, 1.0)
	game.fx.burst_puffs(p + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.9, 0.5), 10, 1.4, 0.5, 0.7, 2.0)
	game.fx.text(p + Vector3(0.0, 3.4, 0.0), "Úroveň %d" % level, Color(1.0, 0.9, 0.4), 1.5, 1.2)


func _build_visual() -> void:
	if visual != null:
		remove_child(visual)
		visual.queue_free()
	visual = game.theme.make_tower_visual(type, level)
	add_child(visual)


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
				e.take_damage(float(pd["damage"]), "magic", self)
				game.fx.hit_spark(e.aim_pos(), Color(0.7, 0.95, 1.0))
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
	match type:
		"archer":
			var n: int = int(st["shots"])
			for i in range(n):
				var tgt = targets[mini(i, targets.size() - 1)]
				var crit: bool = _rng.randf() < float(st["crit"])
				var dmg: float = float(st["damage"]) * (2.0 if crit else 1.0)
				game.spawn_projectile("arrow", self, tgt, {"damage": dmg, "pierce": float(st["pierce"]), "crit": crit, "delay": 0.09 * float(i)})
			game.fx.puff(from, Color(1, 1, 1), 0.1, 0.3, 0.2, 0.0, 0.0, 0.5)
		"cannon":
			game.spawn_projectile("ball", self, targets[0], {
				"damage": float(st["damage"]), "splash": float(st["splash"]),
				"burn": float(st["burn"]), "burn_time": float(st["burn_time"]), "stun": float(st["stun"]),
			})
			game.fx.burst_puffs(from, Color(0.9, 0.9, 0.85), 4, 0.8, 0.6, 0.7, 0.0)
			game.fx.burst_puffs(from, Color(1.0, 0.7, 0.25), 3, 0.5, 0.45, 0.25, 2.0)
		"mage":
			game.spawn_projectile("orb", self, targets[0], {
				"damage": float(st["damage"]), "chain": int(st["chain"]),
				"chain_falloff": float(st["chain_falloff"]), "chain_range": float(st["chain_range"]),
			})
			game.fx.burst_puffs(from, Color(0.75, 0.55, 1.0), 4, 0.5, 0.3, 0.3, 2.5)
		_:
			_pulse_count += 1
			var freeze: float = 0.0
			var fe: int = int(st["freeze_every"])
			if fe > 0 and _pulse_count % fe == 0:
				freeze = float(st["freeze_time"])
			var origin: Vector3 = position
			var rng: float = float(st["range"])
			var col: Color = Color(0.55, 0.88, 1.0) if freeze <= 0.0 else Color(0.85, 0.97, 1.0)
			game.fx.ring(Vector3(origin.x, origin.y + 0.35, origin.z), col, rng, rng / PULSE_SPEED + 0.1, 0.12, 0.18, 1.0)
			game.fx.burst_puffs(origin + Vector3(0.0, 1.0, 0.0), Color(0.8, 0.95, 1.0), 6, 1.0, 0.45, 0.6, 1.5)
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
