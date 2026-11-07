extends Node
# Пассивные гаджеты (docs/GADGET_EFFECTS_PROPOSAL_RU.md): Маховик-накопитель (ручная: качение ×0,8, +25 кг), Запасной баллон (пневмовоз: запас воздуха +35%, +20 кг),
# Пого-шест (шестовая: ход под вкопанным шестом +35%, +5 кг). Гаджеты действуют своими ключами и не затирают обычные улучшения.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Pole = preload("res://scripts/pole.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fresh(kind: String):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, kind)
	return m

func run() -> void:
	Model.legacy_tanks = false
	var catalog: Array = []
	for branch in fresh("handcar").data.upgrade_catalog: catalog.append(str(branch.id))
	check("handcar_flywheel" in catalog and "pneumatic_spare_tank" in catalog and "pole_pogo" in catalog, "the three gadgets are in the catalog")
	for card in fresh("handcar").data.casino.cards:
		if str(card.upgrade) in ["handcar_flywheel", "pneumatic_spare_tank", "pole_pogo"]:
			check(fresh("handcar").casino().card_available(card), "the card %s can drop: its gadget exists" % str(card.id))

	# the flywheel: the rolling is lower by a fifth, the car is heavier by 25 kg, and the bearings still work
	var plain = fresh("handcar")
	var stats0 = plain.object_stats("handcar")
	var fly = fresh("handcar")
	fly.object_state("handcar").levels["handcar_flywheel"] = 1
	var stats1 = fly.object_stats("handcar")
	check(is_equal_approx(float(stats1.rolling), float(stats0.rolling) * 0.1) and is_equal_approx(float(stats1.mass), float(stats0.mass) + 25.0), "the flywheel: rolling x0.1 (%.5f), +25 kg (%.0f)" % [float(stats1.rolling), float(stats1.mass)])
	fly.object_state("handcar").levels["handcar_bearings"] = 2
	var both = fly.object_stats("handcar")
	var bearings_only = fresh("handcar")
	bearings_only.object_state("handcar").levels["handcar_bearings"] = 2
	check(float(both.rolling) < float(bearings_only.object_stats("handcar").rolling) * 0.5, "with the bearings both work: the gadget does not overwrite the upgrade (%.5f, %.5f)" % [float(both.rolling), float(bearings_only.object_stats("handcar").rolling)])
	# it rolls further after a push
	var coast_plain = coast(plain)
	var coast_fly = coast(fly_only())
	check(coast_fly > coast_plain * 1.17 and coast_fly < coast_plain * 1.3, "after a push the flywheel car rolls further (%.1f m against %.1f m)" % [coast_fly, coast_plain])

	# the spare cylinder
	var air = fresh("pneumatic")
	var tank0 = float(air.object_stats("pneumatic").tank)
	var mass0 = float(air.object_stats("pneumatic").mass)
	air.object_state("pneumatic").levels["pneumatic_spare_tank"] = 1
	var air1 = air.object_stats("pneumatic")
	check(is_equal_approx(float(air1.tank), tank0 * 1.35) and is_equal_approx(float(air1.mass), mass0 + 20.0), "the spare cylinder: air x1.35 (%.2f -> %.2f), +20 kg" % [tank0, float(air1.tank)])
	air.object_state("pneumatic").levels["pneumatic_tank"] = 2
	var tank_both = float(air.object_stats("pneumatic").tank)
	var tank_up = fresh("pneumatic")
	tank_up.object_state("pneumatic").levels["pneumatic_tank"] = 2
	check(tank_both > float(tank_up.object_stats("pneumatic").tank) * 1.3, "and it stacks with the ordinary tank upgrade")

	# the pogo pole: one stroke goes further before the tip is pulled out
	var pole_plain = fresh("pole")
	var pole_pogo = fresh("pole")
	pole_pogo.object_state("pole").levels["pole_pogo"] = 1
	for m in [pole_plain, pole_pogo]:
		m.state.phase = "route"
		m.state.s = 100.0
		m.state.brake = 0.0
		m.physics_step(1.0 / 60.0)
	check(is_equal_approx(pole_pogo.pole.length_scale, 1.35) and is_equal_approx(pole_plain.pole.length_scale, 1.0), "the pogo pole reaches the pole model")
	for p in [pole_plain.pole, pole_pogo.pole]:
		p.mode = "planted"
		p.tip_s = 104.5   # 4.5 m ahead of the platform: past the plain pole (4 m with the hands' height), inside the pogo
	pole_plain.pole.step(1.0 / 60.0, 100.0, 0.0, 1)
	pole_pogo.pole.step(1.0 / 60.0, 100.0, 0.0, 1)
	check(pole_plain.pole.mode == "free" and pole_pogo.pole.mode == "planted", "at 4.5 m the plain pole is pulled out, the pogo pole still holds")
	check(is_equal_approx(float(pole_pogo.object_stats("pole").mass) - float(pole_plain.object_stats("pole").mass), 5.0), "the pogo pole weighs 5 kg")

	print("PASSIVE GADGETS CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func fly_only():
	var m = fresh("handcar")
	m.object_state("handcar").levels["handcar_flywheel"] = 1
	return m

# the distance a car rolls after a push on a stretch without a grade
func coast(m) -> float:
	var best = 600.0
	var best_grade = 1.0
	for s in range(400, int(m.route.length_m) - 400, 10):
		var g = absf(float(m.route.sample(float(s) + 30.0).y) - float(m.route.sample(float(s)).y)) / 30.0
		if g < best_grade: best_grade = g; best = float(s)
	m.state.phase = "route"
	m.state.s = best
	m.state.v = 4.0
	m.state.brake = 0.0
	m.state.throttle = 0.0
	var start = float(m.state.s)
	for i in range(60 * 30): m.physics_step(1.0 / 60.0)
	return absf(float(m.state.s) - start)
