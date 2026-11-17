extends Node
# 1.4.10 «Скрутка»: запуск электровоза в ящике КОНТАКТОР (модель). Решения владельца 14.11:
# неверная пара — искра, заряд −5%, урон проводке, провода рвутся; провода разводятся при каждой остановке;
# ПУСК/СТОП одной кнопкой; проводов от 1 до 5 по прокачке.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Contactor = preload("res://scripts/contactor.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh(mode: String = "career"):
	Model.contactor_rules = true
	Model.wear_rules = true
	var m = Model.new()
	m.new_game(42, 2, mode)
	m.state.money = 1000000
	Fixtures.equip(m, "locomotive")
	m.state.phase = "route"
	m.state.s = 400.0
	m.state.v = 0.0
	m.state.direction = 1
	m.state.reverser = 1
	m.state.brake = 0.0
	m.state.throttle = 0.0
	m.state.cargo = []
	return m

# wire every wire to its own terminal and twist it fully
func wire_all(m) -> void:
	var c = m.contactor()
	for i in range(c.count()):
		c.join(i, c.terminal_of(i))
		c.twist(i, 2.0)

func run() -> void:
	var m = fresh()
	var c = m.contactor()
	# --- the number of wires grows with the upgrades
	m.object_state("locomotive").levels = {}
	c.stop()
	check(c.wires() == 1 and c.count() == 1, "a new electric locomotive has one wire (%d)" % c.count())
	m.object_state("locomotive").levels = {"locomotive_engine": 2, "locomotive_brakes": 1}
	c.stop()
	check(c.wires() == 4 and c.count() == 4, "three bought levels: four wires (%d)" % c.count())
	m.object_state("locomotive").levels = {"locomotive_engine": 9, "locomotive_brakes": 9}
	c.stop()
	check(c.wires() == 5 and c.count() == 5, "never more than five (%d)" % c.count())
	# --- the scheme: scrambled, never the plain order, a new one at every stop
	var first: Array = (c.st().to as Array).duplicate()
	var plain: Array = []
	for i in range(c.count()): plain.append(i)
	check(first != plain, "the wires are scrambled (%s)" % str(first))
	c.stop()
	check((c.st().to as Array) != first, "a stop scrambles them in a new order (%s, then %s)" % [str(first), str(c.st().to)])
	check(not c.all_joined() and not c.ready() and not c.is_on(), "after a stop every wire is free and it is off")
	# --- off: no pull at all
	m.state.throttle = 1.0
	for i in range(60): m.physics_step(1.0 / 60.0)
	check(not bool(m.state.engine) and float(m.state.v) < 0.05, "with the contactor off the locomotive does not pull forward (v %.2f, it may roll on the slope)" % float(m.state.v))
	m.state.throttle = 0.0
	# --- PUSK with wires missing: refused with a reason
	check(not c.press() and m.message.contains("Соедини все провода"), "ПУСК with free wires is refused: %s" % m.message)
	# --- the right scheme: on, it pulls
	wire_all(m)
	check(c.ready(), "every wire on its terminal and twisted: the lamp ГОТОВ")
	m.events.clear()
	check(c.press() and c.is_on() and m.events.has("contactor_on"), "ПУСК switches the contactor on")
	m.state.throttle = 1.0
	for i in range(120): m.physics_step(1.0 / 60.0)
	check(bool(m.state.engine) and float(m.state.v) > 0.5, "then it pulls (v %.2f)" % float(m.state.v))
	# --- STOP: the same button, the wires come apart in a new order
	var before_stop: Array = (c.st().to as Array).duplicate()
	m.events.clear()
	check(c.press() and not c.is_on() and m.events.has("contactor_off"), "the same button is СТОП")
	check(not c.all_joined() and (c.st().to as Array) != before_stop, "and the wires come apart in a new order")
	m.physics_step(1.0 / 60.0)
	check(not bool(m.state.engine), "stopped: no pull")
	# --- a wrong pair: spark, −5% charge, the controller is hurt, those wires are torn
	m.state.v = 0.0
	m.state.throttle = 0.0
	var tank = float(m.object_stats("locomotive").tank)
	m.state.fleet_by_id.locomotive.fuel = tank
	var ctrl_before = m.wear().condition("locomotive", "controller")
	for i in range(c.count()):
		c.join(i, c.terminal_of(i))
		c.twist(i, 2.0)
	var a = 0
	var b = 1
	c.join(a, c.terminal_of(b))   # wire a onto b's terminal: b comes off
	c.join(b, c.terminal_of(a))
	c.twist(a, 2.0)
	c.twist(b, 2.0)
	m.events.clear()
	check(not c.press() and not c.is_on(), "a wrong pair does not start")
	check(m.events.has("spark") and m.message.contains("Искра"), "it sparks: %s" % m.message)
	check(is_equal_approx(float(m.state.fleet_by_id.locomotive.fuel), tank * 0.95), "the battery drops 5%% (%.1f of %.1f)" % [float(m.state.fleet_by_id.locomotive.fuel), tank])
	check(m.wear().condition("locomotive", "controller") < ctrl_before - 0.02, "the controller is hurt (%.3f from %.3f)" % [m.wear().condition("locomotive", "controller"), ctrl_before])
	check(not c.joined(a) and not c.joined(b) and (c.st().torn as Array).has(a) and (c.st().torn as Array).has(b), "the wires of the wrong pair are torn")
	check(c.joined(2) and c.twisted(2), "the right ones stay as they were")
	c.join(a, c.terminal_of(a))
	c.join(b, c.terminal_of(b))
	check(not (c.st().torn as Array).has(a), "joined again, the torn mark goes")
	c.twist(a, 2.0)
	c.twist(b, 2.0)
	check(c.press() and c.is_on(), "joined right, it starts")
	c.press()
	# --- a loose twist can pop on the move: no pull until it is twisted again
	for i in range(c.count()):
		c.join(i, c.terminal_of(i))
		c.twist(i, 2.0 if i > 0 else 0.5)
	check(not c.ready() and c.press() and m.message.contains("Недокручено"), "it starts with a loose twist, but warns: %s" % m.message)
	m.state.throttle = 0.6
	var popped = false
	for i in range(60 * 600):   # up to ten minutes on the move
		m.physics_step(1.0 / 60.0)
		if not (c.st().popped as Array).is_empty():
			popped = true
			break
	check(popped and not c.live(), "a loose wire pops on the move and the pull is gone")
	m.physics_step(1.0 / 60.0)
	check(not bool(m.state.engine), "no pull while it hangs loose")
	c.twist(0, 2.0)
	check(c.live(), "twisted again, the pull is back")
	c.press()
	# --- an empty battery stops it, and the wires come apart
	wire_all(m)
	c.press()
	m.state.fleet_by_id.locomotive.fuel = 0.0
	m.physics_step(1.0 / 60.0)
	check(not c.is_on() and not c.all_joined(), "an empty battery switches it off and the wires come apart")
	check(not c.press() and m.message.contains("пуст"), "and ПУСК says the battery is empty")
	# --- every trip starts with the wires apart
	var trip = fresh()
	wire_all(trip)
	trip.contactor().press()
	trip.state.phase = "loading"
	trip.depart()
	check(not trip.contactor().is_on() and not trip.contactor().all_joined(), "a new trip starts with the contactor off and the wires apart")
	# --- the creative mode: the twist is ready, only ПУСК
	var cr = fresh("creative")
	cr.contactor().stop()
	check(cr.contactor().ready(), "in the creative mode the scheme comes ready")
	check(cr.contactor().press() and cr.contactor().is_on(), "and ПУСК starts at once")
	# --- the save keeps it, and a JSON round trip (floats) still works
	var sv = fresh()
	wire_all(sv)
	sv.contactor().press()
	var back = Model.new()
	check(back.restore(JSON.parse_string(JSON.stringify(sv.serialize()))), "the save with the contactor is valid")
	check(back.contactor().is_on() and back.contactor().ready(), "the save keeps the contactor on with its twist")
	check(typeof(back.contactor().st().to[0]) == TYPE_INT, "the wire numbers come back whole")
	back.contactor().press()
	check(not back.contactor().is_on() and not back.contactor().all_joined(), "and the loaded one stops and scrambles as usual")
	# --- the rule is off in the old tests: the locomotive pulls as before
	Model.contactor_rules = false
	var old = Model.new()
	old.new_game(42, 2)
	old.state.money = 1000000
	Fixtures.equip(old, "locomotive")
	old.state.phase = "route"
	old.state.s = 400.0
	old.state.v = 0.0
	old.state.direction = 1
	old.state.reverser = 1
	old.state.brake = 0.0
	old.state.throttle = 1.0
	for i in range(60): old.physics_step(1.0 / 60.0)
	check(bool(old.state.engine) and float(old.state.v) > 0.1, "without the rule it pulls as before (old tests)")
	Model.wear_rules = false
	print("CONTACTOR CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
