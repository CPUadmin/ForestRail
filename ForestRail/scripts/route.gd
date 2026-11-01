extends RefCounted

# Generator versions: 1 is the original 1.7 km line (station positions from the data's
# s_m); 2 is the long line of about 6.8 km (s_m_v2 and height_v2), chosen for new games
# only. A saved route keeps its own version and its station positions.
const VERSION = 2
const LENGTH_V1 = 1700.0
# Largest grade per stretch A-B ... E-F on the long line (docs/SIDE_VIEW_MAP_v3_1_RU.md).
# V2.1 (2026-11-01): steeper map. The first two legs stay within the handcar (3%), the rest is harder.
const GRADE_LIMITS_V2 = [0.02, 0.025, 0.04, 0.06, 0.045]
var points: Array = []
var seed_value = 42
var length_m = 0.0
var station_s: Array = []
var station_x: Array = []
var version = 1
var used_fallback = false
# Springboard knolls (N14): small short swells in the rail on the long line, one in the flattest
# place of each leg. The grade layer (points) stays smooth; the knolls are added on sampling.
# Each one is [x_start, length_m, height_m]. At about 76 km/h a train leaves the rail on one.
const KNOLL_LENGTH = 14.0
const KNOLL_HEIGHT = 0.26
const KNOLL_EDGE_M = 160.0
# B2.6: every new career gets its own line. Stations move along the track by up to 15% of the leg and
# their heights change by up to 30%, still inside each leg's grade limit.
const SPREAD_DISTANCE = 0.15
const SPREAD_HEIGHT = 0.30
const SPREAD_GRADE_SHARE = 0.8   # the plain rise uses at most this share of the limit, the waves get the rest
var knolls: Array = []

# Fuel and water tanks grow with the line so that one tank still means about one
# round trip to the far station (N10).
func fuel_scale() -> float:
	return float(station_x[-1]) / LENGTH_V1 if version >= 2 and not station_x.is_empty() else 1.0

func generate(world_seed: int, stations: Array, line_version: int = 1, grade_limits: Array = [], spread: bool = false) -> void:
	version = line_version
	used_fallback = false
	station_x.clear()
	if line_version >= 2:
		generate_long(world_seed, stations, grade_limits if not grade_limits.is_empty() else GRADE_LIMITS_V2, spread)
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
func generate_long(world_seed: int, stations: Array, limits: Array, spread: bool = false) -> void:
	seed_value = world_seed
	points.clear()
	station_s.clear()
	var xs: Array = []
	var heights: Array = []
	for station in stations:
		xs.append(float(station.s_m_v2))
		heights.append(float(station.height_v2))
		station_x.append(float(station.s_m_v2))
	if spread:
		var moved = spread_stations(world_seed, xs, heights, limits)
		xs = moved.xs
		heights = moved.heights
		station_x = xs.duplicate()
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed
	for segment in range(stations.size() - 1):
		var start = float(xs[segment])
		var finish = float(xs[segment + 1])
		var span = finish - start - 44.0
		var waves = maxf(1.0, roundf(span / rng.randf_range(420.0, 560.0)))
		var sign_y = 1.0 if rng.randf() > 0.5 else -1.0
		var wish = rng.randf_range(1.8, 3.6)
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
	knolls = place_knolls(world_seed, xs)

# The line of this career: each leg is 85-115% of the data's length and each station (not the home one)
# stands 70-130% of its data height. A rise steeper than the leg's limit allows is pulled back towards
# the previous station, so the grade limits keep holding and no seed falls back to a plain profile.
func spread_stations(world_seed: int, xs: Array, heights: Array, limits: Array) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 4242
	var new_xs: Array = [float(xs[0])]
	var new_heights: Array = [float(heights[0])]
	for i in range(1, xs.size()):
		var leg = float(xs[i]) - float(xs[i - 1])
		var x = float(new_xs[i - 1]) + roundf(leg * (1.0 + rng.randf_range(-SPREAD_DISTANCE, SPREAD_DISTANCE)))
		var h = float(heights[i]) * (1.0 + rng.randf_range(-SPREAD_HEIGHT, SPREAD_HEIGHT))
		var span = x - float(new_xs[i - 1]) - 44.0
		var room = SPREAD_GRADE_SHARE * float(limits[i - 1]) * span * 2.0 / PI
		var previous = float(new_heights[i - 1])
		h = clampf(h, previous - room, previous + room)
		new_xs.append(x)
		new_heights.append(snappedf(h, 0.1))
	return {"xs": new_xs, "heights": new_heights}

# One knoll per leg, in the flattest place at least KNOLL_EDGE_M from the platforms; a leg with
# no such place (grade over 2%) gets none. The same seed gives the same places.
func place_knolls(world_seed: int, xs: Array) -> Array:
	var result: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 99
	for leg in range(xs.size() - 1):
		var low = float(xs[leg]) + KNOLL_EDGE_M
		var high = float(xs[leg + 1]) - KNOLL_EDGE_M - KNOLL_LENGTH
		var best_x = -1.0
		var best_grade = 1.0
		var x = low + float(rng.randi_range(0, 20))
		while x < high:
			var worst = 0.0
			for k in range(int(KNOLL_LENGTH)):
				var i = int(x) + k + 40
				if i + 1 >= points.size(): break
				worst = maxf(worst, absf(float(points[i + 1][1]) - float(points[i][1])))
			if worst < best_grade:
				best_grade = worst
				best_x = x
			x += 12.0
		if best_x >= 0.0 and best_grade < 0.02: result.append([best_x, KNOLL_LENGTH, KNOLL_HEIGHT])
	return result

func knoll_y(x: float) -> float:
	for knoll in knolls:
		var u = (x - float(knoll[0])) / float(knoll[1])
		if u > 0.0 and u < 1.0: return float(knoll[2]) * 0.5 * (1.0 - cos(TAU * u))
	return 0.0

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
	var x = lerpf(float(a[0]), float(b[0]), t)
	return Vector2(x, lerpf(float(a[1]), float(b[1]), t) + knoll_y(x))

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
	knolls = saved.get("knolls", []).duplicate(true)
	station_s.clear()
	station_x.clear()
	for i in range(stations.size()):
		var x = float(saved.station_x[i]) if version >= 2 and saved.has("station_x") else float(stations[i].s_m)
		station_x.append(x)
		station_s.append(distance_at_x(x))

func serialize() -> Dictionary:
	return {"seed": seed_value, "generator_version": version, "points": points, "station_x": station_x, "used_fallback": used_fallback, "knolls": knolls}
