class_name Terrain
extends RefCounted
## Výškové pole ostrova (mřížka HALF*2 / STEP) + pomocná pole vzdáleností k cestě a řece.
## Z této jediné datové struktury se dělá mesh terénu, textury pro shader i dotazy na výšku (věže, nepřátelé).

const HALF: float = 36.0
const STEP: float = 0.5
const N: int = 145
const BASE_R: float = 29.0
const PATH_HALF: float = 0.95
const FIELD_RANGE: float = 16.0   # kódování vzdálenosti do textury: (sd + 4) / 16

var hm: PackedFloat32Array = PackedFloat32Array()
var path_d: PackedFloat32Array = PackedFloat32Array()
var path_i: PackedInt32Array = PackedInt32Array()
var river_d: PackedFloat32Array = PackedFloat32Array()
var river_i: PackedInt32Array = PackedInt32Array()

var path: PathData
var river: RiverData
var seed_value: int = 7

var _n_hill: FastNoiseLite
var _n_hill2: FastNoiseLite
var _n_rim: FastNoiseLite
var _n_outline: FastNoiseLite
var _n_warp: FastNoiseLite
var _n_dune: FastNoiseLite

const BIOME_CENTERS: Array = [Vector2(17.0, -17.0), Vector2(-17.0, 17.0), Vector2(17.0, 17.0), Vector2(-17.0, -17.0)]

var biome_centers: Array = BIOME_CENTERS      # les, louka, poušť, sníh (podle rozložení ostrova)


func _init(seed_in: int = 7, centers: Array = []) -> void:
	seed_value = seed_in
	if centers.size() == 4:
		biome_centers = centers
	_n_hill = _mk(seed_in + 1, 0.035, 3)
	_n_hill2 = _mk(seed_in + 2, 0.11, 2)
	_n_rim = _mk(seed_in + 3, 0.06, 2)
	_n_outline = _mk(seed_in + 4, 0.35, 3)
	_n_warp = _mk(seed_in + 5, 1.0, 2)
	_n_dune = _mk(seed_in + 6, 0.09, 2)


func _mk(sd: int, freq: float, octaves: int) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = sd
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


# ------------------------------------------------------------------ obrys ostrova
func outline_r(theta: float) -> float:
	var c: float = absf(cos(theta))
	var s: float = absf(sin(theta))
	var p: float = 2.8
	var se: float = 1.0 / pow(pow(c, p) + pow(s, p), 1.0 / p)
	var n: float = _n_outline.get_noise_2d(cos(theta) * 1.6, sin(theta) * 1.6)
	return BASE_R * se * (1.0 + 0.075 * n)


## Vzdálenost od okraje dovnitř (kladná uvnitř ostrova), v metrech.
func edge_dist(x: float, z: float) -> float:
	return outline_r(atan2(z, x)) - sqrt(x * x + z * z)


# ------------------------------------------------------------------ biomy
func biome_weights(x: float, z: float) -> Color:
	var wx: float = x + 7.0 * _n_warp.get_noise_2d(x * 0.05, z * 0.05)
	var wz: float = z + 7.0 * _n_warp.get_noise_2d(x * 0.05 + 50.0, z * 0.05 + 50.0)
	var ds: Array = []
	var dmin: float = 1.0e9
	for c in biome_centers:
		var d: float = Vector2(wx, wz).distance_to(c)
		ds.append(d)
		dmin = minf(dmin, d)
	var ws: Array = []
	var sum: float = 0.0
	for d in ds:
		var w: float = exp(-(float(d) - dmin) / 3.2)
		ws.append(w)
		sum += w
	return Color(ws[0] / sum, ws[1] / sum, ws[2] / sum, ws[3] / sum)   # les, louka, poušť, sníh


## Nejvýraznější biom: 0 les, 1 louka, 2 poušť, 3 sníh.
func dominant_biome(x: float, z: float) -> int:
	var b: Color = biome_weights(x, z)
	var best: int = 0
	var bv: float = b.r
	if b.g > bv:
		bv = b.g
		best = 1
	if b.b > bv:
		bv = b.b
		best = 2
	if b.a > bv:
		best = 3
	return best


