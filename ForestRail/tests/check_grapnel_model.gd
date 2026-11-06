extends Node
# Кошка с лебёдкой в модели шестовой (model.throw_grapnel, grapnel_step): без гаджета бросить нельзя, с гаджетом лебёдка тянет дрезину к опоре по физике,
# масса гаджета в массе, новый рейс прячет крюк в скобу.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fresh(with_gadget: bool):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "pole")
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	if with_gadget: m.object_state("pole").levels["pole_grapnel"] = 1
	# a stretch of the line without a grade, the pole truck stands there
	for p in m.route.points: p[1] = 0.0
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.v = 0.0
	m.state.brake = 0.0
	return m

func run() -> void:
	var m0 = fresh(false)
	var catalog: Array = []
	for branch in m0.data.upgrade_catalog: catalog.append(str(branch.id))
	check("pole_grapnel" in catalog, "the gadget is in the catalog")
	for card in m0.data.casino.cards:
		if str(card.upgrade) == "pole_grapnel": check(m0.casino().card_available(card), "the card %s can drop" % str(card.id))
	check(not m0.grapnel_installed() and not m0.throw_grapnel() and "Повешенного" in m0.message, "without the gadget there is no grapnel (%s)" % m0.message)

	var m = fresh(true)
	check(m.grapnel_installed(), "with the card the grapnel is on the truck")
	var weight_plain = float(m0.object_stats("pole").mass)
	check(is_equal_approx(float(m.object_stats("pole").mass), weight_plain + 12.0), "the winch weighs 12 kg")
	m.physics_step(1.0 / 60.0)   # builds the anchors
	m.grapnel.anchors = [{"s": 610.0, "type": "post"}]
	check(m.throw_grapnel() and m.grapnel.mode == "flying", "the hook flies")
	check(not m.throw_grapnel(), "and cannot be thrown twice")
	var start = float(m.state.s)
	var hooked = false
	var reached = false
	for i in range(60 * 20):
		m.physics_step(1.0 / 60.0)
		if m.grapnel.mode == "hooked": hooked = true
		if "grapnel_reached" in m.events:
			reached = true
			m.state.brake = 1.0   # the driver brakes at the post
		m.events.clear()
	check(hooked and reached, "the hook caught and the truck reached the post")
	check(float(m.state.s) > 607.0 and float(m.state.s) < 614.0, "the winch pulled the truck up to the post (%.1f)" % float(m.state.s))
	# the same without a winch: the truck stands (the pole is not planted)
	var idle = fresh(false)
	for i in range(60 * 5): idle.physics_step(1.0 / 60.0)
	check(absf(float(idle.state.s) - 600.0) < 0.5, "without the winch the loose truck stands")
	# a weak anchor tears out under the winch (a bush is a thin target: try the throws until one catches)
	var weak = null
	for attempt in range(40):
		weak = fresh(true)
		weak.physics_step(1.0 / 60.0)
		weak.grapnel.anchors = [{"s": 610.0, "type": "bush"}]
		weak.grapnel.throws = attempt
		weak.throw_grapnel()
		if weak.grapnel.catch_t >= 0.0: break
	check(weak.grapnel.catch_t >= 0.0, "some throw catches the bush")
	var torn = false
	for i in range(60 * 10):
		weak.physics_step(1.0 / 60.0)
		if "grapnel_tear" in weak.events: torn = true
		weak.events.clear()
	check(torn, "a bush is torn out by the winch")
	# release by hand: the hook comes off
	var hand = fresh(true)
	hand.physics_step(1.0 / 60.0)
	hand.grapnel.anchors = [{"s": 612.0, "type": "tree"}]
	hand.throw_grapnel()
	for i in range(90): hand.physics_step(1.0 / 60.0)
	check(hand.grapnel.mode == "hooked", "the hook is on the tree")
	hand.release_grapnel()
	check(hand.grapnel.mode == "dropped", "let go by hand")
	# a new trip: the hook is back in the clip
	hand.grapnel.mode = "hooked"
	hand.depart()
	check(hand.grapnel.mode == "stowed", "a new trip puts the hook into the clip")
	print("GRAPNEL MODEL CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
