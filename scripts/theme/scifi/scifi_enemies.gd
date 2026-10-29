class_name SciFiEnemies
extends RefCounted
## Modely nepřátel vesmírné stanice: pěšák-bot, robopes, těžký mech, dron-manta (létající), opravář, štítový droid,
## nanorój (a nanočástice) a titán (boss). +Z = směr pohybu. Končetiny jsou samostatné pivoty => animace chůze/mávání.

const STEEL: Color = Color(0.68, 0.73, 0.82)
const STEEL_D: Color = Color(0.34, 0.38, 0.48)
const STEEL_L: Color = Color(0.86, 0.90, 0.96)
const ORANGE: Color = Color(1.0, 0.58, 0.20)
const RED: Color = Color(1.0, 0.22, 0.25)
const CYAN: Color = Color(0.20, 0.92, 1.0)
const GREEN: Color = Color(0.40, 1.0, 0.50)
const AMBER: Color = Color(1.0, 0.72, 0.18)


static func _x(pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return MeshKit.xf(pos, rot, scl)


static func build(type: String) -> EnemyVisual:
	var ev: EnemyVisual = EnemyVisual.new()
	ev.name = "Enemy_" + type
	ev.mat = Gfx.model_mat(0.5, 0.1, true)
	ev.body = Node3D.new()
	ev.body.name = "Body"
	ev.add_child(ev.body)
	match type:
		"goblin":
			_grunt(ev)
		"wolf":
			_hound(ev)
		"golem":
			_mech(ev)
		"drake":
			_manta(ev)
		"healer":
			_medic(ev)
		"shield":
			_shielder(ev)
		"slime":
			_nano(ev, 1.0)
		"slimeling":
			_nano(ev, 0.55)
		_:
			_titan(ev)
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


# ------------------------------------------------------------------ pěšák-bot (skřet)
static func _grunt(ev: EnemyVisual) -> void:
	var kb: MeshKit = MeshKit.new(1, 0.05)
	kb.box(Vector3(0.36, 0.42, 0.26), ORANGE, _x(Vector3(0.0, 0.52, 0.0)))
	kb.box(Vector3(0.4, 0.08, 0.3), STEEL_D, _x(Vector3(0.0, 0.3, 0.0)))
	kb.box(Vector3(0.24, 0.2, 0.06), STEEL_D, _x(Vector3(0.0, 0.58, 0.15)))
	kb.box(Vector3(0.1, 0.05, 0.02), CYAN, _x(Vector3(0.0, 0.6, 0.19)), 1.8)
	# hlava: kopule s visorem
	kb.sphere(0.19, STEEL_L, _x(Vector3(0.0, 0.93, 0.0), Vector3.ZERO, Vector3(1.0, 0.9, 1.0)), 0.0, 8, 6)
	kb.box(Vector3(0.26, 0.08, 0.1), Color(0.05, 0.06, 0.1), _x(Vector3(0.0, 0.94, 0.14)))
	kb.box(Vector3(0.2, 0.04, 0.04), RED, _x(Vector3(0.0, 0.94, 0.19)), 2.4)
	kb.cyl(0.015, 0.015, 0.22, 5, STEEL, _x(Vector3(0.1, 1.03, -0.02), Vector3(0.0, 0.0, -12.0)), 0.0, false, false)
	kb.sphere(0.03, AMBER, _x(Vector3(0.13, 1.25, -0.02)), 2.0, 5, 3)
	# kapsle na zádech
	kb.cyl(0.07, 0.07, 0.3, 6, STEEL_D, _x(Vector3(0.0, 0.4, -0.2)), 0.0, false, true)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(2 + i, 0.05)
		lk.box(Vector3(0.1, 0.28, 0.1), STEEL_D, _x(Vector3(0.0, -0.14, 0.0)))
		lk.sphere(0.06, STEEL_L, _x(Vector3(0.0, -0.02, 0.0)), 0.0, 5, 3)
		lk.box(Vector3(0.13, 0.06, 0.22), ORANGE.darkened(0.3), _x(Vector3(0.0, -0.28, 0.05)))
		ev.legs.append(_limb(ev, Vector3(sx * 0.1, 0.3, 0.0), lk))
	for j in range(2):
		var sx2: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(4 + j, 0.05)
		ak.box(Vector3(0.08, 0.3, 0.08), STEEL, _x(Vector3(0.0, -0.15, 0.0)))
		ak.sphere(0.06, STEEL_L, _x(Vector3(0.0, -0.31, 0.0)), 0.0, 5, 3)
		if j == 1:
			# paže s blasterem
			ak.box(Vector3(0.09, 0.09, 0.34), STEEL_D, _x(Vector3(0.0, -0.3, 0.2)))
			ak.cyl(0.03, 0.03, 0.18, 5, STEEL_L, _x(Vector3(0.0, -0.3, 0.34), Vector3(90.0, 0.0, 0.0)), 0.0, false, true)
			ak.sphere(0.035, RED, _x(Vector3(0.0, -0.3, 0.52)), 2.2, 5, 3)
		else:
			ak.box(Vector3(0.12, 0.1, 0.08), ORANGE, _x(Vector3(0.0, -0.33, 0.03)))
		ev.arms.append(_limb(ev, Vector3(sx2 * 0.22, 0.66, 0.0), ak))
	ev.gait = "biped"
	ev.stride_freq = 3.6
	ev.swing = 0.7
	ev.bob = 0.04
	ev.height = 1.2
	ev.aim_height = 0.6
	ev.setup_bar(0.75, 1.5)


# ------------------------------------------------------------------ robopes (vlk)
static func _hound(ev: EnemyVisual) -> void:
	var kb: MeshKit = MeshKit.new(11, 0.05)
	kb.box(Vector3(0.34, 0.3, 0.8), STEEL_D, _x(Vector3(0.0, 0.52, 0.0)))
	kb.box(Vector3(0.36, 0.1, 0.62), STEEL, _x(Vector3(0.0, 0.7, -0.02)))
	kb.box(Vector3(0.05, 0.04, 0.56), CYAN, _x(Vector3(0.0, 0.76, -0.02)), 1.6)
	kb.box(Vector3(0.3, 0.1, 0.6), STEEL_L, _x(Vector3(0.0, 0.36, 0.0)))
	# krk a hlava: klínová přilba
	kb.box(Vector3(0.18, 0.2, 0.3), STEEL, _x(Vector3(0.0, 0.66, 0.42), Vector3(-25.0, 0.0, 0.0)))
	kb.box(Vector3(0.26, 0.22, 0.34), STEEL_L, _x(Vector3(0.0, 0.74, 0.62)))
	kb.box(Vector3(0.18, 0.1, 0.28), STEEL_D, _x(Vector3(0.0, 0.68, 0.82)))
	kb.box(Vector3(0.24, 0.05, 0.08), RED, _x(Vector3(0.0, 0.78, 0.76)), 2.4)
	kb.cone(0.04, 0.2, 4, STEEL_L, _x(Vector3(0.1, 0.93, 0.52)), 0.0, false)
	kb.cone(0.04, 0.2, 4, STEEL_L, _x(Vector3(-0.1, 0.93, 0.52)), 0.0, false)
	for q in range(3):
		kb.box(Vector3(0.1, 0.05, 0.12), STEEL_L, _x(Vector3(0.0, 0.8, 0.12 - 0.2 * float(q)), Vector3(-10.0, 0.0, 0.0)))
	_body_mesh(ev, kb)
	var pos: Array = [Vector3(-0.14, 0.42, 0.28), Vector3(0.14, 0.42, 0.28), Vector3(-0.14, 0.42, -0.28), Vector3(0.14, 0.42, -0.28)]
	for i in range(4):
		var lk: MeshKit = MeshKit.new(12 + i, 0.04)
		lk.box(Vector3(0.07, 0.24, 0.09), STEEL_D, _x(Vector3(0.0, -0.12, 0.0), Vector3(-18.0, 0.0, 0.0)))
		lk.sphere(0.055, STEEL_L, _x(Vector3(0.0, -0.22, -0.04)), 0.0, 5, 3)
		lk.box(Vector3(0.06, 0.22, 0.07), STEEL, _x(Vector3(0.0, -0.33, 0.0), Vector3(14.0, 0.0, 0.0)))
		lk.box(Vector3(0.09, 0.04, 0.14), CYAN, _x(Vector3(0.0, -0.43, 0.04)), 1.4)
		ev.legs.append(_limb(ev, pos[i], lk))
	var tk: MeshKit = MeshKit.new(20, 0.04)
	tk.cyl(0.015, 0.012, 0.5, 5, STEEL_L, _x(Vector3(0.0, 0.0, -0.05), Vector3(-65.0, 0.0, 0.0)), 0.0, false, false)
	tk.sphere(0.045, CYAN, _x(Vector3(0.0, 0.2, -0.5)), 2.0, 5, 3)
	ev.tail = _limb(ev, Vector3(0.0, 0.62, -0.4), tk)
	ev.gait = "quad"
	ev.stride_freq = 2.7
	ev.swing = 0.8
	ev.bob = 0.035
	ev.height = 1.0
	ev.aim_height = 0.55
	ev.setup_bar(0.75, 1.25)


# ------------------------------------------------------------------ těžký mech (obrněnec)
static func _mech(ev: EnemyVisual) -> void:
	var kb: MeshKit = MeshKit.new(31, 0.04)
	kb.box(Vector3(0.78, 0.7, 0.54), STEEL, _x(Vector3(0.0, 1.16, 0.0)))
	kb.box(Vector3(0.62, 0.5, 0.14), STEEL_L, _x(Vector3(0.0, 1.22, 0.3)))
	kb.box(Vector3(0.74, 0.12, 0.56), STEEL_D, _x(Vector3(0.0, 0.82, 0.0)))
	# reaktor na hrudi
	kb.cyl(0.12, 0.12, 0.06, 8, ORANGE, _x(Vector3(0.0, 1.15, 0.34), Vector3(90.0, 0.0, 0.0)), 1.9, false, true)
	for sx in [-1.0, 1.0]:
		kb.box(Vector3(0.38, 0.3, 0.42), STEEL_L, _x(Vector3(float(sx) * 0.52, 1.5, 0.0), Vector3(0.0, 0.0, float(sx) * -10.0)))
		kb.cone(0.07, 0.22, 5, STEEL_D, _x(Vector3(float(sx) * 0.54, 1.72, 0.0)), 0.0, false)
	# kabina: skleněná kopule
	kb.box(Vector3(0.36, 0.3, 0.36), STEEL_D, _x(Vector3(0.0, 1.72, 0.04)))
	kb.box(Vector3(0.3, 0.1, 0.04), CYAN, _x(Vector3(0.0, 1.76, 0.23)), 2.0)
	kb.box(Vector3(0.05, 0.22, 0.4), RED, _x(Vector3(0.0, 1.98, 0.0)), 0.6)
	kb.cyl(0.06, 0.06, 0.4, 6, STEEL_D, _x(Vector3(-0.2, 1.44, -0.34)), 0.0, false, true)
	kb.cyl(0.06, 0.06, 0.4, 6, STEEL_D, _x(Vector3(0.2, 1.44, -0.34)), 0.0, false, true)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx2: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(32 + i, 0.04)
		lk.box(Vector3(0.26, 0.6, 0.28), STEEL, _x(Vector3(0.0, -0.3, 0.0)))
		lk.sphere(0.16, STEEL_D, _x(Vector3(0.0, -0.3, 0.12)), 0.0, 6, 4)
		lk.box(Vector3(0.3, 0.16, 0.46), STEEL_D, _x(Vector3(0.0, -0.62, 0.08)))
		lk.box(Vector3(0.05, 0.4, 0.06), ORANGE, _x(Vector3(float(sx2) * 0.14, -0.3, 0.12)), 1.0)
		ev.legs.append(_limb(ev, Vector3(sx2 * 0.2, 0.8, 0.0), lk))
	for j in range(2):
		var sx3: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(34 + j, 0.04)
		ak.box(Vector3(0.22, 0.56, 0.22), STEEL, _x(Vector3(0.0, -0.28, 0.0)))
		ak.sphere(0.13, STEEL_D, _x(Vector3(0.0, -0.6, 0.0)), 0.0, 6, 4)
		if j == 0:
			# energetický štít na paži
			ak.box(Vector3(0.08, 0.84, 0.62), STEEL_D, _x(Vector3(-0.2, -0.4, 0.15)))
			ak.box(Vector3(0.04, 0.64, 0.46), CYAN, _x(Vector3(-0.26, -0.4, 0.15)), 1.4)
		else:
			# kanón
			ak.box(Vector3(0.2, 0.2, 0.7), STEEL_D, _x(Vector3(0.0, -0.58, 0.34)))
			ak.cyl(0.07, 0.06, 0.5, 8, STEEL_L, _x(Vector3(0.0, -0.58, 0.82), Vector3(90.0, 0.0, 0.0)), 0.0, false, true)
			ak.sphere(0.06, RED, _x(Vector3(0.0, -0.58, 1.07)), 2.4, 5, 3)
		ev.arms.append(_limb(ev, Vector3(sx3 * 0.54, 1.5, 0.0), ak))
	ev.gait = "heavy"
	ev.stride_freq = 3.1
	ev.swing = 0.5
	ev.bob = 0.06
	ev.height = 2.1
	ev.aim_height = 1.1
	ev.setup_bar(0.95, 2.45)


# ------------------------------------------------------------------ dron-manta (létající)
static func _manta(ev: EnemyVisual) -> void:
	var kb: MeshKit = MeshKit.new(41, 0.04)
	kb.sphere(0.3, STEEL, _x(Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.55, 1.5)), 0.0, 9, 6)
	kb.sphere(0.24, STEEL_D, _x(Vector3(0.0, -0.1, 0.0), Vector3.ZERO, Vector3(0.7, 0.4, 1.2)), 0.0, 8, 5)
	kb.sphere(0.17, STEEL_L, _x(Vector3(0.0, 0.08, 0.48), Vector3.ZERO, Vector3(1.0, 0.8, 1.1)), 0.0, 8, 5)
	kb.box(Vector3(0.22, 0.06, 0.06), RED, _x(Vector3(0.0, 0.1, 0.62)), 2.6)
	kb.sphere(0.05, CYAN, _x(Vector3(0.0, -0.18, 0.1)), 2.0, 5, 3)
	kb.box(Vector3(0.05, 0.14, 0.4), STEEL_L, _x(Vector3(0.0, 0.2, -0.1)))
	kb.cyl(0.015, 0.015, 0.3, 5, STEEL_L, _x(Vector3(0.1, 0.2, 0.3), Vector3(-20.0, 0.0, -10.0)), 0.0, false, false)
	_body_mesh(ev, kb)
	# ocas: stabilizační ploutev s tryskou
	var tk: MeshKit = MeshKit.new(42, 0.04)
	tk.box(Vector3(0.08, 0.06, 0.5), STEEL_D, _x(Vector3(0.0, 0.0, -0.25)))
	tk.cone(0.08, 0.2, 5, ORANGE, _x(Vector3(0.0, 0.0, -0.58), Vector3(-90.0, 0.0, 0.0)), 2.0, false)
	ev.tail = _limb(ev, Vector3(0.0, 0.0, -0.4), tk)
	# křídla z tvrdého světla (mávají jako u manty)
	for i in range(2):
		var sx: float = -1.0 if i == 0 else 1.0
		var wk: MeshKit = MeshKit.new(43 + i, 0.03)
		var mem: Color = Color(0.15, 0.55, 0.95)
		wk.quad(Vector3(0.0, 0.0, 0.22), Vector3(0.0, 0.0, -0.32), Vector3(sx * 0.95, 0.08, -0.58), Vector3(sx * 1.15, 0.16, 0.0), mem, Transform3D.IDENTITY, 0.9, true)
		wk.tri(Vector3(sx * 1.15, 0.16, 0.0), Vector3(sx * 0.95, 0.08, -0.58), Vector3(sx * 1.3, 0.05, -0.38), CYAN, Transform3D.IDENTITY, 1.4, true)
		wk.box(Vector3(1.2, 0.045, 0.05), STEEL_L, _x(Vector3(sx * 0.58, 0.07, 0.0), Vector3(0.0, 0.0, sx * 8.0)))
		ev.wings.append(_limb(ev, Vector3(sx * 0.2, 0.1, 0.05), wk))
	ev.gait = "fly"
	ev.is_flyer = true
	ev.height = 0.9
	ev.aim_height = 0.0
	ev.setup_bar(0.8, 0.85)


