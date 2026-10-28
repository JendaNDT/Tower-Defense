class_name RiverData
extends RefCounted
## Osa řeky: Catmull-Rom křivka z řídicích bodů, navzorkovaná po STEP metrech.
## half_w = poloviční šířka hladiny, rh = výška břehů, water_y = hladina (nerostoucí po toku).

const STEP: float = 0.5

var pts: PackedVector2Array = PackedVector2Array()
var half_w: PackedFloat32Array = PackedFloat32Array()
var rh: PackedFloat32Array = PackedFloat32Array()
var water_y: PackedFloat32Array = PackedFloat32Array()
var end_index: int = 0      # první vzorek mimo ostrov (řeka tam padá jako vodopád)


static func build(control: Array) -> RiverData:
	var rd: RiverData = RiverData.new()
	var dense: Array = []
	var n: int = control.size()
	for i in range(n - 1):
		var p0: Vector2 = control[maxi(i - 1, 0)]
		var p1: Vector2 = control[i]
		var p2: Vector2 = control[i + 1]
		var p3: Vector2 = control[mini(i + 2, n - 1)]
		for k in range(0, 16):
			var t: float = float(k) / 16.0
			var t2: float = t * t
			var t3: float = t2 * t
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			dense.append(q)
	dense.append(control[n - 1])
	rd.pts = PathData._resample(dense, STEP)
	var m: int = rd.pts.size()
	rd.half_w.resize(m)
	rd.rh.resize(m)
	rd.water_y.resize(m)
	var total: float = float(m - 1) * STEP
	for i in range(m):
		var s: float = float(i) * STEP
		var base: float = lerpf(1.35, 2.0, s / total)
		var pond: float = 1.5 * exp(-(s * s) / 30.0)       # malé jezírko u pramene
		rd.half_w[i] = base + pond
	rd.end_index = m
	return rd


func length() -> float:
	return float(pts.size() - 1) * STEP


func dir_at_index(i: int) -> Vector2:
	var a: Vector2 = pts[maxi(i - 1, 0)]
	var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
	var d: Vector2 = b - a
	if d.length_squared() < 0.000001:
		return Vector2(0.0, 1.0)
	return d.normalized()
