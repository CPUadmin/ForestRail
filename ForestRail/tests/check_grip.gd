extends Node
# Веха 5, В5.4: сцепление колёс. Тормоз держит ровно столько, сколько держат колёса; сильнее потянул,
# колёса заблокировались (юз) и держат хуже. В дождь сцепление хуже. Подсказка тормозного пути.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

# A machine alone (no wagons: a light train) or with all its wagons, on the line, rolling at a speed.
func fresh(id: String, wagons: bool, speed: float, rain: float = 0.0):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 1000000
	Fixtures.equip(m, id)
	if not wagons:
		while not m.state.consist_ids.is_empty(): m.toggle_wagon(str(m.state.consist_ids[0]))
	m.weather_force = {"cloud": rain, "rain": rain, "fog": 0.0}
	m.state.phase = "route"
	m.state.s = 300.0
	m.state.v = speed
	m.state.direction = 1
	m.state.reverser = 1
	m.state.engine = false
	m.state.throttle = 0.0
	m.state.brake = 0.0
	return m

# Brake with the lever at a position until the train stops; report the way, whether the wheels locked, and the skid events.
func stop(m, lever: float) -> Dictionary:
	m.state.brake = lever
	var start = float(m.state.s)
	var locked = false
	var skids = 0
	for i in range(60 * 60):
		m.physics_step(1.0 / 60.0)
		locked = locked or m.wheel_lock
		while not m.events.is_empty():
			if str(m.events.pop_front()) == "skid": skids += 1
		if absf(float(m.state.v)) < 0.05: break
	return {"way": float(m.state.s) - start, "locked": locked, "skids": skids, "time": float(m.state.stats.seconds)}

func run() -> void:
	# --- the grip the rail gives: all wheels of the train, less in the rain
	var dry = fresh("motorcar", false, 20.0)
	var wet = fresh("motorcar", false, 20.0, 1.0)
	check(is_equal_approx(dry.brake_cap(), 0.35 * dry.train_mass() * 9.81 * cos(dry.route.slope(300.0))), "the grip is 0.35 of the weight of the train (%.0f N)" % dry.brake_cap())
	check(is_equal_approx(wet.brake_cap() / dry.brake_cap(), 0.7), "in the rain the rails give 30%% less (%.2f)" % (wet.brake_cap() / dry.brake_cap()))
	var heavy = fresh("motorcar", true, 20.0)
	check(heavy.brake_cap() > dry.brake_cap() * 1.5, "a heavier train holds better (%.0f against %.0f)" % [heavy.brake_cap(), dry.brake_cap()])
	# --- a light fast car pulled to the stop: the wheels lock
	var hard = fresh("motorcar", false, 25.0)
	var hard_stop = stop(hard, 1.0)
	check(hard_stop.locked and hard_stop.skids == 1, "a light car braked in full locks its wheels, once (%d)" % hard_stop.skids)
	var safe = fresh("motorcar", false, 25.0)
	var safe_lever = safe.brake_safe()
	check(safe_lever > 0.3 and safe_lever < 0.95, "the lever that does not lock is somewhere in the middle (%.2f)" % safe_lever)
	var safe_stop = stop(safe, safe_lever)
	check(not safe_stop.locked and safe_stop.skids == 0, "braked at that lever, the wheels roll")
	check(safe_stop.way < hard_stop.way, "and the car stops sooner than with locked wheels (%.0f m against %.0f m)" % [safe_stop.way, hard_stop.way])
	# the lock lets go when the lever is eased
	var ease = fresh("motorcar", false, 25.0)
	ease.state.brake = 1.0
	for i in range(30): ease.physics_step(1.0 / 60.0)
	check(ease.wheel_lock, "the wheels are locked while the lever is pulled all the way")
	ease.state.brake = 0.3
	for i in range(30): ease.physics_step(1.0 / 60.0)
	check(not ease.wheel_lock, "they roll again when the lever is eased")
	# --- a heavy train does not lock at all
	var steam = fresh("steam", true, 12.0)
	check(steam.brake_safe() >= 0.99, "a steam engine with its wagons can brake in full (%.2f)" % steam.brake_safe())
	var steam_stop = stop(steam, 1.0)
	check(not steam_stop.locked, "and does not lock the wheels")
	# --- the rain: the grip is less, the way is longer
	var rainy = fresh("motorcar", true, 20.0, 1.0)
	var sunny = fresh("motorcar", true, 20.0, 0.0)
	var rain_stop = stop(rainy, rainy.brake_safe())
	var sun_stop = stop(sunny, sunny.brake_safe())
	check(rain_stop.way > sun_stop.way, "in the rain the way is longer (%.0f m against %.0f m)" % [rain_stop.way, sun_stop.way])
	# --- the hint of the way
	for id in ["motorcar", "steam", "locomotive"]:
		var m = fresh(id, true, 15.0)
		var predicted = m.stopping_distance()
		var real = stop(m, m.brake_safe())
		check(real.way > predicted * 0.85 and real.way < predicted * 1.15, "%s: the hinted way (%.0f m) is the real one (%.0f m)" % [id, predicted, real.way])
	check(fresh("motorcar", true, 0.0).stopping_distance() == 0.0, "a standing train needs no way")
	check(fresh("motorcar", true, 30.0).stopping_distance() > fresh("motorcar", true, 15.0).stopping_distance() * 3.0, "the way grows with the square of the speed")
	# V6.5 prerequisite: measure the current fastest railcar before adding a faster one.
	var high_speed_distances: Array[float] = []
	for rain in [0.0, 1.0]:
		var fast = fresh("motorcar", false, 120.0 / 3.6, rain)
		var forecast = fast.stopping_distance()
		var actual = stop(fast, fast.brake_safe())
		high_speed_distances.append(actual.way)
		check(absf(float(fast.state.v)) < 0.05 and not actual.locked, "the railcar stops from 120 km/h without skidding (rain %.0f)" % rain)
		check(actual.way <= forecast, "120 km/h: the forecast does not underestimate the stopping distance (rain %.0f)" % rain)
		print("120 KM/H BRAKING: rain ", rain, ", measured ", actual.way, " m, forecast ", forecast, " m")
	check(high_speed_distances[1] > high_speed_distances[0], "wet rails increase the stopping distance at 120 km/h")
	# --- the driving wheels: spin in the rain, not on a dry rail
	var dry_pull = fresh("locomotive", true, 0.0)
	dry_pull.state.throttle = 1.0
	for i in range(20): dry_pull.physics_step(1.0 / 60.0)
	check(not dry_pull.wheel_slip, "the locomotive pulls away on a dry rail without spinning")
	var wet_pull = fresh("locomotive", true, 0.0, 1.0)
	wet_pull.state.throttle = 1.0
	for i in range(20): wet_pull.physics_step(1.0 / 60.0)
	check(wet_pull.wheel_slip, "and spins its wheels on a wet one")
	print("GRIP CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
