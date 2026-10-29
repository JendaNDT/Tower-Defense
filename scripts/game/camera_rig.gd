class_name CameraRig
extends Node3D
## Izometrická kamera (ortogonální projekce, sklon 35,264° = pravá izometrie) s přepínačem na pohled přesně shora (sklon 90°).
## Ovládání: pravé tlačítko myši = otáčení, kolečko = přiblížení, prostřední tlačítko = posun,
## Q/E = otáčení, W/A/S/D nebo šipky = posun, +/− = zoom, V = pohled shora / izometrie, Home = původní pohled.
## Dotyk: jeden prst = posun, dva prsty = přiblížení, otáčení a posun; krátké klepnutí vyšle signál `tapped`.

signal tapped(pos: Vector2)

const TAP_MOVE_MAX: float = 14.0       # největší posun prstu (v pixelech obsahu), aby se ještě počítalo jako klepnutí
const PITCH_DEG: float = 35.264        # izometrický sklon
const TOP_PITCH_DEG: float = 90.0      # pohled přesně shora
const DIST: float = 150.0
const DEFAULT_YAW: float = 45.0
const DEFAULT_SIZE: float = 56.0
const MIN_SIZE: float = 16.0
const MAX_SIZE: float = 96.0
const PAN_LIMIT: float = 32.0

var camera: Camera3D = null
var yaw_deg: float = DEFAULT_YAW
var target_yaw: float = DEFAULT_YAW
var zoom_size: float = DEFAULT_SIZE
var target_zoom: float = DEFAULT_SIZE
var target_pivot: Vector3 = Vector3.ZERO
var pitch_deg: float = PITCH_DEG
var target_pitch: float = PITCH_DEG
var input_enabled: bool = true

var _shake: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _drag_rot: bool = false
var _drag_pan: bool = false
var _drag_dist: float = 0.0
var ui_blocker: Callable = Callable()   # (Vector2) -> bool: bod leží na prvku rozhraní, takový dotyk kameru neovládá
var _touch: Dictionary = {}              # index prstu -> {"pos", "start", "t0", "ui"}
var _tap_ok: bool = false
var _yaw_before_top: float = DEFAULT_YAW   # natočení před přepnutím na pohled shora (po návratu se obnoví, pokud se nezměnilo)
var _yaw_top: float = 0.0


func _ready() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = zoom_size
	camera.near = 1.0
	camera.far = 420.0
	camera.current = true
	add_child(camera)
	_apply_pitch()
	_apply()


## Postaví kameru ve vzdálenosti DIST pod aktuálním sklonem (90° = přímo nad středem pohledu).
func _apply_pitch() -> void:
	var p: float = deg_to_rad(pitch_deg)
	camera.transform = Transform3D(Basis(Vector3.RIGHT, -p), Vector3(0.0, sin(p) * DIST, cos(p) * DIST))


func _apply() -> void:
	rotation.y = deg_to_rad(yaw_deg)
	camera.size = zoom_size
	position = target_pivot


func add_shake(amount: float) -> void:
	_shake = minf(maxf(_shake, amount), 0.8)


func reset_view() -> void:
	target_pitch = PITCH_DEG
	target_yaw = DEFAULT_YAW
	target_zoom = DEFAULT_SIZE
	target_pivot = Vector3.ZERO


## Přesune pohled na bod světa (x, z), např. z minimapy.
func focus_xz(p: Vector2) -> void:
	target_pivot = Vector3(p.x, 0.0, p.y)
	_clamp_pivot()


func top_view() -> bool:
	return target_pitch > (PITCH_DEG + TOP_PITCH_DEG) * 0.5


