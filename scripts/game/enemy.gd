class_name Enemy
extends Node3D
## Nepřítel: pohyb po vyhlazené trase podle uražené vzdálenosti `s` (nemůže se zaseknout ani projít objektem),
## létající letí po přímce nad nejvyšší překážkou. Stavy: zpomalení, omráčení, zmrazení, hoření.

const SPAWN_TIME: float = 0.5

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
var shield: float = 0.0            # štít (štítonoš): pohlcuje poškození dřív než zdraví
var max_shield: float = 0.0
var _shield_idle: float = 0.0      # čas od posledního zásahu do štítu
var _heal_t: float = 0.0

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
var spawn_style: String = "portal"   # portal = vystoupí z portálu, pop = vyskočí na místě (potomci slizáku)
var _age: float = 0.0
var _spawn_done: bool = false
var _reach_pos: Vector3 = Vector3.ZERO
var _death_from: Vector3 = Vector3.ZERO
var _death_fx_done: bool = false
var _ripple_t: float = 0.0


func setup(game_ref, type_id: String, wave_idx: int, hp_mult: float, lateral_offset: float, start_s: float = 0.0) -> void:
	game = game_ref
	type = type_id
	def = Cfg.ENEMIES[type_id]
	wave_index = wave_idx
	max_hp = float(def["hp"]) * hp_mult
	hp = max_hp
	armor = float(def["armor"])
	base_speed = float(def["speed"]) * float(game.diff["speed"])
	reward = int(def["reward"])
	lives_cost = int(def["lives"])
	flying = bool(def["flying"])
	radius = float(def["radius"])
	lateral = lateral_offset
	if type_id == "boss":
		cc_mult = 0.5
	if def.has("shield"):
		max_shield = float(def["shield"]) * hp_mult
		shield = max_shield
	if def.has("heal_every"):
		_heal_t = float(def["heal_every"]) * 0.6
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
	s = start_s
	position = _compute_pos(start_s)
	var d0: Vector2 = _dir_at(start_s)
	_heading = atan2(d0.x, d0.y)
	visual.rotation.y = _heading
	visual.set_health(1.0, type == "boss")
	if max_shield > 0.0:
		visual.set_shield(1.0)


## Příchod: nepřítel vystoupí zpoza portálu (nebo vyskočí na místě) a „nafoukne“ se na plnou velikost.
func _animate_spawn(k: float) -> void:
	var e: float = TowerVisual.ease_out_back(clampf(k, 0.0, 1.0))
	visual.scale = Vector3.ONE * (0.35 + 0.65 * e)
	if spawn_style == "portal":
		var back: Vector3 = Vector3(-sin(_heading), 0.0, -cos(_heading)) * 1.1 * (1.0 - clampf(k, 0.0, 1.0))
		visual.position = back


