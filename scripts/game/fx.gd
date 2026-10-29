class_name Fx
extends Node3D
## Efekty řízené herním časem (tick): puffy, rázové vlny, úlomky s odrazem od terénu, plovoucí texty, blesky.
## Uzly se recyklují (pool), aby ve hře nevznikalo zbytečné smetí.

var map: GameMap = null
var rig = null                    # CameraRig – plovoucí texty drží stálou velikost na obrazovce při zoomu

var _puff_free: Array = []
var _puffs: Array = []
var _ring_free: Array = []
var _rings: Array = []
var _text_free: Array = []
var _texts: Array = []
var _debris: Array = []
var _beams: Array = []
var _disc: ArrayMesh = null
var _quad: QuadMesh = null
var _box_cache: Dictionary = {}
var _scorches: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const MAX_SCORCH: int = 14


func _init() -> void:
	name = "Fx"
	_rng.seed = 2024


func _ready() -> void:
	_disc = Gfx.disc_mesh(1.0, 36)
	_quad = QuadMesh.new()
	_quad.size = Vector2(1.0, 1.0)


# ------------------------------------------------------------------ puffy
func puff(pos: Vector3, color: Color, size0: float, size1: float, life: float, rise: float = 0.0,
		glow: float = 0.0, alpha: float = 0.8, vel: Vector3 = Vector3.ZERO) -> void:
	var e: Dictionary
	if _puff_free.is_empty():
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = Gfx.SH_PUFF
		mi.material_override = m
		add_child(mi)
		e = {"node": mi, "mat": m}
	else:
		e = _puff_free.pop_back()
	var node: MeshInstance3D = e["node"]
	var mat: ShaderMaterial = e["mat"]
	node.visible = true
	node.position = pos
	node.scale = Vector3.ONE * size0
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("alpha", alpha)
	e["age"] = 0.0
	e["life"] = maxf(life, 0.05)
	e["s0"] = size0
	e["s1"] = size1
	e["rise"] = rise
	e["alpha"] = alpha
	e["vel"] = vel
	_puffs.append(e)


func burst_puffs(pos: Vector3, color: Color, count: int, spread: float, size: float, life: float, glow: float = 0.0) -> void:
	for i in range(count):
		var d: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.0, 1.0), _rng.randf_range(-1.0, 1.0))
		puff(pos + d * spread * 0.3, color, size * 0.5, size * _rng.randf_range(1.0, 1.7), life * _rng.randf_range(0.7, 1.2),
			0.2, glow, 0.85, d * spread * 1.4)


# ------------------------------------------------------------------ prstence
func ring(pos: Vector3, color: Color, radius_end: float, life: float, thickness: float = 0.16, fill: float = 0.2, glow: float = 0.5) -> void:
	var e: Dictionary
	if _ring_free.is_empty():
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = _disc
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = Gfx.SH_RING
		mi.material_override = m
		add_child(mi)
		e = {"node": mi, "mat": m}
	else:
		e = _ring_free.pop_back()
	var node: MeshInstance3D = e["node"]
	var mat: ShaderMaterial = e["mat"]
	node.visible = true
	node.position = pos
	node.scale = Vector3(0.1, 1.0, 0.1)
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("thickness", thickness)
	mat.set_shader_parameter("fill", fill)
	mat.set_shader_parameter("glow", glow)
	mat.set_shader_parameter("alpha", 1.0)
	e["age"] = 0.0
	e["life"] = maxf(life, 0.05)
	e["r1"] = radius_end
	_rings.append(e)


# ------------------------------------------------------------------ texty
func text(pos: Vector3, s: String, color: Color, size: float = 1.0, life: float = 1.0) -> void:
	var e: Dictionary
	if _text_free.is_empty():
		var l: Label3D = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.shaded = false
		l.double_sided = true
		l.fixed_size = false
		l.font_size = 56
		l.outline_size = 14
		l.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
		l.render_priority = 5
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(l)
		e = {"node": l}
	else:
		e = _text_free.pop_back()
	var node: Label3D = e["node"]
	node.visible = true
	node.text = s
	node.modulate = color
	node.pixel_size = 0.024 * size
	node.position = pos
	var zf0: float = 1.0 if rig == null else rig.zoom_size / 44.0
	node.scale = Vector3.ONE * zf0
	e["age"] = 0.0
	e["life"] = life
	e["color"] = color
	_texts.append(e)


