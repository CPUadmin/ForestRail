extends Node
# N7.3: the long line. Shape (length, heights, flat platforms, grades, smoothness), seeds,
# the fallback profile, saving, the old line left alone, and what scales with the length.
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
	for world_seed in [42, 7, 1234, 99999, 31337, 5]:
		var route = Route.new()
		route.generate(world_seed, stations, 2)
		var label = "seed %d: " % world_seed
		check(route.version == 2 and route.station_x.size() == 6, label + "version 2 with six stations")
		check(route.length_m > 6840.0 and route.length_m < 6900.0, label + "about 6.8 km plus the buffer (%.0f)" % route.length_m)
		check(is_equal_approx(float(route.station_x[5]), 6800.0) and is_equal_approx(float(route.station_x[1]), 900.0), label + "stations where the data puts them")
		var ok_heights = true
		for i in range(6):
			ok_heights = ok_heights and absf(height_at_x(route, float(route.station_x[i])) - float(stations[i].height_v2)) < 0.01
		check(ok_heights, label + "stations at their heights")
		# platforms are flat: 10 m either side of each station within a centimetre
		var flat = true
		for i in range(6):
			var x = float(route.station_x[i])
			for d in [-10.0, -5.0, 5.0, 10.0]:
				if x + d < 0.0 or x + d > 6800.0: continue
				flat = flat and absf(height_at_x(route, x + d) - height_at_x(route, x)) < 0.01
		check(flat, label + "platforms are flat")
		# grades per stretch under the limits, and smooth (no steps, no sawtooth)
		var worst = [0.0, 0.0, 0.0, 0.0, 0.0]
		var kink = 0.0
		var previous = 0.0
		for x in range(1, 6800):
			var g = float(route.points[x + 40][1]) - float(route.points[x + 39][1])
			var segment = 4
			for i in range(5):
				if float(x) < float(route.station_x[i + 1]):
					segment = i
					break
			worst[segment] = maxf(worst[segment], absf(g))
			if x % 5 == 0:
				if x > 40: kink = maxf(kink, absf(g - previous))
				previous = g
		var inside = true
		for i in range(5): inside = inside and worst[i] <= Route.GRADE_LIMITS_V2[i] + 0.0005
		print("LINE ", label, "worst grades ", worst, " kink ", snappedf(kink, 0.0001), " length ", snappedf(route.length_m, 0.1))
		check(inside, label + "grades under the limits " + str(worst))
		check(kink < 0.012, label + "no sharp changes of grade (%.4f)" % kink)
		check(not route.used_fallback, label + "no fallback needed")
	# the same seed gives the same line, another seed another
	var a = Route.new()
	a.generate(42, stations, 2)
	var b = Route.new()
	b.generate(42, stations, 2)
	var c = Route.new()
	c.generate(43, stations, 2)
	check(a.points == b.points and a.points != c.points, "deterministic per seed, different between seeds")
	# impossible limits: the waves are dropped, the line still reaches every height
	var strict = Route.new()
	strict.generate(42, stations, 2, [0.001, 0.001, 0.001, 0.001, 0.001])
	check(strict.used_fallback and absf(height_at_x(strict, 5200.0) - 40.0) < 0.01, "an impossible seed falls back to the plain profile")
	# saving: positions and version travel with the route; the old line restores as before
	var restored = Route.new()
	restored.restore(a.serialize(), stations)
	check(restored.version == 2 and restored.station_s == a.station_s and restored.station_x == a.station_x, "a saved long line restores its stations")
	var old = Route.new()
	old.generate(42, stations)
	var old_restored = Route.new()
	old_restored.restore(old.serialize(), stations)
	check(old.version == 1 and old_restored.version == 1 and old_restored.station_s == old.station_s and float(old.station_x[5]) == 1700.0 and old.length_m < 1800.0, "the old 1.7 km line is untouched")
	var legacy = Route.new()
	legacy.restore({"seed": 42, "generator_version": 1, "points": old.points}, stations)
	check(legacy.station_s == old.station_s, "a save from before this change restores")
	# the model: scaling with the line
	var short_game = Model.new()
	short_game.new_game(42)
	var long_game = Model.new()
	long_game.new_game(42, 2)
	var scale = 6800.0 / 1700.0
	check(is_equal_approx(float(long_game.object_stats("motorcar").tank), float(short_game.object_stats("motorcar").tank) * scale * 1.1), "tanks grow with the line (and with the class factor)")
	check(is_equal_approx(float(long_game.object_stats("steam").water), float(short_game.object_stats("steam").water) * scale * 0.45), "and the water of the boiler")
	check(int(short_game.current_mission().reward) == 120 and int(long_game.current_mission().reward) == 360, "the first order pays 3 times more over 3 times the distance")
	check(is_equal_approx(long_game.mission_reward_scale(long_game.data.missions[9]), 4.0), "the last career order scales by the far station")
	long_game.state.chapter = 9
	check(int(long_game.current_mission().reward) == 1500 * 4, "the career order list follows the line")
	long_game.state.chapter = 0
	check(int(long_game.free_offers()[0].reward) > int(short_game.free_offers()[0].reward), "free orders pay for the longer way")
	check(long_game.accept_mission(long_game.data.missions[0]) and int(long_game.state.active.reward) == 360, "accepting a raw mission applies the scale once")
	var save = long_game.serialize()
	var reloaded = Model.new()
	check(reloaded.restore(save) and reloaded.route.version == 2 and is_equal_approx(float(reloaded.route.station_x[5]), 6800.0), "a long-line career survives saving and loading")
	check(float(reloaded.state.s) <= reloaded.route.length_m, "position inside the long line")
	var broken = save.duplicate(true)
	broken.route.erase("station_x")
	check(not Model.new().restore(broken), "a long-line save without its stations is refused")
	var old_game = Model.new()
	old_game.new_game(42)
	check(Model.new().restore(old_game.serialize()), "an old-line save is still accepted")
	print("LINE V2 CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
