extends Node
# Гаджет «Автоматическая КПП» бензиновой: на пульте селектор Д/Н/З вместо кулисы; в Д передачу выбирает сама коробка по скорости, переключение не рвёт тягу,
# бензина уходит на 5% меньше. Окно: настоящая мышь двигает селектор (check_auto_gearbox_view).
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fresh(auto: bool):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "motorcar")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	if auto: m.object_state("motorcar").levels["motorcar_automatic"] = 1
	for p in m.route.points: p[1] = 0.0
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.brake = 0.0
	return m

func run() -> void:
	Model.legacy_tanks = false
	var m0 = fresh(false)
	var catalog: Array = []
	for branch in m0.data.upgrade_catalog: catalog.append(str(branch.id))
	check("motorcar_automatic" in catalog, "the gadget is in the catalog")
	for card in m0.data.casino.cards:
		if str(card.upgrade) == "motorcar_automatic": check(m0.casino().card_available(card), "the card %s can drop" % str(card.id))
	check(not m0.auto_gearbox() and m0.selector_gear() == int(m0.state.gear), "without the gadget the gear is the gear")

	var m = fresh(true)
	check(m.auto_gearbox(), "the gadget is on the car")
	check(m.start_engine(true), "the engine starts in neutral")
	check(m.set_gear(3) and int(m.state.gear) == 1 and m.selector_gear() == 1, "any gear asked is D (the box starts from the first)")
	# a run: the box climbs through the gears by itself and the pull does not break at a shift
	m.state.throttle = 1.0
	var seen: Dictionary = {}
	var broke = false
	var previous_v = 0.0
	for i in range(60 * 60):
		m.physics_step(1.0 / 60.0)
		seen[int(m.state.gear)] = true
		if m.shift_cut > 0.0: broke = true
		if int(m.state.gear) == 5 and float(m.state.v) > 5.0: break
	check(seen.size() >= 4 and seen.has(1) and seen.has(5), "in D the box goes through the gears by itself (%s)" % str(seen.keys()))
	check(not broke, "a shift of the box does not cut the pull")
	check(m.selector_gear() == 1, "the selector still shows D")
	# slowing down, the box goes back down
	m.state.throttle = 0.0
	m.state.brake = 1.0
	for i in range(60 * 30): m.physics_step(1.0 / 60.0)
	check(int(m.state.gear) <= 2, "after braking the box is in a low gear again (%d)" % int(m.state.gear))
	# the neutral and the reverse (after a stop)
	m.state.throttle = 0.0
	check(m.set_gear(0) and int(m.state.gear) == 0 and m.selector_gear() == 0, "N")
	check(m.set_gear(6) and int(m.state.gear) == 6 and m.selector_gear() == 6, "R after a stop")
	# the petrol: the same idle step burns 5% less
	var plain = fresh(false)
	var auto = fresh(true)
	var burnt: Array = []
	for car in [plain, auto]:
		car.start_engine(true)
		car.set_gear(1)
		car.state.throttle = 0.5
		var before = float(car.state.fleet_by_id.motorcar.fuel)
		car.state.v = 0.0
		car.state.brake = 1.0
		car.physics_step(1.0 / 60.0)
		burnt.append(before - float(car.state.fleet_by_id.motorcar.fuel))
	check(burnt[0] > 0.0 and absf(float(burnt[1]) / float(burnt[0]) - 0.95) < 0.001, "the petrol burns 5%% less (%.8f against %.8f)" % [burnt[1], burnt[0]])
	print("AUTO GEARBOX CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
