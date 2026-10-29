class_name SciFiAmbient
extends Ambient
## Živá vesmírná scenérie: hluboký vesmír s hvězdami a mlhovinou pod stanicí, plující trosky a satelity, asteroidy
## se světly, hlídkové drony, svítící můry a částice (ledové jiskry, spóry, rudý prach, energetická mlha).
## Používá animace ze základní třídy Ambient (stejné názvy polí), jen jiné modely a barvy.

const METAL: Color = Color(0.60, 0.64, 0.74)
const METAL_D: Color = Color(0.28, 0.31, 0.40)
const CYAN: Color = Color(0.10, 0.90, 1.00)
const MAGENTA: Color = Color(1.00, 0.25, 0.80)
const METAL_L: Color = Color(0.66, 0.70, 0.78)


# ------------------------------------------------------------------ vesmír pod stanicí
func _build_cloud_layers() -> void:
	var tex: ImageTexture = Gfx.noise_tex("cloud", 5, 0.012, 256, 4)
	var bg: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(1000.0, 1000.0)
	bg.mesh = pm
	bg.position = Vector3(0.0, -36.0, 0.0)
	var bm: ShaderMaterial = ShaderMaterial.new()
	bm.shader = load("res://shaders/space_bg.gdshader")
	bm.set_shader_parameter("noise_tex", tex)
	bg.material_override = bm
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bg)
	# řídké pásy mlhoviny nad pozadím (průsvitné)
	var shader: Shader = load("res://shaders/cloud_layer.gdshader")
	var specs: Array = [
		{"y": -20.0, "cover": 0.50, "soft": 0.30, "tile": 0.014, "scroll": Vector2(0.012, 0.006), "alpha": 0.42,
			"light": Color(0.55, 0.45, 1.0), "shade": Color(0.30, 0.10, 0.60)},
		{"y": -9.0, "cover": 0.58, "soft": 0.25, "tile": 0.019, "scroll": Vector2(0.020, 0.009), "alpha": 0.30,
			"light": Color(0.35, 0.90, 1.0), "shade": Color(0.10, 0.25, 0.65)},
	]
	for s in specs:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var pl: PlaneMesh = PlaneMesh.new()
		pl.size = Vector2(1000.0, 1000.0)
		mi.mesh = pl
		mi.position = Vector3(0.0, float(s["y"]), 0.0)
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("noise_tex", tex)
		m.set_shader_parameter("coverage", float(s["cover"]))
		m.set_shader_parameter("softness", float(s["soft"]))
		m.set_shader_parameter("tile", float(s["tile"]))
		m.set_shader_parameter("scroll", s["scroll"])
		m.set_shader_parameter("opaque_base", 0.0)
		m.set_shader_parameter("max_alpha", float(s["alpha"]))
		m.set_shader_parameter("light_color", s["light"])
		m.set_shader_parameter("shade_color", s["shade"])
		m.set_shader_parameter("base_color", Color(0.0, 0.0, 0.0))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


