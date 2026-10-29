class_name SciFiWorld
extends RefCounted
## Poskládá svět „vesmírná stanice“ do uzlu `parent`: plošina na asteroidu s neonovými biomy, energetická řeka a vodopád,
## kulisy, hvězdná brána, reaktor a živá scenérie. Vrací stejné odkazy jako WorldBuilder.

const SH_TERRAIN: Shader = preload("res://shaders/terrain_scifi.gdshader")
const SH_RIVER: Shader = preload("res://shaders/energy_river.gdshader")
const SH_FALL: Shader = preload("res://shaders/energy_fall.gdshader")


static func make_environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.65, 0.96)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.15
	env.glow_bloom = 0.07
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.05, 0.06, 0.16)
	env.fog_depth_begin = 150.0
	env.fog_depth_end = 300.0
	env.fog_depth_curve = 1.0
	env.fog_density = 0.55
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	return env


static func make_sun(high_quality: bool) -> DirectionalLight3D:
	## Hlavní světlo: chladné hvězdné slunce.
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -128.0, 0.0)
	sun.light_color = Color(0.90, 0.95, 1.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 230.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.4
	sun.shadow_blur = 1.3 if high_quality else 1.0
	return sun


static func build(parent: Node3D, map: GameMap, high_quality: bool = true) -> Dictionary:
	var t: Terrain = map.terrain
	var out: Dictionary = {}

	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = make_environment()
	parent.add_child(we)
	var sun: DirectionalLight3D = make_sun(high_quality)
	parent.add_child(sun)
	out["sun"] = sun
	out["environment"] = we.environment
	# doplňkové purpurové světlo z opačné strany (bez stínů): neonový odlesk
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.name = "Rim"
	rim.rotation_degrees = Vector3(-25.0, 52.0, 0.0)
	rim.light_color = Color(0.85, 0.35, 1.0)
	rim.light_energy = 0.45
	rim.shadow_enabled = false
	parent.add_child(rim)

	var rv: Dictionary = WorldMeshes.build_river(t)
	var lip: Vector3 = rv["lip"]

	var island: MeshInstance3D = MeshInstance3D.new()
	island.name = "Island"
	island.mesh = WorldMeshes.build_island(t, atan2(lip.z, lip.x))
	var tm: ShaderMaterial = ShaderMaterial.new()
	tm.shader = SH_TERRAIN
	tm.set_shader_parameter("field_tex", ImageTexture.create_from_image(t.make_field_image()))
	tm.set_shader_parameter("biome_tex", ImageTexture.create_from_image(t.make_biome_image()))
	tm.set_shader_parameter("noise_tex", Gfx.noise_tex("terrain", 3, 0.02, 256, 4))
	tm.set_shader_parameter("map_origin", Vector2(-Terrain.HALF, -Terrain.HALF))
	tm.set_shader_parameter("map_size", Terrain.HALF * 2.0)
	island.material_override = tm
	parent.add_child(island)

	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "River"
	water.mesh = rv["mesh"]
	var wm: ShaderMaterial = ShaderMaterial.new()
	wm.shader = SH_RIVER
	wm.set_shader_parameter("noise_tex", Gfx.noise_tex("water", 8, 0.03, 256, 3))
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(water)

	var fall_len: float = 32.0
	var fall: MeshInstance3D = MeshInstance3D.new()
	fall.name = "Waterfall"
	fall.mesh = WorldMeshes.build_waterfall(rv["lip"], rv["flow"], float(rv["half_w"]), fall_len)
	var fm: ShaderMaterial = ShaderMaterial.new()
	fm.shader = SH_FALL
	fm.set_shader_parameter("noise_tex", Gfx.noise_tex("fall", 9, 0.05, 256, 3))
	fm.set_shader_parameter("fall_len", fall_len)
	fall.material_override = fm
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fall)
	var wf: Dictionary = {"lip": rv["lip"], "flow": rv["flow"], "half_w": rv["half_w"]}
	out["waterfall"] = wf

	var props: SciFiProps = SciFiProps.new()
	parent.add_child(Decor.build(map, 1.0 if high_quality else 0.55, props))
	_spring_rocks(parent, map, props)
	_thrusters(parent, map)

	var portal: Node3D = SciFiStructures.build_portal(map)
	parent.add_child(portal)
	var heart: Node3D = SciFiStructures.build_base(map)
	parent.add_child(heart)
	parent.add_child(SciFiStructures.build_bridge(map))
	out["portal"] = portal
	out["heart"] = heart

	var amb: SciFiAmbient = SciFiAmbient.new()
	amb.name = "Ambient"
	amb.heart = heart
	amb.portal = portal
	amb.waterfall = wf
	parent.add_child(amb)
	amb.setup(map, high_quality)
	out["ambient"] = amb
	return out


## Skály (asteroidy) kolem pramene řeky.
static func _spring_rocks(parent: Node3D, map: GameMap, props: SciFiProps) -> void:
	var t: Terrain = map.terrain
	var p0: Vector2 = t.river.pts[0]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var buckets: Dictionary = {}
	for i in range(9):
		var a: float = TAU * float(i) / 9.0 + rng.randf() * 0.3
		var r: float = t.river.half_w[0] + rng.randf_range(0.5, 1.6)
		var x: float = p0.x + cos(a) * r
		var z: float = p0.y + sin(a) * r
		if t.edge_dist(x, z) < 0.6:
			continue
		var key: String = "rock" if i % 2 == 0 else "rock2"
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(Decor._xf(Vector3(x, t.height_at(x, z) - 0.05, z), rng.randf() * TAU, rng.randf_range(0.7, 1.5)))
	for key2 in buckets.keys():
		var arr: Array = buckets[key2]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = props.get_mesh(str(key2))
		mm.instance_count = arr.size()
		for j in range(arr.size()):
			mm.set_instance_transform(j, arr[j])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = props.material_for(str(key2))
		parent.add_child(mmi)


## Trysky pod asteroidem: svítící kužely, které drží stanici ve vzduchu.
static func _thrusters(parent: Node3D, map: GameMap) -> void:
	var k: MeshKit = MeshKit.new(88, 0.04)
	var spots: Array = [Vector2(-10.0, -8.0), Vector2(11.0, -6.0), Vector2(-4.0, 12.0), Vector2(14.0, 11.0), Vector2(-14.0, 6.0)]
	for sp in spots:
		var s: Vector2 = sp
		var base_y: float = -9.0
		k.cyl(1.1, 0.8, 0.9, 8, Color(0.22, 0.25, 0.33), MeshKit.xf(Vector3(s.x, base_y - 0.9, s.y)), 0.0, false, true)
		k.torus(1.0, 0.07, Color(0.10, 0.90, 1.0), MeshKit.xf(Vector3(s.x, base_y - 0.95, s.y)), 1.4, 16, 4)
		k.cone(0.7, 3.2, 8, Color(0.35, 0.8, 1.0), MeshKit.xf(Vector3(s.x, base_y - 4.1, s.y), Vector3(180.0, 0.0, 0.0)), 1.5, false)
	var mi: MeshInstance3D = Gfx.mesh_node(k, Gfx.model_mat(0.5, 0.12), false)
	mi.name = "Thrusters"
	parent.add_child(mi)
