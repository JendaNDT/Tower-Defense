class_name Cfg
extends RefCounted
## Herní data na jednom místě: mřížka, ceny, statistiky věží po úrovních, nepřátelé a vlny.
## Číselné hodnoty se dají snadno ladit bez zásahu do logiky.

# ---------------------------------------------------------------- mřížka
const CELL: float = 2.0
const GRID_W: int = 32
const GRID_H: int = 32
const GRID_MIN: Vector2 = Vector2(-32.0, -32.0)   # světový roh buňky (0,0) v rovině XZ

# Výšková stupně pole: 0 = rovina, 1 = kopec, 2 = vrchol. Věž na vyvýšeném poli dohlédne dál (násobek dosahu).
const ELEV_RANGE: Array = [1.0, 1.15, 1.3]
const ELEV_NAMES: Array = ["rovina", "kopec", "vrchol"]

const SELL_RATIO: float = 0.7
const MAX_LEVEL: int = 4
const TOTAL_WAVES: int = 12          # počet vln v běžné hře (v nekonečném režimu vln přibývá dál)

# ---------------------------------------------------------------- obtížnosti
# gold/lives = start, hp = násobek zdraví nepřátel, bonus = násobek bonusu za zvládnutou vlnu, speed = rychlost nepřátel.
const DIFFICULTIES: Dictionary = {
	"easy": {"name": "Lehká", "gold": 320, "lives": 30, "hp": 0.8, "bonus": 1.2, "speed": 1.0,
		"desc": "Víc zlata a životů, slabší nepřátelé. Na rozkoukání."},
	"normal": {"name": "Normální", "gold": 240, "lives": 20, "hp": 1.0, "bonus": 1.0, "speed": 1.0,
		"desc": "Základní výzva."},
	"hard": {"name": "Těžká", "gold": 220, "lives": 15, "hp": 1.25, "bonus": 0.95, "speed": 1.05,
		"desc": "Méně zlata a životů, odolnější a rychlejší nepřátelé."},
}
const DIFFICULTY_ORDER: Array = ["easy", "normal", "hard"]

# ---------------------------------------------------------------- aktivní schopnosti hráče
const ABILITIES: Dictionary = {
	"meteor": {"name": "Meteor", "hotkey": "5", "cooldown": 35.0, "radius": 3.6, "damage": 200.0, "burn_frac": 0.06, "burn_time": 4.0,
		"desc": "Klikni na mapu: dopadne meteor, který zasáhne všechny nepřátele v okruhu (i létající). Poškození roste s vlnou, zasažení hoří."},
	"blizzard": {"name": "Mrazivý poryv", "hotkey": "6", "cooldown": 55.0, "freeze": 2.6, "slow": 0.5, "slow_time": 4.0,
		"desc": "Zmrazí všechny nepřátele na mapě na chvíli a potom je zpomalí. (Boss odolává.)"},
	"gold": {"name": "Zlatá horečka", "hotkey": "7", "cooldown": 80.0, "duration": 15.0, "mult": 2.0,
		"desc": "Na 15 sekund dostaneš za každého zabitého nepřítele dvojnásobek zlata."},
}
const ABILITY_ORDER: Array = ["meteor", "blizzard", "gold"]

const TARGET_MODES: Array = ["first", "last", "strong", "close"]
const TARGET_NAMES: Dictionary = {
	"first": "První",
	"last": "Poslední",
	"strong": "Nejsilnější",
	"close": "Nejbližší",
}

# Trasa, řeka a Srdce ostrova jsou v Islands (rozložení ostrovů).

