class_name Projectile
extends Node3D
## Projektil s uzavřenou smyčkou navádění: v každém kroku se z aktuální polohy přepočítá rychlost tak, aby
## letěl po balistické křivce přesně do PŘEDPOVĚZENÉHO bodu cíle v čase dopadu (cíl se pohybuje po známé trase).
## Díky tomu vždy dorazí k cíli přesně v čase `_t_total` (nemůže minout ani projít skrz) a i při změně
## rychlosti cíle (zpomalení) se křivka plynule opraví.

var game = null
var kind: String = "arrow"
var tower = null
var target = null
var damage: float = 1.0
var pierce: float = 0.0
var crit: bool = false
var splash: float = 0.0
var burn: float = 0.0
var burn_time: float = 0.0
var stun: float = 0.0
var chain: int = 0
var chain_falloff: float = 0.6
var chain_range: float = 3.5
var speed: float = 28.0
var grav: float = 4.0
var launch_delay: float = 0.0
var done: bool = false

var visual: Node3D = null
var _started: bool = false
var _t_total: float = 0.3
var _t_el: float = 0.0
var _impact: Vector3 = Vector3.ZERO
var _vel: Vector3 = Vector3.ZERO
var _trail: float = 0.0
var _phase: float = 0.0


func setup(game_ref, k: String, from_tower, tgt, params: Dictionary) -> void:
	game = game_ref
	kind = k
	tower = from_tower
	target = tgt
	damage = float(params.get("damage", 1.0))
	pierce = float(params.get("pierce", 0.0))
	crit = bool(params.get("crit", false))
	splash = float(params.get("splash", 0.0))
	burn = float(params.get("burn", 0.0))
	burn_time = float(params.get("burn_time", 0.0))
	stun = float(params.get("stun", 0.0))
	chain = int(params.get("chain", 0))
	chain_falloff = float(params.get("chain_falloff", 0.6))
	chain_range = float(params.get("chain_range", 3.5))
	launch_delay = float(params.get("delay", 0.0))
	match k:
		"arrow":
			speed = 30.0
			grav = 5.0
		"ball":
			speed = 14.0
			grav = 20.0
		_:
			speed = 13.0
			grav = 0.0
	_phase = randf() * TAU
	visual = game.theme.make_projectile_visual(k)
	add_child(visual)
	visible = false
	position = from_tower.visual.muzzle_pos()


func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and target.alive


func _start() -> void:
	_started = true
	var from: Vector3 = tower.visual.muzzle_pos()
	position = from
	var aim: Vector3 = target.aim_pos() if _target_ok() else from + Vector3(0, 0, 1)
	var t: float = maxf(from.distance_to(aim) / speed, 0.18)
	for i in range(3):
		if _target_ok():
			aim = target.aim_pos_at(t)
		t = maxf(from.distance_to(aim) / speed, 0.18)
	_t_total = t
	_impact = aim
	_vel = (aim - from) / t + Vector3(0.0, 0.5 * grav * t, 0.0)
	_t_el = 0.0
	visible = true


