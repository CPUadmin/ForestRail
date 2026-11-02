extends Node
# B3.4: temperatures and the hungry fire. The petrol engine and the electric motor warm with work and cool
# in the wind of the run; the steam fire burns fast, gives heat by the coal on the grate and wants stoking.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	Model.legacy_tanks = true
	call_deferred("run")

func setup(kind: String, chapter: int = 4):
	var m = Model.new()
	m.new_game(42)
	m.state.money = 5000
	m.state.chapter = chapter
	Fixtures.equip(m, kind)
	m.accept_mission(m.current_mission())
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	m.depart()
	m.state.brake = 0.0
	for p in m.route.points: p[1] = 0.0
	return m

func run_for(m, seconds: float) -> void:
	for i in range(int(seconds * 60)): m.physics_step(1.0 / 60)

func run() -> void:
	# petrol: a long crawl on full throttle in first gear overheats and stalls it; running at speed does not
	var crawl = setup("motorcar")
	crawl.state.phase = "route"
	check(crawl.start_engine(true) and crawl.state.engine, "the petrol engine starts")
	crawl.set_gear(1)
	crawl.state.s = 100.0
	crawl.state.brake = 1.0
	crawl.state.throttle = 1.0
	crawl.state.v = 0.0
	crawl.state.fleet_by_id.motorcar.temp = 0.5
	# a brake holds the car so that it crawls: the heat is made, the cooling stays low
	var hot_before = crawl.engine_temp()
	for i in range(60 * 60):
		crawl.physics_step(1.0 / 60)
		if not crawl.state.engine: break
	check(crawl.engine_temp() > hot_before and crawl.engine_temp() >= 0.99, "holding full throttle at a standstill overheats the petrol engine (%.2f)" % crawl.engine_temp())
	check(not crawl.state.engine, "an engine at 100% stalls")
	crawl.state.throttle = 0.0
	crawl.set_gear(0)
	check(not crawl.start_engine(true), "a hot engine will not start")
	run_for(crawl, 120.0)
	check(crawl.engine_temp() < Model.TEMP_RESTART, "it cools down while standing (%.2f)" % crawl.engine_temp())
	check(crawl.start_engine(true), "and starts again when cool")
	var fast = setup("motorcar")
	fast.start_engine(true)
	fast.set_gear(4)
	fast.state.s = 100.0
	fast.state.v = 10.0
	for i in range(60 * 90):
		fast.state.throttle = clampf(0.4 + (14.0 - float(fast.state.v)) * 1.5, 0.0, 1.0) if float(fast.state.v) < 14.0 else 0.0
		fast.physics_step(1.0 / 60)
	check(fast.engine_temp() < Model.TEMP_HOT and bool(fast.state.engine), "cruising in fourth gear stays cool (%.2f)" % fast.engine_temp())
	# the hot engine pulls less
	var power = setup("motorcar")
	power.state.fleet_by_id.motorcar.temp = 0.4
	var cool_factor = power.thermal_factor()
	power.state.fleet_by_id.motorcar.temp = 0.95
	check(cool_factor == 1.0 and power.thermal_factor() < 0.9 and power.thermal_factor() >= 0.7, "an engine over 85% pulls weaker (%.2f)" % power.thermal_factor())
	power.state.fleet_by_id.motorcar.temp = 0.1
	check(power.thermal_factor() < 0.9, "a cold engine is a little weak at first")
	# electric: full current makes the motor hot, then the pull is cut to 60%
	var motor = setup("locomotive", 9)
	motor.state.s = 100.0
	motor.state.brake = 1.0
	motor.state.throttle = 1.0
	motor.state.fleet_by_id.locomotive.temp = 0.5
	run_for(motor, 120.0)
	check(motor.engine_temp() > Model.TEMP_HOT, "full current while held makes the motor hot (%.2f)" % motor.engine_temp())
	check(is_equal_approx(motor.thermal_factor(), 0.6) or motor.thermal_factor() < 0.75, "and the pull is weaker (%.2f)" % motor.thermal_factor())
	motor.state.throttle = 0.0
	run_for(motor, 200.0)
	check(motor.engine_temp() < 0.4, "the motor cools when idle (%.2f)" % motor.engine_temp())
	# steam: the fire burns about eight times faster than before
	var steam = setup("steam", 2)
	Fixtures.fire_up(steam)
	steam.state.throttle = 0.0
	steam.boiler().firebox = 12.0
	run_for(steam, 300.0)
	check(float(steam.boiler().firebox) < 7.0 and float(steam.boiler().firebox) > 3.0, "idle burns the 12 kg fire by half in five minutes (%.1f kg)" % float(steam.boiler().firebox))
	# heat follows the coal: a thin fire is a weak one, an overfull one chokes
	var thin = setup("steam", 2)
	Fixtures.fire_up(thin)
	thin.boiler().firebox = 1.0
	thin.boiler().chill = 0.0
	run_for(thin, 60.0)
	check(float(thin.boiler().heat) < 0.5, "a thin fire gives little heat (%.2f)" % float(thin.boiler().heat))
	var good = setup("steam", 2)
	Fixtures.fire_up(good)
	good.boiler().firebox = 6.0
	run_for(good, 30.0)
	check(float(good.boiler().heat) > 0.95, "a fire of half a grate burns at full heat (%.2f)" % float(good.boiler().heat))
	var full = setup("steam", 2)
	Fixtures.fire_up(full)
	full.boiler().firebox = 12.0
	full.boiler().pressure = 0.0
	run_for(full, 20.0)
	var normal = setup("steam", 2)
	Fixtures.fire_up(normal)
	normal.boiler().firebox = 6.0
	normal.boiler().pressure = 0.0
	run_for(normal, 20.0)
	check(float(full.boiler().pressure) < float(normal.boiler().pressure) * 0.9, "an overfull firebox chokes the steam (%.3f against %.3f)" % [float(full.boiler().pressure), float(normal.boiler().pressure)])
	# a fresh portion chills the fire for a moment
	var chilled = setup("steam", 2)
	Fixtures.fire_up(chilled)
	chilled.boiler().firebox = 2.0
	chilled.set_door(true)
	check(chilled.stoke() and float(chilled.boiler().chill) > 3.0, "stoking chills the fire (%.1f s)" % float(chilled.boiler().chill))
	# B4.3: what the weather does. Rain: grip and brake; fog: sight; cold: electric, frost, steam, petrol.
	var dry = setup("motorcar")
	var wet = setup("motorcar")
	wet.weather_force = {"cloud": 1.0, "rain": 1.0, "fog": 0.0}
	check(is_equal_approx(dry.grip_factor(), 1.0) and is_equal_approx(wet.grip_factor(), 0.7), "wet rails grip 30% worse (%.2f)" % wet.grip_factor())
	wet.weather_effect = 0.0
	check(is_equal_approx(wet.grip_factor(), 1.0), "the setting 'no weather' switches the effect off")
	wet.weather_effect = 1.0
	var stops: Array = []
	for m in [dry, wet]:
		m.state.phase = "route"
		m.state.s = 100.0
		m.state.v = 15.0
		m.state.throttle = 0.0
		m.state.brake = 1.0
		var start = float(m.state.s)
		for i in range(60 * 30):
			m.physics_step(1.0 / 60)
			if absf(float(m.state.v)) < 0.05: break
		stops.append(float(m.state.s) - start)
	check(stops[1] > stops[0] * 1.1, "the braking distance in rain is longer (%.1f m against %.1f m)" % [stops[1], stops[0]])
	var foggy = setup("motorcar")
	foggy.weather_force = {"cloud": 1.0, "rain": 0.0, "fog": 1.0}
	check(is_equal_approx(foggy.sight_m(), 150.0) and is_equal_approx(dry.sight_m(), 400.0), "fog shortens the sight to 150 m")
	var night = setup("locomotive", 9)
	var day = setup("locomotive", 9)
	night.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	day.weather_force = night.weather_force
	night.state.stats.seconds = 18.0 * 60.0
	day.state.stats.seconds = 6.0 * 60.0   # one o'clock in the afternoon
	night.state.fleet_by_id.locomotive.temp = 0.95
	day.state.fleet_by_id.locomotive.temp = 0.95
	check(night.cold() > 0.5 and day.cold() < 0.01, "the night is cold, the day is not (%.2f)" % night.cold())
	check(night.thermal_factor() < day.thermal_factor(), "the electric pull is weaker in the cold (%.2f against %.2f)" % [night.thermal_factor(), day.thermal_factor()])
	var pn = setup("pneumatic", 5)
	var pd = setup("pneumatic", 5)
	pn.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	pd.weather_force = pn.weather_force
	pn.state.stats.seconds = 18.0 * 60.0
	pd.state.stats.seconds = 6.0 * 60.0
	for m in [pn, pd]:
		m.state.phase = "route"
		m.state.v = 5.0
		m.state.throttle = 1.0
		for i in range(600): m.update_frost(m.state.fleet_by_id.pneumatic, 1.0 / 60.0)
	check(pn.frost() > pd.frost() * 1.4, "ice grows faster in the cold (%.3f against %.3f)" % [pn.frost(), pd.frost()])
	var steam_cold = setup("steam", 2)
	var steam_warm = setup("steam", 2)
	steam_cold.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	steam_warm.weather_force = steam_cold.weather_force
	steam_cold.state.stats.seconds = 18.0 * 60.0
	steam_warm.state.stats.seconds = 6.0 * 60.0
	for m in [steam_cold, steam_warm]:
		Fixtures.fire_up(m)
		m.boiler().lit = false
		m.boiler().heat = 1.0
		for i in range(60 * 8): m.steam_step(1.0 / 60.0, m.state.fleet_by_id.steam)
	check(float(steam_cold.boiler().heat) < float(steam_warm.boiler().heat), "the fire loses heat faster in the cold (%.2f against %.2f)" % [float(steam_cold.boiler().heat), float(steam_warm.boiler().heat)])
	var pole_dry = setup("handcar")
	var pole_wet = setup("handcar")
	pole_dry.pole.build(42, 6800.0, pole_dry.route.station_s)
	pole_wet.pole.build(42, 6800.0, pole_wet.route.station_s)
	pole_wet.pole.wet = 1.0
	var clay_at = -1.0
	for seg in pole_dry.pole.segments:
		if str(seg[2]) == "clay": clay_at = float(seg[0]) + 1.0
	if clay_at >= 0.0:
		check(float(pole_wet.pole.ground_at(clay_at).g) < float(pole_dry.pole.ground_at(clay_at).g) * 0.7, "wet clay is much slicker for the pole")
	var wind_dry = setup("handcar")
	var wind_wet = setup("handcar")
	wind_wet.weather_force = {"cloud": 1.0, "rain": 1.0, "fog": 0.0}
	check(wind_wet.wind_here(500.0).length() > wind_dry.wind_here(500.0).length() + 1.0, "a rain squall blows harder")
	print("THERMAL CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
