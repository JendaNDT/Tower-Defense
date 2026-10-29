class_name SciFiStructures
extends RefCounted
## Pevné stavby vesmírné stanice: hvězdná brána (začátek trasy), reaktor (cíl, nahrazuje Srdce ostrova) a lávka přes energetickou řeku.

const METAL: Color = Color(0.58, 0.62, 0.72)
const METAL_D: Color = Color(0.28, 0.31, 0.40)
const METAL_L: Color = Color(0.80, 0.84, 0.92)
const CYAN: Color = Color(0.10, 0.90, 1.00)
const MAGENTA: Color = Color(1.00, 0.25, 0.80)


## Hvězdná brána: kovový prstenec se svítícími segmenty a vířící energetický disk. Potomci: "Disc", "Light".
static func build_portal(map: GameMap) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Portal"
	var p: PathData = map.terrain.path
	var pos: Vector3 = p.pos_at(0.0)
	var dir2: Vector2 = p.dir_at(0.0)
	root.position = pos
	root.rotation.y = atan2(dir2.x, dir2.y)      # +Z uzlu míří po směru trasy

	var k: MeshKit = MeshKit.new(5, 0.05)
	k.ao = 0.3
	k.ao_height = 1.2
	# podstavec
	k.cyl(2.7, 2.4, 0.3, 12, METAL_D, MeshKit.xf(Vector3(0.0, -0.22, 0.0)), 0.0, false, true)
	k.cyl(2.2, 2.0, 0.12, 12, METAL, MeshKit.xf(Vector3(0.0, 0.06, 0.0)), 0.0, false, true)
	k.torus(2.3, 0.05, CYAN, MeshKit.xf(Vector3(0.0, 0.14, 0.0)), 1.4, 36, 4)
	# prstenec brány (svislý, v rovině XY)
	var cy: float = 2.05
	k.torus(1.85, 0.2, METAL, MeshKit.xf(Vector3(0.0, cy, 0.0), Vector3(90.0, 0.0, 0.0)), 0.0, 36, 6)
	k.torus(1.62, 0.07, CYAN, MeshKit.xf(Vector3(0.0, cy, 0.0), Vector3(90.0, 0.0, 0.0)), 1.6, 36, 4)
	# svítící segmenty po obvodu
	for i in range(12):
		var a: float = TAU * float(i) / 12.0
		var seg_pos: Vector3 = Vector3(cos(a) * 1.85, cy + sin(a) * 1.85, 0.0)
		k.box(Vector3(0.34, 0.12, 0.34), CYAN if i % 2 == 0 else MAGENTA, MeshKit.xf(seg_pos, Vector3(0.0, 0.0, rad_to_deg(a))), 1.5)
		if i % 3 == 0:
			k.box(Vector3(0.2, 0.42, 0.5), METAL_D, MeshKit.xf(seg_pos, Vector3(0.0, 0.0, rad_to_deg(a))))
	# nosné pylony
	for sx in [-1.0, 1.0]:
		k.cyl(0.34, 0.26, 1.6, 6, METAL_D, MeshKit.xf(Vector3(float(sx) * 2.25, 0.0, 0.0)), 0.0, false, true)
		k.box(Vector3(0.14, 1.2, 0.06), CYAN, MeshKit.xf(Vector3(float(sx) * 2.25, 0.8, 0.28)), 1.3)
		k.sphere(0.16, MAGENTA, MeshKit.xf(Vector3(float(sx) * 2.25, 1.75, 0.0)), 1.7, 6, 4)
		k.box(Vector3(0.28, 0.12, 1.0), METAL, MeshKit.xf(Vector3(float(sx) * 2.0, 1.1, 0.0), Vector3(0.0, 0.0, float(sx) * -35.0)))
	root.add_child(Gfx.mesh_node(k, Gfx.model_mat(0.45, 0.12)))

	var disc: MeshInstance3D = MeshInstance3D.new()
	disc.name = "Disc"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(3.4, 3.4)
	disc.mesh = q
	disc.position = Vector3(0.0, cy, 0.0)
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load("res://shaders/portal.gdshader")
	sm.set_shader_parameter("noise_tex", Gfx.noise_tex("portal", 21, 0.03, 128, 3))
	sm.set_shader_parameter("color_a", Color(0.02, 0.10, 0.45, 1.0))
	sm.set_shader_parameter("color_b", Color(0.15, 0.95, 1.0, 1.0))
	disc.material_override = sm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(0.25, 0.85, 1.0)
	light.light_energy = 1.6
	light.omni_range = 7.5
	light.position = Vector3(0.0, 2.0, 0.9)
	root.add_child(light)
	return root


