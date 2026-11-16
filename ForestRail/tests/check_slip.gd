extends Node
# The driving wheels spin when the engine asks more than the rail holds (steam, motorcar, locomotive);
# a smooth trip pays +5% with a medal, a harsh one −5%.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const TripDriver = preload("res://tests/trip_driver.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

# The machine with its usual wagons, standing on the line, ready to go.
func fresh(id: String, rain: float = 0.0):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 1000000
	Fixtures.equip(m, id)
	m.weather_force = {"cloud": rain, "rain": rain, "fog": 0.0}
	m.state.phase = "route"
	m.state.s = 300.0
	m.state.v = 0.0
	m.state.direction = 1
	m.state.reverser = 1
	m.state.brake = 0.0
	m.state.throttle = 0.0
	if id == "steam": Fixtures.fire_up(m)
	if id == "motorcar":
		m.state.engine = true
		m.state.gear = 1
	return m

# Drives 6 s with a throttle given by a function of the time; reports the metres, the seconds of spin
# and the throttle at the first spin (-1: none).
func start(m, throttle: Callable) -> Dictionary:
	var from = float(m.state.s)
	var spin = 0.0
	var first = -1.0
	for i in range(360):
		m.state.throttle = float(throttle.call(i / 60.0))
		m.physics_step(1.0 / 60.0)
		if m.wheel_slip:
			spin += 1.0 / 60.0
			if first < 0.0: first = float(m.state.throttle)
	return {"m": float(m.state.s) - from, "spin": spin, "first": first}