# ------------------------------------------------------------------ úlomky
func _debris_mesh(col: Color) -> ArrayMesh:
	var key: String = col.to_html()
	if _box_cache.has(key):
		return _box_cache[key]
	var k: MeshKit = MeshKit.new(3, 0.1)
	k.box(Vector3(1.0, 1.0, 1.0), col)
	var m: ArrayMesh = k.build()
	_box_cache[key] = m
	return m


func debris(pos: Vector3, color: Color, count: int, speed: float, size: float, life: float = 1.2, emit: float = 0.0) -> void:
	for i in range(count):
		var mi: MeshInstance3D = MeshInstance3D.new()
		var col: Color = color
		if emit > 0.0:
			col = Color(color.r, color.g, color.b, emit)
		mi.mesh = _debris_mesh(col)
		mi.material_override = Gfx.model_mat(0.9)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s: float = size * _rng.randf_range(0.5, 1.2)
		mi.scale = Vector3(s, s, s)
		mi.position = pos
		add_child(mi)
		var a: float = _rng.randf() * TAU
		var up: float = _rng.randf_range(0.5, 1.2)
		_debris.append({
			"node": mi,
			"vel": Vector3(cos(a), up, sin(a)) * speed * _rng.randf_range(0.5, 1.1) + Vector3(0.0, speed * 0.5, 0.0),
			"spin": Vector3(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0)),
			"age": 0.0,
			"life": life * _rng.randf_range(0.7, 1.2),
			"s": s,
		})


# ------------------------------------------------------------------ blesk
func beam(points: Array, color: Color, life: float = 0.18, width: float = 0.07) -> void:
	if points.size() < 2:
		return
	var k: MeshKit = MeshKit.new(1, 0.0)
	var pts: Array = []
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var segs: int = maxi(int(a.distance_to(b) / 0.55), 2)
		for j in range(segs):
			var t: float = float(j) / float(segs)
			var p: Vector3 = a.lerp(b, t)
			if j > 0:
				p += Vector3(_rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.18, 0.18), _rng.randf_range(-0.22, 0.22))
			pts.append(p)
	pts.append(points[points.size() - 1])
	for i2 in range(pts.size() - 1):
		var p0: Vector3 = pts[i2]
		var p1: Vector3 = pts[i2 + 1]
		var d: Vector3 = p1 - p0
		var len2: float = d.length()
		if len2 < 0.001:
			continue
		var basis: Basis = Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
		k.box(Vector3(width, width, len2), Color(color.r, color.g, color.b, 3.0), Transform3D(basis, (p0 + p1) * 0.5))
	var mi: MeshInstance3D = Gfx.mesh_node(k, Gfx.model_mat(0.3), false)
	add_child(mi)
	_beams.append({"node": mi, "age": 0.0, "life": life})


