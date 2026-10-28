class_name Ambient
extends Node3D
## Živý svět: pohyblivé mraky, ptáci, motýli, plovoucí skály, sníh, pylové jiskřičky, prach a sprška vodopádu.
## Vše se animuje jen v kódu (_process) a částicích.

const WIND: Vector2 = Vector2(0.94, 0.34)

var heart: Node3D = null
var portal: Node3D = null
var waterfall: Dictionary = {}     # {lip: Vector3, flow: Vector2, half_w: float} – nastaví stavitel světa před setup()

var _time: float = 0.0
var _puffs: Array = []
var _birds: Array = []
var _butterflies: Array = []
var _floaters: Array = []
var _heart_flash: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ------------------------------------------------------------------ stavba
func setup(map: GameMap, high_quality: bool) -> void:
	_rng.seed = 987
	_build_cloud_layers()
	_build_puffs()
	_build_floaters()
	_build_birds()
	_build_butterflies()
	_build_particles(map, high_quality)


func _build_cloud_layers() -> void:
	var tex: ImageTexture = Gfx.noise_tex("cloud", 5, 0.012, 256, 4)
	var shader: Shader = load("res://shaders/cloud_layer.gdshader")
	var specs: Array = [
		{"y": -36.0, "opaque": 1.0, "cover": 0.40, "soft": 0.30, "tile": 0.011, "scroll": Vector2(0.008, 0.004), "alpha": 1.0},
		{"y": -20.0, "opaque": 0.0, "cover": 0.50, "soft": 0.22, "tile": 0.016, "scroll": Vector2(0.015, 0.007), "alpha": 0.9},
		{"y": -9.0, "opaque": 0.0, "cover": 0.60, "soft": 0.18, "tile": 0.021, "scroll": Vector2(0.022, 0.010), "alpha": 0.75},
	]
	for s in specs:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(1000.0, 1000.0)
		mi.mesh = pm
		mi.position = Vector3(0.0, float(s["y"]), 0.0)
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("noise_tex", tex)
		m.set_shader_parameter("coverage", float(s["cover"]))
		m.set_shader_parameter("softness", float(s["soft"]))
		m.set_shader_parameter("tile", float(s["tile"]))
		m.set_shader_parameter("scroll", s["scroll"])
		m.set_shader_parameter("opaque_base", float(s["opaque"]))
		m.set_shader_parameter("max_alpha", float(s["alpha"]))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _cloud_mesh(seed_value: int, size: float) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(8):
		var r: float = size * rng.randf_range(0.5, 1.0)
		var off: Vector3 = Vector3(rng.randf_range(-1.0, 1.0) * size * 1.5, rng.randf() * size * 0.4, rng.randf_range(-1.0, 1.0) * size * 0.8)
		var col: Color = Color(0.78, 0.85, 0.96).lerp(Color(1.0, 1.0, 1.0), clampf(off.y / (size * 0.4) * 0.8 + 0.2, 0.0, 1.0))
		k.sphere(r, col, MeshKit.xf(off, Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), 0.55, 10, 6, true)
	return k.build()


