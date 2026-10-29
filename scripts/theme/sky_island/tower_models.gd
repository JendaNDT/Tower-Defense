class_name TowerModels
extends RefCounted
## Modely věží poskládané v kódu. Každá úroveň má viditelně odlišný vzhled (vyšší stavba, víc zdobení, víc krystalů...).
## Počet zlatých drahokamů na podstavci = úroveň věže.

const STONE: Color = Color(0.64, 0.62, 0.58)
const STONE_D: Color = Color(0.46, 0.45, 0.45)
const WOOD: Color = Color(0.60, 0.42, 0.25)
const WOOD_D: Color = Color(0.40, 0.27, 0.16)
const GOLD: Color = Color(1.0, 0.78, 0.25)
const IRON: Color = Color(0.30, 0.31, 0.36)
const IRON_L: Color = Color(0.48, 0.50, 0.56)
const RED: Color = Color(0.75, 0.24, 0.20)


static func build(type: String, level: int) -> TowerVisual:
	var tv: TowerVisual = TowerVisual.new()
	tv.name = "Visual_" + type
	var base: MeshKit = MeshKit.new(level * 7 + 1, 0.05)
	base.ao = 0.3
	base.ao_height = 1.3
	_pad(base, level, type)
	match type:
		"archer":
			_archer(tv, base, level)
		"cannon":
			_cannon(tv, base, level)
		"mage":
			_mage(tv, base, level)
		_:
			_frost(tv, base, level)
	var bm: MeshInstance3D = Gfx.mesh_node(base, Gfx.model_mat(0.85))
	bm.name = "Base"
	tv.add_child(bm)
	return tv


