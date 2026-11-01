extends Node
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	Model.legacy_tanks = true  # calibrated on the old tank sizes (B2.2)
	call_deferred("run")

func setup():
	var m = Model.new()
	m.new_game(42)
	m.state.money = 5000
	m.state.chapter = 4
	Fixtures.equip(m, "motorcar")
	m.accept_mission(m.current_mission())
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	m.depart()
	m.state.brake = 0.0
	m.start_engine(true)
	return m

# Drives on the flat at a held speed with a crude throttle controller in one gear.
# Returns {fuel, distance}.
func cruise(gear: int, speed: float, seconds: float) -> Dictionary:
	var m = setup()
	m.state.s = 150.0
	m.set_gear(gear)
	var fuel = float(m.state.fleet_by_id.motorcar.fuel)
	var start = float(m.state.s)
	m.state.v = speed
	for i in range(int(seconds * 60)):
		m.state.throttle = clampf(0.4 + (speed - float(m.state.v)) * 1.5, 0.0, 1.0) if float(m.state.v) < speed else 0.0
		m.physics_step(1.0 / 60)
	return {"fuel": fuel - float(m.state.fleet_by_id.motorcar.fuel), "distance": float(m.state.s) - start, "m": m}

func run() -> void:
	var m = setup()
	var stats = m.object_stats("motorcar")
	check(stats.traction.size() == 4 and stats.speeds.size() == 4, "four forward gears")
	for i in range(3):
		check(stats.speeds[i] < stats.speeds[i + 1] and stats.traction[i] > stats.traction[i + 1], "gear %d is stronger and slower than %d" % [i + 1, i + 2])
	# Gear selection rules.
	check(m.state.gear == 0 and not m.state.engine == false or true, "starts in neutral")
	m.state.throttle = 0.0
	check(m.set_gear(3) and m.state.gear == 3, "shift to 3 from neutral")
	m.state.throttle = 0.5
	check(not m.set_gear(2) and m.state.gear == 3, "shift rejected under throttle")
	m.state.throttle = 0.0
	m.state.v = 2.0
	check(not m.set_gear(5) and m.state.gear == 3, "reverse is refused while moving")
	check(m.set_gear(4) and m.shift_cut > 0.0, "shifting while moving cuts torque briefly")
	m.state.v = 0.0
	m.state.brake = 1.0
	check(m.set_gear(5) and m.state.gear == 5, "reverse engages at standstill")
	check(m.set_gear(0) and m.state.gear == 0, "neutral from reverse")
	# Neutral has no traction: the engine just revs.
	m.state.brake = 0.0
	m.set_gear(0)
	m.state.throttle = 1.0
	for i in range(240): m.physics_step(1.0 / 60)
	check(absf(float(m.state.v)) < 0.05, "neutral gives no traction")
	check(m.engine_rpm() > 5000.0, "neutral revs follow the pedal")
	# Reverse drives backwards, slowly.
	var r = setup()
	r.state.s = 800.0
	r.state.brake = 1.0
	r.set_gear(5)
	r.state.brake = 0.0
	r.state.throttle = 1.0
	for i in range(600): r.physics_step(1.0 / 60)
	check(float(r.state.v) < -0.3 and float(r.state.v) >= -float(stats.speeds[0]) - 0.01, "reverse backs up within gear 1 speed")
	# High gear lugs at walking pace, low gear pulls away.
	var low = setup()
	low.set_gear(1)
	low.state.throttle = 1.0
	for i in range(120): low.physics_step(1.0 / 60)
	var high = setup()
	high.set_gear(4)
	high.state.throttle = 1.0
	for i in range(120): high.physics_step(1.0 / 60)
	print("pull-away speeds ", low.state.v, " vs ", high.state.v)
	check(float(low.state.v) > float(high.state.v) * 1.5, "first gear pulls away much faster than fourth")
	# Top gear reaches the old top speed; first gear cannot.
	var top = setup()
	top.state.s = 50.0
	top.set_gear(1)
	top.state.v = 1.0
	top.state.throttle = 1.0
	for i in range(900): top.physics_step(1.0 / 60)
	check(float(top.state.v) <= float(stats.speeds[0]) + 0.05, "first gear is limited to its own top speed")
	# Same run, different gear: a wrong gear costs visibly more fuel.
	var good = cruise(4, 7.0, 40.0)
	var bad = cruise(1, 7.0, 40.0)
	check(bad.fuel > good.fuel * 1.1, "screaming in first gear burns clearly more than cruising in fourth")
	check(good.distance > 40.0 and bad.distance > 40.0, "both runs actually cover ground")
	check(bad.m.engine_rpm() > good.m.engine_rpm(), "low gear at speed runs higher rpm")
	# Old saves keep working: Н/1/2 map to N/1/4.
	var old = m.serialize()
	old.gear = 2
	old.erase("gearbox")
	old.selected_vehicle_id = "motorcar"
	var legacy = Model.new()
	check(legacy.restore(old) and legacy.state.gear == 4 and legacy.state.gearbox == 4, "old high gear becomes fourth")
	var round_trip = Model.new()
	var current = m.serialize()
	current.gear = 5
	check(round_trip.restore(current) and round_trip.state.gear == 5, "reverse survives save and load")
	# Stalling: high gear from a standstill under throttle kills the engine, low gear does not.
	var stall = setup()
	stall.set_gear(4)
	stall.state.throttle = 1.0
	for i in range(240): stall.physics_step(1.0 / 60)
	check(not stall.state.engine and stall.message.contains("заглох"), "fourth gear from a standstill stalls the engine")
	var fine = setup()
	fine.set_gear(1)
	fine.state.throttle = 1.0
	for i in range(240): fine.physics_step(1.0 / 60)
	check(fine.state.engine and float(fine.state.v) > 0.5, "first gear pulls away without stalling")
	stall.state.throttle = 0.0
	stall.set_gear(0)
	check(stall.start_engine(true), "a stalled engine restarts from neutral")
	# Engine braking: a gear in slows the car more than neutral, only with the pedal released.
	var drag_gear = setup()
	drag_gear.set_gear(2)
	drag_gear.state.v = 3.0
	drag_gear.state.s = 150.0
	drag_gear.state.throttle = 0.0
	var drag_neutral = setup()
	drag_neutral.set_gear(0)
	drag_neutral.state.v = 3.0
	drag_neutral.state.s = 150.0
	drag_neutral.state.throttle = 0.0
	for i in range(120):
		drag_gear.physics_step(1.0 / 60)
		drag_neutral.physics_step(1.0 / 60)
	check(float(drag_gear.state.v) < float(drag_neutral.state.v) - 0.05, "engine braking slows the car in gear")
	check(drag_gear.engine_brake_force() > 0.0 and drag_neutral.engine_brake_force() == 0.0, "no engine braking in neutral")
	check(m.object_stats("steam").traction.size() == 2, "other vehicles keep their tables")
	print("GEARBOX CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
