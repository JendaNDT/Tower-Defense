class_name TestBridge
extends RefCounted
## Testovací rozhraní pro prohlížeč (aktivní jen s ?test=1 nebo na webu):
## window.TD_state() -> JSON se stavem hry,  window.TD_cmd(JSON) -> provede příkaz a vrátí JSON.
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


func _js_state(_args) -> String:
	return JSON.stringify(state())


func _js_cmd(args) -> String:
	var parsed = JSON.parse_string(str(args[0]))
	if typeof(parsed) != TYPE_DICTIONARY:
		return JSON.stringify({"ok": false, "error": "bad json"})
	return JSON.stringify(cmd(parsed))


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
			return {"ok": true, "p": _screen(tw3.position + Vector3(0, 1.0, 0))}
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
		"max_dt":
			g.max_frame_dt = float(req.get("v", 0.1))
			return {"ok": true}
		"tower_info":
			var tw4 = _tower_by_id(int(req["id"]))
			if tw4 == null:
				return {"ok": false}
			return {"ok": true, "type": tw4.type, "level": tw4.level, "stats": tw4.stats(), "damage_dealt": tw4.damage_dealt,
				"kills": tw4.kills, "shots": tw4.shots_fired}
		"hud":
			return {"ok": true, "toast": main.hud._toast_lbl.text, "gold_lbl": main.hud._gold_lbl.text,
				"lives_lbl": main.hud._lives_lbl.text, "wave_lbl": main.hud._wave_lbl.text}
	return {"ok": false, "error": "unknown op " + op}


func _is_disabled(nm: String) -> bool:
	match nm:
		"wave_btn":
			return main.hud._wave_btn.disabled
		"upgrade_btn":
			return (main.hud._tp["upgrade"] as Button).disabled
	return false