## Pohled přesně shora: mřížka polí je pak souměrná čtvercová síť, proto se natočení zarovná na nejbližší násobek 90°.
## Při návratu do izometrie se vrátí původní natočení (pokud ho hráč mezitím neotočil).
func set_top_view(on: bool) -> void:
	if on == top_view():
		return
	if on:
		_yaw_before_top = target_yaw
		target_yaw = roundf((target_yaw - 0.01) / 90.0) * 90.0
		_yaw_top = target_yaw
		target_pitch = TOP_PITCH_DEG
	else:
		if absf(target_yaw - _yaw_top) < 1.0:
			target_yaw = _yaw_before_top
		target_pitch = PITCH_DEG


func toggle_top_view() -> void:
	set_top_view(not top_view())


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
	var sinp: float = maxf(sin(deg_to_rad(pitch_deg)), 0.2)
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
	elif event is InputEventPanGesture:
		var pg: InputEventPanGesture = event
		_pan_pixels(-pg.delta * 8.0)
	elif event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		zoom_by(1.0 / maxf(mg.factor, 0.1))


## Dotyk se zpracovává už v _input (před rozhraním): Godot jinak část dotyků pohltí jako „klik myší“ na tlačítko,
## které bylo naposledy stisknuto, a klepnutí na mapu by se ztratilo. Dotyky na prvcích rozhraní se vyřadí přes ui_blocker.
func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _free_touches() -> Array:
	## Indexy prstů, které nezačaly na prvku rozhraní.
	var out: Array = []
	for k in _touch.keys():
		if not bool(_touch[k]["ui"]):
			out.append(k)
	out.sort()
	return out


func _on_touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		var over_ui: bool = ui_blocker.is_valid() and bool(ui_blocker.call(st.position))
		_touch[st.index] = {"pos": st.position, "start": st.position, "t0": Time.get_ticks_msec(), "ui": over_ui}
		_tap_ok = (not over_ui) and _free_touches().size() == 1
		if _free_touches().size() >= 2:
			_tap_ok = false
		return
	if not _touch.has(st.index):
		return
	var t: Dictionary = _touch[st.index]
	_touch.erase(st.index)
	# klepnutí = prst se nepohnul; délka dotyku se záměrně nehlídá (na pomalém zařízení se stisk a puštění zpracují
	# s odstupem celých snímků a delší dotyk by se jinak ztratil)
	if _tap_ok and not bool(t["ui"]) and st.position.distance_to(t["start"]) <= TAP_MOVE_MAX:
		tapped.emit(st.position)
	if _free_touches().is_empty():
		_tap_ok = false


func _on_drag(sd: InputEventScreenDrag) -> void:
	if not _touch.has(sd.index):
		return
	var free: Array = _free_touches()
	var me: Dictionary = _touch[sd.index]
	if bool(me["ui"]):
		me["pos"] = sd.position
		return
	if free.size() == 1:
		if sd.position.distance_to(me["start"]) > TAP_MOVE_MAX:
			_tap_ok = false
		me["pos"] = sd.position
		_pan_pixels(sd.relative)
		return
	_tap_ok = false
	var ia: int = free[0]
	var ib: int = free[1]
	var a_old: Vector2 = _touch[ia]["pos"]
	var b_old: Vector2 = _touch[ib]["pos"]
	me["pos"] = sd.position
	var a_new: Vector2 = _touch[ia]["pos"]
	var b_new: Vector2 = _touch[ib]["pos"]
	var d_old: float = a_old.distance_to(b_old)
	var d_new: float = a_new.distance_to(b_new)
	if d_old > 1.0 and d_new > 1.0:
		zoom_by(d_old / d_new)
	target_yaw += rad_to_deg(angle_difference((b_old - a_old).angle(), (b_new - a_new).angle()))
	_pan_pixels((a_new + b_new) * 0.5 - (a_old + b_old) * 0.5)


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
	if absf(pitch_deg - target_pitch) > 0.001:
		pitch_deg = lerpf(pitch_deg, target_pitch, k)
		if absf(pitch_deg - target_pitch) < 0.02:
			pitch_deg = target_pitch
		_apply_pitch()
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