## Reaktor: plošina s pylony a levitující energetické jádro. Potomci: "Crystal" (jádro), "Ring", "Light".
static func build_base(map: GameMap) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Heart"
	var c: Vector2 = Cfg.cell_center(map.base_cell.x, map.base_cell.y)
	var y: float = map.terrain.height_at(c.x, c.y)
	root.position = Vector3(c.x, y, c.y)

	var k: MeshKit = MeshKit.new(9, 0.05)
	k.ao = 0.3
	k.ao_height = 1.0
	k.cyl(1.8, 1.65, 0.55, 8, METAL_D, MeshKit.xf(Vector3(0.0, -0.28, 0.0)), 0.0, false, true)
	k.cyl(1.5, 1.35, 0.3, 8, METAL, MeshKit.xf(Vector3(0.0, 0.28, 0.0)), 0.0, false, true)
	k.torus(1.42, 0.05, CYAN, MeshKit.xf(Vector3(0.0, 0.6, 0.0)), 1.4, 32, 4)
	for i in range(6):
		var a: float = TAU * float(i) / 6.0
		var px: float = cos(a) * 1.3
		var pz: float = sin(a) * 1.3
		k.cyl(0.2, 0.15, 1.25, 6, METAL_D, MeshKit.xf(Vector3(px, 0.58, pz)), 0.0, false, true)
		k.box(Vector3(0.07, 0.8, 0.07), CYAN, MeshKit.xf(Vector3(px * 1.1, 0.95, pz * 1.1)), 1.3)
		k.cone(0.2, 0.3, 6, METAL, MeshKit.xf(Vector3(px, 1.83, pz)), 0.0, false)
		k.sphere(0.12, MAGENTA if i % 2 == 0 else CYAN, MeshKit.xf(Vector3(px, 2.1, pz)), 1.9, 6, 4)
	# zvýšený držák jádra
	k.cyl(0.55, 0.4, 0.35, 8, METAL, MeshKit.xf(Vector3(0.0, 0.55, 0.0)), 0.0, false, true)
	root.add_child(Gfx.mesh_node(k, Gfx.model_mat(0.45, 0.12)))

	var cr: Node3D = Node3D.new()
	cr.name = "Crystal"
	cr.position = Vector3(0.0, 1.9, 0.0)
	var ck: MeshKit = MeshKit.new(10, 0.04)
	ck.sphere(0.6, Color(0.10, 0.75, 1.0), MeshKit.xf(Vector3.ZERO, Vector3.ZERO, Vector3(0.85, 1.0, 0.85)), 1.1, 8, 6, true)
	ck.sphere(0.34, Color(0.9, 1.0, 1.0), MeshKit.xf(Vector3.ZERO), 2.4, 6, 4)
	for i2 in range(4):
		var a2: float = TAU * float(i2) / 4.0
		ck.box(Vector3(0.06, 0.8, 0.06), MAGENTA, MeshKit.xf(Vector3(cos(a2) * 0.62, 0.0, sin(a2) * 0.62)), 1.6)
	var cm: MeshInstance3D = Gfx.mesh_node(ck, Gfx.model_mat(0.2, 0.0, true), false)
	cm.name = "Mesh"
	cr.add_child(cm)
	root.add_child(cr)

	var rk: MeshKit = MeshKit.new(12, 0.0)
	rk.torus(1.0, 0.045, CYAN, MeshKit.xf(Vector3.ZERO, Vector3(70.0, 0.0, 0.0)), 1.4, 28, 5)
	rk.torus(1.15, 0.03, MAGENTA, MeshKit.xf(Vector3.ZERO, Vector3(110.0, 40.0, 0.0)), 1.5, 28, 4)
	var ring: MeshInstance3D = Gfx.mesh_node(rk, Gfx.model_mat(0.4, 0.12), false)
	ring.name = "Ring"
	ring.position = Vector3(0.0, 1.9, 0.0)
	root.add_child(ring)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(0.3, 0.85, 1.0)
	light.light_energy = 1.4
	light.omni_range = 6.5
	light.position = Vector3(0.0, 2.1, 0.0)
	root.add_child(light)
	return root


