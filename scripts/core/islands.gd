class_name Islands
extends RefCounted
## Rozložení ostrovů: síť cest, buňka Srdce ostrova, řeka, kopce a umístění biomů.
##
## Síť cest se skládá z úseků (`segs`: název -> lomená čára v buňkách). Trasa (`lanes`) je řetěz úseků od portálu k Srdci:
## rozcestí vznikne tak, že dvě trasy sdílejí začátek (mají stejný první úsek), splynutí tak, že sdílejí konec.
## Každý úsek začíná v buňce, kde předchozí končí. Váha trasy (`w`) určuje, kolik nepřátel jí půjde (poměrově).
## Kopce (`hills`): střed v buňce, poloměr paty `r` v metrech a stupeň `tier` (1 kopec, 2 vrchol) – věž na nich dostane bonus dosahu.
## Index biomů ve `biomes`: 0 les, 1 louka, 2 poušť, 3 sníh (poloha středu biomu ve světových souřadnicích XZ).
## Poslední položka výběru (RANDOM_ID) = náhodný ostrov: některé z rozložení v LIST, náhodně převrácené/otočené, s náhodným seedem.

const RANDOM_ID: int = 3

const LIST: Array = [
	{
		"name": "Dvě brány",
		"desc": "Nepřátelé přicházejí dvěma branami, ze západu a ze severu. Obě cesty se u řeky spojí v jednu. Kopec mezi nimi je ideální pro věže.",
		"seed": 7,
		"segs": {
			"a": [Vector2i(0, 5), Vector2i(8, 5), Vector2i(8, 11), Vector2i(2, 11), Vector2i(2, 15), Vector2i(11, 15), Vector2i(11, 22), Vector2i(15, 22)],
			"b": [Vector2i(21, 0), Vector2i(21, 7), Vector2i(28, 7), Vector2i(28, 13), Vector2i(19, 13), Vector2i(19, 22), Vector2i(15, 22)],
			"tail": [Vector2i(15, 22), Vector2i(15, 26), Vector2i(25, 26), Vector2i(25, 28)],
		},
		"lanes": [{"segs": ["a", "tail"], "w": 1.0}, {"segs": ["b", "tail"], "w": 1.0}],
		"base": Vector2i(26, 28),
		"river": [
			Vector2(-33.0, 9.0), Vector2(-20.0, 7.0), Vector2(-9.0, 8.5), Vector2(0.0, 7.0),
			Vector2(8.0, 8.5), Vector2(20.0, 7.0), Vector2(30.0, 8.0), Vector2(52.0, 8.0),
		],
		"hills": [
			{"c": Vector2i(15, 13), "r": 6.6, "tier": 1}, {"c": Vector2i(15, 13), "r": 4.0, "tier": 2},
			{"c": Vector2i(24, 23), "r": 5.8, "tier": 1}, {"c": Vector2i(5, 13), "r": 6.0, "tier": 1},
			{"c": Vector2i(25, 3), "r": 6.0, "tier": 1},
		],
		"biomes": [Vector2(22.0, -22.0), Vector2(-22.0, 22.0), Vector2(22.0, 22.0), Vector2(-22.0, -22.0)],
	},
	{
		"name": "Rozcestí",
		"desc": "Jediná brána, ale cesta se hned rozdělí na dvě větve, které obkrouží skalní vrch a znovu se spojí. Pak ještě třikrát překročí řeku.",
		"seed": 11,
		"segs": {
			"in": [Vector2i(0, 10), Vector2i(6, 10)],
			"up": [Vector2i(6, 10), Vector2i(6, 6), Vector2i(16, 6), Vector2i(16, 10)],
			"dn": [Vector2i(6, 10), Vector2i(6, 14), Vector2i(16, 14), Vector2i(16, 10)],
			"tail": [Vector2i(16, 10), Vector2i(24, 10), Vector2i(24, 18), Vector2i(16, 18), Vector2i(16, 25), Vector2i(26, 25)],
		},
		"lanes": [{"segs": ["in", "up", "tail"], "w": 1.0}, {"segs": ["in", "dn", "tail"], "w": 1.0}],
		"base": Vector2i(27, 25),
		"river": [
			Vector2(10.0, -33.0), Vector2(11.0, -20.0), Vector2(9.0, -8.0), Vector2(10.0, 4.0),
			Vector2(11.0, 14.0), Vector2(9.0, 26.0), Vector2(10.0, 52.0),
		],
		"hills": [
			{"c": Vector2i(11, 10), "r": 7.0, "tier": 1}, {"c": Vector2i(11, 10), "r": 4.0, "tier": 2},
			{"c": Vector2i(28, 14), "r": 6.0, "tier": 1}, {"c": Vector2i(6, 19), "r": 6.0, "tier": 1},
			{"c": Vector2i(12, 22), "r": 5.2, "tier": 1},
		],
		"biomes": [Vector2(-22.0, 22.0), Vector2(22.0, -22.0), Vector2(22.0, 22.0), Vector2(-22.0, -22.0)],
	},
	{
		"name": "Tři brány",
		"desc": "Nejtěžší: tři brány, dvě cesty se spojí, rozdělí a znovu spojí, až k Srdci vede jediná stezka. Nepřátelé mají o 10 % víc zdraví, ale kopce uprostřed pokryjí většinu cest.",
		"seed": 23,
		"hp": 1.1,
		"segs": {
			"n": [Vector2i(6, 0), Vector2i(6, 12)],
			"w": [Vector2i(0, 5), Vector2i(3, 5), Vector2i(3, 12), Vector2i(6, 12)],
			"a": [Vector2i(6, 12), Vector2i(13, 12), Vector2i(13, 19)],
			"b": [Vector2i(6, 12), Vector2i(6, 19), Vector2i(13, 19)],
			"ab": [Vector2i(13, 19), Vector2i(17, 19)],
			"e": [Vector2i(31, 5), Vector2i(27, 5), Vector2i(27, 12), Vector2i(22, 12), Vector2i(22, 19), Vector2i(17, 19)],
			"tail": [Vector2i(17, 19), Vector2i(17, 24), Vector2i(25, 24), Vector2i(25, 28)],
		},
		"lanes": [
			{"segs": ["n", "a", "ab", "tail"], "w": 0.5}, {"segs": ["n", "b", "ab", "tail"], "w": 0.5},
			{"segs": ["w", "a", "ab", "tail"], "w": 0.5}, {"segs": ["w", "b", "ab", "tail"], "w": 0.5},
			{"segs": ["e", "tail"], "w": 1.0},
		],
		"base": Vector2i(26, 28),
		"river": [
			Vector2(-33.0, -14.0), Vector2(-20.0, -13.0), Vector2(-5.0, -15.0), Vector2(8.0, -13.0),
			Vector2(22.0, -14.0), Vector2(35.0, -13.0), Vector2(52.0, -14.0),
		],
		"hills": [
			{"c": Vector2i(9, 15), "r": 6.6, "tier": 1}, {"c": Vector2i(9, 15), "r": 4.0, "tier": 2},
			{"c": Vector2i(19, 15), "r": 6.0, "tier": 1}, {"c": Vector2i(10, 3), "r": 6.0, "tier": 1},
			{"c": Vector2i(22, 26), "r": 5.4, "tier": 1},
		],
		"biomes": [Vector2(22.0, -22.0), Vector2(22.0, 22.0), Vector2(-22.0, 22.0), Vector2(-22.0, -22.0)],
	},
]