# ------------------------------------------------------------------ spálené skvrny
## Tmavá skvrna přilepená na terén, pomalu mizí (jen ve vysoké kvalitě). Tvar sleduje terén.
func scorch(pos: Vector3, radius: float, alpha: float = 0.5, life: float = 12.0) -> void:
	if not Gfx.quality_high or map == null:
		return
	var segs: int = 20
	var rings: int = 3
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()
	verts.append(Vector3(pos.x, map.height_at(pos.x, pos.z) + 0.07, pos.z))
	uvs.append(Vector2(0.5, 0.5))
	for r in range(1, rings + 1):
		var rr: float = radius * float(r) / float(rings)
		for i in range(segs):
			var a: float = TAU * float(i) / float(segs)
			var x: float = pos.x + cos(a) * rr
			var z: float = pos.z + sin(a) * rr
			verts.append(Vector3(x, map.height_at(x, z) + 0.07, z))
			uvs.append(Vector2(0.5 + 0.5 * cos(a) * float(r) / float(rings), 0.5 + 0.5 * sin(a) * float(r) / float(rings)))
	for i2 in range(segs):
		var i3: int = (i2 + 1) % segs
		idx.append_array([0, 1 + i2, 1 + i3])
	for r2 in range(1, rings):
		var b0: int = 1 + (r2 - 1) * segs
		var b1: int = 1 + r2 * segs
		for i4 in range(segs):
			var i5: int = (i4 + 1) % segs
			idx.append_array([b0 + i4, b1 + i4, b1 + i5, b0 + i4, b1 + i5, b0 + i5])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = Gfx.SH_SCORCH
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("seed", _rng.randf() * 20.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_scorches.append({"node": mi, "mat": m, "age": 0.0, "life": life, "alpha": alpha})
	while _scorches.size() > MAX_SCORCH:
		var old: Dictionary = _scorches.pop_front()
		(old["node"] as Node).queue_free()


func scorch_count() -> int:
	return _scorches.size()


# ------------------------------------------------------------------ hotové kombinace
## Prstenec prachu rozlétající se po zemi (stavba věže, dopad).
func dust_ring(pos: Vector3, color: Color, count: int, radius: float, size: float) -> void:
	for i in range(count):
		var a: float = TAU * float(i) / float(count) + _rng.randf() * 0.4
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
		puff(pos + dir * radius * 0.25 + Vector3(0.0, 0.1, 0.0), color, size * 0.5, size * _rng.randf_range(1.0, 1.7),
			_rng.randf_range(0.5, 0.85), 0.15, 0.0, 0.6, dir * radius * 2.4)


## Záblesk a jiskry u ústí (dir = směr výstřelu).
func muzzle_flash(pos: Vector3, dir: Vector3, color: Color, size: float, sparks: int = 3) -> void:
	puff(pos, Color(1.0, 0.95, 0.8), size * 0.4, size, 0.09, 0.0, 3.0, 0.95)
	puff(pos + dir * size * 0.35, color, size * 0.3, size * 1.2, 0.12, 0.0, 2.2, 0.8)
	var n: int = sparks if Gfx.quality_high else 0
	for i in range(n):
		var d: Vector3 = (dir + Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.2, 0.35), _rng.randf_range(-0.35, 0.35))).normalized()
		puff(pos, color, size * 0.18, 0.02, 0.22, 0.0, 3.0, 0.9, d * size * 7.0)


func ground_y(x: float, z: float) -> float:
	if map != null:
		return map.height_at(x, z)
	return 0.0


func explosion(pos: Vector3, radius: float) -> void:
	var gy: float = ground_y(pos.x, pos.z)
	burst_puffs(pos + Vector3(0, 0.3, 0), Color(1.0, 0.65, 0.2), 8, radius * 0.9, radius * 0.9, 0.5, 1.4)
	burst_puffs(pos + Vector3(0, 0.4, 0), Color(0.35, 0.33, 0.32), 7, radius * 0.9, radius * 1.2, 0.9, 0.0)
	ring(Vector3(pos.x, gy + 0.2, pos.z), Color(1.0, 0.7, 0.3), radius, 0.4, 0.2, 0.25, 0.8)
	debris(pos, Color(0.45, 0.36, 0.26), 8, 4.0, 0.14, 1.0)


func death_burst(pos: Vector3, color: Color, big: bool = false) -> void:
	var n: int = 14 if big else 6
	debris(pos + Vector3(0, 0.4, 0), color, n, 4.0 if big else 3.0, 0.2 if big else 0.12, 1.1)
	burst_puffs(pos + Vector3(0, 0.4, 0), Color(0.95, 0.95, 0.9), 5 if not big else 10, 1.0 if not big else 2.0, 0.6 if not big else 1.2, 0.5, 0.2)


func hit_spark(pos: Vector3, color: Color) -> void:
	burst_puffs(pos, color, 3, 0.35, 0.22, 0.25, 1.5)