# ---------------------------------------------------------------- věže
# Každá úroveň: damage, range, cooldown + specifické klíče. "cost" = cena dosažení úrovně.
const TOWERS: Dictionary = {
	"archer": {
		"name": "Lučištník",
		"short": "Rychlá střelba",
		"desc": "Rychlé šípy na pozemní i vzdušné cíle. Slabý proti brnění.",
		"hotkey": "1",
		"air": true, "ground": true,
		"color": Color(0.80, 0.62, 0.30),
		"levels": [
			{"cost": 60, "damage": 9.0, "range": 7.0, "cooldown": 0.75, "shots": 1, "crit": 0.0, "pierce": 0.0,
				"note": "Základní věž. Rychlé šípy."},
			{"cost": 50, "damage": 13.0, "range": 7.8, "cooldown": 0.65, "shots": 1, "crit": 0.0, "pierce": 0.0,
				"note": "Silnější luk: větší dosah, poškození i rychlost."},
			{"cost": 90, "damage": 16.0, "range": 8.6, "cooldown": 0.55, "shots": 2, "crit": 0.0, "pierce": 0.0,
				"note": "Dvojitý výstřel: 2 šípy naráz (na různé cíle)."},
			{"cost": 150, "damage": 22.0, "range": 9.6, "cooldown": 0.45, "shots": 2, "crit": 0.25, "pierce": 0.5,
				"note": "Mistr lukostřelec: 25 % kritický zásah (×2), šípy probíjejí 50 % brnění."},
		],
	},
	"cannon": {
		"name": "Kanón",
		"short": "Plošné poškození",
		"desc": "Pomalé, ale silné dělové koule s výbuchem. Střílí jen po zemi.",
		"hotkey": "2",
		"air": false, "ground": true,
		"color": Color(0.45, 0.45, 0.50),
		"levels": [
			{"cost": 100, "damage": 34.0, "range": 8.0, "cooldown": 2.4, "splash": 1.8, "burn": 0.0, "burn_time": 0.0, "stun": 0.0,
				"note": "Základní kanón. Výbuch zasáhne i okolní nepřátele."},
			{"cost": 80, "damage": 48.0, "range": 8.8, "cooldown": 2.1, "splash": 2.2, "burn": 0.0, "burn_time": 0.0, "stun": 0.0,
				"note": "Těžší koule: větší poškození a plocha výbuchu."},
			{"cost": 140, "damage": 62.0, "range": 9.6, "cooldown": 1.8, "splash": 2.6, "burn": 7.0, "burn_time": 3.0, "stun": 0.0,
				"note": "Zápalné koule: zasažení hoří (7 dmg/s po 3 s)."},
			{"cost": 230, "damage": 90.0, "range": 10.5, "cooldown": 1.5, "splash": 3.3, "burn": 12.0, "burn_time": 3.5, "stun": 0.5,
				"note": "Drtič: obří výbuch, silnější oheň a 0,5 s omráčení."},
		],
	},
	"mage": {
		"name": "Mág",
		"short": "Magie, řetězový blesk",
		"desc": "Magické koule ignorují brnění. Vyšší úrovně přeskakují mezi nepřáteli.",
		"hotkey": "3",
		"air": true, "ground": true,
		"color": Color(0.55, 0.35, 0.95),
		"levels": [
			{"cost": 120, "damage": 20.0, "range": 7.5, "cooldown": 1.1, "chain": 0, "chain_falloff": 0.6, "chain_range": 3.5,
				"note": "Základní mág. Magie ignoruje brnění."},
			{"cost": 90, "damage": 30.0, "range": 8.3, "cooldown": 1.0, "chain": 0, "chain_falloff": 0.6, "chain_range": 3.5,
				"note": "Silnější krystal: víc poškození a dosahu."},
			{"cost": 150, "damage": 38.0, "range": 9.0, "cooldown": 0.9, "chain": 2, "chain_falloff": 0.6, "chain_range": 3.8,
				"note": "Řetězový blesk: zásah přeskočí na další 2 cíle."},
			{"cost": 240, "damage": 55.0, "range": 9.8, "cooldown": 0.8, "chain": 4, "chain_falloff": 0.7, "chain_range": 4.2,
				"note": "Archmág: blesk přeskočí na 4 cíle a téměř neztrácí sílu."},
		],
	},
	"frost": {
		"name": "Mráz",
		"short": "Zpomalení v okruhu",
		"desc": "Pulzy mrazu zpomalí všechny nepřátele v okruhu (i vzdušné). Malé poškození.",
		"hotkey": "4",
		"air": true, "ground": true,
		"color": Color(0.45, 0.80, 0.98),
		"levels": [
			{"cost": 90, "damage": 5.0, "range": 4.8, "cooldown": 1.8, "slow": 0.35, "slow_time": 2.0, "freeze_every": 0, "freeze_time": 0.0,
				"note": "Základní mráz: zpomalí o 35 %."},
			{"cost": 70, "damage": 8.0, "range": 5.6, "cooldown": 1.6, "slow": 0.45, "slow_time": 2.2, "freeze_every": 0, "freeze_time": 0.0,
				"note": "Větší okruh a zpomalení o 45 %."},
			{"cost": 120, "damage": 12.0, "range": 6.4, "cooldown": 1.4, "slow": 0.55, "slow_time": 2.5, "freeze_every": 0, "freeze_time": 0.0,
				"note": "Hluboký mráz: zpomalení o 55 % a delší účinek."},
			{"cost": 200, "damage": 18.0, "range": 7.4, "cooldown": 1.2, "slow": 0.65, "slow_time": 3.0, "freeze_every": 3, "freeze_time": 0.9,
				"note": "Ledová bouře: zpomalení o 65 %, každý 3. pulz zmrazí na 0,9 s."},
		],
	},
}
const TOWER_ORDER: Array = ["archer", "cannon", "mage", "frost"]

