class_name SciFiProps
extends PropSet
## Kulisy vesmírné stanice: krystaly, antény, mimozemské stromy se svítícími plody, solární palmy, monolity, asteroidy,
## zářící tráva a energetická vlákna. Používají stejné klíče jako Props (ostrov v oblacích), takže je rozmisťuje stejný Decor.

static var _cache: Dictionary = {}

const CYAN: Color = Color(0.10, 0.90, 1.00)
const MAGENTA: Color = Color(1.00, 0.25, 0.80)
const VIOLET: Color = Color(0.55, 0.30, 1.00)
const AMBER: Color = Color(1.00, 0.60, 0.15)
const LIME: Color = Color(0.55, 1.00, 0.35)
const METAL: Color = Color(0.36, 0.40, 0.48)
const METAL_D: Color = Color(0.17, 0.19, 0.25)


func get_mesh(key: String) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var m: ArrayMesh
	match key:
		"pine": m = crystals(Color(0.52, 0.26, 0.92), Color(0.55, 0.95, 1.0), 1, false)
		"pine2": m = pylon()
		"pine_snow": m = crystals(Color(0.82, 0.94, 1.0), Color(1.0, 1.0, 1.0), 3, true)
		"oak": m = alien_tree(0)
		"oak2": m = alien_tree(1)
		"oak3": m = alien_tree(2)
		"bush": m = glow_bush()
		"cactus": m = monolith()
		"palm": m = solar_palm()
		"rock": m = asteroid(Color(0.30, 0.29, 0.38), CYAN, 5)
		"rock2": m = asteroid(Color(0.26, 0.27, 0.34), MAGENTA, 6)
		"rock_snow": m = asteroid(Color(0.58, 0.74, 0.92), Color(0.85, 1.0, 1.0), 7)
		"rock_desert": m = asteroid(Color(0.52, 0.26, 0.18), AMBER, 8)
		"grass_meadow": m = glow_grass(Color(0.12, 0.50, 0.38), Color(0.35, 1.00, 0.72), 0.7, 11)
		"grass_forest": m = glow_grass(Color(0.08, 0.28, 0.36), CYAN, 0.9, 12)
		"grass_dry": m = glow_grass(Color(0.60, 0.30, 0.18), AMBER, 0.6, 13)
		"grass_snow": m = glow_grass(Color(0.50, 0.66, 0.84), Color(0.9, 1.0, 1.0), 0.8, 14)
		"reed": m = filaments()
		"flower_white": m = bulbs(Color(0.80, 1.00, 1.00), 21)
		"flower_yellow": m = bulbs(Color(1.00, 0.90, 0.30), 22)
		"flower_pink": m = bulbs(MAGENTA, 23)
		"flower_blue": m = bulbs(Color(0.30, 0.50, 1.00), 24)
		_:
			m = ArrayMesh.new()
	_cache[key] = m
	return m


func height_of(key: String) -> float:
	match key:
		"pine", "pine2", "pine_snow":
			return 4.6
		"oak", "oak2", "oak3":
			return 3.8
		"palm":
			return 4.2
		"cactus":
			return 2.0
		"reed":
			return 1.3
		"bush":
			return 1.2
		_:
			return 0.6


func material_for(key: String) -> Material:
	# pevné věci (krystaly, antény, skály, monolity) se nehýbou; rostliny se houpají ve větru
	if key.begins_with("rock") or key.begins_with("pine") or key == "cactus":
		return Gfx.model_mat(0.4, 0.12)
	if key.begins_with("grass") or key.begins_with("flower") or key == "reed":
		return Gfx.foliage_mat(0.55 if key != "reed" else 1.3, 0.30 if key == "reed" else 0.20, 0.04)
	return Gfx.foliage_mat(height_of(key), 0.10, 0.035)


