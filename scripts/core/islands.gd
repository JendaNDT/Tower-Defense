class_name Islands
extends RefCounted
## Rozložení ostrovů: trasa (lomená čára v buňkách), buňka Srdce ostrova, řeka a umístění biomů.
## Index biomů ve `biomes`: 0 les, 1 louka, 2 poušť, 3 sníh (poloha středu biomu ve světových souřadnicích XZ).
## Poslední položka výběru (RANDOM_ID) = náhodný ostrov: náhodné rozložení z LIST a náhodný seed.

const RANDOM_ID: int = 3

const LIST: Array = [
	{
		"name": "Klikatá stezka",
		"desc": "Dlouhá cesta ze sněhu přes louku, most a poušť do lesa. Vyvážená pro začátek.",
		"seed": 7,
		"path": [
			Vector2i(0, 3), Vector2i(8, 3), Vector2i(8, 9), Vector2i(3, 9), Vector2i(3, 17),
			Vector2i(21, 17), Vector2i(21, 10), Vector2i(15, 10), Vector2i(15, 4), Vector2i(21, 4),
		],
		"base": Vector2i(22, 4),
		"river": [
			Vector2(0.0, -23.0), Vector2(1.6, -16.0), Vector2(-0.4, -8.0), Vector2(1.0, 0.0),
			Vector2(3.0, 8.0), Vector2(2.2, 16.0), Vector2(4.2, 24.0), Vector2(5.0, 34.0),
		],
		"biomes": [Vector2(17.0, -17.0), Vector2(-17.0, 17.0), Vector2(17.0, 17.0), Vector2(-17.0, -17.0)],
	},
	{
		"name": "Podkova",
		"desc": "Cesta obkrouží ostrov jako podkova a uprostřed je velký prostor pro věže. Cesta je kratší, proto mají nepřátelé o 12 % méně zdraví.",
		"seed": 11,
		"hp": 0.88,
		"path": [
			Vector2i(0, 19), Vector2i(4, 19), Vector2i(4, 4), Vector2i(19, 4), Vector2i(19, 17), Vector2i(12, 17),
		],
		"base": Vector2i(12, 18),
		"river": [
			Vector2(-4.0, -22.0), Vector2(-4.5, -12.0), Vector2(-6.0, -2.0), Vector2(-5.0, 8.0),
			Vector2(-3.0, 18.0), Vector2(-2.0, 26.0), Vector2(-2.0, 36.0),
		],
		"biomes": [Vector2(-17.0, 17.0), Vector2(-17.0, -17.0), Vector2(17.0, 17.0), Vector2(17.0, -17.0)],
	},
	{
		"name": "Hadí údolí",
		"desc": "Tři dlouhé vlnovky za sebou. Věže mezi řadami střílí na obě cesty, ale nepřátelé jdou dlouho.",
		"seed": 23,
		"path": [
			Vector2i(0, 4), Vector2i(18, 4), Vector2i(18, 12), Vector2i(4, 12), Vector2i(4, 20), Vector2i(17, 20),
		],
		"base": Vector2i(18, 20),
		"river": [
			Vector2(-22.0, -9.0), Vector2(-10.0, -8.0), Vector2(0.0, -6.5), Vector2(10.0, -7.5),
			Vector2(20.0, -7.0), Vector2(30.0, -8.0), Vector2(38.0, -8.0),
		],
		"biomes": [Vector2(17.0, -17.0), Vector2(17.0, 17.0), Vector2(-17.0, 17.0), Vector2(-17.0, -17.0)],
	},
]


## Rozložení pro daný výběr (RANDOM_ID => náhodné z LIST podle seedu) a seed ostrova.
static func resolve(island_id: int, random_seed: int) -> Dictionary:
	if island_id == RANDOM_ID:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = random_seed
		var def: Dictionary = (LIST[rng.randi() % LIST.size()] as Dictionary).duplicate()
		def["seed"] = random_seed
		# otočit rozložení biomů o 0–3 čtvrtiny (jiný sled krajin podél cesty)
		var b: Array = (def["biomes"] as Array).duplicate()
		var rot: int = rng.randi() % 4
		var nb: Array = []
		for i in range(4):
			nb.append(b[(i + rot) % 4])
		def["biomes"] = nb
		def["name"] = "Náhodný ostrov č. %d" % random_seed
		return def
	return LIST[clampi(island_id, 0, LIST.size() - 1)]


static func choices() -> int:
	return LIST.size() + 1


static func display_name(island_id: int, th: GameTheme = null) -> String:
	if island_id == RANDOM_ID:
		return (th if th != null else Themes.cur()).text("random_place")
	return str(LIST[clampi(island_id, 0, LIST.size() - 1)]["name"])


static func display_desc(island_id: int, th: GameTheme = null) -> String:
	if island_id == RANDOM_ID:
		return (th if th != null else Themes.cur()).text("random_desc")
	return str(LIST[clampi(island_id, 0, LIST.size() - 1)]["desc"])
