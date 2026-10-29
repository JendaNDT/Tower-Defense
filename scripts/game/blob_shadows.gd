class_name BlobShadows
extends MultiMeshInstance3D
## Měkké stíny pod nepřáteli a věžemi (kontaktní stín). Jedna MultiMesh = jedno volání vykreslení pro všechny.
## Zvlášť se hodí v nízké kvalitě, kde se skutečné stíny od slunce vypínají.

const CAPACITY: int = 200

var game = null
var _mm: MultiMesh = null


func setup(game_ref) -> void:
	game = game_ref
	name = "BlobShadows"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = q
	_mm.instance_count = CAPACITY
	_mm.visible_instance_count = 0
	multimesh = _mm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Gfx.SH_BLOB
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-80.0, -20.0, -80.0), Vector3(160.0, 50.0, 160.0))


func _put(n: int, pos: Vector3, size: float, alpha: float) -> void:
	var b: Basis = Basis.from_scale(Vector3(size, 1.0, size))
	_mm.set_instance_transform(n, Transform3D(b, pos))
	_mm.set_instance_color(n, Color(1.0, 1.0, 1.0, alpha))


## Přepočítá stíny podle aktuálních věží a nepřátel (volá se jednou za snímek).
func refresh() -> void:
	if game == null or _mm == null:
		return
	var k: float = 0.7 if Gfx.quality_high else 1.0       # ve vysoké kvalitě už jsou skutečné stíny, tady jen kontakt
	var n: int = 0
	for t in game.towers:
		if n >= CAPACITY:
			break
		var tp: Vector3 = (t as Node3D).position
		_put(n, Vector3(tp.x, tp.y + 0.03, tp.z), 2.5, 0.5 * k)
		n += 1
	for e in game.enemies:
		if n >= CAPACITY:
			break
		var en: Enemy = e
		var sz: float = en.radius * 2.8 * en.visual.scale.x
		if en.flying:
			var gy: float = game.map.height_at(en.position.x, en.position.z)
			var alt: float = clampf((en.position.y - gy) / 8.0, 0.0, 1.0)
			_put(n, Vector3(en.position.x, gy + 0.06, en.position.z), 1.7 + alt * 0.5, (0.34 - 0.12 * alt) * k)
		else:
			_put(n, Vector3(en.position.x, en.position.y + 0.06, en.position.z), sz, 0.55 * k)
		n += 1
	_mm.visible_instance_count = n


func count() -> int:
	return _mm.visible_instance_count if _mm != null else 0
