class_name Decor
extends RefCounted
## Rozmístění stromů, skal, trávy, květin a rákosu po ostrově (MultiMesh => pár draw callů, vítr ve shaderu).

const SOLID_KEYS: Array = ["rock", "rock2", "rock_snow", "rock_desert"]


static func _xf(pos: Vector3, yaw: float, scl: float, tilt: float = 0.0) -> Transform3D:
	var b: Basis = Basis(Vector3.UP, yaw)
	if tilt != 0.0:
		b = b * Basis(Vector3.RIGHT, tilt)
	b = b * Basis.from_scale(Vector3(scl, scl, scl))
	return Transform3D(b, pos)


static func _add(buckets: Dictionary, key: String, t: Transform3D) -> void:
	if not buckets.has(key):
		buckets[key] = []
	(buckets[key] as Array).append(t)


static func _variant(kind: String, rng: RandomNumberGenerator) -> String:
	match kind:
		"pine":
			return "pine" if rng.randf() < 0.6 else "pine2"
		"oak":
			var r: float = rng.randf()
			if r < 0.55:
				return "oak"
			if r < 0.85:
				return "oak2"
			return "oak3"
		"rock":
			return "rock" if rng.randf() < 0.55 else "rock2"
		_:
			return kind


static func _radius(key: String) -> float:
	if key.begins_with("pine"):
		return 0.95
	if key.begins_with("oak"):
		return 1.15
	if key == "palm":
		return 0.8
	if key == "cactus" or key == "bush":
		return 0.55
	return 0.8


