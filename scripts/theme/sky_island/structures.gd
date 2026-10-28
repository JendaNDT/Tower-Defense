class_name Structures
extends RefCounted
## Pevné stavby: portál (začátek trasy), Srdce ostrova (cíl) a dřevěný most přes řeku.

const STONE: Color = Color(0.62, 0.60, 0.57)
const STONE_DARK: Color = Color(0.46, 0.45, 0.44)
const WOOD: Color = Color(0.55, 0.38, 0.22)
const WOOD_DARK: Color = Color(0.38, 0.26, 0.16)


## Portál: kamenný oblouk + vířící disk. Vrací uzel; disk je potomek "Disc".
static func build_portal(map: GameMap) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Portal"
	var p: PathData = map.terrain.path
	var pos: Vector3 = p.pos_at(0.0)
	var dir2: Vector2 = p.dir_at(0.0)
	var yaw: float = atan2(dir2.x, dir2.y)      # +Z uzlu míří po směru trasy
	root.position = pos
	root.rotation.y = yaw

	var k: MeshKit = MeshKit.new(5, 0.06)
	# podstavec
	k.cyl(2.6, 2.3, 0.35, 10, STONE_DARK, MeshKit.xf(Vector3(0.0, -0.25, 0.0)), 0.0, false, true)
	# sloupy
	for sx in [-1.0, 1.0]:
		var x: float = 1.55 * float(sx)
		k.cyl(0.42, 0.34, 2.9, 8, STONE, MeshKit.xf(Vector3(x, 0.0, 0.0)), 0.0, false, true)
		k.box(Vector3(0.95, 0.28, 0.95), STONE_DARK, MeshKit.xf(Vector3(x, 0.14, 0.0)))
		k.box(Vector3(0.85, 0.3, 0.85), STONE_DARK, MeshKit.xf(Vector3(x, 2.95, 0.0)))
		k.sphere(0.2, Color(0.7, 0.4, 1.0), MeshKit.xf(Vector3(x, 3.35, 0.0)), 1.6, 6, 4)
	# překlad
	k.box(Vector3(4.2, 0.55, 0.85), STONE, MeshKit.xf(Vector3(0.0, 3.25, 0.0)))
	k.box(Vector3(3.2, 0.3, 0.9), STONE_DARK, MeshKit.xf(Vector3(0.0, 3.62, 0.0)))
	# runy (svítící)
	for i in range(5):
		k.box(Vector3(0.14, 0.26, 0.9), Color(0.6, 0.4, 1.0), MeshKit.xf(Vector3(-0.9 + 0.45 * float(i), 3.25, 0.0)), 1.4)
	var body: MeshInstance3D = Gfx.mesh_node(k, Gfx.model_mat(0.9))
	root.add_child(body)

	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = "Disc"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.9, 3.0)
	disc.mesh = q
	disc.position = Vector3(0.0, 1.6, 0.0)
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load("res://shaders/portal.gdshader")
	sm.set_shader_parameter("noise_tex", Gfx.noise_tex("portal", 21, 0.03, 128, 3))
	disc.material_override = sm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(0.6, 0.35, 1.0)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position = Vector3(0.0, 1.8, 0.8)
	root.add_child(light)
	return root


## Srdce ostrova: kamenná plošina a levitující krystal (animuje ambient). Vrací kořen; potomek "Crystal".
static func build_base(map: GameMap) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Heart"
	var c: Vector2 = Cfg.cell_center(Cfg.BASE_CELL.x, Cfg.BASE_CELL.y)
	var y: float = map.terrain.height_at(c.x, c.y)
	root.position = Vector3(c.x, y, c.y)

	var k: MeshKit = MeshKit.new(9, 0.06)
	k.cyl(1.75, 1.6, 0.6, 12, STONE_DARK, MeshKit.xf(Vector3(0.0, -0.3, 0.0)), 0.0, false, true)
	k.cyl(1.45, 1.3, 0.35, 12, STONE, MeshKit.xf(Vector3(0.0, 0.3, 0.0)), 0.0, false, true)
	for i in range(6):
		var a: float = TAU * float(i) / 6.0
		k.cyl(0.18, 0.14, 1.2, 6, STONE, MeshKit.xf(Vector3(cos(a) * 1.25, 0.6, sin(a) * 1.25)), 0.0, false, true)
		k.sphere(0.14, Color(0.4, 0.95, 1.0), MeshKit.xf(Vector3(cos(a) * 1.25, 1.85, sin(a) * 1.25)), 1.8, 6, 3)
	root.add_child(Gfx.mesh_node(k, Gfx.model_mat(0.85)))

	var cr: Node3D = Node3D.new()
	cr.name = "Crystal"
	cr.position = Vector3(0.0, 1.9, 0.0)
	var ck: MeshKit = MeshKit.new(10, 0.05)
	ck.sphere(0.62, Color(0.95, 0.35, 0.75), MeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3(0.75, 1.25, 0.75)), 1.1, 4, 4)
	ck.sphere(0.34, Color(1.0, 0.8, 0.95), MeshKit.xf(Vector3.ZERO, Vector3(0.0, 45.0, 0.0), Vector3(0.7, 1.35, 0.7)), 2.2, 4, 4)
	var cm: MeshInstance3D = Gfx.mesh_node(ck, Gfx.model_mat(0.25, 0.0, true), false)
	cm.name = "Mesh"
	cr.add_child(cm)
	root.add_child(cr)

	var ring: MeshInstance3D = Gfx.mesh_node(_ring_kit(), Gfx.model_mat(0.4, 0.3), false)
	ring.name = "Ring"
	ring.position = Vector3(0.0, 1.9, 0.0)
	root.add_child(ring)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.5, 0.85)
	light.light_energy = 1.4
	light.omni_range = 6.5
	light.position = Vector3(0.0, 2.1, 0.0)
	root.add_child(light)
	return root


