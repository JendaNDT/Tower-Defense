class_name ThemeSciFi
extends GameTheme
## Motiv „Vesmírná stanice“: plošina na asteroidu v hlubokém vesmíru s neonovými biomy, energetickou řekou a vodopádem.
## Věže: laser, plazmomet, Teslova věž, kryo věž. Nepřátelé: roboti, mechové, drony a nanorój. Vlastní zvuk (audio_id "scifi").


func _init() -> void:
	theme_id = "scifi"
	theme_name = "Vesmírná stanice"
	audio_id = "scifi"
	loading_color = Color(0.03, 0.04, 0.11, 1.0)
	panel_tint = Color(0.05, 0.08, 0.15, 0.97)
	accent = Color(0.35, 0.90, 1.0)

	strings = {
		"title": "Vesmírná stanice",
		"gold_gen": "kreditů",
		"intro_sub": "Braň reaktor stanice před vlnami nepřátel. Vyber si hru:",
		"loading": "Spouštím vesmírnou stanici…",
		"place": "Plošina",
		"place_gen": "plošiny",
		"base": "Reaktor stanice",
		"base_dat": "reaktoru",
		"menu_tip": "Nová hra / nastavení (režim, obtížnost, plošina)",
		"menu_change": "Změnit nastavení (režim, obtížnost, plošina)",
		"mode_campaign": "Přežij všech %d vln a ubraň reaktor stanice.",
		"base_fell": "Reaktor stanice byl zničen.",
		"base_hit": "Nepřítel zasáhl reaktor! −%d životů",
		"help_intro": "Braň reaktor stanice před vlnami nepřátel, kteří přicházejí z hvězdné brány po cestě přes celou plošinu.",
		"help_units": "Plazmomet nezasáhne vzdušné cíle, pancíř snižuje poškození laseru – proti němu pomůže Teslova věž.",
		"help_enemies": "Opraváře znič jako prvního, štítové droidy prorazí silné rány, nanorój se po zničení rozdělí.",
		"help_abilities_touch": "Schopnosti vlevo dole: Orbitální úder (klepni na místo dopadu a potvrď), Kryo vlna a Kreditový šok. Po použití se nabíjejí.",
		"help_abilities": "Schopnosti vlevo dole (klávesy 5, 6, 7): Orbitální úder (klikni na mapu), Kryo vlna a Kreditový šok. Po použití se nabíjejí.",
		"aim_touch": "Klepni na mapu, kam má dopadnout orbitální úder, a potvrď.",
		"aim_mouse": "Klikni na mapu, kam má dopadnout orbitální úder (Esc zruší).",
		"aim_confirm": "Spustit úder",
		"ability_charging": "Orbitální úder se ještě nabíjí (%d s).",
		"won": "Stanice je zachráněna. Zvládl jsi všech %d vln!",
		"random_place": "Náhodná plošina",
		"random_desc": "Náhodné rozložení cesty a krajiny. Pokaždé jiná plošina.",
		"blizzard_toast": "Kryo vlna! Nepřátelé zamrzli.",
		"gold_toast": "Kreditový šok! Dvojnásobné kredity po dobu %d s.",
	}

	tower_text = {
		"archer": {"name": "Laser", "short": "Rychlé výboje",
			"desc": "Rychlé laserové výboje na pozemní i vzdušné cíle. Slabé proti pancíři.",
			"notes": ["Základní laser. Rychlé výboje.",
				"Zesílený zdroj: větší dosah, poškození i rychlost.",
				"Dvouhlavňový laser: 2 výboje naráz (na různé cíle).",
				"Přesné zaměřování: 25 % kritický zásah (×2), výboje probíjejí 50 % pancíře."]},
		"cannon": {"name": "Plazmomet", "short": "Plošné poškození",
			"desc": "Pomalé, ale silné plazmové granáty s výbuchem. Střílí jen po zemi.",
			"notes": ["Základní plazmomet. Výbuch zasáhne i okolní nepřátele.",
				"Těžší náboj: větší poškození a plocha výbuchu.",
				"Žhavé plazma: zasažení hoří (7 dmg/s po 3 s).",
				"Rozbušení: obří výbuch, silnější žár a 0,5 s omráčení."]},
		"mage": {"name": "Teslova věž", "short": "Blesky, řetězení",
			"desc": "Elektrické výboje ignorují pancíř. Vyšší úrovně přeskakují mezi nepřáteli.",
			"notes": ["Základní cívka. Elektřina ignoruje pancíř.",
				"Silnější cívka: víc poškození a dosahu.",
				"Řetězový výboj: zásah přeskočí na další 2 cíle.",
				"Tesla Max: výboj přeskočí na 4 cíle a téměř neztrácí sílu."]},
		"frost": {"name": "Kryo věž", "short": "Zpomalení v okruhu",
			"desc": "Pulzy extrémního chladu zpomalí všechny nepřátele v okruhu (i vzdušné). Malé poškození.",
			"notes": ["Základní kryo: zpomalí o 35 %.",
				"Větší okruh a zpomalení o 45 %.",
				"Hluboké zmrazení: zpomalení o 55 % a delší účinek.",
				"Absolutní nula: zpomalení o 65 %, každý 3. pulz zmrazí na 0,9 s."]},
	}
	enemy_text = {
		"goblin": {"name": "Pěšák-bot"},
		"wolf": {"name": "Robopes (rychlý)"},
		"golem": {"name": "Těžký mech"},
		"drake": {"name": "Dron (létající)"},
		"healer": {"name": "Opravář", "tip": "Každé 2 s opraví okolní nepřátele. Znič ho jako prvního."},
		"shield": {"name": "Štítový droid", "tip": "Energetický štít pohlcuje poškození (po 3 s bez zásahu se částečně obnoví). Silné rány ho prorazí."},
		"slime": {"name": "Nanorój", "tip": "Po zničení se rozdělí na dvě rychlé nanočástice. Plošné poškození je výhodné."},
		"slimeling": {"name": "Nanočástice"},
		"boss": {"name": "Titán (boss)"},
	}
	ability_text = {
		"meteor": {"name": "Orbitální úder",
			"desc": "Klikni na mapu: z oběžné dráhy dopadne plazmový úder, který zasáhne všechny nepřátele v okruhu (i létající). Poškození roste s vlnou, zasažení hoří."},
		"blizzard": {"name": "Kryo vlna",
			"desc": "Zmrazí všechny nepřátele na mapě na chvíli a potom je zpomalí. (Boss odolává.)"},
		"gold": {"name": "Kreditový šok",
			"desc": "Na 15 sekund dostaneš za každého zničeného nepřítele dvojnásobek kreditů."},
	}
	tower_icons = {"archer": "laser", "cannon": "plasma", "mage": "tesla", "frost": "cryo"}
	ability_icons = {"meteor": "strike", "blizzard": "snow", "gold": "goldrush"}
	tower_colors = {
		"archer": Color(1.0, 0.36, 0.34),
		"cannon": Color(0.50, 1.0, 0.40),
		"mage": Color(0.68, 0.55, 1.0),
		"frost": Color(0.45, 0.92, 1.0),
	}
	enemy_colors = {
		"goblin": Color(0.92, 0.52, 0.18), "wolf": Color(0.55, 0.62, 0.74), "golem": Color(0.55, 0.60, 0.72),
		"drake": Color(0.25, 0.65, 1.0), "healer": Color(0.45, 1.0, 0.55), "shield": Color(0.40, 0.55, 0.95),
		"slime": Color(0.65, 0.78, 0.92), "slimeling": Color(0.65, 0.85, 0.95), "boss": Color(0.45, 0.50, 0.62),
	}

	# barvy efektů: lasery červené, plazma zelená, Tesla fialová, kryo azurové; výbuchy a jiskry elektrické
	palette = {
		"muzzle_archer": Color(1.0, 0.45, 0.40), "muzzle_cannon": Color(0.55, 1.0, 0.40), "muzzle_mage": Color(0.72, 0.62, 1.0),
		"muzzle_core": Color(1.0, 1.0, 1.0),
		"archer_puff": Color(1.0, 0.7, 0.65), "cannon_smoke": Color(0.55, 0.62, 0.70), "cannon_fire": Color(0.55, 1.0, 0.40),
		"mage_puff": Color(0.72, 0.62, 1.0),
		"frost_ring": Color(0.40, 0.92, 1.0), "frost_ring_freeze": Color(0.85, 1.0, 1.0), "frost_puff": Color(0.7, 0.97, 1.0),
		"frost_hit": Color(0.6, 0.97, 1.0),
		"arrow_hit": Color(1.0, 0.55, 0.45), "arrow_miss": Color(0.55, 0.62, 0.75),
		"ball_trail": Color(0.35, 0.8, 0.5), "orb_trail": Color(0.72, 0.62, 1.0),
		"magic_hit": Color(0.78, 0.7, 1.0), "chain_beam": Color(0.75, 0.8, 1.0), "chain_hit": Color(0.9, 0.9, 1.0),
		"streak_arrow": Color(1.0, 0.35, 0.30), "streak_ball": Color(0.50, 1.0, 0.35), "streak_orb": Color(0.72, 0.62, 1.0),
		"explosion_fire": Color(0.60, 1.0, 0.45), "explosion_smoke": Color(0.20, 0.30, 0.35), "explosion_ring": Color(0.70, 1.0, 0.55),
		"explosion_debris": Color(0.35, 0.45, 0.55), "death_puff": Color(0.55, 0.85, 1.0),
		"crumble_dust": Color(0.45, 0.55, 0.70), "crash_puff": Color(1.0, 0.55, 0.20), "crash_dust": Color(0.45, 0.55, 0.70),
		"step_dust": Color(0.45, 0.55, 0.68), "absorb_spark": Color(0.4, 0.95, 1.0), "shield_break": Color(0.45, 0.95, 1.0),
		"heal": Color(0.45, 1.0, 0.70), "ripple": Color(0.55, 0.95, 1.0), "shield_bubble": Color(0.30, 0.85, 1.0),
		"tint_frozen": Color(0.65, 0.95, 1.0), "tint_burn": Color(0.55, 1.0, 0.30), "tint_slow": Color(0.35, 0.80, 1.0),
		"spawn_puff": Color(0.30, 0.90, 1.0), "base_hit": Color(1.0, 0.35, 0.35),
		"build_ring": Color(0.55, 0.95, 1.0), "build_puff": Color(0.60, 0.80, 0.95), "build_dust": Color(0.45, 0.60, 0.80),
		"sell_puff": Color(0.60, 0.75, 0.95), "upgrade_ring": Color(0.45, 0.95, 1.0), "upgrade_puff": Color(0.70, 1.0, 1.0),
		"gold_text": Color(1.0, 0.85, 0.30), "gold_ring": Color(0.45, 0.95, 1.0),
		"blizzard_puff": Color(0.7, 0.97, 1.0), "blizzard_ring": Color(0.40, 0.90, 1.0),
		"meteor_body": Color(0.30, 0.38, 0.55), "meteor_fire": Color(1.0, 0.75, 0.30), "meteor_ring": Color(1.0, 0.45, 0.30),
		"meteor_flash": Color(1.0, 0.95, 0.75), "meteor_puff": Color(0.45, 0.9, 1.0), "meteor_aim": Color(1.0, 0.55, 0.35),
		"select_ring": Color(0.40, 0.95, 1.0),
	}


