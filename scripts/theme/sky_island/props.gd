class_name Props
extends RefCounted
## Modely přírody (stromy, keře, kaktusy, skály, tráva, květiny) poskládané z primitiv. Počátek = zem, osa Y nahoru.

static var _cache: Dictionary = {}

const TRUNK: Color = Color(0.40, 0.27, 0.16)


static func get_mesh(key: String) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var m: ArrayMesh
	match key:
		"pine": m = pine(false, 1)
		"pine2": m = pine(false, 2)
		"pine_snow": m = pine(true, 3)
		"oak": m = oak(0)
		"oak2": m = oak(1)
		"oak3": m = oak(2)
		"bush": m = bush()
		"cactus": m = cactus()
		"palm": m = palm()
		"rock": m = rock(Color(0.52, 0.50, 0.48), false, 5)
		"rock2": m = rock(Color(0.46, 0.44, 0.44), false, 6)
		"rock_snow": m = rock(Color(0.50, 0.50, 0.53), true, 7)
		"rock_desert": m = rock(Color(0.66, 0.46, 0.32), false, 8)
		"grass_meadow": m = grass(Color(0.38, 0.64, 0.18), Color(0.68, 0.90, 0.34), 11)
		"grass_forest": m = grass(Color(0.17, 0.40, 0.13), Color(0.36, 0.62, 0.24), 12)
		"grass_dry": m = grass(Color(0.55, 0.45, 0.22), Color(0.85, 0.75, 0.42), 13)
		"grass_snow": m = grass(Color(0.55, 0.60, 0.50), Color(0.90, 0.94, 0.96), 14)
		"reed": m = reed()
		"flower_white": m = flowers(Color(1.0, 0.98, 0.92), 21)
		"flower_yellow": m = flowers(Color(1.0, 0.85, 0.20), 22)
		"flower_pink": m = flowers(Color(0.96, 0.45, 0.65), 23)
		"flower_blue": m = flowers(Color(0.45, 0.60, 1.0), 24)
		_:
			m = ArrayMesh.new()
	_cache[key] = m
	return m


static func height_of(key: String) -> float:
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
		"bush", "rock", "rock2", "rock_snow", "rock_desert":
			return 1.2
		_:
			return 0.6


# ------------------------------------------------------------------ stromy
static func pine(snow: bool, seed_value: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.07)
	k.cyl(0.14, 0.09, 1.0, 6, TRUNK, MeshKit.xf(), 0.0, false, false)
	var tiers: int = 4
	for i in range(tiers):
		var y: float = 0.55 + float(i) * 0.8
		var r: float = 1.08 - float(i) * 0.23
		var h: float = 1.5 - float(i) * 0.12
		var green: Color = Color(0.11, 0.34, 0.19).lerp(Color(0.20, 0.50, 0.26), float(i) / 4.0)
		k.cyl(r, 0.0, h, 7, green, MeshKit.xf(Vector3(0.0, y, 0.0)), 0.0, false, true)
		if snow:
			k.cyl(r * 0.8, 0.0, h * 0.62, 7, Color(0.96, 0.98, 1.0), MeshKit.xf(Vector3(0.0, y + h * 0.37, 0.0)), 0.0, false, true)
	return k.build()


static func oak(variant: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(30 + variant, 0.08)
	var g1: Color = Color(0.26, 0.55, 0.20)
	var g2: Color = Color(0.34, 0.64, 0.24)
	var g3: Color = Color(0.20, 0.46, 0.18)
	if variant == 1:
		g1 = Color(0.45, 0.66, 0.22)
		g2 = Color(0.58, 0.74, 0.28)
		g3 = Color(0.36, 0.58, 0.20)
	elif variant == 2:
		g1 = Color(0.78, 0.52, 0.16)
		g2 = Color(0.88, 0.62, 0.20)
		g3 = Color(0.66, 0.40, 0.14)
	k.cyl(0.19, 0.12, 1.55, 6, TRUNK, MeshKit.xf(), 0.0, false, false)
	k.cyl(0.07, 0.04, 0.9, 5, TRUNK, MeshKit.xf(Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 38.0)), 0.0, false, false)
	k.blob(1.15, g1, MeshKit.xf(Vector3(0.0, 2.35, 0.0)), 0.0, 7, 5, 0.16, 100 + variant)
	k.blob(0.85, g2, MeshKit.xf(Vector3(0.78, 1.95, 0.2)), 0.0, 7, 4, 0.16, 110 + variant)
	k.blob(0.8, g3, MeshKit.xf(Vector3(-0.65, 2.05, -0.5)), 0.0, 7, 4, 0.16, 120 + variant)
	k.blob(0.7, g2, MeshKit.xf(Vector3(0.05, 3.0, 0.1)), 0.0, 6, 4, 0.14, 130 + variant)
	return k.build()