## Smrt podle typu: skřet a léčitel padají na záda, vlk na bok, obři se rozsypou, dráček se zřítí, slizák se rozplácne.
func _animate_death(k: float, dt: float) -> void:
	var fall: float = 1.0 - (1.0 - k) * (1.0 - k)
	var shrink: float = 1.0 - smoothstep(0.65, 1.0, k)
	match visual.death_style:
		"fall_side":
			visual.rotation.z = fall * 1.5
			visual.position.y = -0.1 * smoothstep(0.6, 1.0, k)
			visual.scale = Vector3.ONE * shrink
		"crumble":
			visual.position = Vector3(sin(_death_t * 70.0) * 0.07 * (1.0 - k), -0.45 * k * k, cos(_death_t * 63.0) * 0.07 * (1.0 - k))
			var sq: float = pow(k, 1.4)
			visual.scale = Vector3(1.0 + 0.18 * sq, maxf(1.0 - 0.85 * sq, 0.03), 1.0 + 0.18 * sq) * (1.0 if k < 0.85 else (1.0 - (k - 0.85) / 0.15))
			if k > 0.45 and not _death_fx_done:
				_death_fx_done = true
				var gy: float = game.map.height_at(position.x, position.z)
				game.fx.dust_ring(Vector3(position.x, gy + 0.1, position.z), Themes.pal("crumble_dust"), 8, radius * 2.2, 0.8)
		"crash":
			# dráček se řítí šikmo dolů, točí se; při dopadu se rozprskne
			var gyc: float = game.map.height_at(position.x, position.z) + 0.3
			position.y = lerpf(_death_from.y, gyc, k * k)
			var dirc: Vector2 = _dir_at(s)
			position += Vector3(dirc.x, 0.0, dirc.y) * dt * 2.0 * (1.0 - k)
			visual.rotation.z = -k * PI * 3.0
			visual.rotation.x = k * 1.1
			visual.scale = Vector3.ONE * (1.0 if k < 0.88 else (1.0 - (k - 0.88) / 0.12))
			if k >= 0.88 and not _death_fx_done:
				_death_fx_done = true
				game.fx.burst_puffs(Vector3(position.x, gyc, position.z), Themes.pal("crash_puff"), 6, 1.0, 0.6, 0.6, 0.6)
				game.fx.dust_ring(Vector3(position.x, gyc - 0.1, position.z), Themes.pal("crash_dust"), 6, 1.0, 0.5)
		"splat":
			var e: float = 1.0 - pow(1.0 - minf(k * 2.2, 1.0), 2.0)
			var fade: float = 1.0 - smoothstep(0.6, 1.0, k)
			visual.scale = Vector3(1.0 + 0.8 * e, maxf(1.0 - 0.93 * e, 0.05), 1.0 + 0.8 * e) * fade
			if not _death_fx_done:
				_death_fx_done = true
				var gys: float = game.map.height_at(position.x, position.z)
				game.fx.dust_ring(Vector3(position.x, gys + 0.1, position.z), Themes.enemy_color(type), 7, radius * 2.0, 0.5)
		_:
			visual.rotation.x = -fall * 1.45
			visual.position.y = -0.12 * smoothstep(0.6, 1.0, k)
			visual.scale = Vector3.ONE * shrink


## Dorazil k Srdci: letí do krystalu, točí se a zmenšuje.
func _animate_absorb(k: float, dt: float) -> void:
	var tgt: Vector3 = game.map.base_pos + Vector3(0.0, 1.9, 0.0)
	position = _reach_pos.lerp(tgt, k * k)
	visual.rotation.y += dt * 9.0
	visual.scale = Vector3.ONE * maxf(1.0 - k * k * 0.97, 0.03)
	if k >= 0.97 and not _death_fx_done:
		_death_fx_done = true
		game.fx.hit_spark(tgt, Themes.pal("absorb_spark"))


func death_duration() -> float:
	return 0.7 if reached else visual.death_time


func _on_step(p: Vector3) -> void:
	if game != null and game.fx != null:
		var gy: float = game.map.height_at(p.x, p.z)
		game.fx.burst_puffs(Vector3(p.x, gy + 0.15, p.z), Themes.pal("step_dust"), 3, 0.7, 0.55, 0.45)
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
	var absorbed: float = 0.0
	if shield > 0.0:
		absorbed = minf(eff, shield)
		shield -= absorbed
		eff -= absorbed
		_shield_idle = 0.0
		visual.set_shield(maxf(shield, 0.0) / max_shield)
		if source != null:
			source.damage_dealt += absorbed
		game.total_damage += absorbed
		if shield <= 0.0:
			game.fx.burst_puffs(position + Vector3(0.0, visual.aim_height + 0.2, 0.0), Themes.pal("shield_break"), 8, 1.0, 0.5, 0.6, 1.6)
			game.fx.ring(Vector3(position.x, position.y + 0.3, position.z), Themes.pal("shield_break"), 1.8, 0.4, 0.14, 0.1, 1.0)
			game.sfx("shield_break", position)
	var dealt: float = minf(eff, hp)
	hp -= eff
	if source != null:
		source.damage_dealt += dealt
	game.total_damage += dealt
	visual.flash()
	visual.set_health(maxf(hp, 0.0) / max_hp, type == "boss")
	# plovoucí čísla (sloučená, ať to nepřekáží)
	dealt += absorbed
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


