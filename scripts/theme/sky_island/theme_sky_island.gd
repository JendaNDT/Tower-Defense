class_name ThemeSkyIsland
extends GameTheme
## Motiv „Ostrov v oblacích“: létající ostrov s biomy (les, louka, poušť, sníh), řekou a vodopádem.


func _init() -> void:
	theme_id = "sky_island"
	theme_name = "Ostrov v oblacích"


func build_world(parent: Node3D, map: GameMap, high_quality: bool) -> Dictionary:
	return WorldBuilder.build(parent, map, high_quality)


func make_tower_visual(type: String, level: int) -> TowerVisual:
	return TowerModels.build(type, level)


func make_enemy_visual(type: String) -> EnemyVisual:
	return EnemyModels.build(type)


func make_projectile_visual(kind: String) -> Node3D:
	var root: Node3D = Node3D.new()
	var k: MeshKit = MeshKit.new(7, 0.0)
	var mat: ShaderMaterial = Gfx.model_mat(0.5, 0.2)
	match kind:
		"arrow":
			# dřevce, hrot a opeření; špička míří do -Z
			k.cyl(0.018, 0.018, 0.62, 5, Color(0.62, 0.45, 0.28), MeshKit.xf(Vector3(0.0, 0.0, 0.31), Vector3(-90.0, 0.0, 0.0)), 0.0, false, false)
			k.cone(0.045, 0.14, 5, Color(0.8, 0.82, 0.88), MeshKit.xf(Vector3(0.0, 0.0, -0.28), Vector3(-90.0, 0.0, 0.0)), 0.2, false)
			for i in range(3):
				var a: float = TAU * float(i) / 3.0
				k.tri(Vector3(0.0, 0.0, 0.6), Vector3(0.0, 0.0, 0.42), Vector3(cos(a) * 0.07, sin(a) * 0.07, 0.6), Color(0.95, 0.95, 0.9), Transform3D.IDENTITY, 0.0, true)
			root.scale = Vector3(1.0, 1.0, 1.0)
		"ball":
			k.sphere(0.22, Color(0.16, 0.16, 0.19), Transform3D.IDENTITY, 0.0, 10, 7, true)
			k.sphere(0.10, Color(1.0, 0.5, 0.1), MeshKit.xf(Vector3(0.0, 0.0, 0.17)), 2.0, 6, 4)
			mat = Gfx.model_mat(0.35, 0.7)
		_:
			k.sphere(0.2, Color(0.7, 0.45, 1.0), Transform3D.IDENTITY, 2.2, 8, 6, true)
			k.sphere(0.11, Color(1.0, 0.95, 1.0), Transform3D.IDENTITY, 3.5, 6, 4, true)
			mat = Gfx.model_mat(0.2, 0.0)
	var mi: MeshInstance3D = Gfx.mesh_node(k, mat, false)
	root.add_child(mi)
	return root
