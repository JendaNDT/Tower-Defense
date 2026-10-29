class_name GameSettings
extends RefCounted
## Volby hráče (režim, obtížnost, ostrov, prostředí) a rekordy. Statické proměnné přežijí i znovunačtení scény
## (výběr jiného ostrova = nová scéna); na disk (v prohlížeči do IndexedDB) se ukládá do user://nastaveni.cfg.

static var path: String = "user://nastaveni.cfg"          # (pro testy jde přepsat)

static var difficulty: String = "normal"       # easy | normal | hard
static var mode: String = "campaign"           # campaign | endless
static var island: int = 0                     # index v Islands.LIST (Islands.RANDOM_ID = náhodný ostrov)
static var theme: String = "sky_island"        # prostředí hry (viz Themes.LIST)
static var random_seed: int = 0                # seed právě zvoleného náhodného ostrova
static var autostart: bool = false             # po znovunačtení scény rovnou začít hrát (bez úvodní obrazovky)
static var loaded: bool = false
const REC_SECTION: String = "rekordy_mapy2"     # rekordy ze starých map (sekce "rekordy") se po výměně map nepoužívají
static var records: Dictionary = {}            # klíč -> {"waves": int, "won": bool, "lives": int}


static func cfg_load() -> ConfigFile:
	var cf: ConfigFile = ConfigFile.new()
	cf.load(path)
	return cf


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var cf: ConfigFile = cfg_load()
	var d: String = str(cf.get_value("hra", "obtiznost", "normal"))
	difficulty = d if Cfg.DIFFICULTIES.has(d) else "normal"
	var m: String = str(cf.get_value("hra", "rezim", "campaign"))
	mode = m if (m == "campaign" or m == "endless") else "campaign"
	island = clampi(int(cf.get_value("hra", "ostrov", 0)), 0, Islands.RANDOM_ID)
	var th: String = str(cf.get_value("hra", "prostredi", Themes.DEFAULT_ID))
	theme = th if Themes.is_valid(th) else Themes.DEFAULT_ID
	records = {}
	if cf.has_section(REC_SECTION):
		for k in cf.get_section_keys(REC_SECTION):
			var v = cf.get_value(REC_SECTION, k)
			if typeof(v) == TYPE_DICTIONARY:
				records[k] = v


static func save_all() -> void:
	var cf: ConfigFile = cfg_load()
	cf.set_value("hra", "obtiznost", difficulty)
	cf.set_value("hra", "rezim", mode)
	cf.set_value("hra", "ostrov", island)
	cf.set_value("hra", "prostredi", theme)
	for k in records.keys():
		cf.set_value(REC_SECTION, k, records[k])
	cf.save(path)


## Pro testy a URL parametry (?diff=hard&mode=endless&island=1).
static func apply_args(args: Dictionary) -> void:
	if args.has("diff") and Cfg.DIFFICULTIES.has(str(args["diff"])):
		difficulty = str(args["diff"])
	if args.has("mode") and (str(args["mode"]) == "campaign" or str(args["mode"]) == "endless"):
		mode = str(args["mode"])
	if args.has("island"):
		island = clampi(int(args["island"]), 0, Islands.RANDOM_ID)
	if args.has("seed"):
		random_seed = int(args["seed"])
	if args.has("theme") and Themes.is_valid(str(args["theme"])):
		theme = str(args["theme"])


static func is_endless() -> bool:
	return mode == "endless"


static func record_key() -> String:
	return "%s_%s_%d" % [mode, difficulty, island]


static func get_record(key: String = "") -> Dictionary:
	var k: String = key if key != "" else record_key()
	return records.get(k, {"waves": 0, "won": false, "lives": 0})


## Zapíše výsledek, pokud je lepší než dosavadní rekord. Vrací true, když se rekord zlepšil.
static func submit(waves_cleared: int, won: bool, lives_left: int) -> bool:
	var k: String = record_key()
	var old: Dictionary = get_record(k)
	var better: bool = false
	if waves_cleared > int(old.get("waves", 0)):
		better = true
	elif waves_cleared == int(old.get("waves", 0)) and won and (not bool(old.get("won", false)) or lives_left > int(old.get("lives", 0))):
		better = true
	if better:
		records[k] = {"waves": waves_cleared, "won": won, "lives": lives_left}
		save_all()
	return better


static func record_text(key: String = "") -> String:
	var r: Dictionary = get_record(key)
	var endless: bool = (key if key != "" else record_key()).begins_with("endless")
	if int(r.get("waves", 0)) <= 0 and not bool(r.get("won", false)):
		return "zatím žádný"
	if endless:
		return "vlna %d" % int(r["waves"])
	if bool(r.get("won", false)):
		return "vítězství (životy %d)" % int(r["lives"])
	return "vlna %d / %d" % [int(r["waves"]), Cfg.TOTAL_WAVES]