## Vyléčení (léčitel): vrací skutečně obnovené zdraví.
func heal(amount: float) -> float:
	if not alive or hp >= max_hp:
		return 0.0
	var got: float = minf(amount, max_hp - hp)
	hp += got
	visual.set_health(hp / max_hp, type == "boss")
	return got


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
	_death_from = position
	game.on_enemy_killed(self, source)


func reach_base() -> void:
	if not alive:
		return
	alive = false
	dying = true
	reached = true
	_death_t = 0.0
	_reach_pos = position
	game.on_enemy_reached(self)


## Pulz léčitele: obnoví zdraví všem ostatním živým nepřátelům v dosahu.
func _do_heal() -> void:
	var r: float = float(def["heal_radius"])
	var frac: float = float(def["heal_frac"])
	var healed: int = 0
	for o in game.enemies:
		var en: Enemy = o
		if en == self or not en.is_targetable():
			continue
		var dx: float = en.position.x - position.x
		var dz: float = en.position.z - position.z
		if dx * dx + dz * dz > r * r:
			continue
		var got: float = en.heal(en.max_hp * frac)
		if got > 0.0:
			healed += 1
			game.fx.burst_puffs(en.position + Vector3(0.0, en.visual.aim_height + 0.3, 0.0), Themes.pal("heal"), 3, 0.5, 0.3, 0.6, 1.4)
	game.fx.ring(Vector3(position.x, position.y + 0.25, position.z), Themes.pal("heal"), r, 0.7, 0.08, 0.1, 1.0)
	if healed > 0:
		game.sfx("heal", position)


# ------------------------------------------------------------------ aktualizace
func update(dt: float) -> void:
	if dying:
		_death_t += dt
		var kd: float = clampf(_death_t / death_duration(), 0.0, 1.0)
		visual.set_health(0.0)
		if visual.bar != null:
			visual.bar.visible = false
		if reached:
			_animate_absorb(kd, dt)
		else:
			_animate_death(kd, dt)
		return
	_age += dt
	if _age < SPAWN_TIME:
		_animate_spawn(_age / SPAWN_TIME)
	elif not _spawn_done:
		_spawn_done = true
		visual.scale = Vector3.ONE
		visual.position = Vector3.ZERO
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
	if max_shield > 0.0 and shield > 0.0 and shield < max_shield:
		_shield_idle += dt
		if _shield_idle > 3.0:
			shield = minf(shield + max_shield * float(def["shield_regen"]) * dt, max_shield)
			visual.set_shield(shield / max_shield)
	if def.has("heal_every"):
		_heal_t -= dt
		if _heal_t <= 0.0:
			_heal_t += float(def["heal_every"])
			_do_heal()
	if not flying and game.map.is_on_bridge(s):
		_ripple_t -= dt
		if _ripple_t <= 0.0:
			_ripple_t = 0.6
			# kruhy se šíří po hladině po obou stranách mostu (přímo pod mostem by je nebylo vidět)
			var dirb: Vector2 = _dir_at(s)
			for side in [-1.0, 1.0]:
				var rx: float = position.x - dirb.y * 1.9 * side
				var rz: float = position.z + dirb.x * 1.9 * side
				var wy: float = game.map.terrain.water_y_at(rx, rz)
				if wy > -50.0:
					game.fx.ring(Vector3(rx, wy + 0.03, rz), Themes.pal("ripple"), 1.2 + radius, 1.0, 0.2, 0.0, 0.6)
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
