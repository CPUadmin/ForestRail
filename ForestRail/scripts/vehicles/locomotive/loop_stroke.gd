extends RefCounted
# Петля курсора — перенос Stroke из демки владельца «Мастерская двигателя» (mechanics.js, 21.11).
# Петлю засчитывает накопленный поворот направления движения, а не угол вокруг точки: дрожание руки,
# прямой рывок и мелкий кружок петлёй не становятся. Координаты — пиксели картинки шкафчика (inside.png).

const GOOD = 0.6625   # порог демки: средняя доля хорошего витка (было 0.53, владелец поднял на 25%)

var points := PackedVector2Array()
var tail := PackedVector2Array()
var last := Vector2.ZERO
var angle = null
var spin := 0.0
var count := 0
var loops: Array = []   # готовые петли, их забирает take(): {"dir", "radius", "centre", "path"}

func _init(p: Vector2) -> void:
	regrip(p)

# перехватить хвост: новое место руки, недокрученная петля начинается заново
func regrip(p: Vector2) -> void:
	points = PackedVector2Array([p])
	tail = PackedVector2Array([p])
	last = p
	angle = null
	spin = 0.0

func add(p: Vector2) -> void:
	var length = last.distance_to(p)
	if length < 2.5: return
	var from = last
	var n = ceili(length / 3.5)
	for i in range(1, n + 1): sample(from.lerp(p, float(i) / float(n)))
	last = p

func sample(p: Vector2) -> void:
	points.append(p)
	tail.append(p)
	if tail.size() > 4: tail.remove_at(0)
	var prev = tail[0]
	if prev.distance_to(p) < 2.0: return
	var a = (p - prev).angle()
	if angle != null:
		var diff = wrapf(a - float(angle), -PI, PI)
		if absf(diff) < 2.05: spin += diff
	angle = a
	if absf(spin) >= TAU - 0.035: finish(false)
	if points.size() > 1600:
		points = PackedVector2Array([p])
		spin = 0.0

func finish(on_release: bool) -> bool:
	var box = Rect2(points[0], Vector2.ZERO)
	var area = 0.0
	for i in range(points.size()):
		var p = points[i]
		var q = points[(i + 1) % points.size()]
		box = box.expand(p)
		area += p.x * q.y - p.y * q.x
	area = absf(area) * 0.5
	var radius = (box.size.x + box.size.y) * 0.25
	var end = points[points.size() - 1]
	if points.size() < 8 or radius < 6.0 or minf(box.size.x, box.size.y) < 8.0 or area < box.size.x * box.size.y * 0.29:
		if not on_release:
			spin = 0.0
			points = PackedVector2Array([end])
		return false
	loops.append({"dir": int(signf(spin)), "radius": radius, "centre": box.get_center(), "path": points.duplicate()})
	count += 1
	spin = 0.0
	points = PackedVector2Array([end])
	return true

# отпустил мышь: почти законченная петля тоже засчитывается
func end() -> void:
	if points.size() < 2: return
	var box = Rect2(points[0], Vector2.ZERO)
	for p in points: box = box.expand(p)
	var returned = absf(points[0].y - points[points.size() - 1].y) < maxf(4.0, box.size.y * 0.14)
	if absf(spin) > TAU * (0.70 if returned else 0.83): finish(true)

func take() -> Array:
	var out = loops
	loops = []
	return out

# Качество витка (Joint.quality демки, под стык-точку): виток мимо стыка — 0; иначе 1, а слишком широкий
# или сбитый в сторону виток весит меньше.
static func quality(loop: Dictionary, joint: Vector2, ideal_r: float) -> float:
	if not Geometry2D.is_point_in_polygon(joint, loop.path): return 0.0
	var r = float(loop.radius)
	var slack = maxf(0.0, r / ideal_r - 1.16)
	var off = maxf(0.0, (loop.centre as Vector2).distance_to(joint) / r - 0.5)
	return 1.0 / (1.0 + 1.8 * slack + off)