# ------------------------------------------------------------------ opravář (léčitel)
static func _medic(ev: EnemyVisual) -> void:
	var white: Color = Color(0.86, 0.92, 0.94)
	var kb: MeshKit = MeshKit.new(61, 0.04)
	kb.cyl(0.26, 0.16, 0.8, 8, white, _x(Vector3(0.0, 0.22, 0.0)), 0.0, false, true)
	kb.box(Vector3(0.1, 0.3, 0.04), GREEN, _x(Vector3(0.0, 0.62, 0.2)), 2.0)
	kb.box(Vector3(0.3, 0.1, 0.04), GREEN, _x(Vector3(0.0, 0.62, 0.2)), 2.0)
	kb.cyl(0.28, 0.26, 0.1, 8, STEEL_D, _x(Vector3(0.0, 0.26, 0.0)), 0.0, false, true)
	kb.sphere(0.19, white, _x(Vector3(0.0, 1.14, 0.02)), 0.0, 8, 6)
	kb.box(Vector3(0.24, 0.1, 0.1), Color(0.05, 0.12, 0.08), _x(Vector3(0.0, 1.14, 0.15)))
	kb.box(Vector3(0.2, 0.04, 0.04), GREEN, _x(Vector3(0.0, 1.14, 0.2)), 2.4)
	# zdravotní halo nad hlavou a zdroj na zádech
	kb.torus(0.26, 0.028, GREEN, _x(Vector3(0.0, 1.62, 0.0)), 2.4, 18, 5)
	kb.box(Vector3(0.07, 0.2, 0.025), GREEN, _x(Vector3(0.0, 1.62, 0.0)), 2.2)
	kb.box(Vector3(0.2, 0.07, 0.025), GREEN, _x(Vector3(0.0, 1.62, 0.0)), 2.2)
	kb.cyl(0.09, 0.09, 0.4, 6, STEEL_D, _x(Vector3(0.0, 0.5, -0.24)), 0.0, false, true)
	kb.sphere(0.09, GREEN, _x(Vector3(0.0, 0.95, -0.24)), 2.2, 6, 4)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(62 + i, 0.04)
		lk.box(Vector3(0.12, 0.14, 0.22), STEEL_D, _x(Vector3(0.0, -0.05, 0.05)))
		ev.legs.append(_limb(ev, Vector3(sx * 0.1, 0.12, 0.0), lk))
	for j in range(2):
		var sx2: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(64 + j, 0.04)
		ak.box(Vector3(0.08, 0.3, 0.08), white, _x(Vector3(0.0, -0.15, 0.0)))
		ak.sphere(0.055, STEEL_L, _x(Vector3(0.0, -0.31, 0.0)), 0.0, 5, 3)
		if j == 1:
			# opravná tyč se zářící špičkou
			ak.cyl(0.03, 0.035, 1.1, 6, STEEL, _x(Vector3(0.0, -0.4, 0.05)), 0.0, false, true)
			ak.sphere(0.11, GREEN, _x(Vector3(0.0, 0.76, 0.05)), 2.6, 7, 5)
			ak.torus(0.12, 0.02, STEEL_L, _x(Vector3(0.0, 0.76, 0.05), Vector3(90.0, 0.0, 0.0)), 0.0, 10, 3)
		ev.arms.append(_limb(ev, Vector3(sx2 * 0.22, 0.86, 0.0), ak))
	ev.gait = "biped"
	ev.stride_freq = 3.2
	ev.swing = 0.45
	ev.bob = 0.03
	ev.height = 1.75
	ev.aim_height = 0.75
	ev.setup_bar(0.75, 1.95)


