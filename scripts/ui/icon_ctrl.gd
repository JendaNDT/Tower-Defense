class_name IconCtrl
extends Control
## Ikona nakreslená v kódu (srdce, mince, věže, ovládací symboly). Žádné obrázky ani znaky mimo font.

var kind: String = "heart"
var col: Color = Color(1, 1, 1)
var col2: Color = Color(0.2, 0.2, 0.25)


static func make(kind_name: String, size_px: float, color: Color = Color(1, 1, 1), color2: Color = Color(0.2, 0.2, 0.25)) -> IconCtrl:
	var ic: IconCtrl = IconCtrl.new()
	ic.kind = kind_name
	ic.col = color
	ic.col2 = color2
	ic.custom_minimum_size = Vector2(size_px, size_px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func set_kind(k: String, c: Color) -> void:
	kind = k
	col = c
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	match kind:
		"heart":
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(0, 41):
				var t: float = TAU * float(i) / 40.0
				var x: float = 16.0 * pow(sin(t), 3.0)
				var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				pts.append(c + Vector2(x, -y) * (s / 38.0) + Vector2(0, s * 0.03))
			draw_colored_polygon(pts, col)
			draw_polyline(pts, col.darkened(0.35), maxf(s * 0.05, 1.0), true)
			draw_circle(c + Vector2(-s * 0.16, -s * 0.15), s * 0.07, Color(1, 1, 1, 0.55))
		"coin":
			draw_circle(c, s * 0.44, col.darkened(0.3))
			draw_circle(c, s * 0.37, col)
			draw_arc(c, s * 0.27, 0.0, TAU, 24, col.darkened(0.25), maxf(s * 0.05, 1.0), true)
			draw_rect(Rect2(c + Vector2(-s * 0.04, -s * 0.16), Vector2(s * 0.08, s * 0.32)), col.darkened(0.25))
		"archer":
			draw_arc(c + Vector2(-s * 0.14, 0), s * 0.38, -PI * 0.42, PI * 0.42, 20, col, maxf(s * 0.07, 1.5), true)
			var top: Vector2 = c + Vector2(-s * 0.14 + cos(-PI * 0.42) * s * 0.38, sin(-PI * 0.42) * s * 0.38)
			var bot: Vector2 = c + Vector2(-s * 0.14 + cos(PI * 0.42) * s * 0.38, sin(PI * 0.42) * s * 0.38)
			draw_line(top, bot, col2.lightened(0.5), maxf(s * 0.025, 1.0), true)
			draw_line(c + Vector2(-s * 0.28, 0), c + Vector2(s * 0.42, 0), col, maxf(s * 0.05, 1.0), true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.46, 0), c + Vector2(s * 0.3, -s * 0.09), c + Vector2(s * 0.3, s * 0.09)]), col)
		"cannon":
			var ang: float = -0.5
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			var nrm: Vector2 = Vector2(-dir.y, dir.x)
			var p0: Vector2 = c + Vector2(-s * 0.28, s * 0.1)
			var p1: Vector2 = p0 + dir * s * 0.62
			draw_colored_polygon(PackedVector2Array([p0 + nrm * s * 0.16, p1 + nrm * s * 0.11, p1 - nrm * s * 0.11, p0 - nrm * s * 0.16]), col)
			draw_circle(p0, s * 0.17, col.darkened(0.15))
			draw_circle(c + Vector2(-s * 0.1, s * 0.26), s * 0.17, col2.lightened(0.3))
			draw_circle(c + Vector2(-s * 0.1, s * 0.26), s * 0.07, col)
		"mage":
			var d: PackedVector2Array = PackedVector2Array([c + Vector2(0, -s * 0.44), c + Vector2(s * 0.24, 0), c + Vector2(0, s * 0.44), c + Vector2(-s * 0.24, 0)])
			draw_colored_polygon(d, col)
			draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), col.lightened(0.5), maxf(s * 0.04, 1.0), true)
			draw_line(c + Vector2(0, -s * 0.44), c + Vector2(0, s * 0.44), col.lightened(0.55), maxf(s * 0.03, 1.0), true)
			draw_circle(c + Vector2(s * 0.34, -s * 0.3), s * 0.05, Color(1, 1, 1, 0.9))
			draw_circle(c + Vector2(-s * 0.34, s * 0.2), s * 0.04, Color(1, 1, 1, 0.8))
		"frost":
			for i in range(3):
				var a: float = PI * float(i) / 3.0
				var v: Vector2 = Vector2(cos(a), sin(a)) * s * 0.44
				draw_line(c - v, c + v, col, maxf(s * 0.06, 1.5), true)
				for sg in [-1.0, 1.0]:
					var tip: Vector2 = c + v * float(sg)
					var inward: Vector2 = -v.normalized() * float(sg)
					var perp: Vector2 = Vector2(-inward.y, inward.x)
					var base: Vector2 = tip + inward * s * 0.12
					draw_line(base, base + (inward + perp * 0.9).normalized() * s * 0.1, col, maxf(s * 0.04, 1.0), true)
					draw_line(base, base + (inward - perp * 0.9).normalized() * s * 0.1, col, maxf(s * 0.04, 1.0), true)
		"pause":
			draw_rect(Rect2(c + Vector2(-s * 0.26, -s * 0.3), Vector2(s * 0.18, s * 0.6)), col)
			draw_rect(Rect2(c + Vector2(s * 0.08, -s * 0.3), Vector2(s * 0.18, s * 0.6)), col)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.32), c + Vector2(s * 0.34, 0), c + Vector2(-s * 0.22, s * 0.32)]), col)
		"ff":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.34, -s * 0.28), c + Vector2(s * 0.02, 0), c + Vector2(-s * 0.34, s * 0.28)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s * 0.28), c + Vector2(s * 0.36, 0), c + Vector2(0.0, s * 0.28)]), col)
		"rotl", "rotr":
			if kind == "rotl":
				draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
			draw_arc(c, s * 0.3, PI * 0.15, PI * 1.35, 22, col, maxf(s * 0.08, 1.5), true)
			var endp: Vector2 = c + Vector2(cos(PI * 1.35), sin(PI * 1.35)) * s * 0.3
			var tang: Vector2 = Vector2(sin(PI * 1.35), -cos(PI * 1.35))
			var perp2: Vector2 = Vector2(-tang.y, tang.x)
			draw_colored_polygon(PackedVector2Array([endp + tang * s * 0.2, endp + perp2 * s * 0.14, endp - perp2 * s * 0.14]), col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"plus":
			draw_line(c + Vector2(-s * 0.28, 0), c + Vector2(s * 0.28, 0), col, maxf(s * 0.09, 2.0), true)
			draw_line(c + Vector2(0, -s * 0.28), c + Vector2(0, s * 0.28), col, maxf(s * 0.09, 2.0), true)
		"minus":
			draw_line(c + Vector2(-s * 0.28, 0), c + Vector2(s * 0.28, 0), col, maxf(s * 0.09, 2.0), true)
		"star":
			var pts2: PackedVector2Array = PackedVector2Array()
			for i2 in range(10):
				var rr: float = s * (0.46 if i2 % 2 == 0 else 0.2)
				var aa: float = -PI * 0.5 + TAU * float(i2) / 10.0
				pts2.append(c + Vector2(cos(aa), sin(aa)) * rr)
			draw_colored_polygon(pts2, col)
		"flag":
			draw_line(c + Vector2(-s * 0.26, s * 0.42), c + Vector2(-s * 0.26, -s * 0.42), col2.lightened(0.5), maxf(s * 0.07, 1.5), true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.4), c + Vector2(s * 0.38, -s * 0.2), c + Vector2(-s * 0.24, 0.0)]), col)
		"speaker", "speaker_off":
			var sp: Color = col
			draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.12), Vector2(s * 0.16, s * 0.24)), sp)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.12), c + Vector2(s * 0.04, -s * 0.34), c + Vector2(s * 0.04, s * 0.34), c + Vector2(-s * 0.2, s * 0.12)]), sp)
			if kind == "speaker":
				draw_arc(c + Vector2(s * 0.04, 0.0), s * 0.2, -PI * 0.3, PI * 0.3, 10, sp, maxf(s * 0.06, 1.5), true)
				draw_arc(c + Vector2(s * 0.04, 0.0), s * 0.34, -PI * 0.32, PI * 0.32, 12, sp, maxf(s * 0.06, 1.5), true)
			else:
				draw_line(c + Vector2(s * 0.14, -s * 0.14), c + Vector2(s * 0.42, s * 0.14), Color(1.0, 0.4, 0.38), maxf(s * 0.08, 2.0), true)
				draw_line(c + Vector2(s * 0.14, s * 0.14), c + Vector2(s * 0.42, -s * 0.14), Color(1.0, 0.4, 0.38), maxf(s * 0.08, 2.0), true)
		"note", "note_off":
			var nc: Color = col
			draw_circle(c + Vector2(-s * 0.14, s * 0.26), s * 0.17, nc)
			draw_line(c + Vector2(s * 0.02, s * 0.24), c + Vector2(s * 0.02, -s * 0.36), nc, maxf(s * 0.07, 1.5), true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.02, -s * 0.36), c + Vector2(s * 0.3, -s * 0.18), c + Vector2(s * 0.02, -s * 0.12)]), nc)
			if kind == "note_off":
				draw_line(c + Vector2(-s * 0.36, s * 0.36), c + Vector2(s * 0.36, -s * 0.36), Color(1.0, 0.4, 0.38), maxf(s * 0.08, 2.0), true)
		"warn":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -s * 0.42), c + Vector2(s * 0.46, s * 0.38), c + Vector2(-s * 0.46, s * 0.38)]), col)
			draw_line(c + Vector2(0.0, -s * 0.12), c + Vector2(0.0, s * 0.14), Color(0.15, 0.1, 0.05), maxf(s * 0.1, 1.5), true)
			draw_circle(c + Vector2(0.0, s * 0.27), s * 0.055, Color(0.15, 0.1, 0.05))
		"meteor":
			draw_line(c + Vector2(-s * 0.44, -s * 0.44), c + Vector2(-s * 0.05, -s * 0.05), col.darkened(0.2), maxf(s * 0.14, 2.0), true)
			draw_line(c + Vector2(-s * 0.46, -s * 0.2), c + Vector2(-s * 0.12, s * 0.06), col.darkened(0.35), maxf(s * 0.08, 1.5), true)
			draw_circle(c + Vector2(s * 0.12, s * 0.12), s * 0.27, col)
			draw_circle(c + Vector2(s * 0.12, s * 0.12), s * 0.27, col.darkened(0.45), false, maxf(s * 0.05, 1.0), true)
			draw_circle(c + Vector2(s * 0.2, s * 0.2), s * 0.1, Color(1.0, 0.9, 0.5))
		"snow":
			for i in range(3):
				var a: float = PI * float(i) / 3.0
				var v: Vector2 = Vector2(cos(a), sin(a)) * s * 0.42
				draw_line(c - v, c + v, col, maxf(s * 0.07, 1.5), true)
			draw_circle(c, s * 0.08, Color(1, 1, 1))
		"goldrush":
			draw_circle(c + Vector2(-s * 0.12, s * 0.12), s * 0.26, col.darkened(0.25))
			draw_circle(c + Vector2(-s * 0.12, s * 0.12), s * 0.2, col)
			draw_circle(c + Vector2(s * 0.16, -s * 0.1), s * 0.22, col.darkened(0.25))
			draw_circle(c + Vector2(s * 0.16, -s * 0.1), s * 0.16, col)
			draw_line(c + Vector2(s * 0.3, -s * 0.4), c + Vector2(s * 0.3, -s * 0.22), Color(1, 1, 1), maxf(s * 0.05, 1.0), true)
			draw_line(c + Vector2(s * 0.21, -s * 0.31), c + Vector2(s * 0.39, -s * 0.31), Color(1, 1, 1), maxf(s * 0.05, 1.0), true)
		"menu":
			for i in range(3):
				draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.26 + float(i) * s * 0.26), Vector2(s * 0.64, s * 0.12)), col)
		"dot":
			draw_circle(c, s * 0.4, col)
			draw_arc(c, s * 0.4, 0.0, TAU, 20, col.darkened(0.4), maxf(s * 0.06, 1.0), true)
		"auto":
			draw_arc(c, s * 0.3, PI * 0.1, PI * 1.5, 20, col, maxf(s * 0.08, 1.5), true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.05), c + Vector2(s * 0.46, -s * 0.28), c + Vector2(s * 0.12, -s * 0.26)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.12), c + Vector2(s * 0.14, 0), c + Vector2(-s * 0.1, s * 0.12)]), col)
		_:
			draw_circle(c, s * 0.3, col)