func build_world(parent: Node3D, map: GameMap, high_quality: bool) -> Dictionary:
	return SciFiWorld.build(parent, map, high_quality)


func make_tower_visual(type: String, level: int) -> TowerVisual:
	return SciFiTowers.build(type, level)


func make_enemy_visual(type: String) -> EnemyVisual:
	return SciFiEnemies.build(type)


## Projektily: laserový výboj (arrow), plazmová koule (ball), Teslova koule (orb). Špička míří do -Z.
func make_projectile_visual(kind: String) -> Node3D:
	var root: Node3D = Node3D.new()
	var k: MeshKit = MeshKit.new(7, 0.0)
	var mat: ShaderMaterial = Gfx.model_mat(0.3, 0.0)
	match kind:
		"arrow":
			k.cyl(0.03, 0.03, 0.8, 6, Color(1.0, 0.45, 0.4), MeshKit.xf(Vector3(0.0, 0.0, 0.4), Vector3(-90.0, 0.0, 0.0)), 2.6, false, false)
			k.cyl(0.012, 0.012, 0.82, 5, Color(1.0, 1.0, 1.0), MeshKit.xf(Vector3(0.0, 0.0, 0.4), Vector3(-90.0, 0.0, 0.0)), 3.5, false, false)
			k.cone(0.045, 0.14, 6, Color(1.0, 0.8, 0.75), MeshKit.xf(Vector3(0.0, 0.0, -0.36), Vector3(-90.0, 0.0, 0.0)), 3.0, false)
		"ball":
			k.sphere(0.2, Color(0.35, 0.95, 0.30), Transform3D.IDENTITY, 2.0, 10, 7, true)
			k.sphere(0.11, Color(0.9, 1.0, 0.85), Transform3D.IDENTITY, 3.4, 7, 5)
			k.torus(0.27, 0.025, Color(0.7, 1.0, 0.6), MeshKit.xf(Vector3.ZERO, Vector3(70.0, 0.0, 0.0)), 2.4, 14, 4)
			mat = Gfx.model_mat(0.25, 0.0)
		_:
			k.sphere(0.17, Color(0.62, 0.52, 1.0), Transform3D.IDENTITY, 2.4, 8, 6, true)
			k.sphere(0.09, Color(1.0, 0.98, 1.0), Transform3D.IDENTITY, 3.6, 6, 4)
			for i in range(5):
				var a: float = TAU * float(i) / 5.0
				k.cone(0.03, 0.22, 4, Color(0.85, 0.85, 1.0), MeshKit.xf(Vector3(cos(a) * 0.17, sin(a) * 0.17, 0.0), Vector3(0.0, 0.0, rad_to_deg(a) - 90.0)), 3.0, false)
			mat = Gfx.model_mat(0.2, 0.0)
	var mi: MeshInstance3D = Gfx.mesh_node(k, mat, false)
	root.add_child(mi)
	return root
