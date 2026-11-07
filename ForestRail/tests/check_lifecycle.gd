extends Node
# Жизненный цикл каждой машины в карьере и в творческом режиме: двигатель можно запустить и потушить, расходники не кончаются без возврата.
# Появилась после находок владельца 07.11.2026 (реактивный нельзя было потушить, в творческом не пополнялись парашюты): тесты были зелёными, а игра нет.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var failures: Array = []
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fresh(kind: String, mode: String):
	var m = Model.new()
	m.new_game(42, 2, mode)
	m.state.money = 500000
	m.state.chapter = 9
	Fixtures.equip(m, kind)
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	for p in m.route.points: p[1] = 0.0
	m.state.phase = "route"
	m.state.s = 400.0
	m.state.v = 0.0
	m.state.brake = 1.0
	m.state.throttle = 0.0
	m.state.gear = 0
	return m

func run_seconds(m, seconds: float) -> void:
	for i in range(int(seconds * 60.0)): m.physics_step(1.0 / 60.0)

func run() -> void:
	for mode in ["career", "creative"]:
		# the engines that have a switch: it goes on and it goes off
		for kind in ["motorcar", "pneumatic", "zeppelin"]:
			var m = fresh(kind, mode)
			var label = "%s/%s" % [kind, mode]
			if kind == "pneumatic": continue   # the pneumatic train has no engine switch (a valve and a heater instead)
			var turned_on = m.start_engine(true)
			check(turned_on and bool(m.state.engine), "%s: the engine starts (%s)" % [label, m.message])
			run_seconds(m, 1.0)
			var turned_off = m.start_engine(false)
			check(turned_off and not bool(m.state.engine), "%s: the engine can be put out" % label)
		# the steam engine: the fire is lit and doused
		var steam = fresh("steam", mode)
		steam.start_engine(true)
		run_seconds(steam, 1.0)
		check(steam.start_engine(false) and not bool(steam.state.engine), "steam/%s: the fire can be doused" % mode)
		# the rocket train: lit by the toggles, put out by the stop
		var jet = fresh("jet", mode)
		jet.set_jet_cover(true)
		for i in range(4):
			if not jet.jet.fuses[i]: jet.flip_jet_fuse(i)
		jet.jet_start()
		run_seconds(jet, 10.6)
		check(jet.jet.started, "jet/%s: lit" % mode)
		check(jet.start_engine(false) and not jet.jet.started, "jet/%s: put out" % mode)
		# the chutes: used up on one run, packed again for the next (a new trip in the career, by themselves in the creative mode)
		var chutes = fresh("jet", mode)
		chutes.jet.chutes_left = 0
		if mode == "career":
			chutes.jet.new_trip()
		else:
			run_seconds(chutes, 0.2)
		check(chutes.jet.chutes_left >= 1, "jet/%s: the chutes come back" % mode)
	print("LIFECYCLE CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
