class_name GameTheme
extends RefCounted
## Rozhraní motivu (theme). Hra (pravidla, vlny, věže, nepřátelé) je oddělená od vzhledu.
## Nový motiv (další prostředí) = nová třída, která dědí z GameTheme, přepíše metody pro svět, modely
## věží a nepřátel, projektily a doplní `palette` (barvy efektů), `strings` (texty) a jména věží a nepřátel.
## Pravidla a čísla zůstávají v Cfg; motiv mění jen vzhled, texty a zvuk.

## Výchozí barvy efektů (motiv „Ostrov v oblacích“). Motiv přepisuje jen ty, které chce mít jiné.
const DEFAULT_PALETTE: Dictionary = {
	# věže: záblesky u ústí, kouř, jiskry
	"muzzle_archer": Color(1.0, 0.9, 0.6), "muzzle_cannon": Color(1.0, 0.6, 0.2), "muzzle_mage": Color(0.75, 0.5, 1.0),
	"muzzle_core": Color(1.0, 0.95, 0.8),
	"archer_puff": Color(1, 1, 1), "cannon_smoke": Color(0.9, 0.9, 0.85), "cannon_fire": Color(1.0, 0.7, 0.25),
	"mage_puff": Color(0.75, 0.55, 1.0),
	"frost_ring": Color(0.55, 0.88, 1.0), "frost_ring_freeze": Color(0.85, 0.97, 1.0), "frost_puff": Color(0.8, 0.95, 1.0),
	"frost_hit": Color(0.7, 0.95, 1.0),
	# projektily a jejich dopady
	"arrow_hit": Color(1.0, 0.92, 0.65), "arrow_miss": Color(0.7, 0.62, 0.5),
	"ball_trail": Color(0.40, 0.38, 0.36), "orb_trail": Color(0.72, 0.5, 1.0),
	"magic_hit": Color(0.8, 0.6, 1.0), "chain_beam": Color(0.75, 0.6, 1.0), "chain_hit": Color(0.8, 0.65, 1.0),
	"streak_arrow": Color(1.0, 0.92, 0.65), "streak_ball": Color(1.0, 0.55, 0.18), "streak_orb": Color(0.72, 0.5, 1.0),
	# výbuchy
	"explosion_fire": Color(1.0, 0.65, 0.2), "explosion_smoke": Color(0.35, 0.33, 0.32), "explosion_ring": Color(1.0, 0.7, 0.3),
	"explosion_debris": Color(0.45, 0.36, 0.26), "death_puff": Color(0.95, 0.95, 0.9),
	# nepřátelé
	"crumble_dust": Color(0.62, 0.58, 0.52), "crash_puff": Color(0.85, 0.35, 0.3), "crash_dust": Color(0.7, 0.62, 0.5),
	"step_dust": Color(0.75, 0.68, 0.58), "absorb_spark": Color(1.0, 0.5, 0.85), "shield_break": Color(0.6, 0.85, 1.0),
	"heal": Color(0.45, 1.0, 0.55), "ripple": Color(0.95, 0.99, 1.0), "shield_bubble": Color(0.5, 0.8, 1.0),
	"tint_frozen": Color(0.65, 0.92, 1.0), "tint_burn": Color(1.0, 0.5, 0.1), "tint_slow": Color(0.45, 0.78, 1.0),
	# hra: příchod, zásah základny, stavba, prodej
	"spawn_puff": Color(0.7, 0.45, 1.0), "base_hit": Color(1.0, 0.4, 0.5),
	"build_ring": Color(1.0, 0.95, 0.7), "build_puff": Color(0.85, 0.8, 0.7), "build_dust": Color(0.74, 0.66, 0.52),
	"sell_puff": Color(0.8, 0.75, 0.65), "upgrade_ring": Color(1.0, 0.85, 0.4), "upgrade_puff": Color(1.0, 0.9, 0.5),
	"gold_text": Color(1.0, 0.85, 0.2), "gold_ring": Color(1.0, 0.85, 0.3),
	# schopnosti
	"blizzard_puff": Color(0.8, 0.95, 1.0), "blizzard_ring": Color(0.7, 0.92, 1.0),
	"meteor_body": Color(0.34, 0.22, 0.16), "meteor_fire": Color(1.0, 0.5, 0.1), "meteor_ring": Color(1.0, 0.35, 0.2),
	"meteor_flash": Color(1.0, 0.9, 0.5), "meteor_puff": Color(1.0, 0.55, 0.15), "meteor_aim": Color(1.0, 0.45, 0.25),
	# ovládání
	"select_ring": Color(1.0, 0.85, 0.3),
	# minimapa: barvy krajiny, cest, vody, kopců a rámečku
	"mm_forest": Color(0.20, 0.45, 0.20), "mm_meadow": Color(0.48, 0.72, 0.28), "mm_desert": Color(0.90, 0.76, 0.48), "mm_snow": Color(0.90, 0.94, 0.98),
	"mm_path": Color(0.50, 0.37, 0.25), "mm_water": Color(0.30, 0.62, 0.95), "mm_hill": Color(0.98, 0.84, 0.40),
	"mm_bg": Color(0.05, 0.09, 0.17, 0.72), "mm_edge": Color(0.78, 0.88, 1.0, 0.95), "mm_portal": Color(0.75, 0.50, 1.0),
}

