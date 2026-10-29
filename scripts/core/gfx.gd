class_name Gfx
extends RefCounted
## Sdílené materiály a textury generované v kódu (žádné externí soubory).

const SH_MODEL: Shader = preload("res://shaders/model.gdshader")
const SH_FOLIAGE: Shader = preload("res://shaders/foliage.gdshader")
const SH_PUFF: Shader = preload("res://shaders/fx_puff.gdshader")
const SH_RING: Shader = preload("res://shaders/fx_ring.gdshader")
const SH_BAR: Shader = preload("res://shaders/healthbar.gdshader")
const SH_GHOST: Shader = preload("res://shaders/ghost_ring.gdshader")
const SH_STREAK: Shader = preload("res://shaders/streak.gdshader")
const SH_SCORCH: Shader = preload("res://shaders/scorch.gdshader")
const SH_BLOB: Shader = preload("res://shaders/blob_shadow.gdshader")

static var _cache: Dictionary = {}
static var quality_high: bool = true


static func noise_tex(key: String, seed_value: int, freq: float, size: int = 256, octaves: int = 4) -> ImageTexture:
	## Bezešvá šumová textura (L8), cache podle klíče.
	if _cache.has("n_" + key):
		return _cache["n_" + key]
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	var img: Image = n.get_seamless_image(size, size, false, false, 0.1, true)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache["n_" + key] = tex
	return tex


static func model_mat(roughness: float = 0.8, metallic: float = 0.0, unique: bool = false) -> ShaderMaterial:
	## Materiál pro modely z MeshKit. Sdílený podle parametrů, unique=true vytvoří vlastní kopii (nepřátelé: záblesk, tint).
	var key: String = "m_%.2f_%.2f" % [roughness, metallic]
	if not unique and _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SH_MODEL
	m.set_shader_parameter("roughness_v", roughness)
	m.set_shader_parameter("metallic_v", metallic)
	if not unique:
		_cache[key] = m
	return m


static func foliage_mat(height_ref: float, wind: float = 0.12, flutter: float = 0.03) -> ShaderMaterial:
	var key: String = "f_%.2f_%.3f_%.3f" % [height_ref, wind, flutter]
	if _cache.has(key):
		return _cache[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SH_FOLIAGE
	m.set_shader_parameter("height_ref", height_ref)
	m.set_shader_parameter("wind_strength", wind)
	m.set_shader_parameter("flutter", flutter)
	m.set_shader_parameter("noise_tex", noise_tex("wind", 11, 0.02, 128, 2))
	_cache[key] = m
	return m


static func unshaded_color(col: Color, alpha: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if alpha or col.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func mesh_node(kit: MeshKit, mat: Material, cast_shadow: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = kit.instance(mat)
	if not cast_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Světelná stopa za střelou: tenký kužel s hrotem vzadu (+Z), sdílený podle druhu střely. Vrací MeshInstance3D.
static func streak_node(kind: String) -> MeshInstance3D:
	var key: String = "streak_%s_%s" % [Themes.cur().theme_id, kind]
	if not _cache.has(key):
		var len: float = 1.5
		var r: float = 0.07
		var col: Color = Themes.pal("streak_arrow")
		var strength: float = 0.9
		match kind:
			"arrow":
				len = 1.7
				r = 0.035
			"ball":
				len = 1.3
				r = 0.16
				col = Themes.pal("streak_ball")
				strength = 1.1
			_:
				len = 1.8
				r = 0.09
				col = Themes.pal("streak_orb")
				strength = 1.2
		var k: MeshKit = MeshKit.new(5, 0.0)
		k.cone(r, len, 6, Color(1, 1, 1), MeshKit.xf(Vector3.ZERO, Vector3(90.0, 0.0, 0.0)), 0.0, false)
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = SH_STREAK
		m.set_shader_parameter("color", col)
		m.set_shader_parameter("len", len)
		m.set_shader_parameter("strength", strength)
		_cache[key] = [k.build(), m]
	var pair: Array = _cache[key]
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = pair[0]
	mi.material_override = pair[1]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Jednoduchý kruhový disk (rovina XZ) o poloměru r.
static func disc_mesh(r: float, segs: int = 40) -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var norms: PackedVector3Array = PackedVector3Array()
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		# CW při pohledu shora (přední strana je nahoře): cross(b-a, c-a) míří dolů
		verts.append(Vector3.ZERO)
		verts.append(Vector3(cos(a0) * r, 0.0, sin(a0) * r))
		verts.append(Vector3(cos(a1) * r, 0.0, sin(a1) * r))
		uvs.append(Vector2(0.5, 0.5))
		uvs.append(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		uvs.append(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
		for k in range(3):
			norms.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Čtverec v rovině XY (pro billboardy), UV 0..1, střed v počátku.
static func quad_mesh(size: float) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	return q
