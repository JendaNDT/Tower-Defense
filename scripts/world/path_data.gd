class_name PathData
extends RefCounted
## Trasa nepřátel: vyhlazená lomená čára v rovině XZ, rovnoměrně navzorkovaná (STEP metrů).
## `ys` = výška trasy (nastaví terén), podle ní chodí nepřátelé i most.

const STEP: float = 0.25

var pts: PackedVector2Array = PackedVector2Array()
var ys: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0


## Zaoblí rohy lomené čáry kvadratickou Bézierovou křivkou o dosahu `rad` metrů a výsledek navzorkuje.
static func from_polyline(poly: Array, rad: float = 2.0) -> PathData:
	var rounded: Array = []
	rounded.append(poly[0])
	for i in range(1, poly.size() - 1):
		var prev: Vector2 = poly[i - 1]
		var cur: Vector2 = poly[i]
		var nxt: Vector2 = poly[i + 1]
		var din: Vector2 = (cur - prev).normalized()
		var dout: Vector2 = (nxt - cur).normalized()
		var r: float = minf(rad, minf(prev.distance_to(cur), cur.distance_to(nxt)) * 0.45)
		var a: Vector2 = cur - din * r
		var b: Vector2 = cur + dout * r
		for k in range(0, 13):
			var t: float = float(k) / 12.0
			var q: Vector2 = a * ((1.0 - t) * (1.0 - t)) + cur * (2.0 * (1.0 - t) * t) + b * (t * t)
			rounded.append(q)
	rounded.append(poly[poly.size() - 1])

	var pd: PathData = PathData.new()
	pd.pts = _resample(rounded, STEP)
	pd.length = float(pd.pts.size() - 1) * STEP
	pd.ys.resize(pd.pts.size())
	return pd


static func _resample(poly: Array, step: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.append(poly[0])
	var acc: float = 0.0
	for i in range(poly.size() - 1):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[i + 1]
		var seg: float = a.distance_to(b)
		if seg < 0.000001:
			continue
		var d: float = step - acc
		while d <= seg:
			out.append(a.lerp(b, d / seg))
			d += step
		acc = seg - (d - step)
	var last: Vector2 = poly[poly.size() - 1]
	if out[out.size() - 1].distance_to(last) > step * 0.5:
		out.append(last)
	return out


func count() -> int:
	return pts.size()


func _idx(s: float) -> Array:
	var f: float = clampf(s, 0.0, length) / STEP
	var i: int = mini(int(floor(f)), pts.size() - 2)
	return [i, f - float(i)]


func xz_at(s: float) -> Vector2:
	var r: Array = _idx(s)
	var i: int = r[0]
	var t: float = r[1]
	return pts[i].lerp(pts[i + 1], t)


func y_at(s: float) -> float:
	var r: Array = _idx(s)
	var i: int = r[0]
	var t: float = r[1]
	return lerpf(ys[i], ys[i + 1], t)


func pos_at(s: float) -> Vector3:
	var r: Array = _idx(s)
	var i: int = r[0]
	var t: float = r[1]
	var p: Vector2 = pts[i].lerp(pts[i + 1], t)
	return Vector3(p.x, lerpf(ys[i], ys[i + 1], t), p.y)


## Jednotkový směr pohybu v rovině XZ (centrální diference => spojitý).
func dir_at(s: float) -> Vector2:
	var s0: float = maxf(s - 0.6, 0.0)
	var s1: float = minf(s + 0.6, length)
	var d: Vector2 = xz_at(s1) - xz_at(s0)
	if d.length_squared() < 0.000001:
		return Vector2(1.0, 0.0)
	return d.normalized()