func update(dt: float) -> void:
	if done:
		return
	if launch_delay > 0.0:
		launch_delay -= dt
		return
	if not _started:
		if not _target_ok():
			_finish()
			return
		_start()
	_t_el += dt
	var rem: float = _t_total - _t_el
	if _target_ok() and rem > 0.0:
		_impact = target.aim_pos_at(rem)
	if rem <= dt + 0.0001:
		position = _impact
		_on_impact()
		return
	var need: Vector3 = (_impact - position) / rem + Vector3(0.0, 0.5 * grav * rem, 0.0)
	position += need * dt + Vector3(0.0, -0.5 * grav * dt * dt, 0.0)
	_vel = need - Vector3(0.0, grav * dt, 0.0)
	if _vel.length_squared() > 0.0001:
		var fwd: Vector3 = _vel.normalized()
		var up: Vector3 = Vector3.UP if absf(fwd.y) < 0.98 else Vector3.RIGHT
		basis = Basis.looking_at(fwd, up)
	# vizuální vlnění magické koule (nemění skutečnou polohu; na dopadu je nulové)
	if kind == "orb" and visual != null:
		var perp: Vector3 = _vel.cross(Vector3.UP).normalized()
		var amp: float = 0.32 * clampf(rem / maxf(_t_total, 0.01), 0.0, 1.0)
		visual.position = (basis.inverse() * perp) * sin(_t_el * 16.0 + _phase) * amp
	# stopa za projektilem
	_trail += dt
	if _trail >= 0.035:
		_trail = 0.0
		match kind:
			"arrow":
				game.fx.puff(position, Color(1, 1, 1), 0.07, 0.02, 0.22, 0.0, 0.0, 0.35)
			"ball":
				game.fx.puff(position, Color(0.4, 0.38, 0.36), 0.25, 0.75, 0.55, 0.3, 0.0, 0.5)
				game.fx.puff(position, Color(1.0, 0.6, 0.2), 0.2, 0.05, 0.18, 0.0, 2.0, 0.8)
			_:
				game.fx.puff(position, Color(0.72, 0.5, 1.0), 0.22, 0.04, 0.3, 0.0, 2.2, 0.7)


func _finish() -> void:
	done = true
	queue_free()


func _on_impact() -> void:
	var hit_pos: Vector3 = position
	match kind:
		"arrow":
			if _target_ok():
				game.proj_hits += 1
				game.sfx("arrow_hit", hit_pos)
				target.take_damage(damage, "phys", tower, pierce, crit)
				game.fx.hit_spark(hit_pos, Color(1.0, 0.92, 0.65))
			else:
				game.proj_fizzles += 1
				game.fx.puff(Vector3(hit_pos.x, game.map.height_at(hit_pos.x, hit_pos.z) + 0.1, hit_pos.z), Color(0.7, 0.62, 0.5), 0.2, 0.6, 0.4, 0.2, 0.0, 0.5)
		"ball":
			var gy: float = game.map.height_at(hit_pos.x, hit_pos.z)
			game.fx.explosion(Vector3(hit_pos.x, gy + 0.2, hit_pos.z), splash)
			game.sfx("explosion", hit_pos)
			game.camera_shake(0.12)
			var any_hit: bool = false
			for e in game.enemies:
				if not e.is_targetable() or e.flying:
					continue
				var d: float = Vector2(e.position.x - hit_pos.x, e.position.z - hit_pos.z).length()
				if d <= splash + e.radius * 0.5:
					any_hit = true
					var f: float = lerpf(1.0, 0.5, clampf(d / maxf(splash, 0.01), 0.0, 1.0))
					e.take_damage(damage * f, "phys", tower)
					if burn > 0.0 and e.alive:
						e.apply_burn(burn, burn_time, tower)
					if stun > 0.0 and e.alive:
						e.apply_stun(stun)
			if any_hit:
				game.proj_hits += 1
			else:
				game.proj_fizzles += 1
		_:
			if _target_ok():
				game.proj_hits += 1
				game.sfx("magic_hit", hit_pos)
				target.take_damage(damage, "magic", tower)
				game.fx.hit_spark(hit_pos, Color(0.8, 0.6, 1.0))
				_do_chain(target, hit_pos)
			else:
				game.proj_fizzles += 1
				game.fx.hit_spark(hit_pos, Color(0.8, 0.6, 1.0))
	_finish()


func _do_chain(first, from_pos: Vector3) -> void:
	if chain <= 0:
		return
	var hit: Array = [first]
	var last_pos: Vector3 = from_pos
	var dmg: float = damage
	for i in range(chain):
		var best = null
		var best_d: float = chain_range
		for e in game.enemies:
			if not e.is_targetable() or hit.has(e):
				continue
			var d: float = e.aim_pos().distance_to(last_pos)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		dmg *= chain_falloff
		var np: Vector3 = best.aim_pos()
		game.fx.beam([last_pos, np], Color(0.75, 0.6, 1.0), 0.2, 0.07)
		game.sfx("zap", np)
		game.fx.hit_spark(np, Color(0.8, 0.65, 1.0))
		best.take_damage(dmg, "magic", tower)
		hit.append(best)
		last_pos = np
