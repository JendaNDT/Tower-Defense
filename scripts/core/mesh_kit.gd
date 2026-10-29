class_name MeshKit
extends RefCounted
## Skládání nízkopolygonových modelů z primitiv do jediné sítě (1 draw call).
## Barva vrcholu = albedo (sRGB), alfa kanál = síla emise (svítící části).
## Orientace trojúhelníků se u konvexních těles opravuje automaticky vůči referenčnímu bodu,
## takže stačí zadat tvar a neřešit pořadí vrcholů.

var _v: PackedVector3Array = PackedVector3Array()
var _n: PackedVector3Array = PackedVector3Array()
var _c: PackedColorArray = PackedColorArray()
var jitter: float = 0.0          # náhodné zesvětlení/ztmavení ploch (0 = vypnuto)
var force_normal: Vector3 = Vector3.ZERO   # nenulová => všechny normály nastavit na tuto hodnotu (tráva)
var ao: float = 0.0              # síla ztmavení spodku modelu 0..1 (levná náhražka okluze: u země je tmavěji)
var ao_height: float = 1.0       # výška (m) od nejnižšího bodu, ve které ztmavení vyprchá
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 1, jitter_amount: float = 0.0) -> void:
	_rng.seed = seed_value
	jitter = jitter_amount


static func xf(pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	b = b * Basis.from_scale(scl)
	return Transform3D(b, pos)


func vertex_count() -> int:
	return _v.size()


func _col(c: Color, emit: float) -> Color:
	if jitter > 0.0:
		var k: float = 1.0 + _rng.randf_range(-jitter, jitter)
		return Color(c.r * k, c.g * k, c.b * k, emit)
	return Color(c.r, c.g, c.b, emit)


## Přidá trojúhelník; `ref` je bod uvnitř tělesa (pro opravu orientace), nebo null.
func _emit(pa: Vector3, pb: Vector3, pc: Vector3, ref, col: Color, emit: float,
		na = null, nb = null, nc = null) -> void:
	var fn: Vector3 = (pb - pa).cross(pc - pa)
	if fn.length_squared() < 1e-14:
		return
	if ref != null:
		var centroid: Vector3 = (pa + pb + pc) / 3.0
		if fn.dot(centroid - (ref as Vector3)) < 0.0:
			# prohodit pb/pc => normála míří ven
			var tp: Vector3 = pb
			pb = pc
			pc = tp
			fn = -fn
			var tn = nb
			nb = nc
			nc = tn
	fn = fn.normalized()
	var k: Color = _col(col, emit)
	# (pa, pc, pb) = po směru hodinových ručiček při pohledu zvenčí (přední strana v Godotu)
	_v.append(pa)
	_v.append(pc)
	_v.append(pb)
	if force_normal != Vector3.ZERO:
		_n.append(force_normal)
		_n.append(force_normal)
		_n.append(force_normal)
	else:
		_n.append(fn if na == null else (na as Vector3))
		_n.append(fn if nc == null else (nc as Vector3))
		_n.append(fn if nb == null else (nb as Vector3))
	_c.append(k)
	_c.append(k)
	_c.append(k)


## Libovolný trojúhelník (vrcholy proti směru hodin při pohledu zepředu). double=true => viditelný z obou stran.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, t: Transform3D = Transform3D.IDENTITY,
		emit: float = 0.0, double: bool = false) -> void:
	var pa: Vector3 = t * a
	var pb: Vector3 = t * b
	var pc: Vector3 = t * c
	# ref == null => bereme pořadí tak, jak je (a,b,c je CCW zepředu)
	_emit(pa, pb, pc, null, col, emit)
	if double:
		_emit(pa, pc, pb, null, col, emit)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, t: Transform3D = Transform3D.IDENTITY,
		emit: float = 0.0, double: bool = false) -> void:
	tri(a, b, c, col, t, emit, double)
	tri(a, c, d, col, t, emit, double)