static func build(map: GameMap, density: float = 1.0, props: PropSet = null) -> Node3D:
	if props == null:
		props = SkyProps.new()
	var root: Node3D = Node3D.new()
	root.name = "Decor"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var t: Terrain = map.terrain
	var buckets: Dictionary = {}

	# --- 1) překážky v herní mřížce (každá v jedné buňce)
	for ob in map.obstacles:
		var key: String = _variant(str(ob["kind"]), rng)
		var pos: Vector3 = ob["pos"]
		var scl: float = rng.randf_range(0.9, 1.2)
		if key.begins_with("rock"):
			scl = rng.randf_range(0.85, 1.15)
		_add(buckets, key, _xf(pos + Vector3(0.0, -0.05, 0.0), rng.randf() * TAU, scl))

	# --- 2) volné stromy a skály mimo hrací pole
	var occupied: Dictionary = {}
	var tries: int = int(3200.0 * density)
	for i in range(tries):
		var x: float = rng.randf_range(-34.0, 34.0)
		var z: float = rng.randf_range(-34.0, 34.0)
		if not map.decor_ok(x, z):
			continue
		var bw: Color = t.biome_weights(x, z)
		var biome: int = t.dominant_biome(x, z)
		var kind: String = ""
		var r: float = rng.randf()
		match biome:
			0:
				if r < 0.50: kind = "pine"
				elif r < 0.82: kind = "oak"
				elif r < 0.90: kind = "rock"
				elif r < 0.95: kind = "bush"
			1:
				if r < 0.28: kind = "oak"
				elif r < 0.50: kind = "bush"
				elif r < 0.58: kind = "rock"
			2:
				if r < 0.26: kind = "cactus"
				elif r < 0.46: kind = "palm"
				elif r < 0.60: kind = "rock_desert"
			_:
				if r < 0.62: kind = "pine_snow"
				elif r < 0.74: kind = "rock_snow"
		if kind == "":
			continue
		var accept: float = bw.r * 1.0 + bw.g * 0.7 + bw.b * 0.55 + bw.a * 0.8
		if rng.randf() > accept:
			continue
		var key2: String = _variant(kind, rng)
		var rad: float = _radius(key2)
		# rozestup od ostatních
		var hx: int = int(floor(x / 2.0))
		var hz: int = int(floor(z / 2.0))
		var blocked: bool = false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var hk: Vector2i = Vector2i(hx + dx, hz + dz)
				if occupied.has(hk):
					for q in occupied[hk]:
						var qq: Vector3 = q
						if Vector2(x - qq.x, z - qq.y).length() < rad + qq.z - 0.35:
							blocked = true
		if blocked:
			continue
		var hk2: Vector2i = Vector2i(hx, hz)
		if not occupied.has(hk2):
			occupied[hk2] = []
		(occupied[hk2] as Array).append(Vector3(x, z, rad))
		var s: float = rng.randf_range(0.85, 1.3)
		if key2.begins_with("rock"):
			s = rng.randf_range(0.7, 1.6)
		_add(buckets, key2, _xf(Vector3(x, t.height_at(x, z) - 0.05, z), rng.randf() * TAU, s))

	# --- 3) tráva a květiny
	var grass_tries: int = int(26000.0 * density)
	for i in range(grass_tries):
		var x2: float = rng.randf_range(-32.0, 32.0)
		var z2: float = rng.randf_range(-32.0, 32.0)
		if t.edge_dist(x2, z2) < 0.35:
			continue
		if t.path_dist_at(x2, z2) < 1.15:
			continue
		if t.river_sd_at(x2, z2) < 0.5:
			continue
		var w2: Color = t.biome_weights(x2, z2)
		var rr: float = rng.randf()
		var gk: String = ""
		if rr < w2.r:
			gk = "grass_forest"
		elif rr < w2.r + w2.g:
			gk = "grass_meadow"
		elif rr < w2.r + w2.g + w2.b:
			gk = "grass_dry" if rng.randf() < 0.22 else ""
		else:
			gk = "grass_snow" if rng.randf() < 0.10 else ""
		if gk == "":
			continue
		var gy: float = t.height_at(x2, z2)
		_add(buckets, gk, _xf(Vector3(x2, gy - 0.02, z2), rng.randf() * TAU, rng.randf_range(0.8, 1.4)))
		if gk == "grass_meadow" and rng.randf() < 0.07:
			var fk: String = ["flower_white", "flower_yellow", "flower_pink", "flower_blue"][rng.randi() % 4]
			_add(buckets, fk, _xf(Vector3(x2 + rng.randf_range(-0.2, 0.2), gy - 0.02, z2 + rng.randf_range(-0.2, 0.2)), rng.randf() * TAU, rng.randf_range(0.8, 1.3)))

	# --- 4) rákos u řeky
	var rv: RiverData = t.river
	var i2: int = 0
	while i2 < rv.end_index:
		var d: Vector2 = rv.dir_at_index(i2)
		var nn: Vector2 = Vector2(-d.y, d.x)
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.6:
				var off: float = rv.half_w[i2] + rng.randf_range(0.15, 0.9)
				var rx: float = rv.pts[i2].x + nn.x * off * float(side)
				var rz: float = rv.pts[i2].y + nn.y * off * float(side)
				if t.edge_dist(rx, rz) > 0.5 and t.path_dist_at(rx, rz) > 1.6:
					_add(buckets, "reed", _xf(Vector3(rx, t.height_at(rx, rz) - 0.05, rz), rng.randf() * TAU, rng.randf_range(0.8, 1.25)))
		i2 += 2

	# --- 5) kamínky podél cesty
	var p: PathData = t.path
	var s_path: float = 1.0
	while s_path < p.length - 1.0:
		var pos2: Vector3 = p.pos_at(s_path)
		var dir2: Vector2 = p.dir_at(s_path)
		var nrm2: Vector2 = Vector2(-dir2.y, dir2.x)
		var sd: float = 1.0 if rng.randf() < 0.5 else -1.0
		var off2: float = rng.randf_range(1.05, 1.5) * sd
		var px: float = pos2.x + nrm2.x * off2
		var pz: float = pos2.z + nrm2.y * off2
		if t.river_sd_at(px, pz) > 0.8 and not map.is_on_bridge(s_path):
			var kk: String = "rock_snow" if t.dominant_biome(px, pz) == 3 else ("rock_desert" if t.dominant_biome(px, pz) == 2 else "rock2")
			_add(buckets, "pebble:" + kk, _xf(Vector3(px, t.height_at(px, pz) - 0.04, pz), rng.randf() * TAU, rng.randf_range(0.16, 0.3)))
		s_path += rng.randf_range(0.9, 2.2)

	# --- MultiMesh uzly
	for key3 in buckets.keys():
		var arr: Array = buckets[key3]
		if arr.is_empty():
			continue
		var mesh_key: String = str(key3)
		if mesh_key.begins_with("pebble:"):
			mesh_key = mesh_key.substr(7)
		var mesh: ArrayMesh = props.get_mesh(mesh_key)
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for j in range(arr.size()):
			mm.set_instance_transform(j, arr[j])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "MM_" + str(key3).replace(":", "_")
		mmi.multimesh = mm
		mmi.material_override = props.material_for(mesh_key)
		if props.no_shadow(mesh_key):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root
