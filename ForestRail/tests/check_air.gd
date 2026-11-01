extends Node
# N14.1: the train is not fastened to the rail. Springboard knolls on the long line, flight off a
# crest when v^2 * curvature beats gravity, landing impact on fragile cargo.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh(version: int = 2, seed_value: int = 42) -> Object:
	var m = Model.new()
	m.new_game(seed_value, version)
	m.state.money = 100000
	Fixtures.equip(m, "motorcar")
	m.state.phase = "route"
	m.state.brake = 0.0
	m.state.throttle = 0.0
	return m

# Roll over the first knoll at the given speed; report the highest and the longest flight.
func roll(m, speed: float, knoll: int = 0) -> Dictionary:
	var x0 = float(m.route.knolls[knoll][0])
	m.state.s = float(m.route.distance_at_x(x0)) - 40.0
	m.state.v = speed
	m.state.direction = 1
	var top = 0.0
	var air_time = 0.0
	var landed = 0.0
	for i in range(60 * 6):
		m.physics_step(1.0 / 60.0)
		top = maxf(top, float(m.air_z))
		if float(m.air_z) > 0.0: air_time += 1.0 / 60.0
		landed = maxf(landed, float(m.last_landing))
		if float(m.state.s) > float(m.route.distance_at_x(x0)) + 60.0: break
	return {"top": top, "time": air_time, "landing": landed, "v": float(m.state.v)}

func run() -> void:
	var m = fresh()
	var count = m.route.knolls.size()
	check(count >= 3 and count <= 5, "the long line has springboard knolls (%d)" % count)
	check(fresh(2, 42).route.knolls == m.route.knolls and fresh(2, 43).route.knolls != m.route.knolls, "the same seed, the same places")
	check(fresh(1).route.knolls.is_empty(), "the old short line has none")
	var worst = 0.0
	var kx = 0.0
	for knoll in m.route.knolls:
		for k in range(int(knoll[1])):
			var a = m.route.sample(m.route.distance_at_x(float(knoll[0]) + float(k)))
			var b = m.route.sample(m.route.distance_at_x(float(knoll[0]) + float(k) + 1.0))
			worst = maxf(worst, absf(b.y - a.y))
	check(worst < 0.07, "a knoll is no steeper than 7%% (%.3f)" % worst)
	for i in range(m.route.station_s.size()):
		var near = false
		for knoll in m.route.knolls:
			if absf(float(m.route.station_x[i]) - float(knoll[0])) < 150.0: near = true
		check(not near, "no knoll within 150 m of station %d" % i)
	# the speed it takes
	var slow = roll(fresh(), 60.0 / 3.6)
	check(slow.top == 0.0 and slow.landing == 0.0, "60 km/h: the knoll is just crossed, no flight")
	var edge = roll(fresh(), 70.0 / 3.6)
	check(edge.top == 0.0, "70 km/h: still on the rail (%.3f m)" % edge.top)
	var fast = roll(fresh(), 100.0 / 3.6)
	print("AIR 100 km/h: hop %.3f m, %.2f s in the air, landing %.2f m/s, v after %.1f" % [fast.top, fast.time, fast.landing, fast.v * 3.6])
	check(fast.top > 0.03 and fast.top < 0.8, "100 km/h: a small hop (%.2f m)" % fast.top)
	check(fast.time > 0.1 and fast.time < 1.5, "the flight lasts a moment (%.2f s)" % fast.time)
	var faster = roll(fresh(), 140.0 / 3.6)
	check(faster.top > fast.top, "faster, higher (%.2f m at 140)" % faster.top)
	check(fast.v > 24.0, "the hop does not stop the train")
	# no traction, no brake in the air
	var air = fresh()
	air.state.s = float(air.route.distance_at_x(float(air.route.knolls[0][0]))) - 40.0
	air.state.v = 100.0 / 3.6
	var flew = false
	var drive_in_air = false
	air.state.brake = 1.0
	for i in range(60 * 4):
		var before = float(air.state.v)
		air.physics_step(1.0 / 60.0)
		if float(air.air_z) > 0.02:
			flew = true
			if float(air.state.v) < before - 0.05: drive_in_air = true
	check(flew and not drive_in_air, "the brake does nothing while the wheels are off the rail")
	# a hard landing hurts fragile cargo, a soft pass does not
	for pair in [[60.0, true], [140.0, false]]:
		var g = fresh()
		g.state.chapter = 2
		var mission = {"id": "x", "tier": "handcar", "dropoffs": [{"station": "B", "cargo": [["fragile", 1]]}]}
		g.state.cargo = [{"id": "c1", "type": "fragile", "destination": "B", "slot": "motorcar:0", "delivered": false, "health": 1.0, "weight_kg": 10}]
		var result = roll(g, float(pair[0]) / 3.6)
		var health = float(g.state.cargo[0].health)
		if pair[1]: check(health >= 0.999, "at %.0f km/h the dishes are fine" % pair[0])
		else: check(health < 0.95, "a hard landing at %.0f km/h breaks dishes (%.2f)" % [pair[0], health])
	# nothing flies on the old line, and the handcar never leaves the rail
	var old = fresh(1)
	old.state.s = 600.0
	old.state.v = 40.0
	var old_top = 0.0
	for i in range(60 * 10):
		old.physics_step(1.0 / 60.0)
		old_top = maxf(old_top, float(old.air_z))
	check(old_top == 0.0, "the old line has no crest sharp enough at 144 km/h")
	var hand = Model.new()
	hand.new_game(42, 2)
	hand.state.phase = "route"
	hand.state.s = float(hand.route.distance_at_x(float(hand.route.knolls[0][0]))) - 40.0
	hand.state.v = 30.0
	for i in range(60 * 3): hand.physics_step(1.0 / 60.0)
	check(float(hand.air_z) == 0.0, "a handcar does not fly")
	# saving keeps the knolls
	var other = Model.new()
	m.state.phase = "depot"
	m.state.active = {}
	m.state.cargo = []
	check(other.restore(m.serialize()) and other.route.knolls == m.route.knolls, "the knolls survive saving and loading")
	print("AIR CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
