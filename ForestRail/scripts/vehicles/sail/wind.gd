extends RefCounted
# N12 / B6.3: the wind over the line, the same for the same seed. It is a field in place and time:
# a steady strength that depends on where the track runs (thick forest, clearings, open water), a
# direction that turns slowly, and gusts that run along the line at the speed of the wind.
# Components are along the route (positive toward larger distance) and across it, in m/s.

const GUST_EVERY_MIN = 8.0
const GUST_EVERY_MAX = 20.0
const GUST_LENGTH_S = 3.0
const TURN_PERIOD_S = 150.0

var seed_value = 42
var station_s: Array = []
var gust_times: Array = []     # start of each gust, seconds, as it passes the line's start
var gust_power: Array = []

func build(world_seed: int, stations: Array) -> void:
	seed_value = world_seed
	station_s = stations.duplicate()
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 777
	gust_times.clear()
	gust_power.clear()
	var t = rng.randf_range(2.0, 8.0)
	while t < 6.0 * 3600.0:
		gust_times.append(t)
		gust_power.append(rng.randf_range(3.0, 5.0))
		t += rng.randf_range(GUST_EVERY_MIN, GUST_EVERY_MAX)

# Steady strength by place: forest 2-3, clearings 3-5, the open lake (D) and the upper forest's
# ridge (E) 5-8 m/s. Interpolated between the stations' marks.
func strength_at(s: float) -> float:
	var marks = [2.5, 2.2, 4.0, 6.5, 6.0, 3.5]
	if station_s.is_empty(): return 3.0
	if s <= float(station_s[0]): return float(marks[0])
	for i in range(1, station_s.size()):
		if s <= float(station_s[i]):
			var u = (s - float(station_s[i - 1])) / maxf(1.0, float(station_s[i]) - float(station_s[i - 1]))
			return lerpf(float(marks[i - 1]), float(marks[mini(i, marks.size() - 1)]), smoothstep(0.0, 1.0, u))
	return float(marks[marks.size() - 1])

# The angle of the wind to the route, turning slowly with time; 0 is a tail wind, PI a head wind.
func angle_at(s: float, t: float) -> float:
	var base = seed_value % 360 * PI / 180.0
	return base + TAU * t / TURN_PERIOD_S + 0.6 * sin(s / 700.0)

# The extra speed of a gust at this place and time: a pulse moving along the line at the wind's speed.
func gust_at(s: float, t: float) -> float:
	var speed = maxf(2.0, strength_at(s))
	var delay = s / speed
	var total = 0.0
	for i in range(gust_times.size()):
		var start = float(gust_times[i]) + delay
		if t < start: break
		if t > start + GUST_LENGTH_S: continue
		var u = (t - start) / GUST_LENGTH_S
		total += float(gust_power[i]) * sin(PI * u)
	return total

# The wind vector at route distance s and time t: x along the route, y across it.
func at(s: float, t: float) -> Vector2:
	var speed = strength_at(s) + gust_at(s, t)
	var angle = angle_at(s, t)
	return Vector2(cos(angle), sin(angle)) * speed

# The next gust that will reach s within `within` seconds, as seconds until it arrives (or -1).
func gust_ahead(s: float, t: float, within: float = 4.0) -> float:
	var speed = maxf(2.0, strength_at(s))
	var delay = s / speed
	for i in range(gust_times.size()):
		var start = float(gust_times[i]) + delay
		if start > t and start - t <= within: return start - t
		if start - t > within: break
	return -1.0
