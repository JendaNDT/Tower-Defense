class_name EnemyVisual
extends Node3D
## Vizuál nepřítele: kostra z pivotů (nohy, ruce, křídla, ocas) animovaná podle skutečné rychlosti pohybu,
## záblesk po zásahu, barevné stavy (zpomalení / zmrazení / hoření) a ukazatel zdraví.

signal stepped(world_pos: Vector3)

var body: Node3D = null            # kořen těla (houpání)
var legs: Array = []               # pivoty nohou (střídavý švih)
var arms: Array = []
var wings: Array = []
var tail: Node3D = null
var gait: String = "biped"         # biped | quad | fly | heavy
var stride_freq: float = 3.5       # rad na metr
var swing: float = 0.65
var bob: float = 0.05
var height: float = 1.1
var aim_height: float = 0.6
var is_flyer: bool = false
var death_style: String = "fall_back"   # fall_back | fall_side | crumble | crash | splat
var death_time: float = 0.6
var mat: ShaderMaterial = null
var bar: MeshInstance3D = null
var bar_mat: ShaderMaterial = null
var shield_size: float = 1.8        # průměr bubliny štítu (štítonoš)
var _shield: MeshInstance3D = null
var _shield_mat: ShaderMaterial = null
var _shield_frac: float = 1.0
var _shield_flash: float = 0.0

var _phase: float = 0.0
var _t: float = 0.0
var _flash: float = 0.0
var _last_sign: int = 1
var _tint: Color = Color(1, 1, 1, 0)


func setup_bar(bar_width: float, bar_y: float) -> void:
	bar = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(bar_width, bar_width * 0.16)
	bar.mesh = q
	bar_mat = ShaderMaterial.new()
	bar_mat.shader = Gfx.SH_BAR
	bar.material_override = bar_mat
	bar.position = Vector3(0.0, bar_y, 0.0)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.visible = false
	add_child(bar)


func set_health(frac: float, always_show: bool = false) -> void:
	if bar == null:
		return
	bar.visible = always_show or frac < 0.999
	bar_mat.set_shader_parameter("fill", clampf(frac, 0.0, 1.0))


func flash() -> void:
	_flash = 1.0
	_shield_flash = 1.0


## Bublina štítu: průhledný kulatý billboard, s ubývajícím štítem slábne a zmenšuje se; při 0 zmizí.
func set_shield(frac: float) -> void:
	if _shield == null:
		_shield = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_shield.mesh = q
		_shield_mat = ShaderMaterial.new()
		_shield_mat.shader = Gfx.SH_PUFF
		_shield_mat.set_shader_parameter("color", Color(0.5, 0.8, 1.0))
		_shield_mat.set_shader_parameter("softness", 0.35)
		_shield.material_override = _shield_mat
		_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield.position = Vector3(0.0, aim_height + 0.1, 0.0)
		add_child(_shield)
	_shield_frac = clampf(frac, 0.0, 1.0)
	_shield.visible = _shield_frac > 0.001
	_shield.scale = Vector3.ONE * shield_size * (0.75 + 0.25 * _shield_frac)
	_refresh_shield_alpha()


func _refresh_shield_alpha() -> void:
	if _shield_mat == null:
		return
	_shield_mat.set_shader_parameter("alpha", (0.18 + 0.2 * _shield_frac) + _shield_flash * 0.3)
	_shield_mat.set_shader_parameter("glow", 0.5 + _shield_flash * 1.5)


## slow: 0..1 (síla zpomalení), frozen: zmrazen, burning: hoří.
func set_status(slow: float, frozen: bool, burning: bool) -> void:
	if mat == null:
		return
	var c: Color = Color(1, 1, 1, 0)
	if frozen:
		c = Color(0.65, 0.92, 1.0, 0.7)
	elif burning:
		var f: float = 0.5 + 0.5 * sin(_t * 18.0)
		c = Color(1.0, 0.45 + 0.2 * f, 0.1, 0.38)
	elif slow > 0.01:
		c = Color(0.45, 0.78, 1.0, clampf(slow * 0.55, 0.0, 0.45))
	if not c.is_equal_approx(_tint):
		_tint = c
		mat.set_shader_parameter("tint", c)


## speed = skutečná rychlost pohybu v m/s (0 když stojí / je zmrazený).
func animate(dt: float, speed: float, speed_factor: float = 1.0) -> void:
	_t += dt
	if _shield_flash > 0.0:
		_shield_flash = maxf(_shield_flash - dt * 5.0, 0.0)
		_refresh_shield_alpha()
	if _flash > 0.0:
		_flash = maxf(_flash - dt * 6.0, 0.0)
		mat.set_shader_parameter("flash", _flash * 0.65)
	match gait:
		"fly":
			var flap: float = sin(_t * (9.0 * clampf(speed_factor, 0.2, 1.0)) + float(get_instance_id() % 7))
			for i in range(wings.size()):
				var w: Node3D = wings[i]
				var sd: float = -1.0 if i == 0 else 1.0
				w.rotation.z = sd * (flap * 0.75 + 0.15)
			if body != null:
				body.position.y = sin(_t * 2.6) * 0.12 * speed_factor
				body.rotation.x = sin(_t * 2.6 + 0.8) * 0.06
			if tail != null:
				tail.rotation.y = sin(_t * 3.4) * 0.35
		"blob":
			# slizák: poskakuje, při dopadu se rozplácne a při výskoku natáhne
			_phase += speed * stride_freq * dt
			var hop: float = absf(sin(_phase))
			var sq: float = cos(_phase * 2.0) * 0.5 + 0.5          # 1 = rozplácnutý (na zemi), 0 = natažený
			if body != null:
				body.position.y = hop * bob
				body.scale = Vector3(1.0 + 0.16 * sq, 1.0 - 0.2 * sq + 0.08 * (1.0 - sq), 1.0 + 0.16 * sq)
		_:
			_phase += speed * stride_freq * dt
			var s: float = sin(_phase)
			if gait == "quad":
				for i in range(legs.size()):
					var l: Node3D = legs[i]
					var ph: float = 0.0 if (i == 0 or i == 3) else PI
					l.rotation.x = sin(_phase + ph) * swing
				if tail != null:
					tail.rotation.y = sin(_t * 6.0) * 0.4
			else:
				for i in range(legs.size()):
					var l2: Node3D = legs[i]
					l2.rotation.x = sin(_phase + (0.0 if i == 0 else PI)) * swing
				for j in range(arms.size()):
					var a: Node3D = arms[j]
					a.rotation.x = sin(_phase + (PI if j == 0 else 0.0)) * swing * 0.7
			if body != null:
				body.position.y = absf(s) * bob
				body.rotation.z = s * 0.045
				if gait == "heavy":
					body.rotation.x = absf(s) * -0.03
			var sg: int = 1 if s >= 0.0 else -1
			if sg != _last_sign:
				_last_sign = sg
				if speed > 0.2 and (gait == "heavy"):
					stepped.emit(global_position)