# ------------------------------------------------------------------ plující trosky a satelity
func _debris_mesh(variant: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(300 + variant, 0.08)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 300 + variant
	match variant % 4:
		0, 1:
			var s: float = rng.randf_range(1.6, 2.8)
			k.blob(s, Color(0.26, 0.25, 0.33), MeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.7, 0.85)), 0.0, 7, 5, 0.25, 300 + variant)
			k.blob(s * 0.5, Color(0.22, 0.21, 0.28), MeshKit.xf(Vector3(s * 0.8, -s * 0.1, 0.2)), 0.0, 6, 4, 0.25, 320 + variant)
			k.cone(0.12, 0.6, 5, MAGENTA if variant % 2 == 0 else CYAN, MeshKit.xf(Vector3(0.2, s * 0.5, 0.1), Vector3(15.0, 0.0, 20.0)), 1.5, false)
		2:
			# satelit: tělo, solární křídla, talíř
			k.box(Vector3(1.0, 0.8, 1.0), METAL, MeshKit.xf())
			k.box(Vector3(0.2, 0.2, 0.2), METAL_D, MeshKit.xf(Vector3(0.0, 0.5, 0.0)))
			for sx in [-1.0, 1.0]:
				k.box(Vector3(0.1, 0.1, 0.1), METAL_D, MeshKit.xf(Vector3(float(sx) * 0.7, 0.0, 0.0)))
				k.box(Vector3(2.2, 0.05, 1.1), Color(0.10, 0.28, 0.65), MeshKit.xf(Vector3(float(sx) * 1.9, 0.0, 0.0)), 0.5)
				k.box(Vector3(2.2, 0.06, 0.05), CYAN, MeshKit.xf(Vector3(float(sx) * 1.9, 0.0, 0.0)), 1.2)
			k.cone(0.5, 0.35, 8, METAL_L, MeshKit.xf(Vector3(0.0, 0.5, 0.6), Vector3(60.0, 0.0, 0.0)), 0.0, false)
			k.sphere(0.07, Color(1.0, 0.2, 0.25), MeshKit.xf(Vector3(0.0, 0.5, -0.5)), 2.0, 5, 3)
		_:
			# kus trupu
			k.box(Vector3(2.4, 0.18, 1.4), METAL, MeshKit.xf(Vector3.ZERO, Vector3(10.0, 20.0, 5.0)))
			k.box(Vector3(0.8, 0.3, 0.8), METAL_D, MeshKit.xf(Vector3(0.5, 0.2, 0.2), Vector3(0.0, 35.0, 0.0)))
			k.box(Vector3(1.6, 0.04, 0.06), CYAN, MeshKit.xf(Vector3(0.0, 0.12, 0.45), Vector3(10.0, 20.0, 5.0)), 1.4)
	return k.build()


