class_name GameTheme
extends RefCounted
## Rozhraní motivu (theme). Hra (pravidla, vlny, věže, nepřátelé) je oddělená od vzhledu.
## Nový motiv (sci-fi, fantasy, ...) = nová třída, která dědí z GameTheme a přepíše tyto metody:
## svět, modely věží a nepřátel, projektily. Pravidla a čísla zůstávají v Cfg.

var theme_id: String = "base"
var theme_name: String = "Základní"


## Postaví svět do `parent`. Vrací slovník s odkazy: {sun, environment, portal, heart, ambient, waterfall}.
func build_world(_parent: Node3D, _map: GameMap, _high_quality: bool) -> Dictionary:
	return {}


func make_tower_visual(_type: String, _level: int) -> TowerVisual:
	return TowerVisual.new()


func make_enemy_visual(_type: String) -> EnemyVisual:
	return EnemyVisual.new()


## Vizuál projektilu: "arrow" | "ball" | "orb". Špička míří do -Z.
func make_projectile_visual(_kind: String) -> Node3D:
	return Node3D.new()