func box(size: Vector3, col: Color, t: Transform3D = Transform3D.IDENTITY, emit: float = 0.0) -> void:
	var h: Vector3 = size * 0.5
	var ref: Vector3 = t * Vector3.ZERO
	var p: Array = []
	for i in range(8):
		var sx: float = -1.0 if (i & 1) == 0 else 1.0
		var sy: float = -1.0 if (i & 2) == 0 else 1.0
		var sz: float = -1.0 if (i & 4) == 0 else 1.0
		p.append(t * Vector3(h.x * sx, h.y * sy, h.z * sz))
	# index: bit0 = x, bit1 = y, bit2 = z (0 = záporné, 1 = kladné)
	var faces: Array = [
		[1, 3, 7, 5],  # +X
		[0, 4, 6, 2],  # -X
		[2, 6, 7, 3],  # +Y
		[0, 1, 5, 4],  # -Y
		[4, 5, 7, 6],  # +Z
		[0, 2, 3, 1],  # -Z
	]
	for f in faces:
		var a: Vector3 = p[f[0]]
		var b: Vector3 = p[f[1]]
		var c: Vector3 = p[f[2]]
		var d: Vector3 = p[f[3]]
		_emit(a, b, c, ref, col, emit)
		_emit(a, c, d, ref, col, emit)


## Válec/kužel osou Y, spodek v y=0, vršek v y=h. r_top=0 => kužel.
func cyl(r_bottom: float, r_top: float, h: float, segs: int, col: Color, t: Transform3D = Transform3D.IDENTITY,
		emit: float = 0.0, smooth: bool = false, caps: bool = true) -> void:
	var ref: Vector3 = t * Vector3(0.0, h * 0.5, 0.0)
	var nbasis: Basis = t.basis.inverse().transposed()
	var slope: float = (r_bottom - r_top) / maxf(h, 0.0001)
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		var b0: Vector3 = t * Vector3(c0 * r_bottom, 0.0, s0 * r_bottom)
		var b1: Vector3 = t * Vector3(c1 * r_bottom, 0.0, s1 * r_bottom)
		var t0: Vector3 = t * Vector3(c0 * r_top, h, s0 * r_top)
		var t1: Vector3 = t * Vector3(c1 * r_top, h, s1 * r_top)
		if smooth:
			var n0: Vector3 = (nbasis * Vector3(c0, slope, s0)).normalized()
			var n1: Vector3 = (nbasis * Vector3(c1, slope, s1)).normalized()
			_emit(b0, b1, t1, ref, col, emit, n0, n1, n1)
			_emit(b0, t1, t0, ref, col, emit, n0, n1, n0)
		else:
			_emit(b0, b1, t1, ref, col, emit)
			_emit(b0, t1, t0, ref, col, emit)
		if caps:
			if r_top > 0.0001:
				_emit(t * Vector3(0.0, h, 0.0), t1, t0, ref, col, emit)
			if r_bottom > 0.0001:
				_emit(t * Vector3.ZERO, b0, b1, ref, col, emit)


func cone(r: float, h: float, segs: int, col: Color, t: Transform3D = Transform3D.IDENTITY,
		emit: float = 0.0, smooth: bool = false) -> void:
	cyl(r, 0.0, h, segs, col, t, emit, smooth, true)


## Koule se středem v počátku transformace.
func sphere(r: float, col: Color, t: Transform3D = Transform3D.IDENTITY, emit: float = 0.0,
		segs: int = 8, rings: int = 5, smooth: bool = false) -> void:
	var ref: Vector3 = t * Vector3.ZERO
	var nbasis: Basis = t.basis.inverse().transposed()
	for j in range(rings):
		var th0: float = PI * float(j) / float(rings)
		var th1: float = PI * float(j + 1) / float(rings)
		for i in range(segs):
			var ph0: float = TAU * float(i) / float(segs)
			var ph1: float = TAU * float(i + 1) / float(segs)
			var d00: Vector3 = Vector3(sin(th0) * cos(ph0), cos(th0), sin(th0) * sin(ph0))
			var d01: Vector3 = Vector3(sin(th0) * cos(ph1), cos(th0), sin(th0) * sin(ph1))
			var d10: Vector3 = Vector3(sin(th1) * cos(ph0), cos(th1), sin(th1) * sin(ph0))
			var d11: Vector3 = Vector3(sin(th1) * cos(ph1), cos(th1), sin(th1) * sin(ph1))
			var p00: Vector3 = t * (d00 * r)
			var p01: Vector3 = t * (d01 * r)
			var p10: Vector3 = t * (d10 * r)
			var p11: Vector3 = t * (d11 * r)
			if smooth:
				_emit(p00, p01, p11, ref, col, emit, (nbasis * d00).normalized(), (nbasis * d01).normalized(), (nbasis * d11).normalized())
				_emit(p00, p11, p10, ref, col, emit, (nbasis * d00).normalized(), (nbasis * d11).normalized(), (nbasis * d10).normalized())
			else:
				_emit(p00, p01, p11, ref, col, emit)
				_emit(p00, p11, p10, ref, col, emit)