static func xf(pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return MeshKit.xf(pos, rot, scl)


static func _mesh_on(parent: Node3D, kit: MeshKit, mat: Material, shadow: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = Gfx.mesh_node(kit, mat, shadow)
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ podstavec
static func _pad(k: MeshKit, level: int, type: String) -> void:
	var top: Color = STONE
	if type == "frost":
		top = Color(0.78, 0.88, 0.96)
	k.cyl(0.92, 0.84, 0.42, 12, STONE_D, xf(Vector3(0.0, -0.22, 0.0)), 0.0, false, true)
	k.cyl(0.82, 0.76, 0.12, 12, top, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
	if level >= 2:
		for i in range(4):
			var a: float = TAU * float(i) / 4.0 + PI / 4.0
			k.box(Vector3(0.2, 0.22, 0.2), STONE, xf(Vector3(cos(a) * 0.76, 0.3, sin(a) * 0.76), Vector3(0.0, -rad_to_deg(a), 0.0)))
	if level >= 3:
		k.torus(0.86, 0.045, IRON_L, xf(Vector3(0.0, 0.2, 0.0)), 0.0, 24, 5)
	if level >= 4:
		k.torus(0.78, 0.05, GOLD, xf(Vector3(0.0, 0.33, 0.0)), 0.5, 24, 5)
	# drahokamy = úroveň
	for i in range(level):
		var a2: float = TAU * float(i) / float(level) + 0.6
		k.sphere(0.075, GOLD, xf(Vector3(cos(a2) * 0.88, 0.2, sin(a2) * 0.88)), 1.4, 6, 4)


# ------------------------------------------------------------------ lučištník
static func _archer_fig(k: MeshKit, ofs: Vector3, tunic: Color, hat: Color, elite: bool) -> void:
	var skin: Color = Color(0.93, 0.74, 0.58)
	k.box(Vector3(0.09, 0.3, 0.1), Color(0.30, 0.22, 0.16), xf(ofs + Vector3(-0.06, 0.15, 0.0)))
	k.box(Vector3(0.09, 0.3, 0.1), Color(0.30, 0.22, 0.16), xf(ofs + Vector3(0.06, 0.15, 0.0)))
	k.cyl(0.17, 0.12, 0.42, 7, tunic, xf(ofs + Vector3(0.0, 0.28, 0.0)), 0.0, false, true)
	k.box(Vector3(0.3, 0.05, 0.2), Color(0.35, 0.22, 0.12), xf(ofs + Vector3(0.0, 0.34, 0.0)))
	k.sphere(0.115, skin, xf(ofs + Vector3(0.0, 0.8, 0.0)), 0.0, 7, 5)
	k.cone(0.17, 0.24, 7, hat, xf(ofs + Vector3(0.0, 0.84, 0.0)), 0.0, false)
	# toulec
	k.cyl(0.055, 0.05, 0.32, 6, Color(0.42, 0.28, 0.16), xf(ofs + Vector3(-0.08, 0.42, -0.15), Vector3(-15.0, 0.0, 0.0)), 0.0, false, true)
	k.box(Vector3(0.03, 0.1, 0.03), Color(1, 1, 1), xf(ofs + Vector3(-0.08, 0.78, -0.2)))
	# luk
	k.box(Vector3(0.035, 0.2, 0.05), WOOD_D, xf(ofs + Vector3(0.0, 0.55, 0.24)))
	k.box(Vector3(0.03, 0.22, 0.03), WOOD, xf(ofs + Vector3(0.0, 0.72, 0.2), Vector3(-28.0, 0.0, 0.0)))
	k.box(Vector3(0.03, 0.22, 0.03), WOOD, xf(ofs + Vector3(0.0, 0.38, 0.2), Vector3(28.0, 0.0, 0.0)))
	k.box(Vector3(0.012, 0.55, 0.012), Color(0.95, 0.95, 0.9), xf(ofs + Vector3(0.0, 0.55, 0.12)))
	# paže
	k.box(Vector3(0.07, 0.07, 0.3), tunic.darkened(0.1), xf(ofs + Vector3(0.1, 0.58, 0.12), Vector3(0.0, -12.0, 0.0)))
	if elite:
		k.sphere(0.085, GOLD, xf(ofs + Vector3(0.17, 0.62, 0.0)), 0.6, 6, 4)
		k.sphere(0.085, GOLD, xf(ofs + Vector3(-0.17, 0.62, 0.0)), 0.6, 6, 4)
		k.cone(0.05, 0.28, 5, RED, xf(ofs + Vector3(0.0, 1.0, -0.05), Vector3(-30.0, 0.0, 0.0)), 0.0, false)


static func _archer(tv: TowerVisual, base: MeshKit, level: int) -> void:
	var plat_y: float = [1.35, 2.0, 2.0, 2.45][level - 1]
	if level <= 2:
		var h: float = plat_y - 0.25
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				base.cyl(0.075, 0.06, h, 6, WOOD_D, xf(Vector3(float(sx) * 0.4, 0.25, float(sz) * 0.4)), 0.0, false, true)
		for sd in [-1.0, 1.0]:
			base.box(Vector3(0.06, 0.06, 0.95), WOOD, xf(Vector3(float(sd) * 0.4, plat_y * 0.45, 0.0), Vector3(0.0, 0.0, float(sd) * 8.0)))
			base.box(Vector3(0.95, 0.06, 0.06), WOOD, xf(Vector3(0.0, plat_y * 0.62, float(sd) * 0.4), Vector3(float(sd) * 8.0, 0.0, 0.0)))
		base.box(Vector3(1.1, 0.1, 1.1), WOOD, xf(Vector3(0.0, plat_y, 0.0)))
		# zábradlí
		for sd2 in [-1.0, 1.0]:
			base.box(Vector3(1.1, 0.06, 0.06), WOOD_D, xf(Vector3(0.0, plat_y + 0.3, float(sd2) * 0.52)))
			base.box(Vector3(0.06, 0.06, 1.1), WOOD_D, xf(Vector3(float(sd2) * 0.52, plat_y + 0.3, 0.0)))
		for sx2 in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				base.box(Vector3(0.07, 0.4, 0.07), WOOD_D, xf(Vector3(float(sx2) * 0.52, plat_y + 0.2, float(sz2) * 0.52)))
		if level == 2:
			for sx3 in [-1.0, 1.0]:
				for sz3 in [-1.0, 1.0]:
					base.cyl(0.05, 0.05, 1.05, 6, WOOD_D, xf(Vector3(float(sx3) * 0.45, plat_y + 0.1, float(sz3) * 0.45)), 0.0, false, false)
			base.cone(0.98, 0.6, 4, RED, xf(Vector3(0.0, plat_y + 1.12, 0.0), Vector3(0.0, 45.0, 0.0)), 0.0, false)
			base.sphere(0.06, GOLD, xf(Vector3(0.0, plat_y + 1.74, 0.0)), 0.8, 5, 3)
	else:
		# kamenná věž
		var th: float = plat_y - 0.25
		base.cyl(0.7, 0.58, th, 10, STONE, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
		base.torus(0.62, 0.045, STONE_D, xf(Vector3(0.0, 0.2 + th * 0.35, 0.0)), 0.0, 20, 5)
		base.torus(0.6, 0.045, STONE_D, xf(Vector3(0.0, 0.2 + th * 0.8, 0.0)), 0.0, 20, 5)
		for i in range(3):
			var a: float = TAU * float(i) / 3.0 + 0.5
			base.box(Vector3(0.1, 0.26, 0.05), Color(0.12, 0.10, 0.10), xf(Vector3(cos(a) * 0.62, 0.2 + th * 0.55, sin(a) * 0.62), Vector3(0.0, -rad_to_deg(a) + 90.0, 0.0)))
		base.cyl(0.92, 0.82, 0.2, 10, WOOD, xf(Vector3(0.0, plat_y - 0.1, 0.0)), 0.0, false, true)
		for i2 in range(8):
			var a2: float = TAU * float(i2) / 8.0
			base.box(Vector3(0.14, 0.34, 0.3), STONE, xf(Vector3(cos(a2) * 0.82, plat_y + 0.2, sin(a2) * 0.82), Vector3(0.0, -rad_to_deg(a2), 0.0)))
			if level == 4:
				base.box(Vector3(0.16, 0.06, 0.32), GOLD, xf(Vector3(cos(a2) * 0.82, plat_y + 0.4, sin(a2) * 0.82), Vector3(0.0, -rad_to_deg(a2), 0.0)), 0.4)
		# vlajka
		base.cyl(0.03, 0.03, 1.1, 5, WOOD_D, xf(Vector3(-0.55, plat_y, -0.5)), 0.0, false, false)
		base.tri(Vector3(-0.55, plat_y + 1.05, -0.5), Vector3(-0.55, plat_y + 0.62, -0.5), Vector3(-0.05, plat_y + 0.84, -0.5), RED, Transform3D.IDENTITY, 0.0, true)
		if level == 4:
			for sx4 in [-1.0, 1.0]:
				for sz4 in [-1.0, 1.0]:
					base.cyl(0.07, 0.06, 1.1, 7, GOLD, xf(Vector3(float(sx4) * 0.55, plat_y, float(sz4) * 0.55)), 0.35, true, true)
			base.cone(1.15, 0.85, 8, RED, xf(Vector3(0.0, plat_y + 1.1, 0.0)), 0.0, false)
			base.torus(1.0, 0.05, GOLD, xf(Vector3(0.0, plat_y + 1.14, 0.0)), 0.5, 24, 5)
			base.sphere(0.1, GOLD, xf(Vector3(0.0, plat_y + 1.98, 0.0)), 1.0, 6, 4)

	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, plat_y + 0.06, 0.0)
	var tk: MeshKit = MeshKit.new(level + 20, 0.04)
	tk.ao = 0.2
	tk.ao_height = 1.0
	match level:
		1:
			_archer_fig(tk, Vector3.ZERO, Color(0.30, 0.55, 0.28), Color(0.25, 0.45, 0.22), false)
		2:
			_archer_fig(tk, Vector3.ZERO, Color(0.25, 0.42, 0.70), Color(0.20, 0.32, 0.55), false)
		3:
			_archer_fig(tk, Vector3(-0.32, 0.0, 0.0), Color(0.25, 0.42, 0.70), Color(0.20, 0.32, 0.55), false)
			_archer_fig(tk, Vector3(0.32, 0.0, 0.0), Color(0.25, 0.42, 0.70), Color(0.20, 0.32, 0.55), false)
		_:
			_archer_fig(tk, Vector3(-0.32, 0.0, 0.0), Color(0.70, 0.22, 0.20), Color(0.55, 0.16, 0.16), true)
			_archer_fig(tk, Vector3(0.32, 0.0, 0.0), Color(0.70, 0.22, 0.20), Color(0.55, 0.16, 0.16), true)
	_mesh_on(turret, tk, Gfx.model_mat(0.85))
	var mz: Node3D = Node3D.new()
	mz.position = Vector3(0.0, 0.58, 0.4)
	turret.add_child(mz)
	tv.add_child(turret)
	tv.turret = turret
	tv.muzzle = mz
	tv.aim_speed = 9.0 + float(level)


# ------------------------------------------------------------------ kanón
static func _cannon(tv: TowerVisual, base: MeshKit, level: int) -> void:
	var ty: float = 0.32
	if level >= 2:
		base.cyl(0.78, 0.72, 0.3, 10, STONE, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
		ty = 0.5
	if level == 2:
		base.sphere(0.13, IRON, xf(Vector3(0.62, 0.36, -0.55)), 0.0, 7, 5)
		base.sphere(0.13, IRON, xf(Vector3(0.45, 0.36, -0.7)), 0.0, 7, 5)
		base.sphere(0.13, IRON, xf(Vector3(0.55, 0.52, -0.62)), 0.0, 7, 5)
	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, ty, 0.0)
	var tk: MeshKit = MeshKit.new(level + 40, 0.04)
	var bl: float = [1.0, 1.15, 1.3, 1.5][level - 1]
	var br: float = [0.2, 0.22, 0.24, 0.27][level - 1]
	match level:
		1, 2:
			var wr: float = 0.24 if level == 1 else 0.29
			tk.box(Vector3(0.62, 0.2, 0.95), WOOD, xf(Vector3(0.0, 0.26, 0.0)))
			tk.box(Vector3(0.66, 0.06, 0.2), IRON, xf(Vector3(0.0, 0.38, -0.2)))
			for sx in [-1.0, 1.0]:
				tk.cyl(wr, wr, 0.12, 10, WOOD_D, xf(Vector3(float(sx) * 0.36, 0.26, 0.0), Vector3(0.0, 0.0, 90.0)), 0.0, false, true)
				tk.cyl(wr * 0.35, wr * 0.35, 0.16, 6, IRON_L, xf(Vector3(float(sx) * 0.36, 0.26, 0.0), Vector3(0.0, 0.0, 90.0)), 0.0, false, true)
		3:
			tk.cyl(0.62, 0.56, 0.4, 10, IRON, xf(Vector3(0.0, 0.0, 0.0)), 0.0, false, true)
			tk.torus(0.6, 0.04, GOLD, xf(Vector3(0.0, 0.4, 0.0)), 0.3, 20, 5)
			tk.box(Vector3(0.92, 0.55, 0.08), IRON_L, xf(Vector3(0.0, 0.55, 0.38), Vector3(-12.0, 0.0, 0.0)))
			tk.box(Vector3(0.28, 0.2, 0.5), IRON, xf(Vector3(0.0, 0.5, -0.1)))
		_:
			tk.cyl(0.7, 0.62, 0.5, 12, Color(0.22, 0.22, 0.27), xf(Vector3(0.0, 0.0, 0.0)), 0.0, false, true)
			tk.torus(0.66, 0.05, GOLD, xf(Vector3(0.0, 0.5, 0.0)), 0.5, 24, 5)
			for i in range(6):
				var a: float = TAU * float(i) / 6.0
				tk.cone(0.07, 0.3, 5, IRON_L, xf(Vector3(cos(a) * 0.62, 0.34, sin(a) * 0.62), Vector3(0.0, 0.0, 0.0)), 0.0, false)
			tk.box(Vector3(1.0, 0.6, 0.09), IRON_L, xf(Vector3(0.0, 0.6, 0.45), Vector3(-12.0, 0.0, 0.0)))
			tk.box(Vector3(0.34, 0.24, 0.55), IRON, xf(Vector3(0.0, 0.58, -0.1)))
			tk.sphere(0.14, Color(1.0, 0.35, 0.1), xf(Vector3(0.0, 0.8, -0.35)), 2.4, 7, 5)
	_mesh_on(turret, tk, Gfx.model_mat(0.5, 0.35))

	# hlaveň (zpětný ráz + náměr)
	var barrel: Node3D = Node3D.new()
	barrel.name = "Barrel"
	var piv_y: float = 0.5 if level <= 2 else (0.62 if level == 3 else 0.78)
	barrel.position = Vector3(0.0, piv_y, -0.05)
	barrel.rotation.x = -0.25
	var bk: MeshKit = MeshKit.new(level + 50, 0.03)
	bk.cyl(br, br * 0.74, bl, 10, IRON, xf(Vector3(0.0, 0.0, -0.22), Vector3(90.0, 0.0, 0.0)), 0.0, true, true)
	bk.sphere(br * 1.05, IRON, xf(Vector3(0.0, 0.0, -0.22)), 0.0, 9, 6, true)
	bk.torus(br * 0.98, 0.028, IRON_L, xf(Vector3(0.0, 0.0, 0.1), Vector3(90.0, 0.0, 0.0)), 0.0, 14, 4)
	bk.torus(br * 0.86, 0.028, IRON_L, xf(Vector3(0.0, 0.0, 0.5), Vector3(90.0, 0.0, 0.0)), 0.0, 14, 4)
	if level >= 3:
		bk.torus(br * 0.80, 0.04, GOLD, xf(Vector3(0.0, 0.0, bl - 0.28), Vector3(90.0, 0.0, 0.0)), 0.4 if level == 3 else 0.7, 16, 4)
		bk.torus(br * 0.76, 0.05, Color(1.0, 0.45, 0.12), xf(Vector3(0.0, 0.0, bl - 0.22), Vector3(90.0, 0.0, 0.0)), 2.0, 16, 4)
	if level == 4:
		for sx2 in [-1.0, 1.0]:
			bk.cyl(0.1, 0.075, bl * 0.8, 8, IRON_L, xf(Vector3(float(sx2) * 0.36, -0.06, -0.2), Vector3(90.0, 0.0, 0.0)), 0.0, true, true)
	_mesh_on(barrel, bk, Gfx.model_mat(0.35, 0.65))
	var mz: Node3D = Node3D.new()
	mz.position = Vector3(0.0, 0.0, bl - 0.2)
	barrel.add_child(mz)
	turret.add_child(barrel)
	tv.add_child(turret)
	tv.turret = turret
	tv.muzzle = mz
	tv.setup_barrel(barrel)
	tv.aim_speed = 5.0 + float(level) * 0.5


# ------------------------------------------------------------------ mág
static func _crystal(k: MeshKit, r: float, pos: Vector3, col: Color, emit: float, stretch: float = 1.5) -> void:
	k.sphere(r, col, xf(pos, Vector3.ZERO, Vector3(0.62, stretch, 0.62)), emit, 4, 2)


static func _mage(tv: TowerVisual, base: MeshKit, level: int) -> void:
	var purple: Color = Color(0.62, 0.35, 1.0)
	var pill_h: float = [0.9, 1.25, 1.55, 1.85][level - 1]
	base.cyl(0.48, 0.38, pill_h, 8, STONE, xf(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
	base.cyl(0.58, 0.5, 0.14, 8, STONE_D, xf(Vector3(0.0, 0.2 + pill_h, 0.0)), 0.0, false, true)
	base.torus(0.5, 0.04, STONE_D, xf(Vector3(0.0, 0.2 + pill_h * 0.4, 0.0)), 0.0, 16, 4)
	# runy na pilíři
	for i in range(level + 2):
		var a: float = TAU * float(i) / float(level + 2)
		base.box(Vector3(0.05, 0.14, 0.02), purple, xf(Vector3(cos(a) * 0.45, 0.2 + pill_h * 0.65, sin(a) * 0.45), Vector3(0.0, -rad_to_deg(a) + 90.0, 0.0)), 1.6)
	if level >= 3:
		for i2 in range(4):
			var a2: float = TAU * float(i2) / 4.0 + PI / 4.0
			base.cone(0.1, 0.5, 5, STONE, xf(Vector3(cos(a2) * 0.52, 0.2, sin(a2) * 0.52)), 0.0, false)
	if level == 4:
		base.torus(0.55, 0.05, GOLD, xf(Vector3(0.0, 0.2 + pill_h * 0.85, 0.0)), 0.5, 20, 5)

	var top_y: float = 0.2 + pill_h + 0.14
	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, top_y, 0.0)

	var cr_r: float = [0.26, 0.33, 0.4, 0.48][level - 1]
	var crystal: Node3D = Node3D.new()
	crystal.name = "Crystal"
	crystal.position = Vector3(0.0, cr_r * 1.9 + 0.2, 0.0)
	var ck: MeshKit = MeshKit.new(level + 60, 0.05)
	_crystal(ck, cr_r, Vector3.ZERO, purple, 1.3, 1.55)
	if level >= 4:
		ck.sphere(cr_r * 0.5, Color(1.0, 0.92, 1.0), xf(Vector3.ZERO, Vector3(0.0, 45.0, 0.0), Vector3(0.62, 1.6, 0.62)), 3.0, 4, 2)
	_mesh_on(crystal, ck, Gfx.model_mat(0.2, 0.0), false)
	turret.add_child(crystal)
	tv.add_spinner(crystal, Vector3.UP, 1.1)
	tv.add_bobber(crystal, 0.07, 1.8)
	tv.pulse_nodes.append(crystal)

	# prstenec(e)
	if level >= 2:
		var rk: MeshKit = MeshKit.new(level + 70, 0.0)
		rk.torus(0.55 + 0.06 * float(level), 0.03, Color(0.75, 0.55, 1.0), xf(), 1.6, 28, 5)
		var ring: Node3D = Node3D.new()
		ring.position = crystal.position
		ring.rotation.x = 0.35
		_mesh_on(ring, rk, Gfx.model_mat(0.3, 0.2), false)
		turret.add_child(ring)
		tv.add_spinner(ring, Vector3.UP, -1.4)
	if level >= 4:
		var rk2: MeshKit = MeshKit.new(77, 0.0)
		rk2.torus(0.95, 0.025, Color(0.9, 0.8, 1.0), xf(), 1.8, 32, 5)
		var ring2: Node3D = Node3D.new()
		ring2.position = crystal.position
		ring2.rotation = Vector3(1.2, 0.0, 0.5)
		_mesh_on(ring2, rk2, Gfx.model_mat(0.3, 0.2), false)
		turret.add_child(ring2)
		tv.add_spinner(ring2, Vector3.UP, 1.0)

	# obíhající krystalky
	var orb_n: int = [0, 2, 3, 5][level - 1]
	for i3 in range(orb_n):
		var piv: Node3D = Node3D.new()
		piv.position = crystal.position
		piv.rotation = Vector3(0.0, TAU * float(i3) / float(orb_n), 0.35 * float(i3 % 2))
		var ok: MeshKit = MeshKit.new(80 + i3, 0.0)
		_crystal(ok, 0.09, Vector3(0.0, 0.0, 0.0), Color(0.78, 0.6, 1.0), 2.0, 1.4)
		var om: MeshInstance3D = _mesh_on(piv, ok, Gfx.model_mat(0.2), false)
		om.position = Vector3(0.78 if level >= 3 else 0.6, 0.0, 0.0)
		turret.add_child(piv)
		tv.add_spinner(piv, Vector3.UP, 1.8 + 0.3 * float(i3))

	var mz: Node3D = Node3D.new()
	mz.position = crystal.position
	turret.add_child(mz)
	tv.add_child(turret)
	tv.turret = turret
	tv.muzzle = mz
	tv.aim_speed = 8.0


# ------------------------------------------------------------------ mráz
static func _frost(tv: TowerVisual, base: MeshKit, level: int) -> void:
	var ice: Color = Color(0.55, 0.85, 1.0)
	var ice_d: Color = Color(0.35, 0.65, 0.95)
	# sněhová čepice na podstavci
	base.cyl(0.7, 0.55, 0.14, 10, Color(0.97, 0.98, 1.0), xf(Vector3(0.0, 0.3, 0.0)), 0.0, false, true)

	var turret: Node3D = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 0.4, 0.0)
	var ck: MeshKit = MeshKit.new(level + 90, 0.06)
	var main_h: float = [0.95, 1.2, 1.6, 2.1][level - 1]
	var main_r: float = [0.27, 0.32, 0.38, 0.46][level - 1]
	# hlavní krystal (šestiboký hrot)
	ck.cyl(main_r, main_r * 0.55, main_h * 0.72, 6, ice, xf(), 0.7)
	ck.cone(main_r * 0.55, main_h * 0.28, 6, Color(0.8, 0.95, 1.0), xf(Vector3(0.0, main_h * 0.72, 0.0)), 1.0, false)
	var n_side: int = [2, 4, 6, 8][level - 1]
	for i in range(n_side):
		var a: float = TAU * float(i) / float(n_side) + 0.4
		var rr: float = 0.5 + 0.04 * float(i % 3)
		var h2: float = main_h * (0.35 + 0.12 * float(i % 3))
		ck.cone(0.13 + 0.02 * float(i % 2), h2, 5, ice_d.lerp(ice, 0.5), xf(Vector3(cos(a) * rr, 0.0, sin(a) * rr), Vector3(sin(a) * 10.0, 0.0, -cos(a) * 10.0)), 0.6, false)
	var cryst: Node3D = Node3D.new()
	cryst.name = "Crystal"
	_mesh_on(cryst, ck, Gfx.model_mat(0.18, 0.05), false)
	turret.add_child(cryst)
	tv.pulse_nodes.append(cryst)
	tv.add_spinner(cryst, Vector3.UP, 0.25)

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
			fk2.sphere(0.07, Color(0.9, 1.0, 1.0), xf(Vector3(cos(a3) * 1.15, 0.0, sin(a3) * 1.15), Vector3.ZERO, Vector3(0.6, 1.4, 0.6)), 2.2, 4, 2)
		var fr2: Node3D = Node3D.new()
		fr2.position = Vector3(0.0, main_h * 0.4, 0.0)
		fr2.rotation = Vector3(0.28, 0.0, 0.1)
		_mesh_on(fr2, fk2, Gfx.model_mat(0.2), false)
		turret.add_child(fr2)
		tv.add_spinner(fr2, Vector3.UP, -0.7)
	# plovoucí střepy
	var shard_n: int = [0, 2, 3, 4][level - 1]
	for i4 in range(shard_n):
		var piv: Node3D = Node3D.new()
		piv.position = Vector3(0.0, main_h * 0.5, 0.0)
		piv.rotation = Vector3(0.0, TAU * float(i4) / float(shard_n), 0.0)
		var sk: MeshKit = MeshKit.new(100 + i4, 0.0)
		_crystal(sk, 0.08, Vector3.ZERO, Color(0.85, 0.97, 1.0), 2.0, 1.6)
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
