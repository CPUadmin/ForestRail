extends Node
# Гаджет «Закись азота» бензиновой (docs/GADGET_EFFECTS_PROPOSAL_RU.md): кнопка «Нитро», +60% тяги на 4 с, два заряда на рейс, бензин горит вдвое быстрее на это время.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fresh(with_nitro: bool):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "motorcar")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	if with_nitro: m.object_state("motorcar").levels["motorcar_nitro"] = 1
	m.state.phase = "route"
	m.state.gear = 1
	m.state.engine = true
	m.state.brake = 0.0
	m.state.throttle = 1.0
	m.state.v = 0.0
	m.state.fleet_by_id.motorcar.fuel = float(m.object_stats("motorcar").tank)
	return m

# {speed, fuel burnt} after the given seconds of full throttle
func run_for(m, seconds: float, nitro: bool) -> Dictionary:
	var before = float(m.state.fleet_by_id.motorcar.fuel)
	if nitro: check(m.start_burst(), "the nitro starts")
	for i in range(int(seconds * 60.0)): m.physics_step(1.0 / 60.0)
	return {"v": float(m.state.v), "used": before - float(m.state.fleet_by_id.motorcar.fuel)}

func run() -> void:
	Model.legacy_tanks = false
	var catalog: Array = []
	var m0 = fresh(false)
	for branch in m0.data.upgrade_catalog: catalog.append(str(branch.id))
	check("motorcar_nitro" in catalog, "the gadget is in the catalog")
	for card in m0.data.casino.cards:
		if str(card.machine) == "motorcar" and str(card.upgrade) == "motorcar_nitro": check(m0.casino().card_available(card), "the card %s can drop" % str(card.id))
	check(not m0.nitro_installed() and m0.burst_gadget() == "" and not m0.burst_ready() and not m0.start_burst(), "without the gadget there is no button")

	var m = fresh(true)
	check(m.nitro_installed() and m.burst_gadget() == "nitro" and m.nitro_charges() == 2 and m.burst_ready(), "with the gadget: the button works, two charges")
	m.state.engine = false
	check(not m.burst_ready(), "the nitro needs a running engine")
	m.state.engine = true
	check(m.start_burst() and m.nitro_charges() == 1 and is_equal_approx(m.burst_left(), 4.0) and is_equal_approx(m.burst_factor(), 1.6), "a charge goes, 4 s, the pull x1.6")
	check(not m.burst_ready() and not m.start_burst(), "while it burns the button is closed")
	for i in range(int(4.1 * 60.0)): m.burst_step(1.0 / 60.0)
	check(is_equal_approx(m.burst_factor(), 1.0) and m.burst_ready(), "after 4 s the pull is normal and the second charge is ready at once")
	check(m.start_burst() and m.nitro_charges() == 0, "the second charge")
	for i in range(int(4.1 * 60.0)): m.burst_step(1.0 / 60.0)
	check(not m.burst_ready() and not m.start_burst(), "no third charge in the same trip")
	m.depart()   # a new trip fills the cylinders again (the departure itself fails without a mission, the cylinders are refilled first)
	check(m.nitro_charges() == 2, "a new trip: two charges again")

	# the pull and the burn
	var plain = run_for(fresh(true), 3.0, false)
	var boosted = run_for(fresh(true), 3.0, true)
	check(float(boosted.v) > float(plain.v) * 1.1, "the nitro speeds the car up (%.2f against %.2f m/s after 3 s)" % [float(boosted.v), float(plain.v)])
	check(float(boosted.used) > float(plain.used) * 1.8, "and burns the petrol much faster (%.5f against %.5f l)" % [float(boosted.used), float(plain.used)])
	print("NITRO CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