func _build_puffs() -> void:
	var meshes: Array = []
	for i in range(8):
		meshes.append(_debris_mesh(i))
	var mat: ShaderMaterial = Gfx.model_mat(0.7, 0.12)
	var perp: Vector2 = Vector2(-WIND.y, WIND.x)
	for i in range(22):
		var high: bool = i < 10
		var lane: float = _rng.randf_range(54.0, 110.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var y: float = _rng.randf_range(-10.0, 9.0) if high else _rng.randf_range(-34.0, -14.0)
		if not high:
			lane = _rng.randf_range(-110.0, 110.0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = meshes[i % 8]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc: float = _rng.randf_range(0.7, 1.4)
		mi.scale = Vector3(sc, sc, sc)
		mi.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0.0)
		add_child(mi)
		_puffs.append({"node": mi, "lane": lane, "along": _rng.randf_range(-140.0, 140.0), "y": y,
			"speed": _rng.randf_range(0.4, 1.2), "perp": perp})


# ------------------------------------------------------------------ plovoucí asteroidy se stavbami
func _build_floaters() -> void:
	for i in range(8):
		var k: MeshKit = MeshKit.new(500 + i, 0.08)
		var r: float = _rng.randf_range(1.2, 2.6)
		k.blob(r, Color(0.24, 0.23, 0.31), MeshKit.xf(Vector3(0.0, -r * 0.2, 0.0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), 0.0, 7, 5, 0.2, 500 + i)
		k.cone(r * 0.7, r * 1.6, 7, Color(0.19, 0.18, 0.25), MeshKit.xf(Vector3(0.0, -r * 0.2, 0.0), Vector3(180.0, 0.0, 0.0)), 0.0, false)
		k.cyl(r * 0.95, r * 0.85, 0.28, 9, Color(0.30, 0.34, 0.42), MeshKit.xf(Vector3(0.0, r * 0.2, 0.0)), 0.0, false, true)
		k.torus(r * 0.9, 0.04, CYAN, MeshKit.xf(Vector3(0.0, r * 0.35, 0.0)), 1.3, 20, 4)
		# tryska pod asteroidem
		k.cone(r * 0.25, r * 0.6, 6, Color(1.0, 0.65, 0.2), MeshKit.xf(Vector3(0.0, -r * 1.7, 0.0), Vector3(180.0, 0.0, 0.0)), 1.6, false)
		match i % 3:
			0:
				# anténa
				k.cyl(0.05, 0.03, 1.4, 5, METAL, MeshKit.xf(Vector3(r * 0.2, r * 0.34, 0.0)), 0.0, false, false)
				k.sphere(0.09, Color(1.0, 0.2, 0.25), MeshKit.xf(Vector3(r * 0.2, r * 0.34 + 1.4, 0.0)), 2.0, 5, 3)
			1:
				# krystaly
				for q in range(3):
					k.cone(0.14, 0.9 + 0.3 * float(q), 6, MAGENTA, MeshKit.xf(Vector3(0.25 * float(q), r * 0.34, 0.1 * float(q) - 0.2), Vector3(0.0, 0.0, 8.0 * float(q) - 8.0)), 1.5, false)
			_:
				# kopule
				k.sphere(r * 0.38, Color(0.55, 0.85, 1.0), MeshKit.xf(Vector3(0.0, r * 0.34, 0.0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), 0.6, 8, 4, true)
		var mi: MeshInstance3D = Gfx.mesh_node(k, Gfx.model_mat(0.7, 0.12))
		var ang: float = _rng.randf() * TAU
		var rad: float = _rng.randf_range(52.0, 80.0)
		var y: float = _rng.randf_range(-22.0, 3.0)
		mi.position = Vector3(cos(ang) * rad, y, sin(ang) * rad)
		add_child(mi)
		_floaters.append({"node": mi, "y": y, "ph": _rng.randf() * TAU, "rot": _rng.randf_range(-0.12, 0.12)})


# ------------------------------------------------------------------ hlídkové drony (místo ptáků)
func _build_birds() -> void:
	for i in range(7):
		var root: Node3D = Node3D.new()
		var bk: MeshKit = MeshKit.new(600 + i, 0.03)
		bk.sphere(0.2, Color(0.80, 0.84, 0.90), MeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.45, 1.25)), 0.0, 8, 5)
		bk.sphere(0.09, CYAN if i % 2 == 0 else MAGENTA, MeshKit.xf(Vector3(0.0, 0.0, 0.22)), 2.2, 6, 4)
		bk.sphere(0.07, Color(1.0, 0.8, 0.3), MeshKit.xf(Vector3(0.0, -0.1, 0.0)), 1.8, 5, 3)
		bk.box(Vector3(0.05, 0.16, 0.2), METAL_D, MeshKit.xf(Vector3(0.0, 0.12, -0.2)))
		root.add_child(Gfx.mesh_node(bk, Gfx.model_mat(0.5, 0.12), false))
		var wl: MeshInstance3D = _fin(-1.0)
		var wr: MeshInstance3D = _fin(1.0)
		root.add_child(wl)
		root.add_child(wr)
		root.scale = Vector3.ONE * _rng.randf_range(1.0, 1.4)
		add_child(root)
		_birds.append({
			"root": root, "wl": wl, "wr": wr,
			"r": _rng.randf_range(24.0, 50.0),
			"w": _rng.randf_range(0.10, 0.19) * (1.0 if i % 2 == 0 else -1.0),
			"a": _rng.randf() * TAU,
			"h": _rng.randf_range(6.0, 13.0),
			"ph": _rng.randf() * TAU,
			"cx": _rng.randf_range(-8.0, 8.0), "cz": _rng.randf_range(-8.0, 8.0),
		})


func _fin(side: float) -> MeshInstance3D:
	var k: MeshKit = MeshKit.new(650, 0.0)
	k.quad(Vector3(0.0, 0.0, 0.15), Vector3(0.0, 0.0, -0.12), Vector3(0.42 * side, 0.0, -0.18), Vector3(0.45 * side, 0.0, 0.08), METAL, Transform3D.IDENTITY, 0.0, true)
	k.box(Vector3(0.38, 0.03, 0.04), CYAN, MeshKit.xf(Vector3(0.24 * side, 0.015, -0.04)), 1.5)
	return Gfx.mesh_node(k, Gfx.model_mat(0.5, 0.12), false)


# ------------------------------------------------------------------ svítící můry (místo motýlů)
func _build_butterflies() -> void:
	var cols: Array = [CYAN, MAGENTA, Color(0.6, 1.0, 0.4), Color(1.0, 0.7, 0.2), Color(0.55, 0.5, 1.0)]
	for i in range(8):
		var root: Node3D = Node3D.new()
		var col: Color = cols[i % cols.size()]
		var core: MeshKit = MeshKit.new(710 + i, 0.0)
		core.sphere(0.06, col.lightened(0.5), MeshKit.xf(), 2.4, 5, 3)
		root.add_child(Gfx.mesh_node(core, Gfx.model_mat(0.9), false))
		var wl: MeshInstance3D = _moth_wing(-1.0, col)
		var wr: MeshInstance3D = _moth_wing(1.0, col)
		root.add_child(wl)
		root.add_child(wr)
		add_child(root)
		_butterflies.append({
			"root": root, "wl": wl, "wr": wr,
			"c": Vector3((_centers[1] as Vector2).x + _rng.randf_range(-8.0, 8.0), 0.0, (_centers[1] as Vector2).y + _rng.randf_range(-8.0, 8.0)),
			"ph": _rng.randf() * TAU,
			"sp": _rng.randf_range(0.25, 0.5),
		})


func _moth_wing(side: float, col: Color) -> MeshInstance3D:
	var k: MeshKit = MeshKit.new(700, 0.0)
	k.quad(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.14), Vector3(0.16 * side, 0.0, 0.17), Vector3(0.17 * side, 0.0, -0.06), col, Transform3D.IDENTITY, 1.6, true)
	return Gfx.mesh_node(k, Gfx.model_mat(0.9), false)


