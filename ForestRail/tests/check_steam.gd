extends Node
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

# A steam engine standing at the start of a trip, wagons loaded.
func setup():
	var m = Model.new()
	m.new_game(42)
	m.state.money = 5000
	m.state.chapter = 2
	Fixtures.equip(m, "steam")
	m.accept_mission(m.current_mission())
	for i in range(mini(m.state.cargo.size(), m.slots().size())): m.transfer(m.state.cargo[i].id, m.slots()[i].key)
	return m

func run_for(m, seconds: float) -> void:
	for i in range(int(seconds * 60)): m.physics_step(1.0 / 60)

func run() -> void:
	var m = setup()
	check(m.vehicle_id() == "steam", "steam selected")
	var cfg = m.boiler_cfg()
	# Cold boiler: no fire, no pressure, nothing happens by itself.
	check(not m.boiler().lit and m.pressure_bar() == 0.0, "boiler starts cold")
	check(not m.light_fire(), "no coal, no spark")
	check(not m.stoke(), "door must be open before stoking")
	# The tap alone cannot make pressure.
	m.boiler().feed = 1.0
	run_for(m, 5)
	check(m.pressure_bar() == 0.0, "water alone makes no pressure")
	# Stoking takes coal from the bucket into the firebox.
	var bucket = float(m.state.fleet_by_id.steam.fuel)
	check(m.set_door(true) and m.stoke(), "stoke with the door open")
	var firebox = float(m.boiler().firebox)
	check(is_equal_approx(firebox, float(cfg.portion_kg)) and is_equal_approx(bucket - firebox, float(m.state.fleet_by_id.steam.fuel)), "stoking moves one portion from bucket to firebox")
	while m.stoke(): pass
	check(float(m.boiler().firebox) <= float(cfg.firebox_kg) + 0.0001, "firebox is finite")
	m.set_door(false)
	# Fire without a spark does not heat; the spark lights it.
	run_for(m, 3)
	check(m.pressure_bar() == 0.0, "coal without a spark makes no steam")
	check(m.light_fire() and m.boiler().lit and not m.light_fire(), "spark lights the fire once")
	m.depart()
	check(m.state.phase == "route", "departed")
	m.state.brake = 1.0
	var water = float(m.state.fleet_by_id.steam.water)
	run_for(m, 10)
	check(m.pressure_bar() > 0.0 and not m.steam_ready(), "pressure builds gradually")
	check(float(m.state.fleet_by_id.steam.water) < water, "steam costs water")
	# Valve open before working pressure does not move the engine.
	m.state.brake = 0.0
	m.valve_held = true
	m.state.throttle = 1.0
	run_for(m, 1)
	check(absf(float(m.state.v)) < 0.3, "valve without pressure does not accelerate")
	m.state.throttle = 0.0
	m.state.brake = 1.0
	run_for(m, 20)
	check(m.steam_ready(), "working pressure reached in about half a minute")
	# Pull away at full pressure.
	m.state.brake = 0.0
	m.valve_held = true
	m.state.throttle = 0.9
	run_for(m, 20)
	check(float(m.state.v) > 1.0, "engine pulls with pressure")
	# Letting go closes the valve by spring, and it does not brake.
	m.valve_held = false
	m.state.throttle = 1.0
	run_for(m, 1.0)
	check(float(m.state.throttle) > 0.5 and float(m.state.throttle) < 1.0, "spring closes the valve gradually")
	run_for(m, 3)
	check(float(m.state.throttle) == 0.0 and float(m.state.brake) == 0.0, "valve returns to zero and does not brake")
	check(float(m.state.v) > 0.0, "engine coasts after the valve closes")
	# Steam is spent by the valve: a held full valve drains the boiler.
	var before = float(m.boiler().pressure)
	m.valve_held = true
	m.state.throttle = 1.0
	run_for(m, 30)
	check(float(m.boiler().pressure) < before, "full valve spends steam faster than it is made")
	# Coal runs out: the fire dies, heat and pressure fade gradually.
	m.valve_held = true
	m.state.throttle = 0.0
	m.boiler().firebox = 0.0
	run_for(m, 1)
	check(not m.boiler().lit and not m.state.engine, "fire dies when the firebox is empty")
	var fading = float(m.boiler().pressure)
	run_for(m, 90)
	check(float(m.boiler().pressure) < fading and float(m.boiler().pressure) > 0.0, "pressure fades gradually, not instantly")
	# No water: no new steam even with fire.
	var m2 = setup()
	Fixtures.fire_up(m2)
	m2.depart()
	m2.state.fleet_by_id.steam.water = 0.0
	m2.boiler().pressure = 0.0
	run_for(m2, 20)
	check(m2.pressure_bar() == 0.0, "no water, no steam")
	check(not m2.start_engine(true) or m2.boiler().lit, "relighting needs water")
	# Open door loses heat; safety valve caps the pressure.
	var m3 = setup()
	Fixtures.fire_up(m3)
	m3.depart()
	m3.boiler().pressure = 0.99
	m3.state.brake = 1.0
	run_for(m3, 5)
	check(float(m3.boiler().pressure) <= 1.0 and bool(m3.boiler().venting), "safety valve caps the pressure")
	# Save keeps the boiler; an old save without one still loads.
	var copy = Model.new()
	check(copy.restore(m3.serialize()), "boiler save restores")
	check(is_equal_approx(float(copy.boiler().firebox), float(m3.boiler().firebox)) and copy.boiler().lit == m3.boiler().lit, "boiler survives save and load")
	var old = m3.serialize()
	for key in ["firebox", "heat", "pressure", "lit", "door", "venting", "feed"]: old.fleet_by_id.steam.erase(key)
	var legacy = Model.new()
	check(legacy.restore(old), "pre-boiler save loads")
	check(legacy.boiler().lit and legacy.pressure_bar() > 0.0, "mid-trip pre-boiler save gets a warm boiler")
	# Coming back to the depot puts the fire out but keeps the coal.
	m3.state.phase = "route"
	m3.back_to_depot()
	check(not m3.boiler().lit and m3.pressure_bar() == 0.0 and float(m3.boiler().firebox) > 0.0, "depot cools the boiler, coal stays")
	# Steam never offers deck places, gears or a start switch.
	check(m3.object_stats("steam").slots == 0, "no deck places on steam")
	check(m3.set_gear(2) and m3.state.gear == 1, "no gearbox on steam")
	var result = {"checks": checks, "failures": failures}
	print("STEAM CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
