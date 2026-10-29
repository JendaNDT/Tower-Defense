class_name TestBridge
extends RefCounted
## Testovací rozhraní pro prohlížeč (aktivní jen s ?test=1 nebo na webu):
## window.TD_state() / window.TD_cmd(JSON) provedou dotaz/příkaz; výsledek (JSON) je pak v window.TD_out.
## Slouží automatickým testům (Playwright); hráč ho nepotřebuje.

var main = null
var _win = null
var _cb_state = null
var _cb_cmd = null


func setup(m) -> void:
	main = m
	if not OS.has_feature("web"):
		return
	_win = JavaScriptBridge.get_interface("window")
	_cb_state = JavaScriptBridge.create_callback(_js_state)
	_cb_cmd = JavaScriptBridge.create_callback(_js_cmd)
	_win.TD_state = _cb_state
	_win.TD_cmd = _cb_cmd
	_win.TD_ready = true


## Callbacky z JavaScriptu nevrací hodnotu, proto se výsledek ukládá do window.TD_out.
func _js_state(_args) -> void:
	_win.TD_out = JSON.stringify(state())


func _js_cmd(args) -> void:
	var parsed = JSON.parse_string(str(args[0]))
	if typeof(parsed) != TYPE_DICTIONARY:
		_win.TD_out = JSON.stringify({"ok": false, "error": "bad json"})
		return
	_win.TD_out = JSON.stringify(cmd(parsed))