## Výchozí texty rozhraní (motiv „Ostrov v oblacích“). Motiv přepisuje v `strings`.
const DEFAULT_STRINGS: Dictionary = {
	"title": "Ostrov v oblacích",
	"gold_gen": "zlata",
	"intro_sub": "Braň Srdce ostrova před vlnami nepřátel. Vyber si hru:",
	"loading": "Načítám ostrov v oblacích…",
	"place": "Ostrov",                              # nadpis výběru mapy v menu
	"place_gen": "ostrova",
	"base": "Srdce ostrova",
	"base_dat": "Srdci ostrova",
	"menu_tip": "Nová hra / nastavení (režim, obtížnost, ostrov)",
	"menu_change": "Změnit nastavení (režim, obtížnost, ostrov)",
	"mode_campaign": "Přežij všech %d vln a zachraň ostrov.",
	"base_fell": "Srdce ostrova padlo.",
	"base_hit": "Nepřítel dorazil k Srdci ostrova! −%d životů",
	"help_intro": "Braň Srdce ostrova před vlnami nepřátel, kteří přicházejí z portálů po cestách přes celý ostrov. Některé mapy mají víc bran a rozcestí.",
	"help_units": "Kanón nezasáhne vzdušné cíle, brnění snižuje poškození šípů – proti němu pomůže mág.",
	"help_enemies": "Léčitele zabij první, štítonoše prorazí silné rány, slizák se po smrti rozpadne.",
	"help_abilities_touch": "Schopnosti vlevo dole: Meteor (klepni na místo dopadu a potvrď), Mrazivý poryv a Zlatá horečka. Po použití se nabíjejí.",
	"help_abilities": "Schopnosti vlevo dole (klávesy 5, 6, 7): Meteor (klikni na mapu), Mrazivý poryv a Zlatá horečka. Po použití se nabíjejí.",
	"aim_touch": "Klepni na mapu, kam má meteor dopadnout, a potvrď.",
	"aim_mouse": "Klikni na mapu, kam má meteor dopadnout (Esc zruší).",
	"aim_confirm": "Seslat meteor",
	"ability_charging": "Meteor se ještě nabíjí (%d s).",
	"won": "Ostrov je zachráněn. Zvládl jsi všech %d vln!",
	"random_place": "Náhodný ostrov",
	"random_desc": "Náhodné rozložení cesty a krajiny. Pokaždé jiný ostrov.",
	"blizzard_toast": "Mrazivý poryv! Nepřátelé zamrzli.",
	"gold_toast": "Zlatá horečka! Dvojnásobné zlato po dobu %d s.",
	"theme_tip": "Prostředí hry (svět, věže, nepřátelé, zvuk). Pravidla zůstávají stejná.",
}

var theme_id: String = "base"
var theme_name: String = "Základní"
var theme_desc: String = ""
var palette: Dictionary = {}            # přepisuje DEFAULT_PALETTE
var strings: Dictionary = {}            # přepisuje DEFAULT_STRINGS
var tower_text: Dictionary = {}         # id -> {name, short, desc, notes: [4 popisy úrovní]}
var enemy_text: Dictionary = {}         # id -> {name, tip}
var ability_text: Dictionary = {}       # id -> {name, desc}
var tower_colors: Dictionary = {}       # id věže -> barva karty a ikony
var enemy_colors: Dictionary = {}       # id nepřítele -> barva (úlomky, tečky v přehledu vlny)
var tower_icons: Dictionary = {}        # id věže -> druh ikony (IconCtrl)
var ability_icons: Dictionary = {}      # id schopnosti -> druh ikony
var audio_id: String = "sky_island"    # které zvukové ladění (Synth) se použije
var loading_color: Color = Color(0.40, 0.62, 0.92, 1.0)
var panel_tint: Color = Color(0.08, 0.11, 0.19, 0.97)
var accent: Color = Color(1.0, 0.82, 0.30)


func color(key: String) -> Color:
	if palette.has(key):
		return palette[key]
	return DEFAULT_PALETTE.get(key, Color(1, 0, 1))


func text(key: String) -> String:
	if strings.has(key):
		return str(strings[key])
	return str(DEFAULT_STRINGS.get(key, key))


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