static func _ring_kit() -> MeshKit:
	var k: MeshKit = MeshKit.new(12, 0.0)
	k.torus(1.0, 0.045, Color(0.4, 0.95, 1.0), MeshKit.xf(Vector3.ZERO, Vector3(70.0, 0.0, 0.0)), 1.4, 28, 5)
	return k


## Dřevěný most přes řeku podél úseku trasy bridge_s0..bridge_s1.
static func build_bridge(map: GameMap) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Bridge"
	if map.bridge_s0 < 0.0:
		return root
	var p: PathData = map.terrain.path
	var k: MeshKit = MeshKit.new(15, 0.07)
	var s0: float = map.bridge_s0
	var s1: float = map.bridge_s1
	var s: float = s0
	var prev_pos: Vector3 = p.pos_at(s0)
	var plank_i: int = 0
	while s <= s1:
		var pos: Vector3 = p.pos_at(s)
		var d: Vector2 = p.dir_at(s)
		var yaw: float = atan2(d.x, d.y) * 180.0 / PI
		var col: Color = WOOD if plank_i % 2 == 0 else WOOD.lightened(0.08)
		k.box(Vector3(2.15, 0.14, 0.42), col, MeshKit.xf(pos + Vector3(0.0, -0.09, 0.0), Vector3(0.0, yaw, 0.0)))
		plank_i += 1
		s += 0.46
		prev_pos = pos
	# nosníky a zábradlí po obou stranách
	var side_pts: Array = []
	var step: float = 1.1
	s = s0
	while s <= s1 + 0.01:
		var pos2: Vector3 = p.pos_at(s)
		var d2: Vector2 = p.dir_at(s)
		var nn: Vector3 = Vector3(-d2.y, 0.0, d2.x)
		side_pts.append([pos2, nn])
		s += step
	for sd in [-1.0, 1.0]:
		var last: Vector3 = Vector3.ZERO
		var have_last: bool = false
		for e in side_pts:
			var ep: Vector3 = e[0]
			var en: Vector3 = e[1]
			var base: Vector3 = ep + en * 1.04 * float(sd)
			k.cyl(0.08, 0.07, 0.95, 6, WOOD_DARK, MeshKit.xf(base + Vector3(0.0, -0.15, 0.0)), 0.0, false, true)
			k.sphere(0.1, WOOD, MeshKit.xf(base + Vector3(0.0, 0.8, 0.0)), 0.0, 5, 3)
			if have_last:
				var mid: Vector3 = (base + last) * 0.5 + Vector3(0.0, 0.55, 0.0)
				var dv: Vector3 = base - last
				var seg_len: float = dv.length()
				var yaw2: float = atan2(dv.x, dv.z) * 180.0 / PI
				k.box(Vector3(0.09, 0.09, seg_len), WOOD, MeshKit.xf(mid, Vector3(0.0, yaw2, 0.0)))
				k.box(Vector3(0.07, 0.07, seg_len), WOOD_DARK, MeshKit.xf(mid - Vector3(0.0, 0.3, 0.0), Vector3(0.0, yaw2, 0.0)))
			last = base
			have_last = true
	# kamenné opěry
	for e2 in [s0, s1]:
		var pe: Vector3 = p.pos_at(e2)
		var de: Vector2 = p.dir_at(e2)
		var yawe: float = atan2(de.x, de.y) * 180.0 / PI
		k.box(Vector3(2.6, 0.5, 1.0), STONE_DARK, MeshKit.xf(pe + Vector3(0.0, -0.32, 0.0), Vector3(0.0, yawe, 0.0)))
	var mi: MeshInstance3D = Gfx.mesh_node(k, Gfx.model_mat(0.9))
	root.add_child(mi)
	return root
