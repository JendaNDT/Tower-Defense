class_name EnemyModels
extends RefCounted
## Modely nepřátel poskládané v kódu: skřet, vlk, obrněnec, dráček (létající) a kamenný obr (boss).
## +Z = směr pohybu. Končetiny jsou samostatné pivoty => animace chůze/mávání křídel.


static func _x(pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return MeshKit.xf(pos, rot, scl)


static func build(type: String) -> EnemyVisual:
	var ev: EnemyVisual = EnemyVisual.new()
	ev.name = "Enemy_" + type
	ev.mat = Gfx.model_mat(0.75, 0.0, true)
	ev.body = Node3D.new()
	ev.body.name = "Body"
	ev.add_child(ev.body)
	match type:
		"goblin":
			_goblin(ev)
		"wolf":
			_wolf(ev)
		"golem":
			_golem(ev)
		"drake":
			_drake(ev)
		"healer":
			_healer(ev)
		"shield":
			_shield(ev)
		"slime":
			_slime(ev, 1.0)
		"slimeling":
			_slime(ev, 0.55)
		_:
			_boss(ev)
	match type:
		"wolf":
			ev.death_style = "fall_side"
			ev.death_time = 0.55
		"golem":
			ev.death_style = "crumble"
			ev.death_time = 0.8
		"boss":
			ev.death_style = "crumble"
			ev.death_time = 1.1
		"drake":
			ev.death_style = "crash"
			ev.death_time = 0.85
		"slime", "slimeling":
			ev.death_style = "splat"
			ev.death_time = 0.5
		_:
			ev.death_style = "fall_back"
			ev.death_time = 0.6
	return ev


static func _body_mesh(ev: EnemyVisual, kit: MeshKit) -> void:
	kit.ao = 0.28
	kit.ao_height = 1.0
	ev.body.add_child(kit.instance(ev.mat))


static func _limb(ev: EnemyVisual, pos: Vector3, kit: MeshKit) -> Node3D:
	kit.ao = 0.25
	kit.ao_height = 0.45
	var piv: Node3D = Node3D.new()
	piv.position = pos
	piv.add_child(kit.instance(ev.mat))
	ev.body.add_child(piv)
	return piv


# ------------------------------------------------------------------ skřet
static func _goblin(ev: EnemyVisual) -> void:
	var skin: Color = Color(0.46, 0.72, 0.30)
	var pants: Color = Color(0.34, 0.27, 0.20)
	var kb: MeshKit = MeshKit.new(1, 0.06)
	kb.cyl(0.21, 0.15, 0.42, 7, Color(0.58, 0.40, 0.22), _x(Vector3(0.0, 0.3, 0.0)), 0.0, false, true)
	kb.box(Vector3(0.36, 0.06, 0.26), Color(0.28, 0.18, 0.10), _x(Vector3(0.0, 0.36, 0.0)))
	kb.sphere(0.2, skin, _x(Vector3(0.0, 0.93, 0.02), Vector3.ZERO, Vector3(1.0, 0.95, 1.0)), 0.0, 8, 6)
	kb.cone(0.07, 0.24, 5, skin, _x(Vector3(0.2, 0.98, 0.0), Vector3(0.0, 0.0, -75.0)), 0.0, false)
	kb.cone(0.07, 0.24, 5, skin, _x(Vector3(-0.2, 0.98, 0.0), Vector3(0.0, 0.0, 75.0)), 0.0, false)
	kb.sphere(0.042, Color(1.0, 0.9, 0.2), _x(Vector3(0.08, 0.97, 0.17)), 1.6, 5, 3)
	kb.sphere(0.042, Color(1.0, 0.9, 0.2), _x(Vector3(-0.08, 0.97, 0.17)), 1.6, 5, 3)
	kb.cone(0.04, 0.1, 5, skin.darkened(0.12), _x(Vector3(0.0, 0.92, 0.2), Vector3(90.0, 0.0, 0.0)), 0.0, false)
	kb.box(Vector3(0.1, 0.025, 0.02), Color(0.15, 0.05, 0.05), _x(Vector3(0.0, 0.85, 0.19)))
	kb.cone(0.2, 0.16, 7, Color(0.45, 0.3, 0.18), _x(Vector3(0.0, 1.03, 0.0), Vector3(-12.0, 0.0, 0.0)), 0.0, false)   # špinavá čapka
	_body_mesh(ev, kb)
	for i in range(2):
		var sx: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(2 + i, 0.05)
		lk.box(Vector3(0.1, 0.3, 0.12), pants, _x(Vector3(0.0, -0.15, 0.0)))
		lk.box(Vector3(0.12, 0.06, 0.2), Color(0.22, 0.16, 0.12), _x(Vector3(0.0, -0.28, 0.04)))
		ev.legs.append(_limb(ev, Vector3(sx * 0.09, 0.3, 0.0), lk))
	for j in range(2):
		var sx2: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(4 + j, 0.05)
		ak.box(Vector3(0.08, 0.3, 0.08), skin, _x(Vector3(0.0, -0.15, 0.0)))
		ak.sphere(0.055, skin, _x(Vector3(0.0, -0.31, 0.0)), 0.0, 5, 3)
		if j == 1:
			ak.cyl(0.045, 0.08, 0.5, 6, Color(0.48, 0.32, 0.18), _x(Vector3(0.0, -0.3, 0.04), Vector3(70.0, 0.0, 0.0)), 0.0, false, true)
			ak.sphere(0.09, Color(0.4, 0.27, 0.15), _x(Vector3(0.0, -0.18, 0.5)), 0.0, 6, 4)
		ev.arms.append(_limb(ev, Vector3(sx2 * 0.23, 0.66, 0.0), ak))
	ev.gait = "biped"
	ev.stride_freq = 3.6
	ev.swing = 0.7
	ev.bob = 0.04
	ev.height = 1.15
	ev.aim_height = 0.6
	ev.setup_bar(0.75, 1.45)


# ------------------------------------------------------------------ vlk
static func _wolf(ev: EnemyVisual) -> void:
	var fur: Color = Color(0.55, 0.56, 0.62)
	var fur_l: Color = Color(0.68, 0.69, 0.74)
	var kb: MeshKit = MeshKit.new(11, 0.06)
	kb.box(Vector3(0.36, 0.34, 0.8), fur, _x(Vector3(0.0, 0.52, 0.0)))
	kb.box(Vector3(0.4, 0.38, 0.36), fur_l, _x(Vector3(0.0, 0.54, 0.26)))
	kb.box(Vector3(0.3, 0.1, 0.6), Color(0.9, 0.9, 0.92), _x(Vector3(0.0, 0.36, 0.0)))
	kb.box(Vector3(0.24, 0.26, 0.26), fur_l, _x(Vector3(0.0, 0.66, 0.46), Vector3(-25.0, 0.0, 0.0)))
	kb.box(Vector3(0.28, 0.26, 0.3), fur_l, _x(Vector3(0.0, 0.75, 0.64)))
	kb.box(Vector3(0.16, 0.13, 0.26), fur, _x(Vector3(0.0, 0.69, 0.86)))
	kb.sphere(0.04, Color(0.05, 0.05, 0.06), _x(Vector3(0.0, 0.71, 0.99)), 0.0, 5, 3)
	kb.cone(0.075, 0.22, 5, fur, _x(Vector3(0.09, 0.93, 0.56)), 0.0, false)
	kb.cone(0.075, 0.22, 5, fur, _x(Vector3(-0.09, 0.93, 0.56)), 0.0, false)
	kb.sphere(0.035, Color(1.0, 0.2, 0.15), _x(Vector3(0.09, 0.79, 0.77)), 2.0, 5, 3)
	kb.sphere(0.035, Color(1.0, 0.2, 0.15), _x(Vector3(-0.09, 0.79, 0.77)), 2.0, 5, 3)
	for k in range(4):
		kb.cone(0.05, 0.14, 4, fur.darkened(0.2), _x(Vector3(0.0, 0.7, 0.2 - 0.18 * float(k)), Vector3(-15.0, 0.0, 0.0)), 0.0, false)
	_body_mesh(ev, kb)
	var pos: Array = [Vector3(-0.14, 0.42, 0.28), Vector3(0.14, 0.42, 0.28), Vector3(-0.14, 0.42, -0.28), Vector3(0.14, 0.42, -0.28)]
	for i in range(4):
		var lk: MeshKit = MeshKit.new(12 + i, 0.05)
		lk.box(Vector3(0.1, 0.42, 0.1), fur.darkened(0.12), _x(Vector3(0.0, -0.21, 0.0)))
		lk.box(Vector3(0.11, 0.05, 0.16), Color(0.25, 0.25, 0.28), _x(Vector3(0.0, -0.4, 0.03)))
		ev.legs.append(_limb(ev, pos[i], lk))
	var tk: MeshKit = MeshKit.new(20, 0.05)
	tk.box(Vector3(0.1, 0.1, 0.5), fur, _x(Vector3(0.0, 0.0, -0.25), Vector3(20.0, 0.0, 0.0)))
	tk.box(Vector3(0.11, 0.11, 0.14), fur_l, _x(Vector3(0.0, 0.09, -0.52), Vector3(20.0, 0.0, 0.0)))
	ev.tail = _limb(ev, Vector3(0.0, 0.62, -0.4), tk)
	ev.gait = "quad"
	ev.stride_freq = 2.7
	ev.swing = 0.8
	ev.bob = 0.035
	ev.height = 1.0
	ev.aim_height = 0.55
	ev.setup_bar(0.75, 1.25)


# ------------------------------------------------------------------ obrněnec
static func _golem(ev: EnemyVisual) -> void:
	var steel: Color = Color(0.60, 0.63, 0.70)
	var dark: Color = Color(0.30, 0.32, 0.38)
	var kb: MeshKit = MeshKit.new(31, 0.05)
	kb.box(Vector3(0.7, 0.72, 0.5), steel, _x(Vector3(0.0, 1.18, 0.0)))
	kb.box(Vector3(0.58, 0.5, 0.12), steel.lightened(0.12), _x(Vector3(0.0, 1.24, 0.28)))
	kb.box(Vector3(0.68, 0.12, 0.52), dark, _x(Vector3(0.0, 0.84, 0.0)))
	for sx in [-1.0, 1.0]:
		kb.sphere(0.27, steel, _x(Vector3(float(sx) * 0.48, 1.5, 0.0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), 0.0, 8, 5)
		kb.cone(0.07, 0.22, 5, dark, _x(Vector3(float(sx) * 0.5, 1.68, 0.0)), 0.0, false)
	kb.box(Vector3(0.34, 0.34, 0.34), steel, _x(Vector3(0.0, 1.76, 0.02)))
	kb.box(Vector3(0.26, 0.06, 0.02), Color(1.0, 0.55, 0.1), _x(Vector3(0.0, 1.78, 0.19)), 2.4)
	kb.box(Vector3(0.06, 0.2, 0.4), Color(0.8, 0.2, 0.18), _x(Vector3(0.0, 2.0, -0.02)))
	_body_mesh(ev, kb)
	for i in range(2):
		var sx2: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(32 + i, 0.05)
		lk.box(Vector3(0.24, 0.6, 0.26), steel, _x(Vector3(0.0, -0.3, 0.0)))
		lk.sphere(0.15, dark, _x(Vector3(0.0, -0.3, 0.1)), 0.0, 6, 4)
		lk.box(Vector3(0.28, 0.16, 0.42), dark, _x(Vector3(0.0, -0.62, 0.07)))
		ev.legs.append(_limb(ev, Vector3(sx2 * 0.2, 0.8, 0.0), lk))
	for j in range(2):
		var sx3: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(34 + j, 0.05)
		ak.box(Vector3(0.2, 0.56, 0.2), steel, _x(Vector3(0.0, -0.28, 0.0)))
		ak.sphere(0.12, dark, _x(Vector3(0.0, -0.6, 0.0)), 0.0, 6, 4)
		if j == 0:
			ak.box(Vector3(0.09, 0.82, 0.6), dark, _x(Vector3(-0.2, -0.38, 0.14)))
			ak.box(Vector3(0.05, 0.62, 0.44), steel.lightened(0.1), _x(Vector3(-0.26, -0.38, 0.14)))
			ak.sphere(0.1, Color(1.0, 0.8, 0.3), _x(Vector3(-0.3, -0.38, 0.14)), 0.5, 6, 4)
		else:
			ak.cyl(0.05, 0.05, 0.75, 6, Color(0.45, 0.3, 0.18), _x(Vector3(0.0, -0.55, 0.05), Vector3(70.0, 0.0, 0.0)), 0.0, false, true)
			ak.sphere(0.17, Color(0.25, 0.26, 0.3), _x(Vector3(0.0, -0.3, 0.72)), 0.0, 7, 5)
			for q in range(5):
				var a: float = TAU * float(q) / 5.0
				ak.cone(0.04, 0.14, 4, Color(0.5, 0.5, 0.55), _x(Vector3(cos(a) * 0.17, -0.3 + sin(a) * 0.17, 0.72), Vector3(sin(a) * 0.0, 0.0, 0.0)), 0.0, false)
		ev.arms.append(_limb(ev, Vector3(sx3 * 0.52, 1.5, 0.0), ak))
	ev.gait = "heavy"
	ev.stride_freq = 3.1
	ev.swing = 0.5
	ev.bob = 0.06
	ev.height = 2.1
	ev.aim_height = 1.1
	ev.setup_bar(0.95, 2.45)


# ------------------------------------------------------------------ dráček (létající)
static func _drake(ev: EnemyVisual) -> void:
	var red: Color = Color(0.82, 0.30, 0.26)
	var belly: Color = Color(0.97, 0.78, 0.5)
	var kb: MeshKit = MeshKit.new(41, 0.05)
	kb.sphere(0.3, red, _x(Vector3.ZERO, Vector3.ZERO, Vector3(0.85, 0.8, 1.5)), 0.0, 9, 6)
	kb.sphere(0.28, belly, _x(Vector3(0.0, -0.1, 0.05), Vector3.ZERO, Vector3(0.62, 0.5, 1.25)), 0.0, 8, 5)
	kb.sphere(0.16, red, _x(Vector3(0.0, 0.12, 0.42)), 0.0, 7, 5)
	kb.sphere(0.2, red.lightened(0.05), _x(Vector3(0.0, 0.2, 0.62), Vector3.ZERO, Vector3(0.9, 0.85, 1.1)), 0.0, 8, 5)
	kb.cone(0.09, 0.22, 6, red.darkened(0.1), _x(Vector3(0.0, 0.15, 0.76), Vector3(90.0, 0.0, 0.0)), 0.0, false)
	kb.sphere(0.04, Color(1.0, 0.9, 0.2), _x(Vector3(0.1, 0.27, 0.72)), 2.2, 5, 3)
	kb.sphere(0.04, Color(1.0, 0.9, 0.2), _x(Vector3(-0.1, 0.27, 0.72)), 2.2, 5, 3)
	kb.cone(0.045, 0.22, 5, Color(0.9, 0.85, 0.7), _x(Vector3(0.1, 0.36, 0.55), Vector3(-30.0, 0.0, -10.0)), 0.0, false)
	kb.cone(0.045, 0.22, 5, Color(0.9, 0.85, 0.7), _x(Vector3(-0.1, 0.36, 0.55), Vector3(-30.0, 0.0, 10.0)), 0.0, false)
	for k in range(4):
		kb.cone(0.05, 0.14, 4, red.darkened(0.25), _x(Vector3(0.0, 0.25 - 0.015 * float(k), 0.25 - 0.18 * float(k))), 0.0, false)
	kb.box(Vector3(0.06, 0.2, 0.08), red.darkened(0.2), _x(Vector3(0.1, -0.3, 0.15)))
	kb.box(Vector3(0.06, 0.2, 0.08), red.darkened(0.2), _x(Vector3(-0.1, -0.3, 0.15)))
	_body_mesh(ev, kb)
	var tk: MeshKit = MeshKit.new(42, 0.05)
	tk.sphere(0.16, red, _x(Vector3(0.0, 0.0, -0.1)), 0.0, 7, 5)
	tk.sphere(0.13, red, _x(Vector3(0.0, -0.02, -0.3)), 0.0, 7, 5)
	tk.sphere(0.1, red.darkened(0.08), _x(Vector3(0.0, -0.05, -0.5)), 0.0, 7, 5)
	tk.sphere(0.07, red.darkened(0.12), _x(Vector3(0.0, -0.08, -0.68)), 0.0, 6, 4)
	tk.cone(0.07, 0.2, 4, Color(1.0, 0.6, 0.2), _x(Vector3(0.0, -0.1, -0.86), Vector3(-90.0, 0.0, 0.0)), 1.0, false)
	ev.tail = _limb(ev, Vector3(0.0, 0.0, -0.42), tk)
	for i in range(2):
		var sx: float = -1.0 if i == 0 else 1.0
		var wk: MeshKit = MeshKit.new(43 + i, 0.04)
		var mem: Color = Color(0.62, 0.18, 0.20)
		wk.quad(Vector3(0.0, 0.0, 0.22), Vector3(0.0, 0.0, -0.32), Vector3(sx * 0.95, 0.08, -0.58), Vector3(sx * 1.15, 0.16, 0.0), mem, Transform3D.IDENTITY, 0.0, true)
		wk.tri(Vector3(sx * 1.15, 0.16, 0.0), Vector3(sx * 0.95, 0.08, -0.58), Vector3(sx * 1.3, 0.05, -0.38), mem.lightened(0.1), Transform3D.IDENTITY, 0.0, true)
		wk.box(Vector3(1.2, 0.045, 0.05), red.darkened(0.15), _x(Vector3(sx * 0.58, 0.07, 0.0), Vector3(0.0, 0.0, sx * 8.0)))
		ev.wings.append(_limb(ev, Vector3(sx * 0.2, 0.14, 0.05), wk))
	ev.gait = "fly"
	ev.is_flyer = true
	ev.height = 0.9
	ev.aim_height = 0.0
	ev.setup_bar(0.8, 0.85)


# ------------------------------------------------------------------ léčitel
static func _healer(ev: EnemyVisual) -> void:
	var robe: Color = Color(0.80, 0.93, 0.84)
	var sash: Color = Color(0.25, 0.65, 0.40)
	var skin: Color = Color(0.50, 0.74, 0.34)
	var glow: Color = Color(0.40, 1.0, 0.55)
	var kb: MeshKit = MeshKit.new(61, 0.05)
	kb.cyl(0.34, 0.17, 0.85, 8, robe, _x(Vector3(0.0, 0.18, 0.0)), 0.0, false, true)
	kb.cyl(0.355, 0.33, 0.12, 8, sash, _x(Vector3(0.0, 0.2, 0.0)), 0.0, false, true)
	kb.cyl(0.19, 0.17, 0.1, 8, sash, _x(Vector3(0.0, 0.66, 0.0)), 0.0, false, true)
	kb.sphere(0.19, skin, _x(Vector3(0.0, 1.14, 0.02)), 0.0, 8, 6)
	kb.cone(0.27, 0.34, 8, robe, _x(Vector3(0.0, 1.2, -0.03), Vector3(-10.0, 0.0, 0.0)), 0.0, false)            # kapuce
	kb.sphere(0.04, Color(0.4, 1.0, 0.5), _x(Vector3(0.07, 1.14, 0.17)), 2.0, 5, 3)
	kb.sphere(0.04, Color(0.4, 1.0, 0.5), _x(Vector3(-0.07, 1.14, 0.17)), 2.0, 5, 3)
	kb.cone(0.035, 0.09, 5, skin.darkened(0.12), _x(Vector3(0.0, 1.09, 0.2), Vector3(90.0, 0.0, 0.0)), 0.0, false)
	# svítící halo nad hlavou (znamení léčitele)
	kb.torus(0.26, 0.028, glow, _x(Vector3(0.0, 1.62, 0.0)), 2.4, 18, 5)
	kb.box(Vector3(0.07, 0.2, 0.025), glow, _x(Vector3(0.0, 1.62, 0.0)), 2.2)
	kb.box(Vector3(0.2, 0.07, 0.025), glow, _x(Vector3(0.0, 1.62, 0.0)), 2.2)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(62 + i, 0.05)
		lk.box(Vector3(0.12, 0.12, 0.2), Color(0.4, 0.3, 0.2), _x(Vector3(0.0, -0.05, 0.05)))
		ev.legs.append(_limb(ev, Vector3(sx * 0.1, 0.12, 0.0), lk))
	for j in range(2):
		var sx2: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(64 + j, 0.05)
		ak.box(Vector3(0.09, 0.3, 0.09), robe.darkened(0.08), _x(Vector3(0.0, -0.15, 0.0)))
		ak.sphere(0.055, skin, _x(Vector3(0.0, -0.31, 0.0)), 0.0, 5, 3)
		if j == 1:
			# hůl se svítícím kamenem
			ak.cyl(0.035, 0.04, 1.25, 6, Color(0.5, 0.36, 0.2), _x(Vector3(0.0, -0.42, 0.04)), 0.0, false, true)
			ak.sphere(0.12, glow, _x(Vector3(0.0, 0.88, 0.04)), 2.6, 7, 5)
			ak.cone(0.05, 0.14, 5, Color(0.5, 0.36, 0.2), _x(Vector3(0.05, 0.84, 0.04), Vector3(0.0, 0.0, -90.0)), 0.0, false)
			ak.cone(0.05, 0.14, 5, Color(0.5, 0.36, 0.2), _x(Vector3(-0.05, 0.84, 0.04), Vector3(0.0, 0.0, 90.0)), 0.0, false)
		ev.arms.append(_limb(ev, Vector3(sx2 * 0.22, 0.86, 0.0), ak))
	ev.gait = "biped"
	ev.stride_freq = 3.2
	ev.swing = 0.45
	ev.bob = 0.03
	ev.height = 1.75
	ev.aim_height = 0.75
	ev.setup_bar(0.75, 1.95)


# ------------------------------------------------------------------ štítonoš
static func _shield(ev: EnemyVisual) -> void:
	var steel: Color = Color(0.50, 0.62, 0.84)
	var dark: Color = Color(0.26, 0.32, 0.46)
	var skin: Color = Color(0.46, 0.70, 0.32)
	var gold: Color = Color(1.0, 0.82, 0.3)
	var kb: MeshKit = MeshKit.new(71, 0.05)
	kb.box(Vector3(0.5, 0.52, 0.34), steel, _x(Vector3(0.0, 0.88, 0.0)))
	kb.box(Vector3(0.52, 0.12, 0.36), dark, _x(Vector3(0.0, 0.62, 0.0)))
	kb.sphere(0.2, skin, _x(Vector3(0.0, 1.32, 0.02)), 0.0, 8, 6)
	kb.sphere(0.235, steel, _x(Vector3(0.0, 1.38, 0.0), Vector3.ZERO, Vector3(1.0, 0.9, 1.0)), 0.0, 8, 5)      # přilba
	kb.box(Vector3(0.06, 0.2, 0.34), gold, _x(Vector3(0.0, 1.55, 0.0)), 0.5)                                    # hřeben
	kb.box(Vector3(0.3, 0.07, 0.04), Color(0.05, 0.05, 0.08), _x(Vector3(0.0, 1.31, 0.2)))                       # průzor
	kb.sphere(0.04, Color(1.0, 0.9, 0.2), _x(Vector3(0.07, 1.31, 0.21)), 1.8, 5, 3)
	kb.sphere(0.04, Color(1.0, 0.9, 0.2), _x(Vector3(-0.07, 1.31, 0.21)), 1.8, 5, 3)
	for sx in [-1.0, 1.0]:
		kb.sphere(0.17, dark, _x(Vector3(float(sx) * 0.33, 1.08, 0.0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), 0.0, 7, 4)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx2: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(72 + i, 0.05)
		lk.box(Vector3(0.14, 0.4, 0.15), dark, _x(Vector3(0.0, -0.2, 0.0)))
		lk.box(Vector3(0.16, 0.07, 0.26), Color(0.2, 0.2, 0.26), _x(Vector3(0.0, -0.38, 0.05)))
		ev.legs.append(_limb(ev, Vector3(sx2 * 0.12, 0.42, 0.0), lk))
	for j in range(2):
		var sx3: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(74 + j, 0.05)
		ak.box(Vector3(0.1, 0.34, 0.1), skin, _x(Vector3(0.0, -0.17, 0.0)))
		ak.sphere(0.065, skin, _x(Vector3(0.0, -0.35, 0.0)), 0.0, 5, 3)
		if j == 0:
			# velký kulatý štít vpředu (osa válce míří dopředu)
			ak.cyl(0.46, 0.44, 0.08, 12, steel, _x(Vector3(-0.08, -0.28, 0.3), Vector3(90.0, 0.0, 0.0)), 0.0, false, true)
			ak.cyl(0.32, 0.30, 0.06, 12, dark, _x(Vector3(-0.08, -0.28, 0.36), Vector3(90.0, 0.0, 0.0)), 0.0, false, true)
			ak.sphere(0.1, gold, _x(Vector3(-0.08, -0.28, 0.42)), 0.8, 6, 4)
		else:
			ak.cyl(0.03, 0.03, 0.9, 6, Color(0.5, 0.36, 0.2), _x(Vector3(0.0, -0.3, 0.05), Vector3(75.0, 0.0, 0.0)), 0.0, false, true)
			ak.cone(0.06, 0.2, 5, Color(0.8, 0.82, 0.9), _x(Vector3(0.0, -0.22, 0.88), Vector3(75.0, 0.0, 0.0)), 0.2, false)
		ev.arms.append(_limb(ev, Vector3(sx3 * 0.34, 1.1, 0.0), ak))
	ev.gait = "biped"
	ev.stride_freq = 3.2
	ev.swing = 0.5
	ev.bob = 0.035
	ev.height = 1.7
	ev.aim_height = 0.9
	ev.shield_size = 2.0
	ev.setup_bar(0.8, 1.95)


# ------------------------------------------------------------------ slizák (a malý slizánek: sc < 1)
static func _slime(ev: EnemyVisual, sc: float) -> void:
	var green: Color = Color(0.32, 0.82, 0.42)
	var light: Color = Color(0.55, 0.96, 0.62)
	var kb: MeshKit = MeshKit.new(81, 0.04)
	kb.blob(0.52 * sc, green, _x(Vector3(0.0, 0.42 * sc, 0.0), Vector3.ZERO, Vector3(1.15, 0.85, 1.15)), 0.5, 9, 6, 0.06, 811)
	kb.blob(0.3 * sc, light, _x(Vector3(-0.1 * sc, 0.62 * sc, -0.08 * sc), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), 0.7, 7, 5, 0.06, 812)
	kb.blob(0.18 * sc, green.lightened(0.1), _x(Vector3(0.28 * sc, 0.22 * sc, -0.18 * sc)), 0.4, 6, 4, 0.08, 813)
	# oči a pusa
	for sx in [-1.0, 1.0]:
		kb.sphere(0.12 * sc, Color(1.0, 1.0, 1.0), _x(Vector3(float(sx) * 0.18 * sc, 0.55 * sc, 0.4 * sc)), 0.3, 6, 4)
		kb.sphere(0.06 * sc, Color(0.05, 0.08, 0.05), _x(Vector3(float(sx) * 0.18 * sc, 0.55 * sc, 0.5 * sc)), 0.0, 5, 3)
	kb.box(Vector3(0.2 * sc, 0.04 * sc, 0.03 * sc), Color(0.1, 0.3, 0.12), _x(Vector3(0.0, 0.36 * sc, 0.52 * sc)))
	_body_mesh(ev, kb)
	ev.gait = "blob"
	ev.stride_freq = 3.4 if sc >= 1.0 else 4.6
	ev.bob = 0.2 * sc
	ev.height = 0.95 * sc
	ev.aim_height = 0.4 * sc
	ev.setup_bar(0.7 * maxf(sc, 0.8), 1.15 * maxf(sc, 0.75))


# ------------------------------------------------------------------ boss: kamenný obr
static func _boss(ev: EnemyVisual) -> void:
	var rock: Color = Color(0.54, 0.49, 0.45)
	var rock_d: Color = Color(0.42, 0.39, 0.37)
	var moss: Color = Color(0.36, 0.52, 0.26)
	var ember: Color = Color(1.0, 0.5, 0.12)
	var kb: MeshKit = MeshKit.new(51, 0.07)
	kb.blob(0.95, rock, _x(Vector3(0.0, 2.0, 0.0), Vector3.ZERO, Vector3(1.1, 1.0, 0.85)), 0.0, 8, 6, 0.14, 501)
	kb.blob(0.72, rock_d, _x(Vector3(0.0, 1.35, 0.0), Vector3.ZERO, Vector3(1.0, 0.9, 0.9)), 0.0, 7, 5, 0.14, 502)
	for sx in [-1.0, 1.0]:
		kb.blob(0.52, rock, _x(Vector3(float(sx) * 1.0, 2.55, 0.0)), 0.0, 7, 5, 0.16, 503)
		kb.blob(0.3, moss, _x(Vector3(float(sx) * 1.0, 2.95, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0)), 0.0, 6, 4, 0.2, 504)
	kb.blob(0.46, rock, _x(Vector3(0.0, 3.0, 0.2), Vector3.ZERO, Vector3(1.0, 0.9, 1.0)), 0.0, 7, 5, 0.1, 505)
	kb.box(Vector3(0.52, 0.18, 0.36), rock_d, _x(Vector3(0.0, 2.72, 0.38)))
	kb.box(Vector3(0.72, 0.12, 0.22), rock_d, _x(Vector3(0.0, 3.2, 0.46)))
	kb.sphere(0.1, ember, _x(Vector3(0.17, 3.04, 0.56)), 3.0, 6, 4)
	kb.sphere(0.1, ember, _x(Vector3(-0.17, 3.04, 0.56)), 3.0, 6, 4)
	for q in range(4):
		var a: float = (float(q) - 1.5) * 0.45
		kb.cone(0.16, 0.8 - 0.1 * absf(float(q) - 1.5), 5, Color(0.4, 0.75, 1.0), _x(Vector3(sin(a) * 0.7, 2.7, -0.8), Vector3(-25.0, 0.0, -rad_to_deg(a) * 0.8)), 1.8, false)
	for c in range(3):
		kb.box(Vector3(0.05, 0.4, 0.03), ember, _x(Vector3(-0.3 + 0.3 * float(c), 2.0, 0.84), Vector3(0.0, 0.0, 20.0 - 20.0 * float(c))), 2.0)
	kb.blob(0.34, moss, _x(Vector3(0.4, 2.3, -0.6), Vector3.ZERO, Vector3(1.0, 0.6, 1.0)), 0.0, 6, 4, 0.2, 506)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx2: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(52 + i, 0.06)
		lk.box(Vector3(0.52, 1.1, 0.56), rock_d, _x(Vector3(0.0, -0.55, 0.0)))
		lk.blob(0.36, rock, _x(Vector3(0.0, -0.1, 0.0)), 0.0, 6, 4, 0.14, 510 + i)
		lk.box(Vector3(0.64, 0.26, 0.86), rock, _x(Vector3(0.0, -1.1, 0.1)))
		ev.legs.append(_limb(ev, Vector3(sx2 * 0.5, 1.15, 0.0), lk))
	for j in range(2):
		var sx3: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(54 + j, 0.06)
		ak.box(Vector3(0.46, 1.5, 0.46), rock, _x(Vector3(0.0, -0.75, 0.0)))
		ak.blob(0.5, rock_d, _x(Vector3(0.0, -1.65, 0.1)), 0.0, 7, 5, 0.16, 520 + j)
		ak.blob(0.2, moss, _x(Vector3(0.1, -0.1, 0.1), Vector3.ZERO, Vector3(1.0, 0.5, 1.0)), 0.0, 5, 3, 0.2, 524 + j)
		ev.arms.append(_limb(ev, Vector3(sx3 * 1.2, 2.55, 0.0), ak))
	ev.gait = "heavy"
	ev.stride_freq = 2.4
	ev.swing = 0.38
	ev.bob = 0.1
	ev.height = 3.6
	ev.aim_height = 1.8
	ev.setup_bar(1.7, 4.0)
