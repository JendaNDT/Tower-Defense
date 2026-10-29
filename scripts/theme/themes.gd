class_name Themes
extends RefCounted
## Rejstřík motivů (prostředí hry) a přístup k jejich textům a barvám. Aktivní motiv je `Themes.current`.
## Hra se na motiv ptá přes tyto funkce, takže pravidla (Cfg) zůstávají společná a mění se jen vzhled, texty a zvuk.

const LIST: Array = [
	{"id": "sky_island", "name": "Ostrov v oblacích", "short": "Ostrov",
		"desc": "Plovoucí ostrov s lesem, loukou, pouští a sněhem. Řeka padá z okraje jako vodopád do oblaků."},
	{"id": "scifi", "name": "Vesmírná stanice", "short": "Stanice",
		"desc": "Plošina s neonovými biomy v hlubokém vesmíru. Lasery, plazma, roboti a energetická řeka."},
]
const DEFAULT_ID: String = "sky_island"

static var current: GameTheme = null
static var _peek_cache: Dictionary = {}


static func ids() -> Array:
	var out: Array = []
	for d in LIST:
		out.append(str(d["id"]))
	return out


static func is_valid(id: String) -> bool:
	return ids().has(id)


static func info(id: String) -> Dictionary:
	for d in LIST:
		if str(d["id"]) == id:
			return d
	return LIST[0]


static func create(id: String) -> GameTheme:
	match id:
		"scifi":
			return ThemeSciFi.new()
		_:
			return ThemeSkyIsland.new()


## Lehká instance motivu jen pro čtení textů (náhled v menu před přepnutím).
static func peek(id: String) -> GameTheme:
	if not _peek_cache.has(id):
		_peek_cache[id] = create(id if is_valid(id) else DEFAULT_ID)
	return _peek_cache[id]


## Zvolí aktivní motiv podle id (vytvoří novou instanci).
static func use(id: String) -> GameTheme:
	current = create(id if is_valid(id) else DEFAULT_ID)
	return current


static func cur() -> GameTheme:
	if current == null:
		current = ThemeSkyIsland.new()
	return current


# ------------------------------------------------------------------ barvy a texty
static func pal(key: String) -> Color:
	return cur().color(key)


static func t(key: String) -> String:
	return cur().text(key)


static func tower_name(id: String) -> String:
	var tt: Dictionary = cur().tower_text.get(id, {})
	return str(tt.get("name", Cfg.TOWERS[id]["name"]))


static func tower_short(id: String) -> String:
	var tt: Dictionary = cur().tower_text.get(id, {})
	return str(tt.get("short", Cfg.TOWERS[id]["short"]))


static func tower_desc(id: String) -> String:
	var tt: Dictionary = cur().tower_text.get(id, {})
	return str(tt.get("desc", Cfg.TOWERS[id]["desc"]))


## Popis úrovně věže (level 1..4): co přináší vylepšení na tuto úroveň.
static func level_note(id: String, level: int) -> String:
	var tt: Dictionary = cur().tower_text.get(id, {})
	if tt.has("notes"):
		var notes: Array = tt["notes"]
		return str(notes[clampi(level, 1, notes.size()) - 1])
	return str(Cfg.tower_level(id, level)["note"])


static func enemy_name(id: String) -> String:
	var et: Dictionary = cur().enemy_text.get(id, {})
	return str(et.get("name", Cfg.ENEMIES[id]["name"]))


static func enemy_tip(id: String) -> String:
	var et: Dictionary = cur().enemy_text.get(id, {})
	return str(et.get("tip", Cfg.ENEMIES[id].get("tip", "")))


static func ability_name(id: String) -> String:
	var at: Dictionary = cur().ability_text.get(id, {})
	return str(at.get("name", Cfg.ABILITIES[id]["name"]))


static func ability_desc(id: String) -> String:
	var at: Dictionary = cur().ability_text.get(id, {})
	return str(at.get("desc", Cfg.ABILITIES[id]["desc"]))


static func tower_color(id: String) -> Color:
	return cur().tower_colors.get(id, Cfg.TOWERS[id]["color"])


static func enemy_color(id: String) -> Color:
	return cur().enemy_colors.get(id, Cfg.ENEMIES[id]["color"])


static func tower_icon(id: String) -> String:
	return str(cur().tower_icons.get(id, id))


static func ability_icon(id: String) -> String:
	var def: Dictionary = {"meteor": "meteor", "blizzard": "snow", "gold": "goldrush"}
	return str(cur().ability_icons.get(id, def.get(id, id)))
