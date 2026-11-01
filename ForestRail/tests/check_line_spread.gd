extends Node
# B2.6: every new career gets its own line. Over many seeds: legs within +-15% of the data, stations
# within the grade limits, flat platforms, no fallback profile, the starter handcar's first legs within
# 3%, the same seed gives the same line, different seeds give different lines, and a saved line comes back.
const Model = preload("res://scripts/model.gd")
const Route = preload("res://scripts/route.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func height_at_x(route, x: float) -> float:
	return float(route.sample(route.distance_at_x(x)).y)

func run() -> void:
	var m = Model.new()
	var stations = m.data.stations
	var lengths: Array = []
	var seen_layouts: Dictionary = {}
	var worst_height_dev = 0.0
	for world_seed in range(1, 21):
		var route = Route.new()
		route.generate(world_seed * 7919, stations, 2, [], true)
		var label = "seed %d: " % (world_seed * 7919)
		check(route.station_x.size() == 6 and is_equal_approx(float(route.station_x[0]), 0.0), label + "six stations from zero")
		var legs_ok = true
		for i in range(1, 6):
			var data_leg = float(stations[i].s_m_v2) - float(stations[i - 1].s_m_v2)
			var leg = float(route.station_x[i]) - float(route.station_x[i - 1])
			legs_ok = legs_ok and leg >= data_leg * 0.849 and leg <= data_leg * 1.151
		check(legs_ok, label + "every leg within 15% of the data: " + str(route.station_x))
		check(not route.used_fallback, label + "no fallback profile")
		var worst = [0.0, 0.0, 0.0, 0.0, 0.0]
		var flat = true
		for i in range(6):
			var x = float(route.station_x[i])
			for d in [-10.0, -5.0, 5.0, 10.0]:
				if x + d < 0.0 or x + d > float(route.station_x[5]): continue
				flat = flat and absf(height_at_x(route, x + d) - height_at_x(route, x)) < 0.01
			var data_h = float(stations[i].height_v2)
			if data_h > 0.0: worst_height_dev = maxf(worst_height_dev, absf(height_at_x(route, x) / data_h - 1.0))
		check(flat, label + "platforms are flat")
		for x in range(1, int(route.station_x[5])):
			var g = float(route.points[x + 40][1]) - float(route.points[x + 39][1])
			var segment = 4
			for i in range(5):
				if float(x) < float(route.station_x[i + 1]):
					segment = i
					break
			worst[segment] = maxf(worst[segment], absf(g))
		var inside = true
		for i in range(5): inside = inside and worst[i] <= Route.GRADE_LIMITS_V2[i] + 0.0005
		check(inside, label + "grades under the limits " + str(worst))
		check(worst[0] <= 0.03 and worst[1] <= 0.03, label + "the first two legs are within the handcar's 3%")
		lengths.append(float(route.station_x[5]))
		seen_layouts[str(route.station_x)] = true
		check(route.length_m > float(route.station_x[5]) and route.fuel_scale() > 0.8 and route.fuel_scale() < 4.6, label + "fuel scale follows the length (%.2f)" % route.fuel_scale())
	check(seen_layouts.size() == 20, "twenty seeds make twenty different lines (%d)" % seen_layouts.size())
	var lo = lengths.min()
	var hi = lengths.max()
	check(hi - lo > 150.0, "the length really varies (%.0f to %.0f m)" % [lo, hi])
	print("SPREAD lengths ", snappedf(lo, 1), "..", snappedf(hi, 1), " height deviation up to ", snappedf(worst_height_dev, 0.01))
	# same seed, same line; the old way (no spread) is untouched
	var a = Route.new()
	a.generate(555, stations, 2, [], true)
	var b = Route.new()
	b.generate(555, stations, 2, [], true)
	check(a.station_x == b.station_x and a.points.size() == b.points.size(), "the same seed gives the same line")
	var plain = Route.new()
	plain.generate(555, stations, 2)
	check(is_equal_approx(float(plain.station_x[5]), 6800.0), "without spread the line is the data's 6.8 km")
	# saving: the stations come back where they stood
	var saved = a.serialize()
	var back = Route.new()
	back.restore(saved, stations)
	check(back.station_x == a.station_x and is_equal_approx(back.length_m, a.length_m), "a saved line comes back")
	# a whole new game on a spread line: missions pay by the real distance, the forecast and tanks follow
	var game = Model.new()
	game.new_game(31337, 2, "career", true)
	var far = game.mission_far_s({"dropoffs": [{"station": "F"}]})
	check(far > 5000.0 and far < 9000.0, "the far station is %.0f m away" % far)
	print("LINE SPREAD CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
