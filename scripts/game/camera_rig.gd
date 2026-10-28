class_name CameraRig
extends Node3D
## Izometrická kamera (ortogonální projekce, sklon 35,264° = pravá izometrie).
## Ovládání: pravé tlačítko myši = otáčení, kolečko = přiblížení, prostřední tlačítko = posun,
## Q/E = otáčení, W/A/S/D nebo šipky = posun, +/− = zoom, F = původní pohled.

const PITCH_DEG: float = 35.264
const DIST: float = 150.0
const DEFAULT_YAW: float = 45.0
const DEFAULT_SIZE: float = 50.0
const MIN_SIZE: float = 16.0
const MAX_SIZE: float = 72.0
const PAN_LIMIT: float = 24.0

var camera: Camera3D = null
var yaw_deg: float = DEFAULT_YAW
var target_yaw: float = DEFAULT_YAW
var zoom_size: float = DEFAULT_SIZE
var target_zoom: float = DEFAULT_SIZE
var target_pivot: Vector3 = Vector3.ZERO
var input_enabled: bool = true

var _shake: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _drag_rot: bool = false
var _drag_pan: bool = false
var _drag_dist: float = 0.0
var _touches: Dictionary = {}


func _ready() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = zoom_size
	camera.near = 1.0
	camera.far = 420.0
	camera.current = true
	var p: float = deg_to_rad(PITCH_DEG)
	camera.transform = Transform3D(Basis(Vector3.RIGHT, -p), Vector3(0.0, sin(p) * DIST, cos(p) * DIST))
	add_child(camera)
	_apply()


func _apply() -> void:
	rotation.y = deg_to_rad(yaw_deg)
	camera.size = zoom_size
	position = target_pivot


func add_shake(amount: float) -> void:
	_shake = minf(maxf(_shake, amount), 0.8)


func reset_view() -> void:
	target_yaw = DEFAULT_YAW
	target_zoom = DEFAULT_SIZE
	target_pivot = Vector3.ZERO


func rotate_by(deg: float) -> void:
	target_yaw += deg


func zoom_by(factor: float) -> void:
	target_zoom = clampf(target_zoom * factor, MIN_SIZE, MAX_SIZE)


func was_drag() -> bool:
	## Posun myši mezi stiskem a puštěním (rozlišení kliknutí od tažení).
	return _drag_dist > 6.0


func _pan_pixels(rel: Vector2) -> void:
	var vh: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var k: float = zoom_size / vh
	var right: Vector3 = global_transform.basis.x
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var sinp: float = sin(deg_to_rad(PITCH_DEG))
	target_pivot += -right * rel.x * k + fwd * (rel.y * k / sinp)
	_clamp_pivot()


func _clamp_pivot() -> void:
	target_pivot.y = 0.0
	var flat: Vector2 = Vector2(target_pivot.x, target_pivot.z)
	if flat.length() > PAN_LIMIT:
		flat = flat.normalized() * PAN_LIMIT
		target_pivot.x = flat.x
		target_pivot.z = flat.y


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_by(0.9)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(1.1)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_drag_rot = true
				_drag_dist = 0.0
			elif mb.button_index == MOUSE_BUTTON_MIDDLE:
				_drag_pan = true
				_drag_dist = 0.0
		else:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_drag_rot = false
			elif mb.button_index == MOUSE_BUTTON_MIDDLE:
				_drag_pan = false
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _drag_rot:
			target_yaw -= mm.relative.x * 0.32
			_drag_dist += mm.relative.length()
		elif _drag_pan:
			_pan_pixels(mm.relative)
			_drag_dist += mm.relative.length()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		var prev: Dictionary = _touches.duplicate()
		_touches[sd.index] = sd.position
		if _touches.size() == 1:
			_pan_pixels(sd.relative)
		elif _touches.size() == 2 and prev.size() == 2:
			var ks: Array = _touches.keys()
			var a_old: Vector2 = prev[ks[0]]
			var b_old: Vector2 = prev[ks[1]]
			var a_new: Vector2 = _touches[ks[0]]
			var b_new: Vector2 = _touches[ks[1]]
			var d_old: float = a_old.distance_to(b_old)
			var d_new: float = a_new.distance_to(b_new)
			if d_old > 1.0 and d_new > 1.0:
				zoom_by(d_old / d_new)
			var ang_old: float = (b_old - a_old).angle()
			var ang_new: float = (b_new - a_new).angle()
			target_yaw -= rad_to_deg(angle_difference(ang_old, ang_new))
	elif event is InputEventPanGesture:
		var pg: InputEventPanGesture = event
		_pan_pixels(-pg.delta * 8.0)
	elif event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		zoom_by(1.0 / maxf(mg.factor, 0.1))


func _process(delta: float) -> void:
	if input_enabled:
		var rot: float = 0.0
		if Input.is_key_pressed(KEY_Q):
			rot += 1.0
		if Input.is_key_pressed(KEY_E):
			rot -= 1.0
		target_yaw += rot * 100.0 * delta
		var mv: Vector2 = Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			mv.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			mv.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			mv.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			mv.x += 1.0
		if mv != Vector2.ZERO:
			mv = mv.normalized()
			var right: Vector3 = global_transform.basis.x
			var fwd: Vector3 = -global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var speed: float = zoom_size * 0.7
			target_pivot += (right * mv.x - fwd * mv.y) * speed * delta
			_clamp_pivot()
		if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
			zoom_by(1.0 - 1.2 * delta)
		if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
			zoom_by(1.0 + 1.2 * delta)
	var k: float = 1.0 - exp(-11.0 * delta)
	yaw_deg = lerpf(yaw_deg, target_yaw, k)
	zoom_size = lerpf(zoom_size, target_zoom, k)
	position = position.lerp(target_pivot, k)
	rotation.y = deg_to_rad(yaw_deg)
	camera.size = zoom_size
	# otřes kamery
	if _shake > 0.001:
		_shake *= exp(-8.0 * delta)
		camera.h_offset = _rng.randf_range(-1.0, 1.0) * _shake * 1.2
		camera.v_offset = _rng.randf_range(-1.0, 1.0) * _shake * 1.2
	else:
		_shake = 0.0
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Průsečík paprsku z pozice na obrazovce s terénem (nebo null).
func pick_ground(mouse_pos: Vector2, map: GameMap):
	var o: Vector3 = camera.project_ray_origin(mouse_pos)
	var d: Vector3 = camera.project_ray_normal(mouse_pos)
	if d.y > -0.001:
		return null
	var t0: float = (24.0 - o.y) / d.y
	var start: Vector3 = o + d * t0
	var step: float = 0.3
	var prev_t: float = 0.0
	for i in range(0, 520):
		var t: float = float(i) * step
		var p: Vector3 = start + d * t
		if p.y <= map.height_at(p.x, p.z):
			# zjemnění půlením intervalu
			var lo: float = prev_t
			var hi: float = t
			for k in range(8):
				var mid: float = (lo + hi) * 0.5
				var pm: Vector3 = start + d * mid
				if pm.y <= map.height_at(pm.x, pm.z):
					hi = mid
				else:
					lo = mid
			return start + d * hi
		prev_t = t
	return null