## Prstenec kolem osy Y (R = hlavní poloměr, r = poloměr trubice).
func torus(big_r: float, small_r: float, col: Color, t: Transform3D = Transform3D.IDENTITY, emit: float = 0.0,
		segs: int = 18, tsegs: int = 6) -> void:
	for i in range(segs):
		var u0: float = TAU * float(i) / float(segs)
		var u1: float = TAU * float(i + 1) / float(segs)
		var um: float = (u0 + u1) * 0.5
		var ref: Vector3 = t * Vector3(cos(um) * big_r, 0.0, sin(um) * big_r)
		for j in range(tsegs):
			var v0: float = TAU * float(j) / float(tsegs)
			var v1: float = TAU * float(j + 1) / float(tsegs)
			var q00: Vector3 = t * Vector3((big_r + small_r * cos(v0)) * cos(u0), small_r * sin(v0), (big_r + small_r * cos(v0)) * sin(u0))
			var q01: Vector3 = t * Vector3((big_r + small_r * cos(v1)) * cos(u0), small_r * sin(v1), (big_r + small_r * cos(v1)) * sin(u0))
			var q10: Vector3 = t * Vector3((big_r + small_r * cos(v0)) * cos(u1), small_r * sin(v0), (big_r + small_r * cos(v0)) * sin(u1))
			var q11: Vector3 = t * Vector3((big_r + small_r * cos(v1)) * cos(u1), small_r * sin(v1), (big_r + small_r * cos(v1)) * sin(u1))
			_emit(q00, q01, q11, ref, col, emit)
			_emit(q00, q11, q10, ref, col, emit)


## Ikosféra-podobná „kamenná“ koule s náhodně posunutými vrcholy (kameny, koruny stromů).
func blob(r: float, col: Color, t: Transform3D = Transform3D.IDENTITY, emit: float = 0.0,
		segs: int = 7, rings: int = 5, wobble: float = 0.18, seed_value: int = 0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var ref: Vector3 = t * Vector3.ZERO
	# předpočítat mřížku bodů, aby sousední plochy navazovaly
	var grid: Array = []
	for j in range(rings + 1):
		var row: Array = []
		var th: float = PI * float(j) / float(rings)
		for i in range(segs):
			var ph: float = TAU * float(i) / float(segs)
			var k: float = 1.0 + rng.randf_range(-wobble, wobble)
			if j == 0 or j == rings:
				k = 1.0 + (-wobble * 0.3 if j == 0 else 0.0)
			row.append(t * (Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * r * k))
		grid.append(row)
	for j in range(rings):
		for i in range(segs):
			var i2: int = (i + 1) % segs
			var p00: Vector3 = grid[j][i]
			var p01: Vector3 = grid[j][i2]
			var p10: Vector3 = grid[j + 1][i]
			var p11: Vector3 = grid[j + 1][i2]
			_emit(p00, p01, p11, ref, col, emit)
			_emit(p00, p11, p10, ref, col, emit)


## Přidá obsah jiného kitu (s transformací).
func append(other: MeshKit, t: Transform3D = Transform3D.IDENTITY) -> void:
	var nbasis: Basis = t.basis.inverse().transposed()
	for i in range(other._v.size()):
		_v.append(t * other._v[i])
		_n.append((nbasis * other._n[i]).normalized())
		_c.append(other._c[i])


func build() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	if _v.size() == 0:
		return mesh
	var cols: PackedColorArray = _c
	if ao > 0.001:
		cols = _c.duplicate()
		var ymin: float = 1.0e9
		for p in _v:
			ymin = minf(ymin, p.y)
		for i in range(_v.size()):
			var t: float = clampf((_v[i].y - ymin) / maxf(ao_height, 0.01), 0.0, 1.0)
			var k: float = lerpf(1.0 - ao, 1.0, t * t * (3.0 - 2.0 * t))
			cols[i] = Color(_c[i].r * k, _c[i].g * k, _c[i].b * k, _c[i].a)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func instance(mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = build()
	mi.material_override = mat
	return mi