func state() -> Dictionary:
	var g: Game = main.game
	var s: Dictionary = g.snapshot()
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	s["viewport"] = [vp.x, vp.y]
	s["selected"] = main.selected.uid if main.selected != null else -1
	s["build_type"] = main.build_type
	s["fps"] = Engine.get_frames_per_second()
	s["camera"] = {"yaw": main.rig.yaw_deg, "zoom": main.rig.zoom_size}
	s["modal"] = main.hud.is_modal_open()
	s["fly_alt"] = g.fly_altitude
	s["draw_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	s["objects"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	s["primitives"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	s["proj_hits"] = g.proj_hits
	s["proj_fizzles"] = g.proj_fizzles
	return s


func _screen(world_pos: Vector3) -> Array:
	var cam: Camera3D = main.rig.camera
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var p: Vector2 = cam.unproject_position(world_pos)
	return [p.x / vp.x, p.y / vp.y]


func _tower_by_id(id: int):
	for t in main.game.towers:
		if t.uid == id:
			return t
	return null


func cmd(req: Dictionary) -> Dictionary:
	var g: Game = main.game
	var op: String = str(req.get("op", ""))
	match op:
		"begin":
			main.hud._intro.visible = false
			main._on_begin()
			return {"ok": true}
		"build":
			var t = g.build_tower(str(req["type"]), Vector2i(int(req["cx"]), int(req["cz"])))
			return {"ok": t != null, "id": t.uid if t != null else -1}
		"upgrade":
			var tw = _tower_by_id(int(req["id"]))
			return {"ok": g.upgrade_tower(tw) if tw != null else false}
		"sell":
			var tw2 = _tower_by_id(int(req["id"]))
			if tw2 != null:
				g.sell_tower(tw2)
			return {"ok": tw2 != null}
		"wave":
			var ok: bool = g.start_next_wave()
			main.hud._refresh_wave_panel()
			return {"ok": ok}
		"speed":
			g.speed_mul = float(req.get("v", 1.0))
			return {"ok": true}
		"pause":
			main._set_paused(bool(req.get("v", true)))
			return {"ok": true}
		"simbot":
			# celá hra odehraná botem přímo v exportované verzi (stejný kód jako headless test)
			var rep: Dictionary = SimTest._bot_game(g, str(req.get("pol", "vysoka")))
			g.reset()
			return {"ok": true, "report": rep}
		"lives":
			g.lives = int(req.get("v", 1))
			g.lives_changed.emit(g.lives)
			return {"ok": true}
		"win":
			# vynutí dokončení poslední vlny (pro kontrolu obrazovky výhry)
			var last: int = maxi(g.total_waves, 1) - 1
			g.waves_started = last + 1
			g._wave_done[last] = false
			g._wave_spawn_left[last] = 0
			g._wave_alive[last] = 0
			g._check_wave_done(last)
			return {"ok": true, "state": g.state}
		"freeze":
			g.paused = bool(req.get("v", true))
			return {"ok": true}
		"gold":
			g.gold += int(req.get("v", 0))
			g.gold_changed.emit(g.gold)
			return {"ok": true, "gold": g.gold}
		"select":
			main._select_tower(_tower_by_id(int(req["id"])))
			return {"ok": true}
		"cancel":
			main._cancel_all()
			return {"ok": true}
		"cam":
			if req.has("yaw"):
				main.rig.target_yaw = float(req["yaw"])
				main.rig.yaw_deg = float(req["yaw"])
			if req.has("zoom"):
				main.rig.target_zoom = float(req["zoom"])
				main.rig.zoom_size = float(req["zoom"])
			if req.has("px"):
				main.rig.target_pivot = Vector3(float(req["px"]), 0.0, float(req["pz"]))
				main.rig.position = main.rig.target_pivot
			return {"ok": true}
		"project":
			return {"ok": true, "p": _screen(Vector3(float(req["x"]), float(req["y"]), float(req["z"])))}
		"cell_screen":
			var cw: Vector3 = g.map.cell_world(Vector2i(int(req["cx"]), int(req["cz"])))
			return {"ok": true, "p": _screen(cw)}
		"tower_screen":
			var tw3 = _tower_by_id(int(req["id"]))
			if tw3 == null:
				return {"ok": false}
			return {"ok": true, "p": _screen(tw3.position + Vector3(0, 0.15, 0))}
		"cells":
			# volná pole u cesty seřazená podle polohy podél trasy (pro volbu míst ve stavebních testech)
			var out: Array = []
			var path: PathData = g.path
			for cz in range(Cfg.GRID_H):
				for cx in range(Cfg.GRID_W):
					var c: Vector2i = Vector2i(cx, cz)
					if g.map.cell_state(c) != GameMap.Cell.FREE:
						continue
					var w: Vector2 = Cfg.cell_center(cx, cz)
					var best_s: float = 0.0
					var best_d: float = 1e9
					var s: float = 0.0
					while s <= path.length:
						var pp: Vector2 = path.xz_at(s)
						var d: float = pp.distance_to(w)
						if d < best_d:
							best_d = d
							best_s = s
						s += 1.0
					if best_d <= 3.2:
						out.append({"cx": cx, "cz": cz, "s": best_s, "d": snappedf(best_d, 0.01)})
			out.sort_custom(func(a, b): return float(a["s"]) < float(b["s"]))
			return {"ok": true, "cells": out}
		"ui":
			var r: Rect2 = main.hud.ui_rect(str(req.get("name", "")))
			var vp2: Vector2 = main.get_viewport().get_visible_rect().size
			if r.size == Vector2.ZERO:
				return {"ok": false}
			var cc: Vector2 = r.get_center()
			return {"ok": true, "p": [cc.x / vp2.x, cc.y / vp2.y], "enabled": not _is_disabled(str(req.get("name", "")))}
		"spawn":
			var typ: String = str(req.get("type", "goblin"))
			var n: int = int(req.get("n", 5))
			var iv: float = float(req.get("interval", 1.0))
			for i in range(n):
				g._spawn_queue.append({"at": g.time + float(req.get("delay", 0.0)) + float(i) * iv, "type": typ, "wave": Game.TEST_WAVE, "hp": float(req.get("hp", 1.0))})
			g._spawn_queue.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))
			return {"ok": true, "queued": n}
		"lineup":
			# pro snímky: postaví nepřátele za sebe na trase (od vzdálenosti s0, rozestup ds)
			var types: Array = req.get("types", ["goblin", "wolf", "golem", "drake", "boss"])
			var s0: float = float(req.get("s0", 8.0))
			var ds: float = float(req.get("ds", 3.2))
			var out2: Array = []
			for i in range(types.size()):
				g._spawn_enemy({"at": 0.0, "type": str(types[i]), "wave": Game.TEST_WAVE, "hp": 1.0})
				var en = g.enemies[g.enemies.size() - 1]
				en.s = s0 + float(i) * ds
				en.update(0.0)
				out2.append([en.position.x, en.position.y, en.position.z])
			return {"ok": true, "pos": out2}
		"step":
			# posune simulaci o t sekund (kroky po 1/30 s), nezávisle na FPS vykreslování
			var left: float = float(req.get("t", 1.0))
			var was_paused: bool = g.paused
			g.paused = false
			while left > 0.0:
				var h: float = minf(left, 1.0 / 30.0)
				g.tick(h)
				left -= h
			g.paused = was_paused
			return {"ok": true}
		"max_dt":
			g.max_frame_dt = float(req.get("v", 0.1))
			return {"ok": true}
		"tower_info":
			var tw4 = _tower_by_id(int(req["id"]))
			if tw4 == null:
				return {"ok": false}
			return {"ok": true, "type": tw4.type, "level": tw4.level, "stats": tw4.stats(), "damage_dealt": tw4.damage_dealt,
				"kills": tw4.kills, "shots": tw4.shots_fired, "pos": [tw4.position.x, tw4.position.y, tw4.position.z], "visuals": _visual_count(tw4)}
		"kill":
			# zabije nepřátele daných typů (nebo všechny) bez vlivu věže – pro snímky smrti
			var kt: Array = req.get("types", [])
			var nk: int = 0
			for en2 in g.enemies.duplicate():
				if kt.is_empty() or kt.has(en2.type):
					en2.die(null)
					nk += 1
			return {"ok": true, "killed": nk}
		"reach":
			# nepřátelé „dorazí“ k Srdci (animace vsáknutí) bez ztráty životů navíc
			var nr: int = 0
			for en3 in g.enemies.duplicate():
				en3.reach_base()
				nr += 1
			return {"ok": true, "reached": nr}
		"tower_anim":
			var tw5 = _tower_by_id(int(req["id"]))
			if tw5 == null:
				return {"ok": false}
			tw5.visual.seek_anim(str(req.get("kind", "build")), float(req.get("t", 0.0)))
			var tv = tw5.visual
			return {"ok": true, "sx": tv.scale.x, "sy": tv.scale.y, "y": tv.position.y}
		"quality":
			main._on_quality(bool(req.get("v", true)))
			return {"ok": true, "quality": Gfx.quality_high}
		"fx_test":
			var fp: Vector3 = Vector3(float(req.get("x", 0.0)), float(req.get("y", 0.0)), float(req.get("z", 0.0)))
			match str(req.get("kind", "scorch")):
				"scorch":
					g.fx.scorch(fp, float(req.get("r", 2.0)), float(req.get("a", 0.6)))
				"dust":
					g.fx.dust_ring(fp, Color(0.74, 0.66, 0.52), 10, 1.2, 0.55)
				"flash":
					g.fx.muzzle_flash(fp, Vector3(0.0, 0.2, 1.0).normalized(), Color(1.0, 0.7, 0.3), 0.9, 5)
			return {"ok": true}
		"gfx_info":
			main.blobs.refresh()                # stíny se jinak přepočítají až při dalším vykresleném snímku (v testu pomalém)
			return {"ok": true, "quality": Gfx.quality_high, "blobs": main.blobs.count(), "scorches": g.fx.scorch_count(), "rings": g.fx._rings.size(),
				"bridges": g.map.bridges,
				"fog": _fog_on(),
				"draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
				"objects": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
				"primitives": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
				"stats_visible": main.hud.stats_visible()}
		"enemies":
			# stav všech živých i umírajících nepřátel (pro kontrolu animací)
			var list: Array = []
			for en4 in g.enemies + g.dying:
				list.append({"type": en4.type, "dying": en4.dying, "reached": en4.reached, "dur": en4.death_duration(),
					"t": en4._death_t, "age": en4._age, "pos": [en4.position.x, en4.position.y, en4.position.z],
					"sx": en4.visual.scale.x, "sy": en4.visual.scale.y, "vy": en4.visual.position.y,
					"rx": en4.visual.rotation.x, "rz": en4.visual.rotation.z, "s": en4.s})
			return {"ok": true, "list": list, "path_len": g.path.length, "base": [g.map.base_pos.x, g.map.base_pos.y, g.map.base_pos.z]}
		"ui_rect":
			var r3: Rect2 = main.hud.ui_rect(str(req.get("name", "")))
			var vp3: Vector2 = main.get_viewport().get_visible_rect().size
			return {"ok": r3.size != Vector2.ZERO, "rect": [r3.position.x / vp3.x, r3.position.y / vp3.y, r3.size.x / vp3.x, r3.size.y / vp3.y], "px": [r3.position.x, r3.position.y, r3.size.x, r3.size.y], "vp": [vp3.x, vp3.y]}
		"over_ui":
			return {"ok": true, "over": main.hud.point_over_ui(Vector2(float(req.get("x", 0.0)), float(req.get("y", 0.0))))}
		"pick":
			var pk = main.rig.pick_ground(Vector2(float(req.get("x", 0.0)), float(req.get("y", 0.0))), main.map)
			return {"ok": pk != null, "p": [pk.x, pk.y, pk.z] if pk != null else [], "cell": [Cfg.world_to_cell(pk.x, pk.z).x, Cfg.world_to_cell(pk.x, pk.z).y] if pk != null else []}
		"touch_state":
			return {"ok": true, "phone": UiProfile.phone, "touch_mode": UiProfile.touch_mode, "pending": main.touch_pending,
				"touch_cell": [main.touch_cell.x, main.touch_cell.y], "build_type": main.build_type, "aim": main.aim_ability,
				"confirm_visible": main.hud.confirm_visible(), "selected": main.selected.uid if main.selected != null else -1,
				"towers": g.towers.size(), "gold": g.gold, "paused": g.paused, "meteor_cd": float(g.ability_cd.get("meteor", 0.0)), "yaw": main.rig.target_yaw, "zoom": main.rig.target_zoom,
				"pivot": [main.rig.target_pivot.x, main.rig.target_pivot.z],
				"viewport": [main.get_viewport().get_visible_rect().size.x, main.get_viewport().get_visible_rect().size.y]}
		"stats":
			if main.hud.stats_visible() != bool(req.get("v", true)):
				main.hud.toggle_stats()
			return {"ok": true}
		"audio":
			var am = main.audio
			if am == null:
				return {"ok": false, "error": "zvuk není aktivní"}
			return {"ok": true, "sounds": am.sounds_ready, "calm_ready": am.calm_ready, "battle_ready": am.battle_ready,
				"sfx_on": am.sfx_on, "music_on": am.music_on, "started": am.started, "counts": am.play_counts,
				"fade": am._fade, "calm_playing": am._calm.playing, "battle_playing": am._battle.playing,
				"wind_playing": am._wind.playing, "calm_db": am._calm.volume_db, "battle_db": am._battle.volume_db}
		"audio_play":
			if main.audio == null:
				return {"ok": false}
			var lis: AudioListener3D = main.audio._listener
			var side: float = float(req.get("side", 0.0))
			var pos3: Vector3 = lis.global_position + lis.global_basis.x * side * float(req.get("dist", 20.0)) - lis.global_basis.z * float(req.get("front", 0.0))
			main.audio.play(str(req.get("sound", "cannon_shot")), pos3)
			return {"ok": true, "pos": [pos3.x, pos3.y, pos3.z]}
		"audio_set":
			if main.audio == null:
				return {"ok": false}
			main.audio.ambient_on = bool(req.get("ambient", true))
			main._on_audio_toggle("sfx", bool(req.get("sfx", true)))
			main._on_audio_toggle("music", bool(req.get("music", true)))
			main.hud.set_audio_state(main.audio.sfx_on, main.audio.music_on)
			return {"ok": true}
		"hud":
			var rows: Array = []
			for ch in main.hud._wave_rows.get_children():
				var txt: String = ""
				for lc in ch.get_children():
					if lc is Label:
						txt += (lc as Label).text
				rows.append(txt)
			return {"ok": true, "toast": main.hud._toast_lbl.text, "gold_lbl": main.hud._gold_lbl.text,
				"lives_lbl": main.hud._lives_lbl.text, "wave_lbl": main.hud._wave_lbl.text, "info": main.hud._info_lbl.text,
				"wave_title": main.hud._wave_title.text, "wave_rows": rows, "end_title": main.hud._end_title.text,
				"end_body": main.hud._end_body.text, "intro_visible": main.hud._intro.visible, "help_visible": main.hud._help.visible,
				"end_visible": main.hud._end.visible, "aiming": main.aim_ability,
				"menu": {"mode": main.hud._menu_mode, "diff": main.hud._menu_diff, "island": main.hud._menu_island,
					"island_name": main.hud._menu_island_name.text, "record": main.hud._menu_rec.text,
					"back_visible": main.hud._menu_back_btn.visible, "start_text": main.hud._menu_start_btn.text}}
		"settings":
			return {"ok": true, "mode": GameSettings.mode, "difficulty": GameSettings.difficulty, "island": GameSettings.island,
				"random_seed": GameSettings.random_seed, "records": GameSettings.records, "game_mode": g.mode_id, "game_diff": g.diff_id,
				"total_waves": g.total_waves, "island_name": str(main.island_def.get("name", "")), "persist": g.persist_records,
				"abilities_used": g.abilities_used, "ability_cd": g.ability_cd, "gold_boost": g.gold_boost_t, "best_wave": g.best_wave}
		"records":
			# pro test: povolit/zakázat zápis rekordů a vyčistit je
			g.persist_records = bool(req.get("persist", true))
			if bool(req.get("clear", false)):
				GameSettings.records = {}
			return {"ok": true}
		"cast":
			# pro test: sešle schopnost přímo (meteor na souřadnice x, z)
			var cid: String = str(req.get("id", "meteor"))
			var ok_c: bool = false
			if cid == "meteor":
				ok_c = g.cast_meteor(Vector3(float(req.get("x", 0.0)), 0.0, float(req.get("z", 0.0))))
			elif cid == "blizzard":
				ok_c = g.cast_blizzard()
			elif cid == "gold":
				ok_c = g.cast_gold()
			return {"ok": ok_c}
		"set_wave":
			# pro test: přeskočí na vlnu v (zvládnuté předchozí), nic dalšího se nespustí
			g.waves_started = int(req.get("v", 0))
			main.hud._refresh_wave_panel()
			main.hud._on_wave(g.waves_started, g.total_waves)
			return {"ok": true}
		"set_cd":
			g.ability_cd[str(req.get("id", "meteor"))] = float(req.get("v", 0.0))
			return {"ok": true}
		"help":
			main.hud.show_help(bool(req.get("v", true)))
			return {"ok": true}
	return {"ok": false, "error": "unknown op " + op}


func _visual_count(t: Node) -> int:
	var n: int = 0
	for c in t.get_children():
		if c is TowerVisual:
			n += 1
	return n


func _fog_on() -> bool:
	var we: Node = main.world.find_child("WorldEnvironment", true, false)
	return we != null and (we as WorldEnvironment).environment != null and (we as WorldEnvironment).environment.fog_enabled


func _is_disabled(nm: String) -> bool:
	match nm:
		"wave_btn":
			return main.hud._wave_btn.disabled
		"upgrade_btn":
			return (main.hud._tp["upgrade"] as Button).disabled
	return false