# ------------------------------------------------------------------ základní výška
func base_height(x: float, z: float) -> float:
	var r: float = sqrt(x * x + z * z)
	var th: float = atan2(z, x)
	var edge: float = clampf((outline_r(th) - r) / 9.0, 0.0, 1.0)     # 0 na okraji .. 1 hlouběji než 9 m
	var h: float = _n_hill.get_noise_2d(x, z) * 0.5 + _n_hill2.get_noise_2d(x, z) * 0.15
	# okrajové pahorky (rám ostrova) – výš na okraji, v hracím poli klid
	var rim_w: float = pow(1.0 - edge, 1.6)
	h += rim_w * (0.7 + 2.0 * maxf(_n_rim.get_noise_2d(x, z) + 0.2, 0.0))
	# zaoblené „rameno“ těsně u hrany
	h -= pow(1.0 - clampf(edge * 5.0, 0.0, 1.0), 2.0) * 1.1
	# duny v poušti, mírné kopečky ve sněhu
	var bw: Color = biome_weights(x, z)
	h += bw.b * 0.45 * _n_dune.get_noise_2d(x, z)
	h += bw.a * 0.25 * _n_hill2.get_noise_2d(x + 30.0, z)
	return h


# ------------------------------------------------------------------ vzorkování mřížky
func _gi(gx: int, gz: int) -> int:
	return clampi(gz, 0, N - 1) * N + clampi(gx, 0, N - 1)