# ------------------------------------------------------------------ krystaly, antény
static func crystals(base: Color, tip: Color, seed_value: int, ice: bool) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.06)
	k.ao = 0.3
	k.ao_height = 1.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 31
	var n: int = 5
	for i in range(n):
		var a: float = TAU * float(i) / float(n) + rng.randf() * 0.5
		var rr: float = 0.0 if i == 0 else rng.randf_range(0.3, 0.7)
		var h: float = rng.randf_range(1.6, 3.2) if i != 0 else 4.4
		var r: float = rng.randf_range(0.14, 0.24) if i != 0 else 0.30
		var tilt: Vector3 = Vector3(rng.randf_range(-12.0, 12.0), 0.0, rng.randf_range(-12.0, 12.0)) if i != 0 else Vector3.ZERO
		var pos: Vector3 = Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		var tf: Transform3D = MeshKit.xf(pos, tilt)
		k.cyl(r, r * 0.9, h * 0.72, 6, base, tf, 0.55 if ice else 0.35, false, true)
		k.cone(r * 0.9, h * 0.28, 6, tip, tf * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.72, 0.0)), 1.5, false)
	k.blob(0.55, base.darkened(0.35), MeshKit.xf(Vector3(0.0, 0.1, 0.0), Vector3.ZERO, Vector3(1.0, 0.45, 1.0)), 0.0, 6, 3, 0.2, seed_value)
	return k.build()


static func pylon() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(3, 0.04)
	k.ao = 0.3
	k.ao_height = 1.2
	k.cyl(0.42, 0.36, 0.35, 8, METAL_D, MeshKit.xf(), 0.0, false, true)
	k.cyl(0.11, 0.07, 4.2, 6, METAL, MeshKit.xf(Vector3(0.0, 0.3, 0.0)), 0.0, false, true)
	for i in range(3):
		var y: float = 1.1 + float(i) * 1.05
		k.torus(0.32 - 0.05 * float(i), 0.04, METAL_D, MeshKit.xf(Vector3(0.0, y, 0.0)), 0.0, 12, 4)
		k.box(Vector3(0.5 - 0.1 * float(i), 0.05, 0.05), CYAN, MeshKit.xf(Vector3(0.0, y + 0.18, 0.0), Vector3(0.0, 40.0 * float(i), 0.0)), 1.2)
	# talíř
	k.cone(0.34, 0.2, 8, METAL, MeshKit.xf(Vector3(0.12, 3.3, 0.0), Vector3(0.0, 0.0, -75.0)), 0.0, false)
	k.sphere(0.07, CYAN, MeshKit.xf(Vector3(0.2, 3.38, 0.0)), 1.6, 5, 3)
	# výstražné světlo
	k.sphere(0.13, Color(1.0, 0.2, 0.25), MeshKit.xf(Vector3(0.0, 4.55, 0.0)), 2.2, 6, 4)
	return k.build()


