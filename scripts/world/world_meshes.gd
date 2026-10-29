class_name WorldMeshes
extends RefCounted
## Generování sítí ostrova (polární mřížka: horní plocha → útes → skalnatý spodek), řeky a vodopádu.

const NTH: int = 240      # úhlové dělení
const NR: int = 76        # prstence horní plochy
const NB: int = 18        # prstence útesu/spodku
const BELLY_DEPTH: float = 28.0


# ------------------------------------------------------------------ pomocné
static func _outward_normal(p0: Vector3, p1: Vector3, p2: Vector3) -> Vector3:
	## Trojúhelník (p0,p1,p2) je v Godotu přivrácený, když je po směru hodin => vnější normála = (p2-p0) x (p1-p0).
	return (p2 - p0).cross(p1 - p0)


static func _calc_normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var nrm: PackedVector3Array = PackedVector3Array()
	nrm.resize(verts.size())
	var t: int = 0
	while t < idx.size():
		var a: int = idx[t]
		var b: int = idx[t + 1]
		var c: int = idx[t + 2]
		var fn: Vector3 = _outward_normal(verts[a], verts[b], verts[c])
		nrm[a] += fn
		nrm[b] += fn
		nrm[c] += fn
		t += 3
	for i in range(nrm.size()):
		if nrm[i].length_squared() > 1e-12:
			nrm[i] = nrm[i].normalized()
		else:
			nrm[i] = Vector3.UP
	return nrm


# ------------------------------------------------------------------ ostrov
static func build_island(t: Terrain, fall_theta: float = 999.0) -> ArrayMesh:
	## fall_theta = úhel, kde řeka opouští ostrov – tam se spodek stáhne dovnitř, aby vodopád padal volně před skálou.
	var rings: int = NR + 1 + NB
	var verts: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	verts.resize(rings * NTH)
	cols.resize(rings * NTH)

	var n_rock: FastNoiseLite = FastNoiseLite.new()
	n_rock.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_rock.seed = t.seed_value + 40
	n_rock.frequency = 1.0
	n_rock.fractal_octaves = 3
	var n_spike: FastNoiseLite = FastNoiseLite.new()
	n_spike.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_spike.seed = t.seed_value + 41
	n_spike.frequency = 1.0

	for i in range(NTH):
		var th: float = TAU * float(i) / float(NTH)
		var ct: float = cos(th)
		var st: float = sin(th)
		var rim_r: float = t.outline_r(th)
		var rim_y: float = 0.0
		var fall_g: float = 0.0
		if fall_theta < 100.0:
			var dth: float = absf(angle_difference(th, fall_theta))
			fall_g = exp(-pow(dth / 0.17, 2.0))
		for k in range(NR + 1):
			var u: float = float(k) / float(NR)
			var r: float = rim_r * u
			var x: float = ct * r
			var z: float = st * r
			var y: float = t.height_at(x, z)
			verts[k * NTH + i] = Vector3(x, y, z)
			cols[k * NTH + i] = Color(1, 1, 1, 1)
			if k == NR:
				rim_y = y
		for j in range(1, NB + 1):
			var tt: float = float(j) / float(NB)
			var rf: float = 1.0 - pow(tt, 1.25) * 0.985
			var wob: float = n_rock.get_noise_2d(ct * 1.7 + tt * 3.1, st * 1.7 - tt * 2.3)
			rf *= 1.0 + 0.11 * wob * sin(PI * minf(tt * 1.15, 1.0)) * (1.0 - fall_g)
			rf += 0.012 * sin(tt * 30.0 + float(i) * 0.37) * (1.0 - tt)
			rf *= 1.0 - fall_g * 0.2 * minf(tt * 5.0, 1.0)
			rf = maxf(rf, 0.0)
			var dy: float = BELLY_DEPTH * pow(tt, 0.85)
			var spike: float = maxf(n_spike.get_noise_2d(ct * 2.6 + 7.0, st * 2.6 - 3.0), 0.0)
			dy += spike * spike * 9.0 * pow(tt, 1.4) * (1.0 - fall_g)
			var x2: float = ct * rim_r * rf
			var z2: float = st * rim_r * rf
			var y2: float = rim_y - dy
			if j == NB:
				x2 = 0.0
				z2 = 0.0
				y2 = -BELLY_DEPTH - 3.0
			verts[(NR + j) * NTH + i] = Vector3(x2, y2, z2)
			var ca: Color = Color(0.50, 0.42, 0.34)
			var cb: Color = Color(0.46, 0.43, 0.43)
			var cc: Color = Color(0.52, 0.55, 0.66)
			var col: Color = ca.lerp(cb, clampf(tt * 2.2, 0.0, 1.0)).lerp(cc, clampf((tt - 0.45) * 1.8, 0.0, 1.0))
			cols[(NR + j) * NTH + i] = Color(col.r, col.g, col.b, 0.35 if j == 1 else 0.0)

	var idx: PackedInt32Array = PackedInt32Array()
	for k in range(rings - 1):
		for i in range(NTH):
			var i2: int = (i + 1) % NTH
			var a: int = k * NTH + i
			var b: int = k * NTH + i2
			var c: int = (k + 1) * NTH + i
			var d: int = (k + 1) * NTH + i2
			idx.append(a)
			idx.append(c)
			idx.append(b)
			idx.append(b)
			idx.append(c)
			idx.append(d)

	# kontrola orientace: horní plocha musí mít vnější normálu nahoru, jinak otočit všechny trojúhelníky
	var probe: int = (NR / 2) * NTH * 6
	var n0: Vector3 = _outward_normal(verts[idx[probe]], verts[idx[probe + 1]], verts[idx[probe + 2]])
	if n0.y < 0.0:
		var q: int = 0
		while q < idx.size():
			var tmp: int = idx[q + 1]
			idx[q + 1] = idx[q + 2]
			idx[q + 2] = tmp
			q += 3

	var nrm: PackedVector3Array = _calc_normals(verts, idx)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ------------------------------------------------------------------ řeka
