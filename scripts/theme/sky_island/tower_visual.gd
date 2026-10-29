class_name TowerVisual
extends Node3D
## Vizuál věže: nehybná část + otočná část (turret) + animace (vznášení, rotující prstence, zpětný ráz, záblesk).

var turret: Node3D = null          # otáčí se za cílem
var barrel: Node3D = null          # kanón: zpětný ráz a náměr
var muzzle: Node3D = null          # bod, odkud vylétá projektil
var aim_speed: float = 9.0
var pulse_nodes: Array = []        # uzly, které se při výstřelu „nafouknou“ (krystaly)

var _spinners: Array = []          # {node, axis, speed}
var _bobbers: Array = []           # {node, y0, amp, speed, phase}
var _recoil: float = 0.0
var _pulse: float = 0.0
var _t: float = 0.0
var _barrel_rest: Vector3 = Vector3.ZERO
var _barrel_pitch_rest: float = 0.0
const BUILD_TIME: float = 0.6
const UPGRADE_TIME: float = 0.5
const RETIRE_TIME: float = 0.22

var _build_t: float = -1.0           # průběh animace stavby / vylepšení (s), -1 = neběží
var _build_kind: String = "build"
var _retire_t: float = -1.0          # průběh zmizení (prodej / nahrazení vylepšeným modelem)


func add_spinner(n: Node3D, axis: Vector3, speed: float) -> void:
	_spinners.append({"node": n, "axis": axis, "speed": speed})


func add_bobber(n: Node3D, amp: float, speed: float, phase: float = 0.0) -> void:
	_bobbers.append({"node": n, "y0": n.position.y, "amp": amp, "speed": speed, "phase": phase})


func setup_barrel(b: Node3D) -> void:
	barrel = b
	_barrel_rest = b.position
	_barrel_pitch_rest = b.rotation.x


## Plynule natočí otočnou část k cíli (světová pozice).
func aim_at(target: Vector3, dt: float) -> void:
	if turret == null:
		return
	var d: Vector3 = target - global_position
	var yaw: float = atan2(d.x, d.z)
	var k: float = 1.0 - exp(-aim_speed * dt)
	turret.rotation.y = lerp_angle(turret.rotation.y, yaw, k)
	if barrel != null:
		var horiz: float = Vector2(d.x, d.z).length()
		var want: float = -clampf(0.12 + horiz * 0.04, 0.12, 0.62)
		barrel.rotation.x = lerpf(barrel.rotation.x, want, k)


func is_aimed(target: Vector3, tolerance: float = 0.25) -> bool:
	if turret == null:
		return true
	var d: Vector3 = target - global_position
	var yaw: float = atan2(d.x, d.z)
	return absf(angle_difference(turret.rotation.y, yaw)) < tolerance


func muzzle_pos() -> Vector3:
	if muzzle != null:
		return muzzle.global_position
	return global_position + Vector3(0.0, 1.2, 0.0)


func play_fire() -> void:
	_pulse = 1.0
	_recoil = 1.0


## Věž vyroste ze země (s přeskokem a rozplácnutím), nebo se po vylepšení „nafoukne“ z menšího modelu.
func play_build() -> void:
	_build_kind = "build"
	_build_t = 0.0
	_apply_build(0.0)


func play_upgrade() -> void:
	_build_kind = "upgrade"
	_build_t = 0.0
	_apply_build(0.0)


## Zmenší se a zmizí (prodej, starý model při vylepšení); pak se sám uvolní.
func retire() -> void:
	_retire_t = 0.0
	set_process(true)


func is_animating() -> bool:
	return _build_t >= 0.0 or _retire_t >= 0.0


static func ease_out_back(k: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var x: float = k - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x


func build_time() -> float:
	return BUILD_TIME if _build_kind == "build" else UPGRADE_TIME


func _apply_retire(k: float) -> void:
	scale = Vector3.ONE * maxf(1.0 - k * k, 0.001)
	position.y = 0.35 * k


## Jen pro testy: zastaví animaci v daném okamžiku t (s) a nechá ji tak stát. kind: build | upgrade | retire.
func seek_anim(kind: String, t: float) -> void:
	set_process(false)
	if kind == "retire":
		_retire_t = t
		_apply_retire(clampf(t / RETIRE_TIME, 0.0, 1.0))
	else:
		_build_kind = kind
		_build_t = t
		_apply_build(clampf(t / build_time(), 0.0, 1.0))


func _apply_build(k: float) -> void:
	var e: float = ease_out_back(clampf(k, 0.0, 1.0))
	if _build_kind == "build":
		# roste ze země: výška 0 -> 1 s přeskokem, do stran se na začátku rozplácne
		var sy: float = maxf(e, 0.02)
		var sxz: float = 1.0 + (1.0 - minf(sy, 1.0)) * 0.3
		scale = Vector3(sxz, sy, sxz)
		position.y = -0.5 * (1.0 - clampf(k, 0.0, 1.0)) * (1.0 - clampf(k, 0.0, 1.0))
	else:
		var s: float = 0.55 + 0.45 * e
		scale = Vector3(s, s, s)
		position.y = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _build_t >= 0.0:
		_build_t += delta
		var dur: float = build_time()
		if _build_t >= dur:
			_build_t = -1.0
			scale = Vector3.ONE
			position.y = 0.0
		else:
			_apply_build(_build_t / dur)
	if _retire_t >= 0.0:
		_retire_t += delta
		var kr: float = clampf(_retire_t / RETIRE_TIME, 0.0, 1.0)
		_apply_retire(kr)
		if kr >= 1.0:
			queue_free()
			return
	for s in _spinners:
		(s["node"] as Node3D).rotate_object_local(s["axis"], float(s["speed"]) * delta)
	for b in _bobbers:
		(b["node"] as Node3D).position.y = float(b["y0"]) + sin(_t * float(b["speed"]) + float(b["phase"])) * float(b["amp"])
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 4.5, 0.0)
		var sc: float = 1.0 + 0.28 * _pulse
		for n in pulse_nodes:
			(n as Node3D).scale = Vector3(sc, sc, sc)
	if barrel != null:
		if _recoil > 0.0:
			_recoil = maxf(_recoil - delta * 3.2, 0.0)
		var back: Vector3 = barrel.transform.basis * Vector3(0.0, 0.0, -0.3 * _recoil)
		barrel.position = _barrel_rest + back
