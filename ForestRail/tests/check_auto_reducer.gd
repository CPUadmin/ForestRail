extends Node
# Гаджет «Автоматический редуктор» пневмовоза: давление держится само по тяге (на холостом мало, на полной тяге много), колеса в кабине нет,
# воздуха уходит на 10% меньше, потолок давления ниже на 5%.
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
	Fixtures.equip(m, "pneumatic")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	if auto: m.object_state("pneumatic").levels["pneumatic_auto_reducer"] = 1
	m.state.phase = "route"
	m.state.brake = 0.0
	return m

func run() -> void:
	Model.legacy_tanks = false
	var m0 = fresh(false)
	var catalog: Array = []
	for branch in m0.data.upgrade_catalog: catalog.append(str(branch.id))
	check("pneumatic_auto_reducer" in catalog, "the gadget is in the catalog")
	for card in m0.data.casino.cards:
		if str(card.upgrade) == "pneumatic_auto_reducer": check(m0.casino().card_available(card), "the card %s can drop" % str(card.id))
	check(not m0.auto_reducer() and m0.set_reducer(0.5) and is_equal_approx(m0.reducer_position(), 0.5), "without the gadget the wheel works")
	var m = fresh(true)
	check(m.auto_reducer() and not m.set_reducer(0.2), "with the gadget the wheel does nothing")
	m.state.throttle = 0.0
	var idle = m.reducer_position()
	m.state.throttle = 1.0
	var full = m.reducer_position()
	check(is_equal_approx(idle, 0.3) and is_equal_approx(full, 1.0), "the pressure follows the throttle (%.2f at idle, %.2f at full)" % [idle, full])
	var tank = float(m.object_stats("pneumatic").tank)
	check(is_equal_approx(m.reducer_setting(), 0.57) and absf(m.working_pressure() - 0.57 * tank) < 0.001, "the ceiling is 5%% lower: 57%% of the tank (%.3f)" % m.reducer_setting())
	var manual = fresh(false)
	manual.set_reducer(1.0)
	check(is_equal_approx(manual.reducer_setting(), 0.6), "the manual wheel opens to 60%")
	# the air: the same work costs 10% less
	var ratios: Array = []
	for car in [manual, m]:
		car.state.s = 600.0
		car.state.throttle = 1.0
		car.state.gear = 1
		car.state.engine = true
		for i in range(120): car.physics_step(1.0 / 60.0)
		ratios.append(float(car.motor_energy.used_j) / maxf(1.0, float(car.motor_energy.shaft_work_j)))
	check(ratios[1] < ratios[0] * 0.95 and is_equal_approx(float(ratios[1]) / float(ratios[0]), 0.9), "10%% less air for the same work (%.3f against %.3f)" % [ratios[1], ratios[0]])
	print("AUTO REDUCER CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
