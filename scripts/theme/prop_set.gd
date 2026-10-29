class_name PropSet
extends RefCounted
## Sada kulis (stromy, skály, tráva, květiny...) pro rozmístění ve světě. Motiv dodá vlastní sadu se stejnými klíči
## (pine, oak, bush, cactus, palm, rock, rock2, rock_snow, rock_desert, grass_*, flower_*, reed), takže se rozmisťovací logika sdílí.

func get_mesh(_key: String) -> ArrayMesh:
	return ArrayMesh.new()


## Výška modelu (m) – větrný efekt roste s výškou.
func height_of(_key: String) -> float:
	return 1.0


## Materiál pro MultiMesh daného klíče.
func material_for(_key: String) -> Material:
	return Gfx.model_mat(0.9, 0.0)


## Kulisy, které blokují (pevné skály): jen k nim se vážou kamínky u cesty.
func is_solid(key: String) -> bool:
	return key.begins_with("rock")


## Zda se kulisa kreslí bez stínu (tráva, květiny).
func no_shadow(key: String) -> bool:
	return key.begins_with("grass") or key.begins_with("flower") or key == "reed"
