class_name WorldBuilder
extends RefCounted
## Poskládá celý svět „létající ostrov v oblacích“ do uzlu `parent` a vrátí odkazy na důležité části.

const SH_TERRAIN: Shader = preload("res://shaders/terrain.gdshader")
const SH_WATER: Shader = preload("res://shaders/water.gdshader")
const SH_FALL: Shader = preload("res://shaders/waterfall.gdshader")


static func make_environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.75, 0.96)
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.55, 0.92)
	sm.sky_horizon_color = Color(0.74, 0.86, 0.98)
	sm.ground_bottom_color = Color(0.50, 0.64, 0.86)
	sm.ground_horizon_color = Color(0.74, 0.86, 0.98)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.2
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# jemný opar do dálky (hloubková mlha): vzdálenější část ostrova (nahoře na obrazovce) a oblaka se ztrácejí v modři
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.70, 0.83, 0.98)
	env.fog_depth_begin = 150.0
	env.fog_depth_end = 300.0
	env.fog_depth_curve = 1.0
	env.fog_density = 0.55
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.14
	return env


static func make_sun(high_quality: bool) -> DirectionalLight3D:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -140.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.35
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

	# --- řeka (nejdřív: potřebujeme znát, kde padá z ostrova)
	var rv: Dictionary = WorldMeshes.build_river(t)
	var lip: Vector3 = rv["lip"]

	# --- ostrov
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

	# --- řeka a vodopád
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "River"
	water.mesh = rv["mesh"]
	var wm: ShaderMaterial = ShaderMaterial.new()
	wm.shader = SH_WATER
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

	# --- dekorace
	parent.add_child(Decor.build(map, 1.0 if high_quality else 0.55, null, 1.0 if high_quality else 0.3))
	_spring_rocks(parent, map)

	# --- stavby
	var portals: Array = []
	for pi in range(map.portals.size()):
		var portal: Node3D = Structures.build_portal(map, pi)
		parent.add_child(portal)
		portals.append(portal)
	var heart: Node3D = Structures.build_base(map)
	parent.add_child(heart)
	parent.add_child(Structures.build_bridge(map))
	out["portal"] = portals[0]
	out["portals"] = portals
	out["heart"] = heart

	# --- živé prvky
	var amb: Ambient = Ambient.new()
	amb.name = "Ambient"
	amb.heart = heart
	amb.portals = portals
	amb.waterfall = wf
	parent.add_child(amb)
	amb.setup(map, high_quality)
	out["ambient"] = amb
	return out


## Skály kolem pramene řeky.
static func _spring_rocks(parent: Node3D, map: GameMap) -> void:
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
		var s: float = rng.randf_range(0.7, 1.5)
		(buckets[key] as Array).append(Decor._xf(Vector3(x, t.height_at(x, z) - 0.05, z), rng.randf() * TAU, s))
	for key2 in buckets.keys():
		var arr: Array = buckets[key2]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Props.get_mesh(str(key2))
		mm.instance_count = arr.size()
		for j in range(arr.size()):
			mm.set_instance_transform(j, arr[j])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Gfx.model_mat(0.95, 0.0)
		parent.add_child(mmi)
