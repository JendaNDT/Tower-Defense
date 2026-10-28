class_name Enemy
extends Node3D
## Nepřítel: pohyb po vyhlazené trase podle uražené vzdálenosti `s` (nemůže se zaseknout ani projít objektem),
## létající letí po přímce nad nejvyšší překážkou. Stavy: zpomalení, omráčení, zmrazení, hoření.

const DEATH_TIME: float = 0.4

var game = null                    # Game
var type: String = "goblin"
var def: Dictionary = {}
var uid: int = 0
var wave_index: int = 0

var hp: float = 1.0
var max_hp: float = 1.0
var armor: float = 0.0
var base_speed: float = 2.0
var reward: int = 1
var lives_cost: int = 1
var flying: bool = false
var radius: float = 0.5
var cc_mult: float = 1.0           # odolnost vůči zpomalení/omráčení (boss)

var s: float = 0.0                 # uražená vzdálenost po trase
var path_len: float = 1.0
var lateral: float = 0.0
var alive: bool = true
var dying: bool = false
var reached: bool = false

var slow_amt: float = 0.0
var slow_t: float = 0.0
var stun_t: float = 0.0
var frozen_t: float = 0.0
var burn_dps: float = 0.0
var burn_t: float = 0.0
var burn_source = null

var visual: EnemyVisual = null
var fly_from: Vector2 = Vector2.ZERO
var fly_to: Vector2 = Vector2.ZERO
var fly_alt: float = 6.0
var cur_speed: float = 0.0

var _death_t: float = 0.0
var _heading: float = 0.0
var _acc_dmg: float = 0.0
var _acc_t: float = -10.0


func setup(game_ref, type_id: String, wave_idx: int, hp_mult: float, lateral_offset: float) -> void:
	game = game_ref
	type = type_id
	def = Cfg.ENEMIES[type_id]
	wave_index = wave_idx
	max_hp = float(def["hp"]) * hp_mult
	hp = max_hp
	armor = float(def["armor"])
	base_speed = float(def["speed"])
	reward = int(def["reward"])
	lives_cost = int(def["lives"])
	flying = bool(def["flying"])
	radius = float(def["radius"])
	lateral = lateral_offset
	if type_id == "boss":
		cc_mult = 0.5
	name = "%s_%d" % [type_id, uid]
	visual = game.theme.make_enemy_visual(type_id)
	add_child(visual)
	visual.stepped.connect(_on_step)
	if flying:
		var sp: Vector3 = game.map.spawn_pos
		var bp: Vector3 = game.map.base_pos
		fly_from = Vector2(sp.x, sp.z)
		fly_to = Vector2(bp.x, bp.z)
		path_len = fly_from.distance_to(fly_to)
		fly_alt = game.fly_altitude
	else:
		path_len = game.path.length
	s = 0.0
	position = _compute_pos(0.0)
	var d0: Vector2 = _dir_at(0.0)
	_heading = atan2(d0.x, d0.y)
	visual.rotation.y = _heading
	visual.set_health(1.0, type == "boss")


func _on_step(p: Vector3) -> void:
	if game != null and game.fx != null:
		var gy: float = game.map.height_at(p.x, p.z)
		game.fx.burst_puffs(Vector3(p.x, gy + 0.15, p.z), Color(0.75, 0.68, 0.58), 3, 0.7, 0.55, 0.45)
		game.sfx("stomp", p, 0.0 if type == "boss" else -4.0)
		if type == "boss":
			game.camera_shake(0.05)


func progress() -> float:
	return s / maxf(path_len, 0.01)


func _dir_at(sv: float) -> Vector2:
	if flying:
		return (fly_to - fly_from).normalized()
	return game.path.dir_at(sv)


func _compute_pos(sv: float) -> Vector3:
	if flying:
		var f: float = clampf(sv / maxf(path_len, 0.01), 0.0, 1.0)
		var p2: Vector2 = fly_from.lerp(fly_to, f)
		var y: float = fly_alt
		# posledních 6 m plynule klesnout k Srdci ostrova
		var left: float = path_len - sv
		if left < 6.0:
			y = lerpf(fly_alt, game.map.base_pos.y + 1.8, smoothstep(0.0, 1.0, 1.0 - clampf(left / 6.0, 0.0, 1.0)))
		return Vector3(p2.x, y, p2.y)
	var base: Vector3 = game.path.pos_at(sv)
	var d: Vector2 = game.path.dir_at(sv)
	return base + Vector3(-d.y, 0.0, d.x) * lateral


func current_speed() -> float:
	if stun_t > 0.0 or frozen_t > 0.0:
		return 0.0
	var m: float = 1.0
	if slow_t > 0.0:
		m = 1.0 - slow_amt
	return base_speed * m