## Rozložení pro daný výběr (RANDOM_ID => náhodné z LIST podle seedu, náhodně převrácené) a seed ostrova.
static func resolve(island_id: int, random_seed: int) -> Dictionary:
	if island_id == RANDOM_ID:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = random_seed
		var base_def: Dictionary = LIST[rng.randi() % LIST.size()]
		var def: Dictionary = transformed(base_def, rng.randi() % 8)
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


# ------------------------------------------------------------------ trasy
static func lane_count(def: Dictionary) -> int:
	return (def["lanes"] as Array).size()


## Buňky jedné trasy od portálu k poslednímu políčku před Srdcem (úseky se spojí, společný bod se nezdvojí).
static func lane_cells(def: Dictionary, lane: int) -> Array:
	var out: Array = []
	var segs: Dictionary = def["segs"]
	for name in (def["lanes"][lane] as Dictionary)["segs"]:
		for c in (segs[name] as Array):
			if not out.is_empty() and out[out.size() - 1] == c:
				continue
			out.append(c)
	return out


static func lane_weight(def: Dictionary, lane: int) -> float:
	return float((def["lanes"][lane] as Dictionary).get("w", 1.0))


# ------------------------------------------------------------------ převrácení / otočení rozložení
## Převrácené (bit 0: zrcadlení X, bit 1: zrcadlení Z, bit 2: záměna os) kopie rozložení; 0 = beze změny.
static func transformed(def: Dictionary, mode: int) -> Dictionary:
	var out: Dictionary = def.duplicate(true)
	if mode == 0:
		return out
	var segs: Dictionary = {}
	for k in (def["segs"] as Dictionary).keys():
		var arr: Array = []
		for c in (def["segs"][k] as Array):
			arr.append(_tc(c, mode))
		segs[k] = arr
	out["segs"] = segs
	out["base"] = _tc(def["base"], mode)
	var rv: Array = []
	for p in (def["river"] as Array):
		rv.append(_tw(p, mode))
	out["river"] = rv
	var hl: Array = []
	for h in (def["hills"] as Array):
		var nh: Dictionary = (h as Dictionary).duplicate()
		nh["c"] = _tc(h["c"], mode)
		hl.append(nh)
	out["hills"] = hl
	var bl: Array = []
	for b in (def["biomes"] as Array):
		bl.append(_tw(b, mode))
	out["biomes"] = bl
	return out


static func _tc(c: Vector2i, mode: int) -> Vector2i:
	var x: int = c.x
	var z: int = c.y
	if mode & 4:
		var t: int = x
		x = z
		z = t
	if mode & 1:
		x = Cfg.GRID_W - 1 - x
	if mode & 2:
		z = Cfg.GRID_H - 1 - z
	return Vector2i(x, z)


static func _tw(p: Vector2, mode: int) -> Vector2:
	var x: float = p.x
	var z: float = p.y
	if mode & 4:
		var t: float = x
		x = z
		z = t
	if mode & 1:
		x = -x
	if mode & 2:
		z = -z
	return Vector2(x, z)
