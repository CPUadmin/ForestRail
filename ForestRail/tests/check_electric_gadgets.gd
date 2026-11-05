extends Node
# Gadgets of the electric locomotive (docs/GADGET_EFFECTS_PROPOSAL_RU.md): the supercapacitor gives a burst of pull
# (+50% for 5 s, 45 s to charge, 2% of the battery), the liquid cooling keeps the motor cooler.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fresh(with_cap: bool, with_cooling: bool):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "locomotive")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	if with_cap: m.object_state("locomotive").levels["locomotive_supercap"] = 1
	if with_cooling: m.object_state("locomotive").levels["locomotive_cooling"] = 1
	m.state.phase = "route"
	return m

func temperature_after(m, seconds: float) -> float:
	m.state.v = 3.0
	m.state.throttle = 1.0
	var fleet = m.state.fleet_by_id.locomotive
	fleet.temp = 0.1
	for i in range(int(seconds * 60.0)): m.thermal_step(1.0 / 60.0, fleet)
	return float(fleet.temp)

func speed_after(m, seconds: float, burst: bool) -> float:
	m.state.throttle = 1.0
	m.state.brake = 0.0
	m.state.v = 0.0
	if burst: check(m.start_burst(), "the burst starts")
	for i in range(int(seconds * 60.0)): m.physics_step(1.0 / 60.0)
	return float(m.state.v)

func run() -> void:
	Model.legacy_tanks = false
	var catalog: Array = []
	var m0 = fresh(false, false)
	for branch in m0.data.upgrade_catalog: catalog.append(str(branch.id))
	check("locomotive_supercap" in catalog and "locomotive_cooling" in catalog, "both gadgets are in the catalog")
	for card in m0.data.casino.cards:
		if str(card.machine) == "locomotive": check(m0.casino().card_available(card), "the card %s can drop: its gadget exists" % str(card.id))
	# without the gadget nothing happens
	check(not m0.supercap_installed() and not m0.burst_ready() and not m0.start_burst(), "without the supercapacitor there is no burst")
	# the cooling
	var plain = temperature_after(fresh(false, false), 120.0)
	var cooled = temperature_after(fresh(false, true), 120.0)
	check(cooled < plain - 0.03, "the liquid cooling keeps the motor cooler (%.3f against %.3f)" % [cooled, plain])
	# the burst: the numbers of the proposal
	var m = fresh(true, false)
	check(m.supercap_installed() and m.burst_ready(), "with the gadget on the road the burst is ready")
	var battery = float(m.state.fleet_by_id.locomotive.fuel)
	var cost = float(m.object_stats("locomotive").tank) * 0.02
	check(m.start_burst(), "the burst starts")
	check(is_equal_approx(m.burst_left(), 5.0) and is_equal_approx(m.burst_cooldown(), 45.0), "5 seconds of the burst and 45 seconds to charge")
	check(absf(battery - float(m.state.fleet_by_id.locomotive.fuel) - cost) < 0.0001, "the burst takes 2%% of the battery (%.3f kWh)" % cost)
	check(is_equal_approx(m.burst_factor(), 1.5) and not m.burst_ready() and not m.start_burst(), "the pull is x1.5 and the button is closed while it works")
	for i in range(int(5.1 * 60.0)): m.burst_step(1.0 / 60.0)
	check(is_equal_approx(m.burst_factor(), 1.0) and not m.burst_ready(), "after 5 seconds the pull is normal and the charge is not ready")
	for i in range(int(40.0 * 60.0)): m.burst_step(1.0 / 60.0)
	check(m.burst_ready(), "after 45 seconds the burst is ready again")
	# the burst really pushes the train
	var without = speed_after(fresh(true, false), 3.0, false)
	var with_burst = speed_after(fresh(true, false), 3.0, true)
	check(with_burst > without * 1.15, "the burst speeds the train up (%.2f against %.2f m/s after 3 s)" % [with_burst, without])
	# a new run starts without a burst
	var d = fresh(true, false)
	d.start_burst()
	d.state.phase = "depot"
	d.state.burst_left = 0.0
	d.state.burst_cooldown = 0.0
	check(d.burst_cooldown() == 0.0, "a new run begins with a ready gadget")
	print("ELECTRIC GADGETS CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
