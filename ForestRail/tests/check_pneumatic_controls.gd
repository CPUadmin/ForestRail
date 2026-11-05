extends Node
# B6.2 (ROADMAP_RU.md 6.6): the reducer sets the working pressure (the pull and the frost follow it), the heating tap slows the frost
# down and costs air, the four drain valves stop the ice plugs.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh():
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "pneumatic")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.phase = "route"
	m.state.brake = 0.0
	return m

func run_seconds(m, seconds: float, throttle: float = 1.0) -> void:
	m.state.v = 10.0
	m.state.throttle = throttle
	var fleet = m.state.fleet_by_id.pneumatic
	for i in range(int(seconds * 60.0)):
		m.state.v = 10.0
		m.update_frost(fleet, 1.0 / 60.0)

func run() -> void:
	var m = fresh()
	# the defaults keep the old behaviour: the wheel all the way open (60% of a full tank), the tap shut, no plugs
	check(is_equal_approx(m.reducer_position(), 1.0) and is_equal_approx(m.reducer_setting(), 0.6) and not m.heating_on(), "by default the reducer is open, the heating is shut")
	check(is_equal_approx(m.working_pressure(), 30.0), "the working pressure of the open reducer is 30 bar of 50 (%.1f)" % m.working_pressure())
	check(is_equal_approx(m.pneumatic_factor(), 1.0), "with the reducer open the pull is full, as before")
	# the wheel: the working pressure and the pull follow it, the receiver stays
	check(m.set_reducer(0.0) and is_equal_approx(m.reducer_setting(), 0.1) and is_equal_approx(m.working_pressure(), 5.0), "the wheel at the start: 5 bar of the working pressure")
	check(is_equal_approx(m.pneumatic_factor(), 5.0 / 20.0), "5 bar of 20 needed: a quarter of the pull (%.3f)" % m.pneumatic_factor())
	m.set_reducer(0.5)
	check(is_equal_approx(m.reducer_setting(), 0.35) and m.pneumatic_factor() < 1.0 and m.pneumatic_factor() > 0.8, "half a wheel: 17.5 bar, the pull is below the full")
	m.set_reducer(0.6)
	check(is_equal_approx(m.pneumatic_factor(), 1.0), "from 0.6 of the wheel (20 bar) the pull is full")
	m.state.fleet_by_id.pneumatic.fuel = 8.0
	m.set_reducer(1.0)
	check(is_equal_approx(m.working_pressure(), 8.0), "the working pressure never exceeds the receiver (%.1f)" % m.working_pressure())
	m.state.fleet_by_id.pneumatic.fuel = 50.0
	# the frost grows with the 1.5th power of the working pressure
	var open = fresh()
	run_seconds(open, 20.0)
	var lowered = fresh()
	lowered.set_reducer(0.0)
	run_seconds(lowered, 20.0)
	var ratio = lowered.frost() / maxf(0.0001, open.frost())
	var expected = pow(0.1 / 0.6, 1.5)
	check(open.frost() > 0.01 and absf(ratio - expected) < 0.03, "the frost grows with the working pressure to the power 1.5 (%.3f against %.3f)" % [ratio, expected])
	# the heating tap
	var warm = fresh()
	check(warm.set_heating(true) and warm.heating_on(), "the heating tap opens")
	run_seconds(warm, 20.0)
	check(absf(warm.frost() / maxf(0.0001, open.frost()) - 0.2) < 0.03, "the heating slows the frost down 5 times (%.3f)" % (warm.frost() / maxf(0.0001, open.frost())))
	check(warm.set_heating(false) and not warm.heating_on(), "the tap shuts")
	# the heating costs 15% more air for the same work
	var spent: Array = []
	for heating in [false, true]:
		var a = fresh()
		a.set_heating(heating)
		a.state.v = 8.0
		a.state.throttle = 1.0
		a.state.s = 100.0
		var before = float(a.state.fleet_by_id.pneumatic.fuel)
		for i in range(120): a.physics_step(1.0 / 60.0)
		spent.append(before - float(a.state.fleet_by_id.pneumatic.fuel))
	check(spent[0] > 0.0 and absf(spent[1] / spent[0] - 1.15) < 0.04, "the heating costs 15%% more air (%.3f)" % (spent[1] / maxf(0.0001, spent[0])))
	# the drain valves: not pressed for 60 s of running: an ice plug, the frost at that spot grows twice as fast
	var plug = fresh()
	check(not plug.plugged(0) and not plug.drain_due(0), "a new train has no plugs")
	run_seconds(plug, 50.0, 0.0)
	check(plug.drain_due(0) and not plug.plugged(0), "after 48 s the hint blinks, there is no plug yet")
	run_seconds(plug, 20.0, 0.0)
	check(plug.plugged(2) and plug.drain_age(2) > 60.0, "after 60 s of running the spot has a plug")
	var plugged_frost = fresh()
	plugged_frost.set_reducer(0.0)   # a low working pressure: the frost does not reach the top in a minute
	run_seconds(plugged_frost, 61.0)
	var base_spot = float(plugged_frost.state.fleet_by_id.pneumatic.ice_spots[0])
	check(plugged_frost.drain(0) and not plugged_frost.plugged(0) and plugged_frost.drain_age(0) == 0.0, "a click on the valve lets the condensate out: the counter is zero")
	var before_spot0 = float(plugged_frost.state.fleet_by_id.pneumatic.ice_spots[0])
	var before_spot1 = float(plugged_frost.state.fleet_by_id.pneumatic.ice_spots[1])
	run_seconds(plugged_frost, 5.0)
	var growth0 = float(plugged_frost.state.fleet_by_id.pneumatic.ice_spots[0]) - before_spot0
	var growth1 = float(plugged_frost.state.fleet_by_id.pneumatic.ice_spots[1]) - before_spot1
	check(growth0 > 0.0 and growth1 > 0.0 and growth1 / 0.8 > growth0 * 1.5, "the plugged spot freezes about twice as fast as the drained one (%.4f against %.4f per weight)" % [growth1 / 0.8, growth0])
	check(not fresh().drain(7) and not fresh().drain(-1), "a wrong valve does nothing")
	# a saved game of the old kind has none of these fields: the defaults are safe
	var old = fresh()
	old.state.fleet_by_id.pneumatic.erase("reducer")
	old.state.fleet_by_id.pneumatic.erase("heating")
	old.state.fleet_by_id.pneumatic.erase("drain_t")
	run_seconds(old, 2.0)
	check(is_equal_approx(old.reducer_position(), 1.0) and not old.heating_on() and old.drain_age(0) > 1.0, "an old save runs with the defaults")
	print("PNEUMATIC CONTROLS CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