## Vrací {mesh, end_index, lip: Vector3, flow: Vector2, half_w: float}
static func build_river(t: Terrain) -> Dictionary:
	var rv: RiverData = t.river
	var n: int = rv.pts.size()
	# kde řeka opouští ostrov
	var end_i: int = n - 1
	for i in range(n):
		if t.edge_dist(rv.pts[i].x, rv.pts[i].y) <= 0.3:
			end_i = i
			break
	rv.end_index = end_i

	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var tang: PackedFloat32Array = PackedFloat32Array()
	var idx: PackedInt32Array = PackedInt32Array()
	for i in range(end_i + 1):
		var p: Vector2 = rv.pts[i]
		var d: Vector2 = rv.dir_at_index(i)
		var nn: Vector2 = Vector2(-d.y, d.x)
		var hw: float = rv.half_w[i] + 0.12
		var y: float = rv.water_y[i]
		verts.append(Vector3(p.x - nn.x * hw, y, p.y - nn.y * hw))
		verts.append(Vector3(p.x + nn.x * hw, y, p.y + nn.y * hw))
		uvs.append(Vector2(float(i) * RiverData.STEP, -1.0))
		uvs.append(Vector2(float(i) * RiverData.STEP, 1.0))
		nrm.append(Vector3.UP)
		nrm.append(Vector3.UP)
		for k in range(2):
			tang.append(d.x)
			tang.append(0.0)
			tang.append(d.y)
			tang.append(1.0)
	for i in range(end_i):
		var a: int = i * 2
		var b: int = i * 2 + 1
		var c: int = (i + 1) * 2
		var dd: int = (i + 1) * 2 + 1
		_append_up_tri(verts, idx, a, b, c)
		_append_up_tri(verts, idx, b, dd, c)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TANGENT] = tang
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var lip_p: Vector2 = rv.pts[end_i]
	return {
		"mesh": mesh,
		"end_index": end_i,
		"lip": Vector3(lip_p.x, rv.water_y[end_i], lip_p.y),
		"flow": rv.dir_at_index(end_i),
		"half_w": rv.half_w[end_i],
	}


## Přidá trojúhelník tak, aby jeho přední strana směřovala nahoru (po směru hodin při pohledu shora).
static func _append_up_tri(verts: PackedVector3Array, idx: PackedInt32Array, a: int, b: int, c: int) -> void:
	var n_rh: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if n_rh.y > 0.0:
		idx.append(a)
		idx.append(c)
		idx.append(b)
	else:
		idx.append(a)
		idx.append(b)
		idx.append(c)


# ------------------------------------------------------------------ vodopád
static func build_waterfall(lip: Vector3, flow: Vector2, half_w: float, fall_len: float = 32.0) -> ArrayMesh:
	var segs: int = 28
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var across: Vector2 = Vector2(-flow.y, flow.x)
	for s in range(segs + 1):
		var dsc: float = fall_len * float(s) / float(segs)
		var out: float = 1.4 * sqrt(dsc / 4.9)               # vodorovný dolet padající vody
		var base: Vector2 = Vector2(lip.x, lip.z) + flow * (0.35 + out)
		var widen: float = 1.0 + dsc * 0.012
		var l: Vector2 = base - across * half_w * widen
		var r: Vector2 = base + across * half_w * widen
		var y: float = lip.y - dsc
		verts.append(Vector3(l.x, y, l.y))
		verts.append(Vector3(r.x, y, r.y))
		uvs.append(Vector2(0.0, dsc))
		uvs.append(Vector2(1.0, dsc))
		nrm.append(Vector3(flow.x, 0.0, flow.y))
		nrm.append(Vector3(flow.x, 0.0, flow.y))
	for s in range(segs):
		var a: int = s * 2
		var b: int = s * 2 + 1
		var c: int = (s + 1) * 2
		var d: int = (s + 1) * 2 + 1
		idx.append(a)
		idx.append(b)
		idx.append(c)
		idx.append(b)
		idx.append(d)
		idx.append(c)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
