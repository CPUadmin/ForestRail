extends RefCounted

# Generator versions: 1 is the original 1.7 km line (station positions from the data's
# s_m); 2 is the long line of about 6.8 km (s_m_v2 and height_v2), chosen for new games
# only. A saved route keeps its own version and its station positions.
const VERSION = 2
const LENGTH_V1 = 1700.0
# Largest grade per stretch A-B ... E-F on the long line (docs/SIDE_VIEW_MAP_v3_1_RU.md).
const GRADE_LIMITS_V2 = [0.02, 0.025, 0.03, 0.045, 0.03]
var points: Array = []
var seed_value = 42
var length_m = 0.0
var station_s: Array = []
var station_x: Array = []
var version = 1
var used_fallback = false

# Fuel and water tanks grow with the line so that one tank still means about one
# round trip to the far station (N10).
func fuel_scale() -> float:
	return float(station_x[-1]) / LENGTH_V1 if version >= 2 and not station_x.is_empty() else 1.0

func generate(world_seed: int, stations: Array, line_version: int = 1, grade_limits: Array = []) -> void:
	version = line_version
	used_fallback = false
	station_x.clear()
	if line_version >= 2:
		generate_long(world_seed, stations, grade_limits if not grade_limits.is_empty() else GRADE_LIMITS_V2)
		return
	for station in stations: station_x.append(float(station.s_m))
	seed_value = world_seed
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	points.clear()
	station_s.clear()
	# End stations include forty metres of buffer for a reversed full consist.
	var height = 0.0
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
			var y = height + sign_y * amplitude * pow(sin(PI * u), 2) * sin(TAU * waves * u)
			_append(float(x), y)
	for x in range(1700, 1741):
		_append(float(x), height)
	# Prepend a straight approach without changing the station coordinate system.
	var pre: Array = []
	for x in range(-40, 0):
		pre.append([float(x), 0.0, float(x)])
	points = pre + points
	length_m = float(points[-1][2])
	for station in stations:
		station_s.append(distance_at_x(float(station.s_m)))

# The long line: station heights from the data joined by smooth rises, with gentle waves
# whose size is cut to keep every stretch under its grade limit. Platforms stay flat
# (22 m each side), the envelope makes joins exact. If a seed cannot be made to fit, the
# waves are dropped and the plain smooth profile is used.
func generate_long(world_seed: int, stations: Array, limits: Array) -> void:
	seed_value = world_seed
	points.clear()
	station_s.clear()
	var xs: Array = []
	var heights: Array = []
	for station in stations:
		xs.append(float(station.s_m_v2))
		heights.append(float(station.height_v2))
		station_x.append(float(station.s_m_v2))
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	for segment in range(stations.size() - 1):
		var start = float(xs[segment])
		var finish = float(xs[segment + 1])
		var span = finish - start - 44.0
		var waves = maxf(1.0, roundf(span / rng.randf_range(420.0, 560.0)))
		var sign_y = 1.0 if rng.randf() > 0.5 else -1.0
		var wish = rng.randf_range(1.1, 2.3)
		var limit = float(limits[segment])
		var plain = _stretch(start, finish, heights[segment], heights[segment + 1], 0.0, waves, sign_y)
		var base = _max_grade(plain)
		var amplitude = wish
		var stretch = _stretch(start, finish, heights[segment], heights[segment + 1], amplitude, waves, sign_y)
		for attempt in range(8):
			if _max_grade(stretch) <= limit: break
			var room = maxf(0.0, limit - base)
			amplitude *= clampf(room / maxf(0.0001, _max_grade(stretch) - base), 0.0, 0.9)
			stretch = _stretch(start, finish, heights[segment], heights[segment + 1], amplitude, waves, sign_y)
		if _max_grade(stretch) > limit:
			stretch = plain
			used_fallback = true
		for p in stretch: _append(p.x, p.y)
	for x in range(int(xs[-1]), int(xs[-1]) + 41):
		_append(float(x), float(heights[-1]))
	var pre: Array = []
	for x in range(-40, 0):
		pre.append([float(x), 0.0, float(x)])
	points = pre + points
	length_m = float(points[-1][2])
	for x in station_x:
		station_s.append(distance_at_x(float(x)))

func _stretch(start: float, finish: float, h0: float, h1: float, amplitude: float, waves: float, sign_y: float) -> Array:
	var span = finish - start - 44.0
	var result: Array = []
	for x in range(int(start), int(finish)):
		var u = clampf((float(x) - start - 22.0) / span, 0.0, 1.0)
		var rise = h0 + (h1 - h0) * (1.0 - cos(PI * u)) * 0.5
		result.append(Vector2(float(x), rise + sign_y * amplitude * pow(sin(PI * u), 2) * sin(TAU * waves * u)))
	return result

func _max_grade(stretch: Array) -> float:
	var worst = 0.0
	for i in range(1, stretch.size()):
		worst = maxf(worst, absf(stretch[i].y - stretch[i - 1].y) / maxf(0.001, stretch[i].x - stretch[i - 1].x))
	return worst

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
	version = int(saved.get("generator_version", 1))
	used_fallback = bool(saved.get("used_fallback", false))
	station_s.clear()
	station_x.clear()
	for i in range(stations.size()):
		var x = float(saved.station_x[i]) if version >= 2 and saved.has("station_x") else float(stations[i].s_m)
		station_x.append(x)
		station_s.append(distance_at_x(x))

func serialize() -> Dictionary:
	return {"seed": seed_value, "generator_version": version, "points": points, "station_x": station_x, "used_fallback": used_fallback}