func _build_puffs() -> void:
	var meshes: Array = []
	for i in range(4):
		meshes.append(_cloud_mesh(300 + i, _rng.randf_range(3.5, 6.0)))
	var mat: ShaderMaterial = Gfx.model_mat(1.0, 0.0)
	var perp: Vector2 = Vector2(-WIND.y, WIND.x)
	for i in range(22):
		var high: bool = i < 10
		var lane: float = _rng.randf_range(44.0, 95.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var y: float = _rng.randf_range(-10.0, 9.0) if high else _rng.randf_range(-34.0, -14.0)
		if not high:
			lane = _rng.randf_range(-90.0, 90.0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = meshes[i % 4]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc: float = _rng.randf_range(0.9, 1.6)
		mi.scale = Vector3(sc, sc, sc)
		add_child(mi)
		_puffs.append({
			"node": mi,
			"lane": lane,
			"along": _rng.randf_range(-140.0, 140.0),
			"y": y,
			"speed": _rng.randf_range(0.5, 1.4),
			"perp": perp,
		})


func _build_floaters() -> void:
	for i in range(8):
		var k: MeshKit = MeshKit.new(500 + i, 0.08)
		var r: float = _rng.randf_range(1.2, 2.6)
		k.blob(r, Color(0.50, 0.44, 0.38), MeshKit.xf(Vector3(0.0, -r * 0.2, 0.0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), 0.0, 7, 5, 0.2, 500 + i)
		k.cone(r * 0.7, r * 1.6, 7, Color(0.42, 0.38, 0.36), MeshKit.xf(Vector3(0.0, -r * 0.2, 0.0), Vector3(180.0, 0.0, 0.0)), 0.0, false)
		k.cyl(r * 0.95, r * 0.85, 0.28, 9, Color(0.40, 0.68, 0.26), MeshKit.xf(Vector3(0.0, r * 0.2, 0.0)), 0.0, false, true)
		if i % 2 == 0:
			k.append(_mini_tree(500 + i), MeshKit.xf(Vector3(r * 0.2, r * 0.46, 0.0), Vector3.ZERO, Vector3(0.6, 0.6, 0.6)))
		var mi: MeshInstance3D = Gfx.mesh_node(k, Gfx.model_mat(0.95))
		var ang: float = _rng.randf() * TAU
		var rad: float = _rng.randf_range(40.0, 64.0)
		var y: float = _rng.randf_range(-22.0, 3.0)
		mi.position = Vector3(cos(ang) * rad, y, sin(ang) * rad)
		add_child(mi)
		_floaters.append({"node": mi, "y": y, "ph": _rng.randf() * TAU, "rot": _rng.randf_range(-0.12, 0.12)})


func _mini_tree(seed_value: int) -> MeshKit:
	var k: MeshKit = MeshKit.new(seed_value, 0.07)
	k.cyl(0.12, 0.08, 0.9, 6, Props.TRUNK, MeshKit.xf(), 0.0, false, false)
	k.blob(0.8, Color(0.30, 0.60, 0.22), MeshKit.xf(Vector3(0.0, 1.35, 0.0)), 0.0, 7, 4, 0.16, seed_value)
	return k


func _build_birds() -> void:
	for i in range(7):
		var root: Node3D = Node3D.new()
		var bk: MeshKit = MeshKit.new(600 + i, 0.04)
		var body: Color = Color(0.95, 0.95, 0.96)
		bk.sphere(0.13, body, MeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3(0.8, 0.8, 2.1)), 0.0, 7, 4)
		bk.sphere(0.09, body, MeshKit.xf(Vector3(0.0, 0.04, 0.3)), 0.0, 6, 4)
		bk.cone(0.035, 0.12, 5, Color(1.0, 0.65, 0.15), MeshKit.xf(Vector3(0.0, 0.03, 0.4), Vector3(90.0, 0.0, 0.0)), 0.0, false)
		bk.tri(Vector3(-0.07, 0.0, -0.25), Vector3(0.07, 0.0, -0.25), Vector3(0.0, 0.0, -0.5), Color(0.55, 0.57, 0.62), Transform3D.IDENTITY, 0.0, true)
		var bm: MeshInstance3D = Gfx.mesh_node(bk, Gfx.model_mat(0.8), false)
		root.add_child(bm)
		var wl: MeshInstance3D = _wing(-1.0, i)
		var wr: MeshInstance3D = _wing(1.0, i)
		root.add_child(wl)
		root.add_child(wr)
		root.scale = Vector3.ONE * _rng.randf_range(1.0, 1.4)
		add_child(root)
		_birds.append({
			"root": root, "wl": wl, "wr": wr,
			"r": _rng.randf_range(20.0, 40.0),
			"w": _rng.randf_range(0.10, 0.19) * (1.0 if i % 2 == 0 else -1.0),
			"a": _rng.randf() * TAU,
			"h": _rng.randf_range(6.0, 13.0),
			"ph": _rng.randf() * TAU,
			"cx": _rng.randf_range(-5.0, 5.0), "cz": _rng.randf_range(-5.0, 5.0),
		})


func _wing(side: float, seed_value: int) -> MeshInstance3D:
	var k: MeshKit = MeshKit.new(650 + seed_value, 0.0)
	var c: Color = Color(0.82, 0.84, 0.88)
	var tipc: Color = Color(0.30, 0.32, 0.38)
	k.quad(Vector3(0.0, 0.0, 0.2), Vector3(0.0, 0.0, -0.18), Vector3(0.55 * side, 0.0, -0.22), Vector3(0.55 * side, 0.0, 0.05), c, Transform3D.IDENTITY, 0.0, true)
	k.quad(Vector3(0.55 * side, 0.0, 0.05), Vector3(0.55 * side, 0.0, -0.22), Vector3(1.0 * side, 0.0, -0.3), Vector3(1.05 * side, 0.0, -0.05), tipc, Transform3D.IDENTITY, 0.0, true)
	return Gfx.mesh_node(k, Gfx.model_mat(0.85), false)


func _build_butterflies() -> void:
	var cols: Array = [Color(1.0, 0.65, 0.15), Color(1.0, 1.0, 0.95), Color(0.5, 0.7, 1.0), Color(0.95, 0.45, 0.7), Color(1.0, 0.85, 0.2)]
	for i in range(6):
		var root: Node3D = Node3D.new()
		var col: Color = cols[i % cols.size()]
		var wl: MeshInstance3D = _bwing(-1.0, col)
		var wr: MeshInstance3D = _bwing(1.0, col)
		root.add_child(wl)
		root.add_child(wr)
		add_child(root)
		_butterflies.append({
			"root": root, "wl": wl, "wr": wr,
			"c": Vector3(-17.0 + _rng.randf_range(-6.0, 6.0), 0.0, 17.0 + _rng.randf_range(-6.0, 6.0)),
			"ph": _rng.randf() * TAU,
			"sp": _rng.randf_range(0.25, 0.5),
		})


func _bwing(side: float, col: Color) -> MeshInstance3D:
	var k: MeshKit = MeshKit.new(700, 0.0)
	k.quad(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.14), Vector3(0.16 * side, 0.0, 0.17), Vector3(0.17 * side, 0.0, -0.06), col, Transform3D.IDENTITY, 0.25, true)
	k.quad(Vector3(0.0, 0.0, 0.0), Vector3(0.12 * side, 0.0, -0.06), Vector3(0.11 * side, 0.0, -0.16), Vector3(0.0, 0.0, -0.12), col.darkened(0.15), Transform3D.IDENTITY, 0.2, true)
	return Gfx.mesh_node(k, Gfx.model_mat(0.9), false)


# ------------------------------------------------------------------ částice
func _particles(pos: Vector3, extents: Vector3, amount: int, life: float, size: float, col: Color, glow: float,
		gravity: Vector3, direction: Vector3, spread: float, vmin: float, vmax: float, damping: float,
		fade_in: float = 0.15) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = pos
	p.visibility_aabb = AABB(-extents - Vector3(3.0, 14.0, 3.0), extents * 2.0 + Vector3(6.0, 28.0, 6.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = gravity
	pm.direction = direction
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.damping_min = damping
	pm.damping_max = damping
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, fade_in, 0.8, 1.0])
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Gfx.SH_PUFF
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("glow", glow)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


func _build_particles(map: GameMap, high: bool) -> void:
	var f: float = 1.0 if high else 0.5
	# sníh v zasněžené části
	_particles(Vector3(-17.0, 9.0, -17.0), Vector3(13.0, 0.3, 13.0), int(650.0 * f), 9.0, 0.13, Color(1, 1, 1, 0.95), 0.3,
		Vector3(0.5, -2.2, 0.25), Vector3(0, -1, 0), 20.0, 0.0, 0.3, 2.2)
	# pylové jiskřičky v lese
	_particles(Vector3(17.0, 2.2, -17.0), Vector3(12.0, 1.6, 12.0), int(90.0 * f), 8.0, 0.09, Color(1.0, 0.95, 0.55, 1.0), 3.0,
		Vector3(0.05, 0.04, 0.02), Vector3(0, 1, 0), 180.0, 0.1, 0.35, 0.3, 0.3)
	# prach v poušti
	_particles(Vector3(17.0, 1.0, 17.0), Vector3(13.0, 1.0, 13.0), int(110.0 * f), 6.0, 0.55, Color(0.92, 0.80, 0.55, 0.16), 0.0,
		Vector3.ZERO, Vector3(1, 0.05, 0.35), 12.0, 1.8, 3.0, 0.0, 0.3)
	# mlha a sprška vodopádu
	var wf: Dictionary = waterfall
	if wf.has("lip"):
		var lip: Vector3 = wf["lip"]
		var fl: Vector2 = wf["flow"]
		var out: Vector3 = Vector3(fl.x, 0.0, fl.y)
		_particles(lip + out * 0.5, Vector3(wf["half_w"] * 0.8, 0.1, 0.1), int(80.0 * f), 1.3, 0.14, Color(1, 1, 1, 0.8), 0.6,
			Vector3(0, -9.0, 0), Vector3(out.x, 0.25, out.z), 25.0, 1.6, 2.6, 0.0, 0.1)
		_particles(Vector3(lip.x + out.x * 3.6, lip.y - 30.0, lip.z + out.z * 3.6), Vector3(2.8, 1.0, 2.8), int(22.0 * f), 5.0, 5.0, Color(1, 1, 1, 0.38), 0.2,
			Vector3(0.0, 0.25, 0.0), Vector3(0, 1, 0), 40.0, 0.2, 0.6, 0.2, 0.3)
		_particles(Vector3(lip.x + out.x * 1.6, lip.y - 6.0, lip.z + out.z * 1.6), Vector3(wf["half_w"], 4.0, 0.6), int(30.0 * f), 3.0, 0.9, Color(1, 1, 1, 0.22), 0.2,
			Vector3(0.0, -0.4, 0.0), Vector3(out.x, 0, out.z), 40.0, 0.2, 0.5, 0.3, 0.3)


# ------------------------------------------------------------------ animace
func flash_heart(strength: float = 1.0) -> void:
	_heart_flash = maxf(_heart_flash, strength)


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time
	# mraky
	for p in _puffs:
		p["along"] = float(p["along"]) + float(p["speed"]) * delta
		if float(p["along"]) > 150.0:
			p["along"] = -150.0
		var perp: Vector2 = p["perp"]
		var xz: Vector2 = perp * float(p["lane"]) + WIND * float(p["along"])
		(p["node"] as Node3D).position = Vector3(xz.x, float(p["y"]) + sin(t * 0.2 + float(p["lane"])) * 0.6, xz.y)
	# plovoucí skály
	for f in _floaters:
		var n: Node3D = f["node"]
		n.position.y = float(f["y"]) + sin(t * 0.5 + float(f["ph"])) * 0.45
		n.rotation.y += float(f["rot"]) * delta
		n.rotation.z = sin(t * 0.35 + float(f["ph"])) * 0.05
	# ptáci
	for b in _birds:
		var ang: float = float(b["a"]) + float(b["w"]) * t
		var r: float = float(b["r"])
		var pos: Vector3 = Vector3(float(b["cx"]) + cos(ang) * r, float(b["h"]) + sin(t * 0.7 + float(b["ph"])) * 0.8, float(b["cz"]) + sin(ang) * r)
		var sgn: float = signf(float(b["w"]))
		var vel: Vector3 = Vector3(-sin(ang), 0.0, cos(ang)) * sgn
		var root: Node3D = b["root"]
		root.position = pos
		root.rotation = Vector3(0.0, atan2(vel.x, vel.z), -0.35 * sgn)
		var flap: float = sin(t * 8.0 + float(b["ph"]))
		var glide: float = 0.5 + 0.5 * sin(t * 0.6 + float(b["ph"]) * 2.0)
		var amp: float = lerpf(0.15, 0.7, glide)
		(b["wl"] as Node3D).rotation.z = -flap * amp
		(b["wr"] as Node3D).rotation.z = flap * amp
	# motýli
	for bf in _butterflies:
		var ph: float = float(bf["ph"])
		var c: Vector3 = bf["c"]
		var sp: float = float(bf["sp"])
		var pos2: Vector3 = Vector3(c.x + sin(t * sp + ph) * 6.0, 1.1 + sin(t * 0.9 + ph * 2.0) * 0.4, c.z + cos(t * sp * 0.83 + ph * 1.7) * 6.0)
		var root2: Node3D = bf["root"]
		var vel2: Vector3 = pos2 - root2.position
		root2.position = pos2
		if vel2.length_squared() > 0.000001:
			root2.rotation.y = atan2(vel2.x, vel2.z)
		var fl2: float = 0.2 + absf(sin(t * 16.0 + ph)) * 1.0
		(bf["wl"] as Node3D).rotation.z = fl2
		(bf["wr"] as Node3D).rotation.z = -fl2
	# Srdce ostrova
	_heart_flash = maxf(_heart_flash - delta * 2.0, 0.0)
	if heart != null:
		var cr: Node3D = heart.get_node_or_null("Crystal")
		if cr != null:
			cr.rotation.y = t * 0.8
			cr.position.y = 1.9 + sin(t * 1.4) * 0.12
			var sc: float = 1.0 + _heart_flash * 0.35
			cr.scale = Vector3(sc, sc, sc)
		var ring: Node3D = heart.get_node_or_null("Ring")
		if ring != null:
			ring.rotation.y = -t * 0.6
			ring.rotation.x = sin(t * 0.5) * 0.2
			ring.position.y = 1.9 + sin(t * 1.4) * 0.12
		var lt: OmniLight3D = heart.get_node_or_null("Light")
		if lt != null:
			lt.light_energy = 1.4 + sin(t * 2.2) * 0.25 + _heart_flash * 3.0
	if portal != null:
		var pl: OmniLight3D = portal.get_node_or_null("Light")
		if pl != null:
			pl.light_energy = 1.6 + sin(t * 3.1) * 0.35 + sin(t * 7.3) * 0.15