static func bush() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(40, 0.08)
	k.blob(0.5, Color(0.25, 0.52, 0.20), MeshKit.xf(Vector3(0.0, 0.38, 0.0), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), 0.0, 6, 4, 0.16, 41)
	k.blob(0.38, Color(0.32, 0.60, 0.24), MeshKit.xf(Vector3(0.42, 0.3, 0.1)), 0.0, 6, 4, 0.16, 42)
	k.blob(0.34, Color(0.22, 0.46, 0.18), MeshKit.xf(Vector3(-0.38, 0.28, -0.15)), 0.0, 6, 4, 0.16, 43)
	k.sphere(0.06, Color(0.9, 0.2, 0.25), MeshKit.xf(Vector3(0.1, 0.62, 0.35)), 0.0, 5, 3)
	k.sphere(0.06, Color(0.9, 0.2, 0.25), MeshKit.xf(Vector3(-0.3, 0.5, 0.3)), 0.0, 5, 3)
	return k.build()


static func cactus() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(50, 0.05)
	var g: Color = Color(0.25, 0.55, 0.28)
	k.cyl(0.24, 0.22, 1.7, 8, g, MeshKit.xf(), 0.0, true, true)
	k.sphere(0.22, g, MeshKit.xf(Vector3(0.0, 1.7, 0.0)), 0.0, 8, 4, true)
	# levé rameno
	k.cyl(0.13, 0.13, 0.55, 7, g, MeshKit.xf(Vector3(0.0, 0.85, 0.0), Vector3(0.0, 0.0, 90.0)), 0.0, true, true)
	k.cyl(0.13, 0.12, 0.7, 7, g, MeshKit.xf(Vector3(-0.55, 0.85, 0.0)), 0.0, true, true)
	k.sphere(0.12, g, MeshKit.xf(Vector3(-0.55, 1.55, 0.0)), 0.0, 7, 4, true)
	# pravé rameno
	k.cyl(0.12, 0.12, 0.45, 7, g, MeshKit.xf(Vector3(0.0, 1.1, 0.0), Vector3(0.0, 0.0, -90.0)), 0.0, true, true)
	k.cyl(0.12, 0.11, 0.5, 7, g, MeshKit.xf(Vector3(0.45, 1.1, 0.0)), 0.0, true, true)
	k.sphere(0.11, g, MeshKit.xf(Vector3(0.45, 1.6, 0.0)), 0.0, 7, 4, true)
	k.sphere(0.07, Color(0.95, 0.45, 0.6), MeshKit.xf(Vector3(0.0, 1.9, 0.0)), 0.0, 5, 3)
	return k.build()


static func palm() -> ArrayMesh:
	var k: MeshKit = MeshKit.new(60, 0.06)
	var top: Vector3 = Vector3.ZERO
	for i in range(6):
		var t: float = float(i) / 5.0
		var px: float = 0.55 * t * t
		var py: float = 0.72 * float(i)
		var r: float = 0.17 - 0.02 * float(i)
		k.cyl(r, r - 0.012, 0.85, 6, Color(0.52, 0.38, 0.24), MeshKit.xf(Vector3(px, py, 0.0), Vector3(0.0, 0.0, -9.0 * t - 2.0)), 0.0, false, true)
		top = Vector3(px, py + 0.8, 0.0)
	for f in range(8):
		var ang: float = TAU * float(f) / 8.0 + 0.2
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
		var prev_c: Vector3 = top
		var prev_w: float = 0.05
		for j in range(1, 6):
			var d: float = float(j)
			var c: Vector3 = top + dir * (0.52 * d) + Vector3(0.0, 0.5 * d - 0.11 * d * d, 0.0)
			var w: float = 0.38 * sin(PI * minf(d / 5.5, 1.0)) + 0.04
			var col: Color = Color(0.18, 0.46, 0.20).lerp(Color(0.40, 0.68, 0.28), d / 5.0)
			k.quad(prev_c - side * prev_w, prev_c + side * prev_w, c + side * w, c - side * w, col, Transform3D.IDENTITY, 0.0, true)
			prev_c = c
			prev_w = w
	k.sphere(0.12, Color(0.45, 0.30, 0.15), MeshKit.xf(top + Vector3(0.1, -0.1, 0.1)), 0.0, 5, 3)
	k.sphere(0.12, Color(0.45, 0.30, 0.15), MeshKit.xf(top + Vector3(-0.1, -0.12, 0.05)), 0.0, 5, 3)
	return k.build()