# ---------------------------------------------------------------- nepřátelé
# armor = plošné snížení fyzického poškození, magie brnění ignoruje.
const ENEMIES: Dictionary = {
	"goblin": {"name": "Skřet", "hp": 45.0, "speed": 2.0, "armor": 0.0, "reward": 7, "lives": 1,
		"flying": false, "radius": 0.45, "color": Color(0.45, 0.70, 0.30)},
	"wolf": {"name": "Vlk (rychlý)", "hp": 28.0, "speed": 3.8, "armor": 0.0, "reward": 6, "lives": 1,
		"flying": false, "radius": 0.5, "color": Color(0.55, 0.55, 0.62)},
	"golem": {"name": "Obrněnec", "hp": 170.0, "speed": 1.4, "armor": 6.0, "reward": 17, "lives": 2,
		"flying": false, "radius": 0.62, "color": Color(0.58, 0.60, 0.68)},
	"drake": {"name": "Dráček (létající)", "hp": 50.0, "speed": 2.8, "armor": 0.0, "reward": 11, "lives": 1,
		"flying": true, "radius": 0.5, "color": Color(0.85, 0.35, 0.30)},
	"healer": {"name": "Léčitel", "hp": 75.0, "speed": 1.9, "armor": 0.0, "reward": 14, "lives": 1,
		"flying": false, "radius": 0.48, "color": Color(0.55, 0.85, 0.55),
		"heal_radius": 4.6, "heal_frac": 0.07, "heal_every": 2.2,
		"tip": "Každé 2 s vyléčí okolní nepřátele. Zabij ho jako prvního."},
	"shield": {"name": "Štítonoš", "hp": 90.0, "speed": 1.7, "armor": 2.0, "reward": 16, "lives": 1,
		"flying": false, "radius": 0.55, "color": Color(0.45, 0.65, 0.95),
		"shield": 130.0, "shield_regen": 0.2,
		"tip": "Štít pohlcuje poškození (po 3 s bez zásahu se částečně obnoví). Silné rány ho prorazí."},
	"slime": {"name": "Slizák", "hp": 80.0, "speed": 1.9, "armor": 0.0, "reward": 8, "lives": 1,
		"flying": false, "radius": 0.55, "color": Color(0.35, 0.85, 0.45),
		"split": 2, "split_type": "slimeling", "split_hp": 0.3,
		"tip": "Po smrti se rozpadne na dva rychlé slizánky. Plošné poškození je výhodné."},
	"slimeling": {"name": "Slizánek", "hp": 30.0, "speed": 2.7, "armor": 0.0, "reward": 3, "lives": 1,
		"flying": false, "radius": 0.32, "color": Color(0.45, 0.92, 0.55), "hidden": true},
	"boss": {"name": "Kamenný obr (boss)", "hp": 1500.0, "speed": 1.1, "armor": 9.0, "reward": 120, "lives": 5,
		"flying": false, "radius": 1.05, "color": Color(0.50, 0.46, 0.42)},
}