func run() -> void:
	var floored = func(_t): return 1.0
	var smooth = func(t): return minf(0.8, t / 1.0)   # opened over a second to 80%
	for id in ["steam", "motorcar", "locomotive"]:
		var hard = start(fresh(id), floored)
		var soft = start(fresh(id), smooth)
		var gentle = start(fresh(id), func(t): return minf(0.65, t / 2.0))
		print("SLIP %s: floored %.1f m in 6 s, spinning %.1f s; smooth %.1f m, spinning %.1f s" % [id, hard.m, hard.spin, soft.m, soft.spin])
		check(hard.spin > 0.5, "%s: floored from a standstill, the wheels spin (%.1f s)" % [id, hard.spin])
		check(soft.spin == 0.0 and gentle.spin == 0.0, "%s: opened smoothly, they do not" % id)
		check(soft.m > hard.m, "%s: the smooth start goes further in 6 s (%.1f m against %.1f m)" % [id, soft.m, hard.m])
		var slow = func(t): return minf(1.0, t / 5.0)
		var dry = start(fresh(id), slow)
		var wet = start(fresh(id, 1.0), slow)
		print("SLIP %s: a slow opening spins at %.2f dry, %.2f wet" % [id, dry.first, wet.first])
		check(wet.first > 0.0 and (dry.first < 0.0 or wet.first < dry.first - 0.1), "%s: in the rain the wheels spin earlier (%.2f against %.2f)" % [id, wet.first, dry.first])
		var safe = start(fresh(id, 1.0), func(_t): return 1.0)
		check(safe.spin > 0.0, "%s: floored in the rain, they spin" % id)
	# the slip lets go when the throttle is eased
	var ease = fresh("locomotive")
	ease.state.throttle = 1.0
	ease.physics_step(1.0 / 60.0)
	check(ease.wheel_slip and ease.events.has("slip"), "the locomotive spins at full throttle and says so")
	ease.state.throttle = 0.6
	ease.physics_step(1.0 / 60.0)
	check(not ease.wheel_slip, "eased to 60%, the wheels grip again")
	ease.state.throttle = ease.throttle_safe()
	for i in range(60): ease.physics_step(1.0 / 60.0)
	check(not ease.wheel_slip and ease.throttle_safe() > 0.7, "the safe throttle does not spin (%.2f)" % ease.throttle_safe())
	# the pole and the jet never spin
	for id in ["pole", "jet", "pneumatic", "handcar"]:
		var other = fresh(id)
		var spun = false
		for i in range(120):
			other.state.throttle = 1.0
			other.physics_step(1.0 / 60.0)
			spun = spun or other.wheel_slip
		check(not other.spins() and not spun, "%s never spins its wheels" % id)
	# --- the smoothness of the trip
	var jerk = fresh("motorcar")
	jerk.state.active = {"phase": "outbound"}
	jerk.state.v = 10.0
	jerk.track_smooth(1.0 / 60.0, 0.1)
	jerk.state.brake = 1.0
	jerk.track_smooth(1.0 / 60.0, 0.1)
	check(is_equal_approx(float(jerk.state.active.get("rough", 0.0)), 1.5), "the brake jerked on at speed counts 1.5 (%.2f)" % float(jerk.state.active.get("rough", 0.0)))
	var calm = fresh("motorcar")
	calm.state.active = {"phase": "outbound"}
	calm.state.v = 10.0
	for i in range(61):
		calm.state.brake = i / 60.0
		calm.track_smooth(1.0 / 60.0, 0.1)
	check(float(calm.state.active.get("rough", 0.0)) == 0.0, "the brake pulled over a second does not count")
	var crawl = fresh("motorcar")
	crawl.state.active = {"phase": "outbound"}
	crawl.state.v = 3.0
	crawl.track_smooth(1.0 / 60.0, 0.1)
	crawl.state.brake = 1.0
	crawl.track_smooth(1.0 / 60.0, 0.1)
	check(float(crawl.state.active.get("rough", 0.0)) == 0.0, "nor a jerk at a crawl")
	var spinning = fresh("locomotive")
	spinning.state.active = {"phase": "outbound"}
	spinning.state.throttle = 1.0
	for i in range(60): spinning.physics_step(1.0 / 60.0)
	check(float(spinning.state.active.get("rough", 0.0)) > 0.9, "a second of spinning counts a second (%.2f)" % float(spinning.state.active.get("rough", 0.0)))
	# --- the pay
	Model.order_rules = true
	var good = pay(3000.0, 0.0)
	check(good.notes.has("плавный рейс +5%") and good.medals.has("smooth") and good.paid == roundi(good.listed * 1.05), "a clean trip pays +5%% with the medal (%d of %d)" % [good.paid, good.listed])
	var bad = pay(3000.0, 3000.0 / 1000.0 * (Model.SMOOTH_BAD + 1.0))
	check(bad.notes.has("резкая езда −5%") and not bad.medals.has("smooth") and bad.paid == roundi(bad.listed * 0.95), "a harsh trip pays −5%% (%d of %d)" % [bad.paid, bad.listed])
	var mid = pay(3000.0, 3.0 * (Model.SMOOTH_GOOD + Model.SMOOTH_BAD) * 0.5)
	check(mid.notes.is_empty() and mid.medals.is_empty() and mid.paid == mid.listed, "in between: nothing (%s)" % str(mid.notes))
	var short = pay(600.0, 0.0)
	check(short.notes.is_empty() and short.paid == short.listed, "a trip shorter than a kilometre gets no bonus")
	var late = pay(3000.0, 0.0, 2.0)
	check(not late.notes.has("плавный рейс +5%") and not late.medals.has("smooth"), "a late trip gets no bonus (%s)" % str(late.notes))
	var late_bad = pay(3000.0, 30.0, 2.0)
	check(not late_bad.notes.has("резкая езда −5%"), "and no penalty")
	var creative = pay(3000.0, 0.0, 1.0, true)
	check(creative.notes.is_empty() and creative.medals.is_empty(), "the creative mode gets neither (%s)" % str(creative.notes))
	var creative_bad = pay(3000.0, 30.0, 1.0, true)
	check(creative_bad.notes.is_empty(), "neither the penalty")
	Model.order_rules = false
	# --- test drives for the thresholds: a careful driver (throttle_safe, brake_safe)
	Model.order_rules = true
	for id in ["motorcar", "locomotive", "steam"]:
		var d = Model.new()
		d.new_game(42)
		d.state.money = 100000
		Fixtures.equip(d, id)
		d.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
		d.refuel()
		var trip = TripDriver.round_trip(d, "C", 2)
		var result = d.state.last_result
		print("SLIP TRIP %s: ok %s %s, %.0f s, notes %s, rough %.2f a km" % [id, str(trip.ok), str(trip.get("why", "")), float(trip.get("seconds", 0)), str(result.get("notes", [])), float(result.get("rough_km", -1.0))])
		check(trip.ok and result.get("notes", []).has("плавный рейс +5%"), "%s: a careful driver gets the smooth bonus (%s)" % [id, str(result.get("notes", []))])
	Model.order_rules = false
	print("SLIP CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

# Takes a free order, marks the metres and the rough points of the trip, comes back at a share of the time.
func pay(metres: float, rough: float, fraction: float = 1.0, creative: bool = false) -> Dictionary:
	var m = Model.new()
	m.new_game(42, 2)
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.money = 5000
	if creative: m.state.mode = "creative"
	var mission = m.free_offers()[0]
	m.accept_mission(mission)
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	m.depart()
	for item in m.state.cargo: item.delivered = true
	m.evaluate_delivery()
	m.state.stats.seconds = float(m.state.stats.seconds) + float(m.state.active.get("budget_s", 100.0)) * fraction
	m.state.s = float(m.route.station_s[0])
	m.state.v = 0.0
	m.state.brake = 1.0
	m.state.active.pending_reward = int(m.state.active.reward)
	m.state.active.smooth_m = metres
	m.state.active.rough = rough
	var listed = float(m.state.active.reward)
	var before = int(m.state.money)
	m.settle()
	return {"paid": int(m.state.money) - before, "listed": listed, "notes": m.state.last_result.get("notes", []), "medals": m.state.last_result.get("medals", [])}