# ------------------------------------------------------------------ částice
func _build_particles(map: GameMap, high: bool) -> void:
	var f: float = 1.0 if high else 0.5
	var bc: Array = map.terrain.biome_centers        # les, louka, poušť, sníh
	var forest: Vector2 = bc[0]
	var desert: Vector2 = bc[2]
	var snow: Vector2 = bc[3]
	# ledové jiskry v kryo oblasti
	_particles(Vector3(snow.x, 9.0, snow.y), Vector3(17.0, 0.3, 17.0), int(680.0 * f), 9.0, 0.12, Color(0.75, 0.95, 1.0, 0.95), 1.0,
		Vector3(0.4, -1.8, 0.2), Vector3(0, -1, 0), 20.0, 0.0, 0.3, 2.2)
	# spóry v bio-džungli (dvě barvy)
	_particles(Vector3(forest.x, 2.2, forest.y), Vector3(16.0, 1.6, 16.0), int(100.0 * f), 8.0, 0.10, Color(0.2, 0.95, 1.0, 1.0), 3.5,
		Vector3(0.05, 0.05, 0.02), Vector3(0, 1, 0), 180.0, 0.1, 0.35, 0.3, 0.3)
	_particles(Vector3(forest.x, 1.6, forest.y), Vector3(16.0, 1.2, 16.0), int(65.0 * f), 8.0, 0.09, Color(1.0, 0.3, 0.85, 1.0), 3.5,
		Vector3(-0.04, 0.05, 0.03), Vector3(0, 1, 0), 180.0, 0.1, 0.3, 0.3, 0.3)
	# rudý prach v pustině
	_particles(Vector3(desert.x, 1.0, desert.y), Vector3(17.0, 1.0, 17.0), int(140.0 * f), 6.0, 0.55, Color(0.95, 0.42, 0.22, 0.15), 0.0,
		Vector3.ZERO, Vector3(1, 0.05, 0.35), 12.0, 1.8, 3.0, 0.0, 0.3)
	# energetická mlha a jiskry u vodopádu
	var wf: Dictionary = waterfall
	if wf.has("lip"):
		var lip: Vector3 = wf["lip"]
		var fl: Vector2 = wf["flow"]
		var out: Vector3 = Vector3(fl.x, 0.0, fl.y)
		_particles(lip + out * 0.5, Vector3(wf["half_w"] * 0.8, 0.1, 0.1), int(140.0 * f), 1.3, 0.14, Color(0.4, 0.95, 1.0, 0.9), 2.2,
			Vector3(0, -9.0, 0), Vector3(out.x, 0.25, out.z), 25.0, 1.6, 2.6, 0.0, 0.1)
		_particles(Vector3(lip.x + out.x * 3.6, lip.y - 30.0, lip.z + out.z * 3.6), Vector3(2.8, 1.0, 2.8), int(36.0 * f), 5.0, 5.5, Color(0.3, 0.7, 1.0, 0.30), 0.6,
			Vector3(0.0, 0.25, 0.0), Vector3(0, 1, 0), 40.0, 0.2, 0.6, 0.2, 0.3)
		_particles(Vector3(lip.x + out.x * 1.6, lip.y - 6.0, lip.z + out.z * 1.6), Vector3(wf["half_w"], 4.0, 0.6), int(46.0 * f), 3.0, 1.0, Color(0.5, 0.9, 1.0, 0.22), 0.8,
			Vector3(0.0, -0.4, 0.0), Vector3(out.x, 0, out.z), 40.0, 0.2, 0.5, 0.3, 0.3)
