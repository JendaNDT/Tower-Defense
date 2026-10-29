class_name MeteorStrike
extends Node3D
## Meteor (aktivní schopnost): padá z výšky na zvolené místo, při dopadu zasáhne všechny nepřátele v okruhu.
## Průběh řídí Game.tick (čas hry), takže se správně zrychluje i zastavuje s hrou.

const FLIGHT: float = 0.9

var game = null
var target: Vector3 = Vector3.ZERO
var damage: float = 100.0
var radius: float = 3.5
var burn_dps: float = 0.0
var burn_time: float = 0.0
var done: bool = false
var hit_count: int = 0                 # kolik nepřátel zasáhl (pro testy)

var _t: float = 0.0
var _start: Vector3 = Vector3.ZERO
var _body: MeshInstance3D = null
var _impacted: bool = false
var _spin: Vector3 = Vector3(2.1, 1.3, 1.7)


func setup(game_ref, target_pos: Vector3, dmg: float, rad: float) -> void:
	game = game_ref
	target = target_pos
	damage = dmg
	radius = rad
	var ab: Dictionary = Cfg.ABILITIES["meteor"]
	burn_dps = dmg * float(ab["burn_frac"])
	burn_time = float(ab["burn_time"])
	name = "Meteor"
	_start = target + Vector3(9.0, 36.0, -7.0)
	var k: MeshKit = MeshKit.new(77, 0.1)
	k.blob(0.85, Color(0.34, 0.22, 0.16), Transform3D.IDENTITY, 0.0, 7, 5, 0.18, 901)
	k.sphere(0.5, Color(1.0, 0.5, 0.1), MeshKit.xf(Vector3(0.0, 0.0, 0.0)), 2.8, 7, 5)
	_body = Gfx.mesh_node(k, Gfx.model_mat(0.7, 0.0), false)
	add_child(_body)
	position = _start
	look_at_from_position(_start, target, Vector3.UP)
	# varovný kruh dopadu: roste až na poloměr výbuchu přesně do chvíle dopadu
	game.fx.ring(Vector3(target.x, target.y + 0.15, target.z), Color(1.0, 0.35, 0.2), radius, FLIGHT, 0.1, 0.14, 0.9)


func update(dt: float) -> void:
	if done:
		return
	if _impacted:
		done = true
		return
	_t += dt
	var k: float = clampf(_t / FLIGHT, 0.0, 1.0)
	position = _start.lerp(target + Vector3(0.0, 0.5, 0.0), k * k)
	_body.rotation += _spin * dt
	game.fx.puff(position + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.55, 0.15), 1.1, 0.2, 0.4, 0.0, 1.8, 0.8)
	if k >= 1.0:
		_impact()


func _impact() -> void:
	_impacted = true
	_body.visible = false
	var fx: Fx = game.fx
	fx.explosion(target + Vector3(0.0, 0.3, 0.0), radius)
	fx.scorch(target, radius * 1.15, 0.8, 22.0)
	fx.explosion(target + Vector3(0.0, 0.3, 0.0), radius * 0.6)
	fx.ring(Vector3(target.x, target.y + 0.2, target.z), Color(1.0, 0.9, 0.5), radius * 1.4, 0.55, 0.1, 0.1, 1.4)
	fx.debris(target + Vector3(0.0, 0.5, 0.0), Color(0.34, 0.22, 0.16), 14, 6.0, 0.22, 1.3)
	fx.debris(target + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.5, 0.15), 8, 5.0, 0.16, 1.0, 2.0)
	game.camera_shake(0.55)
	game.sfx("meteor_hit", target)
	for o in game.enemies.duplicate():
		var en: Enemy = o
		if not is_instance_valid(en) or not en.is_targetable():
			continue
		var dx: float = en.position.x - target.x
		var dz: float = en.position.z - target.z
		var r: float = radius + en.radius * 0.4
		if dx * dx + dz * dz > r * r:
			continue
		hit_count += 1
		en.apply_burn(burn_dps, burn_time, null)
		en.take_damage(damage, "magic", null)