# ------------------------------------------------------------------ štítový droid (štítonoš)
static func _shielder(ev: EnemyVisual) -> void:
	var blue: Color = Color(0.36, 0.52, 0.92)
	var kb: MeshKit = MeshKit.new(71, 0.04)
	kb.box(Vector3(0.5, 0.52, 0.34), blue, _x(Vector3(0.0, 0.88, 0.0)))
	kb.box(Vector3(0.52, 0.12, 0.36), STEEL_D, _x(Vector3(0.0, 0.62, 0.0)))
	kb.box(Vector3(0.3, 0.14, 0.04), STEEL_D, _x(Vector3(0.0, 0.92, 0.19)))
	kb.box(Vector3(0.18, 0.04, 0.02), CYAN, _x(Vector3(0.0, 0.92, 0.22)), 1.8)
	kb.sphere(0.2, STEEL_L, _x(Vector3(0.0, 1.34, 0.0), Vector3.ZERO, Vector3(1.0, 0.9, 1.0)), 0.0, 8, 6)
	kb.box(Vector3(0.3, 0.08, 0.06), Color(0.04, 0.06, 0.14), _x(Vector3(0.0, 1.34, 0.17)))
	kb.box(Vector3(0.24, 0.04, 0.03), CYAN, _x(Vector3(0.0, 1.34, 0.2)), 2.4)
	kb.box(Vector3(0.06, 0.18, 0.3), AMBER, _x(Vector3(0.0, 1.55, 0.0)), 0.6)
	for sx in [-1.0, 1.0]:
		kb.sphere(0.17, STEEL_D, _x(Vector3(float(sx) * 0.33, 1.08, 0.0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), 0.0, 7, 4)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx2: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(72 + i, 0.04)
		lk.box(Vector3(0.14, 0.4, 0.15), STEEL_D, _x(Vector3(0.0, -0.2, 0.0)))
		lk.box(Vector3(0.16, 0.07, 0.26), STEEL, _x(Vector3(0.0, -0.38, 0.05)))
		ev.legs.append(_limb(ev, Vector3(sx2 * 0.12, 0.42, 0.0), lk))
	for j in range(2):
		var sx3: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(74 + j, 0.04)
		ak.box(Vector3(0.1, 0.34, 0.1), STEEL, _x(Vector3(0.0, -0.17, 0.0)))
		ak.sphere(0.065, STEEL_L, _x(Vector3(0.0, -0.35, 0.0)), 0.0, 5, 3)
		if j == 0:
			# kulatý štítový generátor vpředu
			ak.cyl(0.44, 0.42, 0.08, 12, STEEL_D, _x(Vector3(-0.08, -0.28, 0.3), Vector3(90.0, 0.0, 0.0)), 0.0, false, true)
			ak.cyl(0.32, 0.30, 0.06, 12, CYAN, _x(Vector3(-0.08, -0.28, 0.36), Vector3(90.0, 0.0, 0.0)), 1.1, false, true)
			ak.sphere(0.1, Color(0.9, 1.0, 1.0), _x(Vector3(-0.08, -0.28, 0.42)), 2.2, 6, 4)
		else:
			ak.cyl(0.03, 0.03, 0.85, 6, STEEL_D, _x(Vector3(0.0, -0.3, 0.05), Vector3(75.0, 0.0, 0.0)), 0.0, false, true)
			ak.cone(0.05, 0.2, 5, CYAN, _x(Vector3(0.0, -0.22, 0.86), Vector3(75.0, 0.0, 0.0)), 1.8, false)
		ev.arms.append(_limb(ev, Vector3(sx3 * 0.34, 1.1, 0.0), ak))
	ev.gait = "biped"
	ev.stride_freq = 3.2
	ev.swing = 0.5
	ev.bob = 0.035
	ev.height = 1.7
	ev.aim_height = 0.9
	ev.shield_size = 2.0
	ev.setup_bar(0.8, 1.95)


# ------------------------------------------------------------------ nanorój (slizák) a nanočástice (sc < 1)
static func _nano(ev: EnemyVisual, sc: float) -> void:
	var chrome: Color = Color(0.80, 0.90, 1.0)
	var kb: MeshKit = MeshKit.new(81, 0.03)
	kb.blob(0.52 * sc, chrome, _x(Vector3(0.0, 0.42 * sc, 0.0), Vector3.ZERO, Vector3(1.15, 0.85, 1.15)), 0.3, 9, 6, 0.06, 811)
	kb.blob(0.3 * sc, chrome.lightened(0.2), _x(Vector3(-0.1 * sc, 0.62 * sc, -0.08 * sc), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), 0.4, 7, 5, 0.06, 812)
	kb.blob(0.18 * sc, chrome, _x(Vector3(0.28 * sc, 0.22 * sc, -0.18 * sc)), 0.3, 6, 4, 0.08, 813)
	# svítící jádra v roji
	for q in range(6):
		var a: float = TAU * float(q) / 6.0
		kb.sphere(0.065 * sc, CYAN if q % 2 == 0 else Color(1.0, 0.3, 0.85), _x(Vector3(cos(a) * 0.4 * sc, (0.35 + 0.12 * float(q % 3)) * sc, sin(a) * 0.4 * sc)), 2.2, 5, 3)
	# oči
	for sx in [-1.0, 1.0]:
		kb.sphere(0.1 * sc, Color(1.0, 1.0, 1.0), _x(Vector3(float(sx) * 0.18 * sc, 0.55 * sc, 0.4 * sc)), 0.6, 6, 4)
		kb.sphere(0.05 * sc, RED, _x(Vector3(float(sx) * 0.18 * sc, 0.55 * sc, 0.49 * sc)), 2.4, 5, 3)
	_body_mesh(ev, kb)
	ev.gait = "blob"
	ev.stride_freq = 3.4 if sc >= 1.0 else 4.6
	ev.bob = 0.2 * sc
	ev.height = 0.95 * sc
	ev.aim_height = 0.4 * sc
	ev.setup_bar(0.7 * maxf(sc, 0.8), 1.15 * maxf(sc, 0.75))


# ------------------------------------------------------------------ titán (boss)
static func _titan(ev: EnemyVisual) -> void:
	var kb: MeshKit = MeshKit.new(51, 0.05)
	var plate: Color = Color(0.56, 0.60, 0.70)
	var plate_d: Color = Color(0.30, 0.33, 0.43)
	kb.box(Vector3(2.0, 1.5, 1.3), plate, _x(Vector3(0.0, 2.0, 0.0)))
	kb.box(Vector3(1.6, 0.9, 1.1), plate_d, _x(Vector3(0.0, 1.2, 0.0)))
	kb.box(Vector3(1.5, 1.0, 0.2), STEEL_L, _x(Vector3(0.0, 2.1, 0.7)))
	# reaktor v hrudi
	kb.cyl(0.34, 0.34, 0.16, 10, ORANGE, _x(Vector3(0.0, 2.05, 0.82), Vector3(90.0, 0.0, 0.0)), 2.4, false, true)
	kb.torus(0.38, 0.05, STEEL_L, _x(Vector3(0.0, 2.05, 0.86), Vector3(90.0, 0.0, 0.0)), 0.0, 14, 4)
	for sx in [-1.0, 1.0]:
		kb.box(Vector3(0.9, 0.8, 0.95), plate, _x(Vector3(float(sx) * 1.2, 2.6, 0.0), Vector3(0.0, 0.0, float(sx) * -12.0)))
		kb.box(Vector3(0.5, 0.18, 0.6), RED, _x(Vector3(float(sx) * 1.25, 3.1, 0.0)), 0.5)
		# ramenní kanóny
		kb.cyl(0.13, 0.11, 1.0, 8, STEEL_D, _x(Vector3(float(sx) * 1.1, 3.05, 0.2), Vector3(70.0, 0.0, 0.0)), 0.0, false, true)
		kb.sphere(0.1, RED, _x(Vector3(float(sx) * 1.1, 3.35, 0.65)), 2.4, 5, 3)
	# hlava: úzký "procesor" s visorem
	kb.box(Vector3(0.7, 0.55, 0.6), plate_d, _x(Vector3(0.0, 3.1, 0.15)))
	kb.box(Vector3(0.56, 0.12, 0.06), RED, _x(Vector3(0.0, 3.14, 0.47)), 2.8)
	kb.box(Vector3(0.1, 0.4, 0.1), STEEL_L, _x(Vector3(0.28, 3.55, 0.0)))
	kb.sphere(0.07, AMBER, _x(Vector3(0.28, 3.8, 0.0)), 2.2, 5, 3)
	# chladicí žebra a trysky na zádech
	for q in range(4):
		var a: float = (float(q) - 1.5) * 0.45
		kb.cone(0.16, 0.8 - 0.1 * absf(float(q) - 1.5), 5, CYAN, _x(Vector3(sin(a) * 0.7, 2.7, -0.8), Vector3(-25.0, 0.0, -rad_to_deg(a) * 0.8)), 1.8, false)
	for c in range(3):
		kb.box(Vector3(0.05, 0.4, 0.03), ORANGE, _x(Vector3(-0.3 + 0.3 * float(c), 1.3, 0.62), Vector3(0.0, 0.0, 20.0 - 20.0 * float(c))), 2.0)
	_body_mesh(ev, kb)
	for i in range(2):
		var sx2: float = -1.0 if i == 0 else 1.0
		var lk: MeshKit = MeshKit.new(52 + i, 0.05)
		lk.box(Vector3(0.56, 1.1, 0.6), plate_d, _x(Vector3(0.0, -0.55, 0.0)))
		lk.box(Vector3(0.4, 0.5, 0.4), plate, _x(Vector3(0.0, -0.1, 0.0)))
		lk.box(Vector3(0.7, 0.28, 0.95), plate, _x(Vector3(0.0, -1.1, 0.12)))
		lk.box(Vector3(0.06, 0.8, 0.06), CYAN, _x(Vector3(float(sx2) * 0.29, -0.55, 0.22)), 1.4)
		ev.legs.append(_limb(ev, Vector3(sx2 * 0.5, 1.15, 0.0), lk))
	for j in range(2):
		var sx3: float = -1.0 if j == 0 else 1.0
		var ak: MeshKit = MeshKit.new(54 + j, 0.05)
		ak.box(Vector3(0.5, 1.5, 0.5), plate, _x(Vector3(0.0, -0.75, 0.0)))
		ak.box(Vector3(0.7, 0.7, 0.8), plate_d, _x(Vector3(0.0, -1.7, 0.1)))
		for f in range(3):
			ak.box(Vector3(0.14, 0.1, 0.36), STEEL_L, _x(Vector3(-0.22 + 0.22 * float(f), -2.05, 0.4)))
		ak.box(Vector3(0.05, 1.1, 0.05), ORANGE, _x(Vector3(float(sx3) * 0.26, -0.8, 0.0)), 1.2)
		ev.arms.append(_limb(ev, Vector3(sx3 * 1.3, 2.55, 0.0), ak))
	ev.gait = "heavy"
	ev.stride_freq = 2.4
	ev.swing = 0.38
	ev.bob = 0.1
	ev.height = 3.6
	ev.aim_height = 1.8
	ev.setup_bar(1.7, 4.0)