## Lávka přes energetickou řeku podél úseků trasy: kovové dílce se svítícím lemem, sloupky a opěry.
static func build_bridge(map: GameMap) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Bridge"
	if map.bridges.is_empty():
		return root
	var k: MeshKit = MeshKit.new(15, 0.05)
	for br in map.bridges:
		_add_bridge(k, map, float(br[0]), float(br[1]))
	root.add_child(Gfx.mesh_node(k, Gfx.model_mat(0.45, 0.12)))
	return root


static func _add_bridge(k: MeshKit, map: GameMap, s0: float, s1: float) -> void:
	var p: PathData = map.terrain.path
	var s: float = s0
	var i: int = 0
	while s <= s1:
		var pos: Vector3 = p.pos_at(s)
		var d: Vector2 = p.dir_at(s)
		var yaw: float = atan2(d.x, d.y) * 180.0 / PI
		var col: Color = METAL if i % 2 == 0 else METAL.lightened(0.07)
		k.box(Vector3(2.15, 0.14, 0.42), col, MeshKit.xf(pos + Vector3(0.0, -0.09, 0.0), Vector3(0.0, yaw, 0.0)))
		i += 1
		s += 0.46
	# svítící okraje a sloupky po obou stranách
	var side_pts: Array = []
	s = s0
	while s <= s1 + 0.01:
		var pos2: Vector3 = p.pos_at(s)
		var d2: Vector2 = p.dir_at(s)
		side_pts.append([pos2, Vector3(-d2.y, 0.0, d2.x)])
		s += 1.1
	for sd in [-1.0, 1.0]:
		var last: Vector3 = Vector3.ZERO
		var have_last: bool = false
		for e in side_pts:
			var ep: Vector3 = e[0]
			var en: Vector3 = e[1]
			var base: Vector3 = ep + en * 1.04 * float(sd)
			k.cyl(0.08, 0.07, 0.8, 6, METAL_D, MeshKit.xf(base + Vector3(0.0, -0.15, 0.0)), 0.0, false, true)
			k.sphere(0.09, CYAN, MeshKit.xf(base + Vector3(0.0, 0.68, 0.0)), 1.7, 5, 3)
			if have_last:
				var mid: Vector3 = (base + last) * 0.5 + Vector3(0.0, 0.5, 0.0)
				var dv: Vector3 = base - last
				var yaw2: float = atan2(dv.x, dv.z) * 180.0 / PI
				k.box(Vector3(0.05, 0.05, dv.length()), CYAN, MeshKit.xf(mid, Vector3(0.0, yaw2, 0.0)), 1.4)
				k.box(Vector3(0.07, 0.07, dv.length()), METAL_D, MeshKit.xf(mid - Vector3(0.0, 0.3, 0.0), Vector3(0.0, yaw2, 0.0)))
			last = base
			have_last = true
	for e2 in [s0, s1]:
		var pe: Vector3 = p.pos_at(e2)
		var de: Vector2 = p.dir_at(e2)
		var yawe: float = atan2(de.x, de.y) * 180.0 / PI
		k.box(Vector3(2.6, 0.5, 1.0), METAL_D, MeshKit.xf(pe + Vector3(0.0, -0.32, 0.0), Vector3(0.0, yawe, 0.0)))
		k.box(Vector3(2.62, 0.05, 0.12), CYAN, MeshKit.xf(pe + Vector3(0.0, -0.05, 0.0), Vector3(0.0, yawe, 0.0)), 1.3)