## Bod, kam mířit (střed těla) v čase `t` od teď – podle rychlosti po trase.
func aim_pos_at(t: float) -> Vector3:
	var sv: float = minf(s + current_speed() * t, path_len)
	var p: Vector3 = _compute_pos(sv)
	return p + Vector3(0.0, visual.aim_height, 0.0)


func aim_pos() -> Vector3:
	return position + Vector3(0.0, visual.aim_height, 0.0)


func is_targetable() -> bool:
	return alive and not dying


# ------------------------------------------------------------------ poškození a stavy
func take_damage(amount: float, kind: String = "phys", source = null, pierce: float = 0.0, crit: bool = false) -> float:
	if not alive:
		return 0.0
	var eff: float = amount
	if kind == "phys":
		var a: float = armor * (1.0 - pierce)
		eff = maxf(amount - a, amount * 0.2)
	var dealt: float = minf(eff, hp)
	hp -= eff
	if source != null:
		source.damage_dealt += dealt
	game.total_damage += dealt
	visual.flash()
	visual.set_health(maxf(hp, 0.0) / max_hp, type == "boss")
	# plovoucí čísla (sloučená, ať to nepřekáží)
	_acc_dmg += dealt
	if crit or game.time - _acc_t >= 0.3:
		if kind != "dot" or game.time - _acc_t >= 0.6:
			var col: Color = Color(1.0, 0.92, 0.35) if crit else Color(1.0, 1.0, 1.0, 0.9)
			game.fx.text(position + Vector3(0.0, visual.height + 0.5, 0.0), str(int(round(_acc_dmg))) + ("!" if crit else ""), col, 1.25 if crit else 0.8, 0.8)
			_acc_dmg = 0.0
			_acc_t = game.time
	if hp <= 0.0:
		die(source)
	return dealt


func apply_slow(amount: float, time: float) -> void:
	var a: float = amount * cc_mult
	if slow_t <= 0.0 or a >= slow_amt:
		slow_amt = a
		slow_t = time
	else:
		slow_t = maxf(slow_t, time * 0.5)


func apply_stun(time: float) -> void:
	stun_t = maxf(stun_t, time * (0.4 if type == "boss" else 1.0))


func apply_freeze(time: float) -> void:
	frozen_t = maxf(frozen_t, time * (0.4 if type == "boss" else 1.0))


func apply_burn(dps: float, time: float, source) -> void:
	if dps >= burn_dps or burn_t <= 0.0:
		burn_dps = dps
		burn_source = source
	burn_t = maxf(burn_t, time)


func die(source) -> void:
	if not alive:
		return
	alive = false
	dying = true
	_death_t = 0.0
	game.on_enemy_killed(self, source)


func reach_base() -> void:
	if not alive:
		return
	alive = false
	dying = true
	reached = true
	_death_t = 0.0
	game.on_enemy_reached(self)


# ------------------------------------------------------------------ aktualizace
func update(dt: float) -> void:
	if dying:
		_death_t += dt
		var k: float = clampf(_death_t / DEATH_TIME, 0.0, 1.0)
		var sc: float = 1.0 - k * k
		if reached:
			visual.scale = Vector3.ONE * sc
		else:
			# zhroucení: smrsknutí + pád
			visual.scale = Vector3(1.0 + 0.25 * k, maxf(1.0 - k, 0.02), 1.0 + 0.25 * k)
		visual.set_health(0.0)
		if visual.bar != null:
			visual.bar.visible = false
		return
	if slow_t > 0.0:
		slow_t -= dt
		if slow_t <= 0.0:
			slow_amt = 0.0
	if stun_t > 0.0:
		stun_t -= dt
	if frozen_t > 0.0:
		frozen_t -= dt
	if burn_t > 0.0:
		burn_t -= dt
		take_damage(burn_dps * dt, "dot", burn_source)
		if not alive:
			return
	cur_speed = current_speed()
	s += cur_speed * dt
	position = _compute_pos(s)
	# plynulé natáčení po směru pohybu
	var d: Vector2 = _dir_at(s)
	var want: float = atan2(d.x, d.y)
	_heading = lerp_angle(_heading, want, 1.0 - exp(-10.0 * dt))
	visual.rotation.y = _heading
	var sf: float = 1.0 if base_speed <= 0.0 else cur_speed / base_speed
	visual.animate(dt, cur_speed, sf)
	visual.set_status(slow_amt if slow_t > 0.0 else 0.0, frozen_t > 0.0, burn_t > 0.0)
	if s >= path_len - 0.001:
		reach_base()