func sample_grid(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fx: float = clampf((x + HALF) / STEP, 0.0, float(N - 1) - 0.0001)
	var fz: float = clampf((z + HALF) / STEP, 0.0, float(N - 1) - 0.0001)
	var gx: int = int(fx)
	var gz: int = int(fz)
	var tx: float = fx - float(gx)
	var tz: float = fz - float(gz)
	var a: float = arr[gz * N + gx]
	var b: float = arr[gz * N + gx + 1]
	var c: float = arr[(gz + 1) * N + gx]
	var d: float = arr[(gz + 1) * N + gx + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func height_at(x: float, z: float) -> float:
	return sample_grid(hm, x, z)


func normal_at(x: float, z: float) -> Vector3:
	var e: float = 0.4
	var hx: float = height_at(x + e, z) - height_at(x - e, z)
	var hz: float = height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func path_dist_at(x: float, z: float) -> float:
	return sample_grid(path_d, x, z)


## Vzdálenost od okraje vody (záporná = ve vodě).
func river_sd_at(x: float, z: float) -> float:
	var fx: float = clampf((x + HALF) / STEP, 0.0, float(N - 1))
	var fz: float = clampf((z + HALF) / STEP, 0.0, float(N - 1))
	var k: int = int(roundf(fz)) * N + int(roundf(fx))
	var d: float = sample_grid(river_d, x, z)
	var i: int = river_i[k]
	if i < 0:
		return d
	return d - river.half_w[i]


# ------------------------------------------------------------------ generování
func _stamp(points: PackedVector2Array, radius: float) -> Array:
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(N * N)
	d.fill(1.0e9)
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(N * N)
	idx.fill(-1)
	var rn: int = int(ceil(radius / STEP))
	for i in range(points.size()):
		var p: Vector2 = points[i]
		var cx: int = int(roundf((p.x + HALF) / STEP))
		var cz: int = int(roundf((p.y + HALF) / STEP))
		for gz in range(maxi(0, cz - rn), mini(N - 1, cz + rn) + 1):
			var dz: float = float(gz) * STEP - HALF - p.y
			var dz2: float = dz * dz
			for gx in range(maxi(0, cx - rn), mini(N - 1, cx + rn) + 1):
				var dx: float = float(gx) * STEP - HALF - p.x
				var dd: float = dx * dx + dz2
				var k: int = gz * N + gx
				if dd < d[k]:
					d[k] = dd
					idx[k] = i
	for k in range(N * N):
		d[k] = sqrt(d[k]) if d[k] < 1.0e8 else 99.0
	return [d, idx]


static func _smooth(arr: PackedFloat32Array, win: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(arr.size())
	var n: int = arr.size()
	for i in range(n):
		var sum: float = 0.0
		var cnt: int = 0
		for j in range(maxi(0, i - win), mini(n - 1, i + win) + 1):
			sum += arr[j]
			cnt += 1
		out[i] = sum / float(cnt)
	return out


func generate(path_poly: Array, river_control: Array) -> void:
	var total: int = N * N
	# 1) základní výška
	var h0: PackedFloat32Array = PackedFloat32Array()
	h0.resize(total)
	for gz in range(N):
		for gx in range(N):
			h0[gz * N + gx] = base_height(float(gx) * STEP - HALF, float(gz) * STEP - HALF)

	# 2) řeka: výška břehů, hladina, koridor
	river = RiverData.build(river_control)
	var nr: int = river.pts.size()
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(nr)
	for i in range(nr):
		raw[i] = sample_grid(h0, river.pts[i].x, river.pts[i].y)
	river.rh = _smooth(raw, 16)
	var wy: float = river.rh[0] - 0.7
	for i in range(nr):
		wy = minf(wy, river.rh[i] - 0.7)
		river.water_y[i] = wy
		# koncový úsek (vodopád) – hladina a břehy držet stabilní
	var rs: Array = _stamp(river.pts, 9.0)
	river_d = rs[0]
	river_i = rs[1]
	var h1: PackedFloat32Array = h0.duplicate()
	for k in range(total):
		var dr: float = river_d[k]
		var ri: int = river_i[k]
		if dr < 9.0 and ri >= 0:
			var hw: float = river.half_w[ri]
			var w: float = 1.0 - smoothstep(hw + 1.5, hw + 7.0, dr)
			h1[k] = lerpf(h0[k], river.rh[ri], w)

	# 3) cesta: výška podél trasy (vyhlazená), plochý pás kolem ní
	path = PathData.from_polyline(path_poly)
	var np: int = path.pts.size()
	var rawp: PackedFloat32Array = PackedFloat32Array()
	rawp.resize(np)
	for i in range(np):
		rawp[i] = sample_grid(h1, path.pts[i].x, path.pts[i].y)
	path.ys = _smooth(rawp, 12)
	var ps: Array = _stamp(path.pts, 5.0)
	path_d = ps[0]
	path_i = ps[1]
	var h2: PackedFloat32Array = h1.duplicate()
	for k in range(total):
		var dp: float = path_d[k]
		var pi: int = path_i[k]
		if dp < PATH_HALF + 3.5 and pi >= 0:
			var w2: float = 1.0 - smoothstep(PATH_HALF + 0.35, PATH_HALF + 3.4, dp)
			h2[k] = lerpf(h1[k], path.ys[pi], w2)

	# 4) koryto řeky
	hm = h2.duplicate()
	for k in range(total):
		var dr2: float = river_d[k]
		var ri2: int = river_i[k]
		if ri2 < 0:
			continue
		var hw2: float = river.half_w[ri2]
		if dr2 > hw2 + 1.9:
			continue
		var wl: float = river.water_y[ri2]
		var hnew: float
		if dr2 <= hw2:
			var u: float = dr2 / hw2
			hnew = wl - 0.16 - 0.56 * (1.0 - u * u)
		else:
			hnew = lerpf(wl - 0.16, h2[k], smoothstep(hw2, hw2 + 1.9, dr2))
		hm[k] = minf(h2[k], hnew) if dr2 > hw2 else hnew


# ------------------------------------------------------------------ textury pro shader
func make_field_image() -> Image:
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBA8)
	for gz in range(N):
		for gx in range(N):
			var k: int = gz * N + gx
			var psd: float = path_d[k] - PATH_HALF
			var rsd: float = 99.0
			if river_i[k] >= 0:
				rsd = river_d[k] - river.half_w[river_i[k]]
			img.set_pixel(gx, gz, Color(clampf((psd + 4.0) / FIELD_RANGE, 0.0, 1.0), clampf((rsd + 4.0) / FIELD_RANGE, 0.0, 1.0), 0.0, 1.0))
	return img


func make_biome_image() -> Image:
	var img: Image = Image.create(N, N, false, Image.FORMAT_RGBA8)
	for gz in range(N):
		for gx in range(N):
			img.set_pixel(gx, gz, biome_weights(float(gx) * STEP - HALF, float(gz) * STEP - HALF))
	return img