# ------------------------------------------------------------------ skály
static func rock(col: Color, snow: bool, seed_value: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.10)
	k.blob(0.8, col, MeshKit.xf(Vector3(0.0, 0.32, 0.0), Vector3(0.0, float(seed_value) * 40.0, 0.0), Vector3(1.0, 0.7, 0.9)), 0.0, 6, 4, 0.26, seed_value)
	k.blob(0.45, col.darkened(0.08), MeshKit.xf(Vector3(0.65, 0.18, 0.2), Vector3.ZERO, Vector3(1.0, 0.8, 1.0)), 0.0, 5, 3, 0.25, seed_value + 20)
	if snow:
		k.blob(0.62, Color(0.96, 0.98, 1.0), MeshKit.xf(Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3(1.0, 0.45, 0.9)), 0.0, 6, 3, 0.2, seed_value + 30)
	return k.build()


# ------------------------------------------------------------------ tráva, květiny, rákos
static func grass(c_base: Color, c_tip: Color, seed_value: int) -> ArrayMesh:
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
		var h: float = rng.randf_range(0.28, 0.55)
		var lean: float = rng.randf_range(0.05, 0.22)
		var w: float = 0.045
		var mid: Vector3 = base + dir * (lean * 0.35) + Vector3(0.0, h * 0.55, 0.0)
		var tip: Vector3 = base + dir * lean + Vector3(0.0, h, 0.0)
		k.quad(base - side * w, base + side * w, mid + side * (w * 0.7), mid - side * (w * 0.7), c_base, Transform3D.IDENTITY, 0.0, true)
		k.tri(mid - side * (w * 0.7), mid + side * (w * 0.7), tip, c_tip, Transform3D.IDENTITY, 0.0, true)
	return k.build()


static func reed() -> ArrayMesh:
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
		k.quad(base - side * 0.035, base + side * 0.035, mid + side * 0.03, mid - side * 0.03, Color(0.40, 0.45, 0.20), Transform3D.IDENTITY, 0.0, true)
		k.tri(mid - side * 0.03, mid + side * 0.03, tip, Color(0.62, 0.66, 0.30), Transform3D.IDENTITY, 0.0, true)
		if b % 3 == 0:
			k.cyl(0.04, 0.035, 0.22, 5, Color(0.42, 0.28, 0.16), MeshKit.xf(tip + Vector3(0.0, -0.1, 0.0)), 0.0, false, true)
	return k.build()


static func flowers(col: Color, seed_value: int) -> ArrayMesh:
	var k: MeshKit = MeshKit.new(seed_value, 0.05)
	k.force_normal = Vector3.UP
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for b in range(4):
		var a: float = rng.randf() * TAU
		var rr: float = rng.randf_range(0.05, 0.25)
		var base: Vector3 = Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		var h: float = rng.randf_range(0.22, 0.38)
		k.cyl(0.012, 0.01, h, 4, Color(0.25, 0.5, 0.2), MeshKit.xf(base), 0.0, false, false)
		k.sphere(0.055, col, MeshKit.xf(base + Vector3(0.0, h + 0.02, 0.0)), 0.0, 6, 3)
		k.sphere(0.025, Color(0.95, 0.75, 0.15), MeshKit.xf(base + Vector3(0.0, h + 0.06, 0.0)), 0.0, 4, 2)
	return k.build()