# ------------------------------------------------------------------ aktualizace
func tick(dt: float) -> void:
	# puffy
	var i: int = _puffs.size() - 1
	while i >= 0:
		var e: Dictionary = _puffs[i]
		e["age"] = float(e["age"]) + dt
		var t: float = float(e["age"]) / float(e["life"])
		var node: MeshInstance3D = e["node"]
		if t >= 1.0:
			node.visible = false
			_puff_free.append(e)
			_puffs.remove_at(i)
		else:
			var v: Vector3 = e["vel"]
			node.position += (v + Vector3(0.0, float(e["rise"]), 0.0)) * dt
			e["vel"] = v * maxf(1.0 - dt * 3.0, 0.0)
			node.scale = Vector3.ONE * lerpf(float(e["s0"]), float(e["s1"]), sqrt(t))
			(e["mat"] as ShaderMaterial).set_shader_parameter("alpha", float(e["alpha"]) * (1.0 - t * t))
		i -= 1
	# prstence
	i = _rings.size() - 1
	while i >= 0:
		var r: Dictionary = _rings[i]
		r["age"] = float(r["age"]) + dt
		var t2: float = float(r["age"]) / float(r["life"])
		var rn: MeshInstance3D = r["node"]
		if t2 >= 1.0:
			rn.visible = false
			_ring_free.append(r)
			_rings.remove_at(i)
		else:
			var rad: float = float(r["r1"]) * (1.0 - pow(1.0 - t2, 2.2))
			rn.scale = Vector3(maxf(rad, 0.05), 1.0, maxf(rad, 0.05))
			(r["mat"] as ShaderMaterial).set_shader_parameter("alpha", 1.0 - t2 * t2)
		i -= 1
	# texty
	var zf: float = 1.0 if rig == null else rig.zoom_size / 44.0
	i = _texts.size() - 1
	while i >= 0:
		var tx: Dictionary = _texts[i]
		tx["age"] = float(tx["age"]) + dt
		var t3: float = float(tx["age"]) / float(tx["life"])
		var ln: Label3D = tx["node"]
		if t3 >= 1.0:
			ln.visible = false
			_text_free.append(tx)
			_texts.remove_at(i)
		else:
			ln.position.y += dt * 1.1 * zf
			ln.scale = Vector3.ONE * zf
			var col: Color = tx["color"]
			ln.modulate = Color(col.r, col.g, col.b, col.a * (1.0 - smoothstep(0.55, 1.0, t3)))
		i -= 1
	# úlomky
	i = _debris.size() - 1
	while i >= 0:
		var d: Dictionary = _debris[i]
		d["age"] = float(d["age"]) + dt
		var dn: MeshInstance3D = d["node"]
		var tt: float = float(d["age"]) / float(d["life"])
		if tt >= 1.0:
			dn.queue_free()
			_debris.remove_at(i)
		else:
			var v2: Vector3 = d["vel"]
			v2.y -= 16.0 * dt
			dn.position += v2 * dt
			var gy: float = ground_y(dn.position.x, dn.position.z) + float(d["s"]) * 0.4
			if dn.position.y < gy:
				dn.position.y = gy
				if v2.y < 0.0:
					v2.y = -v2.y * 0.35
					v2.x *= 0.6
					v2.z *= 0.6
			d["vel"] = v2
			var sp: Vector3 = d["spin"]
			dn.rotation += sp * dt * (1.0 - tt)
			var s: float = float(d["s"]) * (1.0 - smoothstep(0.7, 1.0, tt))
			dn.scale = Vector3(s, s, s)
		i -= 1
	# spálené skvrny
	i = _scorches.size() - 1
	while i >= 0:
		var sc: Dictionary = _scorches[i]
		sc["age"] = float(sc["age"]) + dt
		var tk: float = float(sc["age"]) / float(sc["life"])
		if tk >= 1.0:
			(sc["node"] as Node).queue_free()
			_scorches.remove_at(i)
		else:
			(sc["mat"] as ShaderMaterial).set_shader_parameter("alpha", float(sc["alpha"]) * (1.0 - smoothstep(0.5, 1.0, tk)))
		i -= 1
	# blesky
	i = _beams.size() - 1
	while i >= 0:
		var b: Dictionary = _beams[i]
		b["age"] = float(b["age"]) + dt
		var bn: MeshInstance3D = b["node"]
		if float(b["age"]) >= float(b["life"]):
			bn.queue_free()
			_beams.remove_at(i)
		else:
			bn.visible = int(float(b["age"]) * 60.0) % 2 == 0 or float(b["age"]) < 0.06
		i -= 1


func clear_all() -> void:
	for e in _puffs:
		(e["node"] as Node3D).visible = false
		_puff_free.append(e)
	_puffs.clear()
	for r in _rings:
		(r["node"] as Node3D).visible = false
		_ring_free.append(r)
	_rings.clear()
	for t in _texts:
		(t["node"] as Node3D).visible = false
		_text_free.append(t)
	_texts.clear()
	for d in _debris:
		(d["node"] as Node).queue_free()
	_debris.clear()
	for b in _beams:
		(b["node"] as Node).queue_free()
	_beams.clear()
	for sc2 in _scorches:
		(sc2["node"] as Node).queue_free()
	_scorches.clear()
