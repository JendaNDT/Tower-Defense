class_name SkyProps
extends PropSet
## Kulisy ostrova v oblacích: stromy, keře, kaktusy, palmy, skály, tráva, květiny a rákos (viz Props).


func get_mesh(key: String) -> ArrayMesh:
	return Props.get_mesh(key)


func height_of(key: String) -> float:
	return Props.height_of(key)


func material_for(key: String) -> Material:
	if Decor.SOLID_KEYS.has(key):
		return Gfx.model_mat(0.95, 0.0)
	if key.begins_with("grass") or key.begins_with("flower") or key == "reed":
		var wind: float = 0.30 if key == "reed" else 0.20
		return Gfx.foliage_mat(0.55 if key != "reed" else 1.3, wind, 0.04)
	return Gfx.foliage_mat(Props.height_of(key), 0.10, 0.035)
