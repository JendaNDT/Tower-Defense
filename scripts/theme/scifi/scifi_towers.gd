class_name SciFiTowers
extends RefCounted
## Modely věží vesmírné stanice: laser, plazmomet, Teslova věž a kryo věž. Každá úroveň je viditelně jiná
## (vyšší konstrukce, víc hlavní, cívek a prstenců). Počet svítících diod na podstavci = úroveň věže.

const METAL: Color = Color(0.64, 0.68, 0.77)
const METAL_D: Color = Color(0.31, 0.34, 0.43)
const METAL_L: Color = Color(0.82, 0.86, 0.93)
const GOLD: Color = Color(1.0, 0.78, 0.25)
const RED: Color = Color(1.0, 0.28, 0.28)
const GREEN: Color = Color(0.45, 1.0, 0.35)
const VIOLET: Color = Color(0.62, 0.50, 1.0)
const ICE: Color = Color(0.45, 0.90, 1.0)


static func xf(pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return MeshKit.xf(pos, rot, scl)


static func _mesh_on(parent: Node3D, kit: MeshKit, mat: Material, shadow: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = Gfx.mesh_node(kit, mat, shadow)
	parent.add_child(mi)
	return mi


static func accent_of(type: String) -> Color:
	match type:
		"archer":
			return RED
		"cannon":
			return GREEN
		"mage":
			return VIOLET
		_:
			return ICE


static func build(type: String, level: int) -> TowerVisual:
	var tv: TowerVisual = TowerVisual.new()
	tv.name = "Visual_" + type
	var base: MeshKit = MeshKit.new(level * 7 + 3, 0.04)
	base.ao = 0.3
	base.ao_height = 1.3
	_pad(base, level, accent_of(type))
	match type:
		"archer":
			_laser(tv, base, level)
		"cannon":
			_plasma(tv, base, level)
		"mage":
			_tesla(tv, base, level)
		_:
			_cryo(tv, base, level)
	var bm: MeshInstance3D = Gfx.mesh_node(base, Gfx.model_mat(0.45, 0.12))
	bm.name = "Base"
	tv.add_child(bm)
	return tv


# ------------------------------------------------------------------ podstavec
static func _pad(k: MeshKit, level: int, accent: Color) -> void:
	k.cyl(0.95, 0.88, 0.36, 8, METAL_D, xf(Vector3(0.0, -0.22, 0.0)), 0.0, false, true)
	k.cyl(0.84, 0.78, 0.12, 8, METAL, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
	k.torus(0.86, 0.035, accent, xf(Vector3(0.0, 0.27, 0.0)), 1.3, 24, 4)
	if level >= 2:
		for i in range(4):
			var a: float = TAU * float(i) / 4.0 + PI / 4.0
			k.box(Vector3(0.22, 0.2, 0.22), METAL_L, xf(Vector3(cos(a) * 0.74, 0.32, sin(a) * 0.74), Vector3(0.0, -rad_to_deg(a), 0.0)))
	if level >= 3:
		k.torus(0.9, 0.04, METAL_L, xf(Vector3(0.0, 0.14, 0.0)), 0.0, 24, 4)
	if level >= 4:
		k.torus(0.78, 0.05, GOLD, xf(Vector3(0.0, 0.34, 0.0)), 0.8, 24, 4)
	# diody = úroveň
	for i2 in range(level):
		var a2: float = TAU * float(i2) / float(level) + 0.6
		k.box(Vector3(0.12, 0.07, 0.07), GOLD, xf(Vector3(cos(a2) * 0.9, 0.14, sin(a2) * 0.9), Vector3(0.0, -rad_to_deg(a2), 0.0)), 1.8)


# ------------------------------------------------------------------ laser (lučištník)
static func _laser(tv: TowerVisual, base: MeshKit, level: int) -> void:
	var ped: float = [0.9, 1.3, 1.6, 2.0][level - 1]
	var acc: Color = RED
	base.cyl(0.46, 0.34, ped, 6, METAL, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
	for i in range(level + 1):
		var yy: float = 0.2 + ped * (0.2 + 0.7 * float(i) / float(level + 1))
		base.torus(0.44 - 0.1 * (yy / (ped + 0.2)), 0.035, acc, xf(Vector3(0.0, yy, 0.0)), 1.1, 12, 4)
	if level >= 3:
		for i2 in range(4):
			var a: float = TAU * float(i2) / 4.0 + PI / 4.0
			base.box(Vector3(0.1, ped * 0.7, 0.34), METAL_L, xf(Vector3(cos(a) * 0.42, 0.2 + ped * 0.45, sin(a) * 0.42), Vector3(0.0, -rad_to_deg(a) + 90.0, 0.0)))
	var top: float = 0.2 + ped
	base.cyl(0.38, 0.3, 0.1, 6, METAL_D, xf(Vector3(0.0, top, 0.0)), 0.0, false, true)

	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, top + 0.1, 0.0)
	var tk: MeshKit = MeshKit.new(level + 20, 0.04)
	tk.ao = 0.2
	tk.ao_height = 0.8
	# hlava: tělo, radiátory, zdroj
	tk.box(Vector3(0.5, 0.32, 0.62), METAL, xf(Vector3(0.0, 0.26, 0.0)))
	tk.box(Vector3(0.36, 0.2, 0.16), METAL_D, xf(Vector3(0.0, 0.3, -0.34)))
	var barrels: int = 1 if level <= 2 else 2
	var blen: float = [0.7, 0.95, 1.05, 1.2][level - 1]
	for bi in range(barrels):
		var bx: float = 0.0 if barrels == 1 else (-0.15 if bi == 0 else 0.15)
		tk.cyl(0.065, 0.05, blen, 8, METAL_L, xf(Vector3(bx, 0.27, 0.15), Vector3(90.0, 0.0, 0.0)), 0.0, true, true)
		tk.torus(0.08, 0.02, acc, xf(Vector3(bx, 0.27, 0.35), Vector3(90.0, 0.0, 0.0)), 1.6, 10, 3)
		tk.cone(0.05, 0.12, 6, acc.lightened(0.4), xf(Vector3(bx, 0.27, 0.15 + blen), Vector3(90.0, 0.0, 0.0)), 1.8, false)
	if level >= 2:
		for sx in [-1.0, 1.0]:
			tk.box(Vector3(0.05, 0.22, 0.4), METAL_L, xf(Vector3(float(sx) * 0.3, 0.3, -0.05), Vector3(0.0, 0.0, float(sx) * -12.0)))
	if level >= 3:
		# anténa / radar
		tk.cyl(0.02, 0.02, 0.35, 5, METAL_L, xf(Vector3(-0.2, 0.42, -0.2)), 0.0, false, false)
		tk.sphere(0.06, GREEN, xf(Vector3(-0.2, 0.8, -0.2)), 1.8, 5, 3)
	if level >= 4:
		for sx2 in [-1.0, 1.0]:
			tk.cyl(0.025, 0.02, 0.8, 6, GOLD, xf(Vector3(float(sx2) * 0.34, 0.26, 0.2), Vector3(90.0, 0.0, 0.0)), 0.7, false, true)
		tk.box(Vector3(0.6, 0.06, 0.7), GOLD, xf(Vector3(0.0, 0.44, -0.02)), 0.6)
	_mesh_on(turret, tk, Gfx.model_mat(0.4, 0.12))
	# pulzující čočka na konci hlavně (záblesk při výstřelu)
	var lens: Node3D = Node3D.new()
	lens.position = Vector3(0.0, 0.27, 0.15 + blen + 0.06)
	var lk: MeshKit = MeshKit.new(level + 30, 0.0)
	lk.sphere(0.07 + 0.01 * float(level), acc.lightened(0.5), xf(), 2.4, 6, 4)
	_mesh_on(lens, lk, Gfx.model_mat(0.2, 0.0), false)
	turret.add_child(lens)
	tv.pulse_nodes.append(lens)
	if level >= 4:
		# plovoucí kondenzátor za hlavou
		var rk: MeshKit = MeshKit.new(40, 0.0)
		rk.torus(0.34, 0.035, GOLD, xf(), 1.2, 20, 4)
		rk.torus(0.26, 0.025, acc, xf(Vector3.ZERO, Vector3(0.0, 0.0, 0.0)), 1.6, 18, 4)
		var ring: Node3D = Node3D.new()
		ring.position = Vector3(0.0, 0.62, -0.12)
		ring.rotation.x = PI * 0.5
		_mesh_on(ring, rk, Gfx.model_mat(0.3, 0.12), false)
		turret.add_child(ring)
		tv.add_spinner(ring, Vector3.UP, 2.2)
	var mz: Node3D = Node3D.new()
	mz.position = Vector3(0.0, 0.27, 0.15 + blen + 0.1)
	turret.add_child(mz)
	tv.add_child(turret)
	tv.turret = turret
	tv.muzzle = mz
	tv.aim_speed = 9.0 + float(level)


# ------------------------------------------------------------------ plazmomet (kanón)
static func _plasma(tv: TowerVisual, base: MeshKit, level: int) -> void:
	var ty: float = 0.32
	if level >= 2:
		base.cyl(0.78, 0.72, 0.3, 8, METAL, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
		ty = 0.5
	if level == 2:
		for i in range(3):
			base.sphere(0.12, GREEN, xf(Vector3(0.56 + 0.08 * float(i % 2), 0.38 + 0.14 * float(i), -0.5 - 0.1 * float(i))), 1.2, 6, 4)
	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, ty, 0.0)
	var tk: MeshKit = MeshKit.new(level + 40, 0.04)
	var bl: float = [1.0, 1.15, 1.3, 1.5][level - 1]
	var br: float = [0.2, 0.22, 0.24, 0.27][level - 1]
	# otočný podvozek
	tk.cyl(0.6, 0.54, 0.34, 8, METAL_D, xf(Vector3.ZERO), 0.0, false, true)
	tk.torus(0.58, 0.035, GREEN, xf(Vector3(0.0, 0.3, 0.0)), 1.1, 20, 4)
	tk.box(Vector3(0.52, 0.28, 0.5), METAL, xf(Vector3(0.0, 0.42, -0.1)))
	# palivové nádrže
	if level >= 2:
		for sx in [-1.0, 1.0]:
			tk.cyl(0.14, 0.14, 0.62, 8, METAL_L, xf(Vector3(float(sx) * 0.38, 0.4, -0.15), Vector3(90.0, 0.0, 0.0)), 0.0, true, true)
			tk.torus(0.14, 0.025, GREEN, xf(Vector3(float(sx) * 0.38, 0.4, -0.05), Vector3(90.0, 0.0, 0.0)), 1.5, 10, 3)
			tk.torus(0.14, 0.025, GREEN, xf(Vector3(float(sx) * 0.38, 0.4, -0.3), Vector3(90.0, 0.0, 0.0)), 1.5, 10, 3)
	if level >= 3:
		# žhavé žebrování
		for i in range(5):
			tk.box(Vector3(0.5, 0.03, 0.05), Color(1.0, 0.55, 0.2), xf(Vector3(0.0, 0.58, -0.3 + 0.1 * float(i))), 1.8)
	if level >= 4:
		tk.sphere(0.17, Color(0.7, 1.0, 0.6), xf(Vector3(0.0, 0.66, -0.34)), 2.4, 7, 5)
		for sx2 in [-1.0, 1.0]:
			tk.box(Vector3(0.07, 0.08, 1.0), GOLD, xf(Vector3(float(sx2) * 0.52, 0.36, 0.12)), 0.6)
	_mesh_on(turret, tk, Gfx.model_mat(0.4, 0.12))

	# hlaveň: zpětný ráz a náměr
	var barrel: Node3D = Node3D.new()
	barrel.name = "Barrel"
	var piv_y: float = 0.6 if level <= 2 else (0.66 if level == 3 else 0.74)
	barrel.position = Vector3(0.0, piv_y, -0.05)
	barrel.rotation.x = -0.25
	var bk: MeshKit = MeshKit.new(level + 50, 0.03)
	bk.cyl(br, br * 0.78, bl, 10, METAL_L, xf(Vector3(0.0, 0.0, -0.22), Vector3(90.0, 0.0, 0.0)), 0.0, true, true)
	bk.sphere(br * 1.1, METAL, xf(Vector3(0.0, 0.0, -0.22)), 0.0, 9, 6, true)
	# zářící cívky plazmatu podél hlavně
	var coils: int = level + 1
	for i in range(coils):
		var cz: float = 0.05 + (bl - 0.45) * float(i) / float(maxi(coils - 1, 1))
		bk.torus(br * (1.0 - 0.06 * float(i)), 0.03, GREEN, xf(Vector3(0.0, 0.0, cz), Vector3(90.0, 0.0, 0.0)), 1.6 + 0.2 * float(level), 14, 4)
	bk.cone(br * 0.9, 0.16, 10, Color(0.8, 1.0, 0.7), xf(Vector3(0.0, 0.0, bl - 0.22), Vector3(90.0, 0.0, 0.0)), 1.6, false)
	if level >= 3:
		bk.torus(br * 0.80, 0.05, GOLD, xf(Vector3(0.0, 0.0, bl - 0.34), Vector3(90.0, 0.0, 0.0)), 0.7, 16, 4)
	_mesh_on(barrel, bk, Gfx.model_mat(0.3, 0.12))
	var mz: Node3D = Node3D.new()
	mz.position = Vector3(0.0, 0.0, bl - 0.1)
	barrel.add_child(mz)
	turret.add_child(barrel)
	if level == 4:
		# otáčející se chladič
		var rk: MeshKit = MeshKit.new(56, 0.0)
		for i3 in range(6):
			var a3: float = TAU * float(i3) / 6.0
			rk.box(Vector3(0.05, 0.3, 0.2), METAL_L, xf(Vector3(cos(a3) * 0.2, 0.0, sin(a3) * 0.2), Vector3(0.0, -rad_to_deg(a3), 0.0)))
		rk.cyl(0.07, 0.07, 0.08, 6, GREEN, xf(Vector3(0.0, -0.04, 0.0)), 1.4, false, true)
		var fan: Node3D = Node3D.new()
		fan.position = Vector3(0.0, 0.62, 0.3)
		_mesh_on(fan, rk, Gfx.model_mat(0.4, 0.12), false)
		turret.add_child(fan)
		tv.add_spinner(fan, Vector3.UP, 4.0)
	tv.add_child(turret)
	tv.turret = turret
	tv.muzzle = mz
	tv.setup_barrel(barrel)
	tv.aim_speed = 5.0 + float(level) * 0.5


# ------------------------------------------------------------------ Teslova věž (mág)
static func _tesla(tv: TowerVisual, base: MeshKit, level: int) -> void:
	var pill_h: float = [0.9, 1.25, 1.55, 1.85][level - 1]
	base.cyl(0.46, 0.32, pill_h, 8, METAL, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
	# cívky: tlusté toroidy na sloupu
	var coils: int = level + 1
	for i in range(coils):
		var yy: float = 0.2 + pill_h * (0.25 + 0.6 * float(i) / float(maxi(coils - 1, 1)))
		var rr: float = 0.5 - 0.06 * float(i)
		base.torus(rr, 0.1, METAL_D, xf(Vector3(0.0, yy, 0.0)), 0.0, 16, 5)
		base.torus(rr, 0.04, VIOLET, xf(Vector3(0.0, yy, 0.0)), 1.5, 16, 4)
	base.cyl(0.52, 0.42, 0.14, 8, METAL_D, xf(Vector3(0.0, 0.2 + pill_h, 0.0)), 0.0, false, true)
	if level >= 3:
		for i2 in range(4):
			var a2: float = TAU * float(i2) / 4.0 + PI / 4.0
			base.cone(0.1, 0.55, 5, METAL_L, xf(Vector3(cos(a2) * 0.55, 0.2, sin(a2) * 0.55)), 0.0, false)
			base.sphere(0.07, VIOLET, xf(Vector3(cos(a2) * 0.55, 0.78, sin(a2) * 0.55)), 1.8, 5, 3)
	if level == 4:
		base.torus(0.55, 0.05, GOLD, xf(Vector3(0.0, 0.2 + pill_h * 0.92, 0.0)), 0.6, 20, 4)

	var top_y: float = 0.2 + pill_h + 0.14
	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, top_y, 0.0)

	var cr_r: float = [0.24, 0.30, 0.36, 0.44][level - 1]
	var orb: Node3D = Node3D.new()
	orb.name = "Crystal"
	orb.position = Vector3(0.0, cr_r * 1.6 + 0.2, 0.0)
	var ck: MeshKit = MeshKit.new(level + 60, 0.03)
	ck.sphere(cr_r, VIOLET, xf(), 1.4, 9, 6, true)
	ck.sphere(cr_r * 0.55, Color(0.95, 0.92, 1.0), xf(), 3.0, 7, 5)
	# elektrické "jiskry" kolem koule (statické špičky, točí se s koulí)
	for i3 in range(6 + 2 * level):
		var a3: float = TAU * float(i3) / float(6 + 2 * level)
		var el: float = (float(i3 % 3) - 1.0) * 0.5
		ck.cone(0.035, cr_r * 0.5, 4, Color(0.85, 0.9, 1.0), xf(Vector3(cos(a3) * cr_r * 0.9, el * cr_r, sin(a3) * cr_r * 0.9), Vector3(0.0, -rad_to_deg(a3), -90.0 + el * 40.0)), 2.2, false)
	_mesh_on(orb, ck, Gfx.model_mat(0.2, 0.0), false)
	turret.add_child(orb)
	tv.add_spinner(orb, Vector3.UP, 1.4)
	tv.add_bobber(orb, 0.06, 2.2)
	tv.pulse_nodes.append(orb)

	if level >= 2:
		var rk: MeshKit = MeshKit.new(level + 70, 0.0)
		rk.torus(0.52 + 0.06 * float(level), 0.03, Color(0.78, 0.7, 1.0), xf(), 1.6, 28, 5)
		var ring: Node3D = Node3D.new()
		ring.position = orb.position
		ring.rotation.x = 0.35
		_mesh_on(ring, rk, Gfx.model_mat(0.3, 0.12), false)
		turret.add_child(ring)
		tv.add_spinner(ring, Vector3.UP, -1.6)
	if level >= 4:
		var rk2: MeshKit = MeshKit.new(77, 0.0)
		rk2.torus(0.95, 0.025, Color(0.9, 0.85, 1.0), xf(), 1.8, 32, 5)
		var ring2: Node3D = Node3D.new()
		ring2.position = orb.position
		ring2.rotation = Vector3(1.2, 0.0, 0.5)
		_mesh_on(ring2, rk2, Gfx.model_mat(0.3, 0.12), false)
		turret.add_child(ring2)
		tv.add_spinner(ring2, Vector3.UP, 1.1)
	var orb_n: int = [0, 2, 3, 5][level - 1]
	for i4 in range(orb_n):
		var piv: Node3D = Node3D.new()
		piv.position = orb.position
		piv.rotation = Vector3(0.0, TAU * float(i4) / float(orb_n), 0.35 * float(i4 % 2))
		var ok: MeshKit = MeshKit.new(80 + i4, 0.0)
		ok.sphere(0.075, Color(0.85, 0.8, 1.0), xf(), 2.2, 6, 4)
		var om: MeshInstance3D = _mesh_on(piv, ok, Gfx.model_mat(0.2), false)
		om.position = Vector3(0.78 if level >= 3 else 0.62, 0.0, 0.0)
		turret.add_child(piv)
		tv.add_spinner(piv, Vector3.UP, 1.9 + 0.3 * float(i4))
	var mz: Node3D = Node3D.new()
	mz.position = orb.position
	turret.add_child(mz)
	tv.add_child(turret)
	tv.turret = turret
	tv.muzzle = mz
	tv.aim_speed = 8.0


# ------------------------------------------------------------------ kryo věž (mráz)
static func _cryo(tv: TowerVisual, base: MeshKit, level: int) -> void:
	# nízký chladicí blok na podstavci
	base.cyl(0.7, 0.58, 0.22, 8, METAL, xf(Vector3(0.0, 0.3, 0.0)), 0.0, false, true)
	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 0.4, 0.0)
	var main_h: float = [0.95, 1.2, 1.6, 2.1][level - 1]
	var main_r: float = [0.26, 0.31, 0.36, 0.44][level - 1]
	var ck: MeshKit = MeshKit.new(level + 90, 0.05)
	# kryo nádrž: kovový válec s okénky, uvnitř svítí ledová tyč
	ck.cyl(main_r * 1.5, main_r * 1.3, main_h * 0.4, 8, METAL, xf(), 0.0, false, true)
	ck.torus(main_r * 1.45, 0.03, ICE, xf(Vector3(0.0, main_h * 0.28, 0.0)), 1.4, 16, 4)
	ck.cyl(main_r, main_r * 0.55, main_h * 0.72, 6, ICE, xf(Vector3(0.0, main_h * 0.25, 0.0)), 0.9)
	ck.cone(main_r * 0.55, main_h * 0.32, 6, Color(0.85, 0.98, 1.0), xf(Vector3(0.0, main_h * 0.97, 0.0)), 1.4, false)
	# emitory: rohy kolem nádrže
	var n_side: int = [3, 4, 6, 8][level - 1]
	for i in range(n_side):
		var a: float = TAU * float(i) / float(n_side) + 0.4
		var rr: float = main_r * 1.7
		var h2: float = main_h * (0.30 + 0.07 * float(i % 3))
		ck.cone(0.12, h2, 5, METAL_L, xf(Vector3(cos(a) * rr, 0.0, sin(a) * rr), Vector3(sin(a) * 14.0, 0.0, -cos(a) * 14.0)), 0.0, false)
		ck.sphere(0.065, ICE, xf(Vector3(cos(a) * (rr + 0.05), h2 * 0.96, sin(a) * (rr + 0.05))), 1.9, 5, 3)
	var cryst: Node3D = Node3D.new()
	cryst.name = "Crystal"
	_mesh_on(cryst, ck, Gfx.model_mat(0.3, 0.12), false)
	turret.add_child(cryst)
	tv.pulse_nodes.append(cryst)
	tv.add_spinner(cryst, Vector3.UP, 0.3)

	if level >= 3:
		var fk: MeshKit = MeshKit.new(95, 0.0)
		fk.torus(0.85, 0.03, Color(0.85, 0.96, 1.0), xf(), 1.5, 28, 5)
		for i2 in range(6):
			var a2: float = TAU * float(i2) / 6.0
			fk.box(Vector3(0.05, 0.05, 0.28), Color(0.9, 0.98, 1.0), xf(Vector3(cos(a2) * 1.0, 0.0, sin(a2) * 1.0), Vector3(0.0, -rad_to_deg(a2) + 90.0, 0.0)), 1.6)
		var fr: Node3D = Node3D.new()
		fr.position = Vector3(0.0, main_h * 0.55, 0.0)
		_mesh_on(fr, fk, Gfx.model_mat(0.2), false)
		turret.add_child(fr)
		tv.add_spinner(fr, Vector3.UP, 0.9)
	if level >= 4:
		var fk2: MeshKit = MeshKit.new(96, 0.0)
		fk2.torus(1.15, 0.025, Color(0.9, 0.98, 1.0), xf(), 1.6, 32, 5)
		for i3 in range(8):
			var a3: float = TAU * float(i3) / 8.0
			fk2.cone(0.06, 0.24, 4, Color(0.9, 1.0, 1.0), xf(Vector3(cos(a3) * 1.15, 0.0, sin(a3) * 1.15)), 2.2, false)
		var fr2: Node3D = Node3D.new()
		fr2.position = Vector3(0.0, main_h * 0.4, 0.0)
		fr2.rotation = Vector3(0.28, 0.0, 0.1)
		_mesh_on(fr2, fk2, Gfx.model_mat(0.2), false)
		turret.add_child(fr2)
		tv.add_spinner(fr2, Vector3.UP, -0.7)
	var shard_n: int = [0, 2, 3, 4][level - 1]
	for i4 in range(shard_n):
		var piv: Node3D = Node3D.new()
		piv.position = Vector3(0.0, main_h * 0.5, 0.0)
		piv.rotation = Vector3(0.0, TAU * float(i4) / float(shard_n), 0.0)
		var sk: MeshKit = MeshKit.new(100 + i4, 0.0)
		sk.sphere(0.08, Color(0.85, 0.97, 1.0), xf(Vector3.ZERO, Vector3.ZERO, Vector3(0.62, 1.6, 0.62)), 2.0, 4, 2)
		var sm: MeshInstance3D = _mesh_on(piv, sk, Gfx.model_mat(0.2), false)
		sm.position = Vector3(0.75, 0.0, 0.0)
		turret.add_child(piv)
		tv.add_spinner(piv, Vector3.UP, 1.3)
	var mz: Node3D = Node3D.new()
	mz.position = Vector3(0.0, main_h * 0.5, 0.0)
	turret.add_child(mz)
	tv.add_child(turret)
	tv.turret = turret
	tv.muzzle = mz
	tv.aim_speed = 4.0
