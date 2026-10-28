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


func _process(delta: float) -> void:
	_t += delta
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
