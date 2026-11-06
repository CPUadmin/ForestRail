extends Node
# Гаджет «Храповик» ручной дрезины: усилие рычага больше на четверть (потолок мощности руки прежний, поэтому выигрыш на разгоне и в подъёме, где упирается момент), +8 кг.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fresh(with_ratchet: bool):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "handcar")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	if with_ratchet: m.object_state("handcar").levels["handcar_ratchet"] = 1
	return m

# pumps the lever for the given seconds on a stretch without a grade and returns the way made
func pump(m, seconds: float, loaded_kg: float = 0.0) -> float:
	var best = 600.0
	var best_grade = 1.0
	for s in range(400, int(m.route.length_m) - 400, 10):
		var g = absf(float(m.route.sample(float(s) + 30.0).y) - float(m.route.sample(float(s)).y)) / 30.0
		if g < best_grade: best_grade = g; best = float(s)
	m.state.phase = "route"
	m.state.s = best
	m.state.v = 0.0
	m.state.brake = 0.0
	var start = float(m.state.s)
	m.hand_drive.grab(float(m.handcar.pose().angle))
	for i in range(int(seconds * 60.0)):
		var pose = m.handcar.pose()
		m.hand_drive.set_target(float(pose.angle) + signf(float(pose.dangle_dphase)) * 0.32)
		m.physics_step(1.0 / 60.0)
	m.hand_drive.release()
	return absf(float(m.state.s) - start)

func run() -> void:
	var m0 = fresh(false)
	var catalog: Array = []
	for branch in m0.data.upgrade_catalog: catalog.append(str(branch.id))
	check("handcar_ratchet" in catalog, "the gadget is in the catalog")
	for card in m0.data.casino.cards:
		if str(card.upgrade) == "handcar_ratchet": check(m0.casino().card_available(card), "the card %s can drop" % str(card.id))
	var stats0 = m0.object_stats("handcar")
	var m1 = fresh(true)
	var stats1 = m1.object_stats("handcar")
	check(is_equal_approx(float(stats1.mass), float(stats0.mass) + 8.0), "the ratchet weighs 8 kg")
	check(is_equal_approx(float(m1.effects("handcar").get("ratchet_torque", 1.0)), 1.25), "the effect is the torque x1.25")
	# it does not overwrite the lever upgrade
	m1.object_state("handcar").levels["handcar_lever"] = 2
	check(float(m1.effects("handcar").get("work_multiplier", 1.0)) > 1.0 and float(m1.effects("handcar").get("ratchet_torque", 1.0)) > 1.0, "with the lever upgrade both effects stay")
	var plain_way = pump(fresh(false), 8.0)
	var ratchet_way = pump(fresh(true), 8.0)
	print("RATCHET WAY ", plain_way, " ", ratchet_way)
	check(ratchet_way > plain_way * 1.03, "pumping for 8 s the ratchet car goes further (%.1f m against %.1f m)" % [ratchet_way, plain_way])
	print("RATCHET CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