# ------------------------------------------------------------------ rostliny
static func alien_tree(variant: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(30 + variant, 0.08)
	var trunk: Color = Color(0.13, 0.12, 0.20)
	var c1: Color = Color(0.12, 0.85, 0.80)
	var c2: Color = Color(0.45, 0.35, 1.0)
	if variant == 1:
		c1 = Color(0.55, 1.0, 0.35)
		c2 = Color(0.20, 0.85, 0.55)
	elif variant == 2:
		c1 = Color(1.0, 0.62, 0.16)
		c2 = Color(1.0, 0.30, 0.45)
	k.ao = 0.2
	k.ao_height = 1.4
	k.cyl(0.17, 0.10, 1.5, 6, trunk, MeshKit.xf(), 0.0, false, false)
	k.cyl(0.09, 0.05, 1.1, 5, trunk, MeshKit.xf(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 42.0)), 0.0, false, false)
	k.cyl(0.08, 0.05, 0.9, 5, trunk, MeshKit.xf(Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, -38.0)), 0.0, false, false)
	# svítící plody-koule v koruně
	k.blob(0.95, c1.darkened(0.55), MeshKit.xf(Vector3(0.0, 2.45, 0.0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), 0.25, 7, 5, 0.12, 100 + variant)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 40 + variant
	for i in range(9):
		var a: float = TAU * float(i) / 9.0 + rng.randf() * 0.4
		var rr: float = rng.randf_range(0.55, 1.05)
		var y: float = 2.25 + rng.randf_range(-0.3, 1.0)
		var col: Color = c1 if i % 3 != 0 else c2
		k.sphere(rng.randf_range(0.14, 0.24), col, MeshKit.xf(Vector3(cos(a) * rr, y, sin(a) * rr)), 1.5, 6, 4)
	k.sphere(0.34, c2, MeshKit.xf(Vector3(0.0, 3.2, 0.0)), 1.3, 7, 5)
	# visící vlákna
	for j in range(5):
		var a2: float = TAU * float(j) / 5.0
		k.box(Vector3(0.025, 0.7, 0.025), c1, MeshKit.xf(Vector3(cos(a2) * 0.7, 1.75, sin(a2) * 0.7)), 1.1)
	return k.build()


static func glow_bush() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(40, 0.08)
	k.ao = 0.2
	k.ao_height = 0.6
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 41
	for i in range(7):
		var a: float = TAU * float(i) / 7.0 + rng.randf() * 0.4
		var lean: float = rng.randf_range(20.0, 45.0)
		var h: float = rng.randf_range(0.6, 0.95)
		k.cone(0.07, h, 5, Color(0.06, 0.28, 0.30), MeshKit.xf(Vector3(0.0, 0.0, 0.0), Vector3(sin(a) * lean, 0.0, -cos(a) * lean)), 0.0, false)
		var tipp: Vector3 = Vector3(sin(a) * sin(deg_to_rad(lean)) * h, cos(deg_to_rad(lean)) * h, -cos(a) * sin(deg_to_rad(lean)) * h)
		k.sphere(0.075, MAGENTA if i % 2 == 0 else CYAN, MeshKit.xf(tipp), 1.7, 5, 3)
	k.blob(0.28, Color(0.05, 0.20, 0.24), MeshKit.xf(Vector3(0.0, 0.18, 0.0), Vector3.ZERO, Vector3(1.0, 0.6, 1.0)), 0.0, 6, 3, 0.15, 42)
	return k.build()


static func monolith() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(50, 0.04)
	k.ao = 0.3
	k.ao_height = 1.0
	k.cyl(0.36, 0.20, 2.1, 4, Color(0.12, 0.10, 0.14), MeshKit.xf(Vector3.ZERO, Vector3(0.0, 45.0, 0.0)), 0.0, false, true)
	k.cone(0.20, 0.35, 4, Color(0.12, 0.10, 0.14), MeshKit.xf(Vector3(0.0, 2.1, 0.0), Vector3(0.0, 45.0, 0.0)), 0.0, false)
	# svítící žíly a okénko
	for sd in range(4):
		var a: float = PI * 0.5 * float(sd)
		k.box(Vector3(0.035, 1.5, 0.02), AMBER, MeshKit.xf(Vector3(cos(a) * 0.19, 1.05, sin(a) * 0.19), Vector3(0.0, -rad_to_deg(a), 0.0)), 1.3)
	k.sphere(0.1, Color(1.0, 0.45, 0.15), MeshKit.xf(Vector3(0.0, 2.55, 0.0)), 1.8, 5, 3)
	k.box(Vector3(0.5, 0.22, 0.4), Color(0.20, 0.16, 0.16), MeshKit.xf(Vector3(0.5, 0.11, 0.2), Vector3(0.0, 25.0, 0.0)))
	return k.build()


static func solar_palm() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(60, 0.04)
	k.ao = 0.2
	k.ao_height = 1.0
	k.cyl(0.14, 0.08, 3.1, 6, METAL, MeshKit.xf(Vector3.ZERO, Vector3(0.0, 0.0, -4.0)), 0.0, false, true)
	var top: Vector3 = Vector3(0.22, 3.1, 0.0)
	for f in range(6):
		var ang: float = TAU * float(f) / 6.0
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var p0: Vector3 = top + Vector3(0.0, 0.05, 0.0)
		var p1: Vector3 = top + dir * 1.55 + Vector3(0.0, 0.35, 0.0)
		# nosník a solární panel (modrý s mřížkou)
		k.tri(p0 - side * 0.05, p0 + side * 0.05, p1, METAL_D, Transform3D.IDENTITY, 0.0, true)
		for q in range(3):
			var t0: float = 0.18 + 0.27 * float(q)
			var t1: float = t0 + 0.23
			var a0: Vector3 = p0.lerp(p1, t0)
			var a1: Vector3 = p0.lerp(p1, t1)
			var w0: float = 0.30 * sin(PI * (0.2 + t0 * 0.8)) + 0.06
			var w1: float = 0.30 * sin(PI * (0.2 + t1 * 0.8)) + 0.06
			k.quad(a0 - side * w0, a0 + side * w0, a1 + side * w1, a1 - side * w1, Color(0.10, 0.30, 0.70), Transform3D.IDENTITY, 0.35, true)
			k.quad(a0 - side * (w0 * 0.12), a0 + side * (w0 * 0.12), a1 + side * (w1 * 0.12), a1 - side * (w1 * 0.12), CYAN, Transform3D.IDENTITY, 1.0, true)
	k.sphere(0.13, AMBER, MeshKit.xf(top + Vector3(0.0, 0.12, 0.0)), 1.8, 6, 4)
	return k.build()


# ------------------------------------------------------------------ skály
static func asteroid(col: Color, crystal: Color, seed_value: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.10)
	k.ao = 0.25
	k.ao_height = 0.8
	k.blob(0.8, col, MeshKit.xf(Vector3(0.0, 0.32, 0.0), Vector3(0.0, float(seed_value) * 40.0, 0.0), Vector3(1.0, 0.7, 0.9)), 0.0, 6, 4, 0.26, seed_value)
	k.blob(0.45, col.darkened(0.12), MeshKit.xf(Vector3(0.65, 0.18, 0.2), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), 0.0, 5, 3, 0.25, seed_value + 20)
	# svítící krystaly vyrůstající ze skály
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + 50
	for i in range(3):
		var a: float = rng.randf() * TAU
		var p: Vector3 = Vector3(cos(a) * 0.4, 0.45, sin(a) * 0.35)
		k.cone(0.07, rng.randf_range(0.35, 0.6), 5, crystal, MeshKit.xf(p, Vector3(sin(a) * 25.0, 0.0, -cos(a) * 25.0)), 1.6, false)
	return k.build()


# ------------------------------------------------------------------ tráva, vlákna, svítící květy
static func glow_grass(c_base: Color, c_tip: Color, glow: float, seed_value: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.06)
	k.force_normal = Vector3.UP
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for b in range(7):
		var a: float = rng.randf() * TAU
		var rr: float = rng.randf_range(0.0, 0.12)
		var base: Vector3 = Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		var ang: float = rng.randf() * TAU
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var h: float = rng.randf_range(0.30, 0.60)
		var lean: float = rng.randf_range(0.05, 0.22)
		var w: float = 0.04
		var mid: Vector3 = base + dir * (lean * 0.35) + Vector3(0.0, h * 0.55, 0.0)
		var tip: Vector3 = base + dir * lean + Vector3(0.0, h, 0.0)
		k.quad(base - side * w, base + side * w, mid + side * (w * 0.7), mid - side * (w * 0.7), c_base, Transform3D.IDENTITY, 0.0, true)
		k.tri(mid - side * (w * 0.7), mid + side * (w * 0.7), tip, c_tip, Transform3D.IDENTITY, glow, true)
	return k.build()


static func filaments() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(70, 0.05)
	k.force_normal = Vector3.UP
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 71
	for b in range(6):
		var a: float = rng.randf() * TAU
		var rr: float = rng.randf_range(0.0, 0.18)
		var base: Vector3 = Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		var ang: float = rng.randf() * TAU
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var h: float = rng.randf_range(0.9, 1.4)
		var tip: Vector3 = base + dir * rng.randf_range(0.1, 0.3) + Vector3(0.0, h, 0.0)
		var mid: Vector3 = base + dir * 0.04 + Vector3(0.0, h * 0.5, 0.0)
		k.quad(base - side * 0.025, base + side * 0.025, mid + side * 0.02, mid - side * 0.02, Color(0.05, 0.30, 0.40), Transform3D.IDENTITY, 0.3, true)
		k.tri(mid - side * 0.02, mid + side * 0.02, tip, CYAN, Transform3D.IDENTITY, 1.2, true)
		if b % 3 == 0:
			k.sphere(0.055, MAGENTA, MeshKit.xf(tip + Vector3(0.0, 0.02, 0.0)), 1.8, 5, 3)
	return k.build()


static func bulbs(col: Color, seed_value: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.05)
	k.force_normal = Vector3.UP
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for b in range(4):
		var a: float = rng.randf() * TAU
		var rr: float = rng.randf_range(0.05, 0.25)
		var base: Vector3 = Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		var h: float = rng.randf_range(0.22, 0.40)
		k.cyl(0.012, 0.01, h, 4, Color(0.10, 0.35, 0.35), MeshKit.xf(base), 0.0, false, false)
		k.sphere(0.065, col, MeshKit.xf(base + Vector3(0.0, h + 0.03, 0.0)), 1.8, 6, 3)
		k.sphere(0.03, Color(1, 1, 1), MeshKit.xf(base + Vector3(0.0, h + 0.07, 0.0)), 2.2, 4, 2)
	return k.build()