# ---------------------------------------------------------------- vlny
# group: [typ, počet, interval mezi kusy (s), zpoždění začátku skupiny (s)]
const WAVES: Array = [
	{"hp": 1.00, "bonus": 25, "groups": [["goblin", 8, 1.4, 0.0]]},
	{"hp": 1.00, "bonus": 30, "groups": [["goblin", 10, 1.1, 0.0], ["wolf", 4, 1.0, 6.0]]},
	{"hp": 1.10, "bonus": 35, "groups": [["goblin", 8, 1.0, 0.0], ["wolf", 8, 0.8, 5.0], ["drake", 3, 1.5, 12.0]]},
	{"hp": 1.25, "bonus": 40, "groups": [["golem", 3, 3.0, 0.0], ["goblin", 8, 0.9, 3.0], ["slime", 4, 1.4, 8.0]]},
	{"hp": 1.25, "bonus": 60, "groups": [["boss", 1, 1.0, 6.0], ["goblin", 8, 1.0, 0.0], ["wolf", 6, 0.8, 10.0]]},
	{"hp": 1.50, "bonus": 50, "groups": [["drake", 10, 1.0, 0.0], ["golem", 3, 2.5, 4.0], ["shield", 3, 2.0, 8.0], ["wolf", 6, 0.8, 12.0]]},
	{"hp": 1.75, "bonus": 55, "groups": [["goblin", 14, 0.7, 0.0], ["golem", 4, 2.0, 5.0], ["healer", 2, 3.0, 6.0], ["drake", 6, 1.2, 8.0]]},
	{"hp": 2.10, "bonus": 60, "groups": [["wolf", 12, 0.55, 0.0], ["shield", 5, 1.8, 3.0], ["slime", 5, 1.2, 5.0], ["drake", 8, 1.0, 7.0]]},
	{"hp": 2.60, "bonus": 70, "groups": [["golem", 8, 1.6, 0.0], ["drake", 12, 0.8, 5.0], ["healer", 3, 2.5, 6.0], ["shield", 4, 1.8, 8.0], ["goblin", 12, 0.6, 10.0]]},
	{"hp": 3.40, "bonus": 90, "groups": [["boss", 2, 10.0, 4.0], ["golem", 5, 2.0, 0.0], ["drake", 10, 0.9, 6.0], ["slime", 8, 1.0, 8.0], ["healer", 3, 3.0, 9.0], ["wolf", 8, 0.6, 12.0]]},
	{"hp": 4.30, "bonus": 100, "groups": [["goblin", 20, 0.5, 0.0], ["wolf", 12, 0.5, 4.0], ["golem", 8, 1.4, 6.0], ["shield", 6, 1.5, 7.0], ["healer", 4, 2.5, 8.0], ["drake", 14, 0.7, 9.0]]},
	{"hp": 5.40, "bonus": 0, "groups": [["boss", 3, 8.0, 2.0], ["golem", 12, 1.2, 3.0], ["drake", 18, 0.6, 6.0], ["slime", 10, 0.8, 8.0], ["shield", 8, 1.2, 9.0], ["healer", 5, 2.0, 10.0], ["wolf", 16, 0.4, 12.0], ["goblin", 14, 0.4, 14.0]]},
]


