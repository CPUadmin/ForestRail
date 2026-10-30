extends RefCounted

const VERSION = 1
# Straight track beyond each end station for the tail of a reversed full consist.
const BUFFER_M = 40
var points: Array = []
var seed_value = 42
var length_m = 0.0
var station_s: Array = []

func generate(world_seed: int, stations: Array) -> void:
	seed_value = world_seed
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	points.clear()
	station_s.clear()
	for segment in range(stations.size() - 1):
		var start = float(stations[segment].s_m)
		var finish = float(stations[segment + 1].s_m)
		var span = finish - start - 44.0
		var amplitude = rng.randf_range(0.48, 0.68) if segment < 2 else rng.randf_range(0.8, 1.3)
		var waves = 2.0 if segment < 3 else 3.0
		var grade_limit = 0.028 if segment < 2 else 0.055
		amplitude = minf(amplitude, grade_limit * span / (PI + TAU * waves))
		var sign_y = 1.0 if rng.randf() > 0.5 else -1.0
		for x in range(int(start), int(finish)):
			var u = clampf((float(x) - start - 22.0) / span, 0.0, 1.0)
			# A squared sine envelope makes platforms and joins exactly flat.
			var y = sign_y * amplitude * pow(sin(PI * u), 2) * sin(TAU * waves * u)
			_append(float(x), y)
	var last = int(stations[-1].s_m)
	for x in range(last, last + BUFFER_M + 1):
		_append(float(x), 0.0)
	# Prepend a straight approach without changing the station coordinate system.
	var pre: Array = []
	for x in range(-BUFFER_M, 0):
		pre.append([float(x), 0.0, float(x)])
	points = pre + points
	length_m = float(points[-1][2])
	for station in stations:
		station_s.append(distance_at_x(float(station.s_m)))

func _append(x: float, y: float) -> void:
	var distance = 0.0
	if not points.is_empty():
		var p = points[-1]
		distance = float(p[2]) + Vector2(x - float(p[0]), y - float(p[1])).length()
	points.append([x, y, distance])

func distance_at_x(x: float) -> float:
	for p in points:
		if float(p[0]) >= x:
			return float(p[2])
	return float(points[-1][2])

func sample(s: float) -> Vector2:
	if points.is_empty():
		return Vector2(s, 0)
	s = clampf(s, float(points[0][2]), float(points[-1][2]))
	var lo = 0
	var hi = points.size() - 1
	while hi - lo > 1:
		var mid = (lo + hi) / 2
		if float(points[mid][2]) < s:
			lo = mid
		else:
			hi = mid
	var a = points[lo]
	var b = points[hi]
	var t = (s - float(a[2])) / maxf(0.001, float(b[2]) - float(a[2]))
	return Vector2(lerpf(float(a[0]), float(b[0]), t), lerpf(float(a[1]), float(b[1]), t))

func slope(s: float) -> float:
	var a = sample(s - 0.5)
	var b = sample(s + 0.5)
	return atan2(b.y - a.y, b.x - a.x)

func restore(saved: Dictionary, stations: Array) -> void:
	seed_value = int(saved.seed)
	points = saved.points.duplicate(true)
	length_m = float(points[-1][2])
	station_s.clear()
	for station in stations:
		station_s.append(distance_at_x(float(station.s_m)))

func serialize() -> Dictionary:
	return {"seed": seed_value, "generator_version": VERSION, "points": points}