## Definice vlny podle indexu. Po poslední pevné vlně (nekonečný režim) se vlny dopočítávají:
## zdraví roste o ~11,5 % za vlnu, počty o 7 %, každá čtvrtá vlna má bosse.
static func wave_def(idx: int) -> Dictionary:
	if idx < WAVES.size():
		return WAVES[idx]
	var n: int = idx - WAVES.size() + 1
	var k: float = 1.0 + 0.07 * float(n)
	var hp: float = float(WAVES[WAVES.size() - 1]["hp"]) * pow(1.115, float(n))
	var groups: Array = []
	match idx % 4:
		0:
			groups = [["goblin", int(24.0 * k), 0.4, 0.0], ["wolf", int(16.0 * k), 0.45, 4.0], ["slime", int(8.0 * k), 0.9, 6.0],
				["healer", 3 + int(float(n) / 4.0), 2.2, 8.0], ["drake", int(14.0 * k), 0.6, 10.0]]
		1:
			groups = [["golem", int(12.0 * k), 1.2, 0.0], ["shield", int(8.0 * k), 1.3, 3.0], ["healer", 4 + int(float(n) / 4.0), 2.0, 6.0],
				["drake", int(12.0 * k), 0.7, 9.0]]
		2:
			groups = [["drake", int(26.0 * k), 0.5, 0.0], ["wolf", int(14.0 * k), 0.45, 4.0], ["shield", int(6.0 * k), 1.4, 6.0],
				["healer", 3 + int(float(n) / 4.0), 2.2, 8.0], ["slime", int(8.0 * k), 0.9, 10.0]]
		_:
			groups = [["boss", 2 + int(float(n) / 3.0), 7.0, 2.0], ["golem", int(10.0 * k), 1.2, 3.0], ["slime", int(10.0 * k), 0.8, 6.0],
				["wolf", int(18.0 * k), 0.4, 9.0], ["healer", 4 + int(float(n) / 4.0), 2.0, 11.0]]
	return {"hp": hp, "bonus": 100 + 5 * n, "groups": groups}


# ---------------------------------------------------------------- pomocné funkce
static func tower_level(id: String, level: int) -> Dictionary:
	var lv: Array = TOWERS[id]["levels"]
	return lv[clampi(level, 1, lv.size()) - 1]


static func tower_cost(id: String) -> int:
	return int(tower_level(id, 1)["cost"])


static func upgrade_cost(id: String, level: int) -> int:
	## Cena vylepšení z úrovně `level` na `level + 1` (-1 = už je maximum).
	if level >= MAX_LEVEL:
		return -1
	return int(tower_level(id, level + 1)["cost"])


static func invested(id: String, level: int) -> int:
	var sum: int = 0
	for l in range(1, level + 1):
		sum += int(tower_level(id, l)["cost"])
	return sum


static func sell_value(id: String, level: int) -> int:
	return int(floor(invested(id, level) * SELL_RATIO))


static func dps_of(id: String, level: int) -> float:
	## Orientační DPS na jeden cíl (bez brnění) – jen pro zobrazení v UI.
	var st: Dictionary = tower_level(id, level)
	var dmg: float = float(st["damage"])
	var cd: float = float(st["cooldown"])
	match id:
		"archer":
			var crit: float = float(st["crit"])
			return dmg * (1.0 + crit) * float(st["shots"]) / cd
		_:
			return dmg / cd


static func cell_center(cx: int, cz: int) -> Vector2:
	return Vector2(GRID_MIN.x + (cx + 0.5) * CELL, GRID_MIN.y + (cz + 0.5) * CELL)


static func world_to_cell(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor((x - GRID_MIN.x) / CELL)), int(floor((z - GRID_MIN.y) / CELL)))


static func cell_valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID_W and c.y < GRID_H


## Formátování desetinných čísel s českou čárkou.
static func fmt(v: float, decimals: int = 1) -> String:
	var s: String = String.num(v, decimals)
	return s.replace(".", ",")
