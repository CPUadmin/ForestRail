extends Node
# «Скрутка» электровоза, модель (1.4.10, переделка 1.12 по решениям владельца 19–20.11, docs/ELECTRIC_CABINET_MECHANIC_RU.md):
# от 3 проводов; петли: 1 — слабая, 3 — тугая; порвать рывком; рубильник: пуск (3% заряда), мягкий пуск без броска;
# неверная скрутка сжигает предохранитель, третья искра — мотор («габелла»); в пути перегрев и тряска жгут
# предохранители после предупреждения, −15% тяги за каждый; запасные и жучок; депо всё чинит; пять секреток.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/core/model.gd")
const Contactor = preload("res://scripts/vehicles/locomotive/contactor.gd")

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
	m.object_state("locomotive").levels = {}
	m.state.phase = "route"
	m.state.s = 400.0
	m.state.v = 0.0
	m.state.direction = 1
	m.state.reverser = 1
	m.state.brake = 0.0
	m.state.throttle = 0.0
	m.state.cargo = []
	m.contactor().stop()
	return m

# every wire to its own terminal, twisted `loops` times
func wire_all(m, loops: float = 3.0) -> void:
	var c = m.contactor()
	for i in range(c.count()):
		c.join(i, c.terminal_of(i))
		c.twist(i, loops)

func charge(m) -> float:
	return float(m.state.fleet_by_id.locomotive.fuel)

func run() -> void:
	var m = fresh()
	var c = m.contactor()
	var tank = float(m.object_stats("locomotive").tank)
	# --- wires: from three, more with the upgrades, five at most
	check(c.wires() == 3 and c.count() == 3, "a new electric locomotive has three wires (%d)" % c.count())
	m.object_state("locomotive").levels = {"locomotive_engine": 2, "locomotive_brakes": 1}
	c.stop()
	check(c.count() == 4, "upgrades add wires (%d)" % c.count())
	m.object_state("locomotive").levels = {"locomotive_engine": 9}
	c.stop()
	check(c.count() == 5, "never more than five (%d)" % c.count())
	m.object_state("locomotive").levels = {}
	c.stop()
	var plain = true
	for i in range(c.count()): if c.terminal_of(i) != i: plain = false
	check(not plain, "the wires are never in the plain order")
	# --- ready: all joined and twisted at least once; tight from three loops
	check(not c.ready() and not c.start(), "free wires: no start")
	for i in range(c.count()): c.join(i, c.terminal_of(i))
	check(not c.ready() and not c.start() and m.message.contains("Скрути"), "joined but not twisted: no start, it says so")
	for i in range(c.count()): c.twist(i, 1.0)
	check(c.ready() and not c.tight(0), "one loop is a weak twist: ready, not tight")
	var before = charge(m)
	check(c.start() and bool(m.state.engine) and m.message.contains("Слабых"), "a weak twist starts but warns")
	check(is_equal_approx(before - charge(m), tank * Contactor.START_CHARGE), "the start costs 3% of the charge")
	# --- weak twists shake loose on the move; twisted again, the pull is back
	m.state.v = 6.0
	for k in range(60 * 60 * 20):
		m.state.stats.seconds = float(m.state.stats.seconds) + 1.0 / 60.0
		c.step(1.0 / 60.0)
		if not c.live(): break
	check(not c.live() and m.message.contains("отскочил"), "a weak twist pops on the move and the pull is gone")
	for i in range(c.count()): c.twist(i, 3.0)
	check(c.live(), "twisted again, the pull is back")
	m.state.v = 0.0
	# --- stop: the wires are scrambled again
	c.stop()
	var free = true
	for i in range(c.count()): if c.joined(i): free = false
	check(not c.is_on() and not bool(m.state.engine) and free, "the switch down stops it and scrambles the wires")
	# --- tear: a yank frees the wire and leaves a scrap
	c.join(0, c.terminal_of(0))
	c.twist(0, 2.0)
	var scraps = c.scraps()
	check(c.tear(0) and not c.joined(0) and c.scraps() == scraps + 1, "a torn twist frees the wire and leaves a scrap")
	# --- wrong pairs: a fuse burns each time, the third spark burns the motor
	m = fresh()
	c = m.contactor()
	for i in range(c.count()):
		c.join(i, (c.terminal_of(i) + 1) % c.count())
		c.twist(i, 3.0)
	before = charge(m)
	check(not c.start() and c.fuse_count("burnt") == 1 and m.message.contains("осталось попыток: 2"), "a wrong twist sparks: a fuse burns, two tries left")
	check(is_equal_approx(before - charge(m), tank * Contactor.SPARK_CHARGE) and not c.joined(0), "the spark costs 5% and tears the wrong wires")
	for i in range(c.count()):
		c.join(i, (c.terminal_of(i) + 1) % c.count())
		c.twist(i, 3.0)
	c.start()
	check(c.fuse_count("burnt") == 2 and m.message.contains("осталось попыток: 1"), "the second spark: one try left")
	for i in range(c.count()):
		c.join(i, (c.terminal_of(i) + 1) % c.count())
		c.twist(i, 3.0)
	c.start()
	check(c.motor_burnt() and m.message.contains("Габелла") and m.wear().condition("locomotive", "motor") <= 0.0, "the third spark burns the motor: gabella")
	wire_all(m)
	check(not c.start() and m.message.contains("Мотор сгорел"), "a burnt motor does not start")
	m.rescue()
	check(not c.motor_burnt() and c.fuse_count("ok") == 3 and c.spares() == 3, "the help of the depot gives new fuses and mends the motor")
	# --- the factors: −15% pull and +10% drain for every burnt fuse; a bug counts as whole
	m = fresh()
	c = m.contactor()
	c.st().fuses = ["burnt", "ok", "ok"]
	check(is_equal_approx(c.power_factor(), 0.85) and is_equal_approx(c.drain_factor(), 1.1), "a burnt fuse: pull −15%, drain +10%")
	c.st().fuses = ["burnt", "burnt", "ok"]
	check(is_equal_approx(c.power_factor(), 0.7), "two burnt: −30%")
	# --- spares on a stop, not on the move
	m.state.v = 4.0
	check(not c.replace_fuse(0), "fuses are not changed on the move")
	m.state.v = 0.0
	var spares = c.spares()
	check(c.replace_fuse(0) and str(c.fuses()[0]) == "ok" and c.spares() == spares - 1, "a spare goes into the burnt holder")
	# --- the bug: a scrap wound round an empty holder; whole for the pull, no protection
	c.st().scraps = 1
	check(c.bug(1) and str(c.fuses()[1]) == "bug" and c.scraps() == 0, "a scrap makes a bug")
	check(is_equal_approx(c.power_factor(), 1.0), "the bug gives the full pull back")
	# --- heat on the move: a warning first, then a fuse burns
	m = fresh()
	c = m.contactor()
	wire_all(m)
	c.start()
	m.state.fleet_by_id.locomotive.temp = 0.9
	for k in range(60): c.step(1.0 / 60.0)
	check(c.warning() and c.fuse_count("ok") == 3, "an overheated motor: a warning first, the fuse is still whole")
	for k in range(120): c.step(1.0 / 60.0)
	check(c.fuse_count("burnt") == 1 and m.message.contains("перегрев"), "it stays hot: the fuse burns and saves the motor")
	for k in range(60 * 15): c.step(1.0 / 60.0)
	check(c.fuse_count("burnt") == 1 and not c.motor_burnt(), "a breather after the burnt fuse: still hot, nothing else burns for 15 s")
	c.st().fuses = ["burnt", "burnt", "bug"]
	for k in range(60 * 25): c.step(1.0 / 60.0)
	check(c.motor_burnt(), "with no whole fuse left the next burn takes the motor")
	# --- shake near the top speed: tight twists ride it out, a weak twist rattles a fuse to death
	m = fresh()
	c = m.contactor()
	wire_all(m)
	c.start()
	m.state.v = float(m.object_stats("locomotive").speeds[0]) * 0.97
	for k in range(60 * 300): c.step(1.0 / 60.0)
	check(c.fuse_count("ok") == 3 and c.live(), "five minutes at the top speed with tight twists: nothing burns")
	m = fresh()
	c = m.contactor()
	wire_all(m, 1.0)
	c.start()
	m.state.v = float(m.object_stats("locomotive").speeds[0]) * 0.97
	for k in range(60 * 20): c.step(1.0 / 60.0)
	check(c.fuse_count("burnt") >= 1 and m.message.contains("тряска"), "a weak twist at the top speed shakes a fuse to death")
	# --- secret: the golden twist (five loops in one motion) does not shake
	m = fresh()
	c = m.contactor()
	for i in range(c.count()):
		c.join(i, c.terminal_of(i))
		c.twist(i, 5.0, 5.0)
	check(c.golden_all(), "five loops in one motion: the golden twist")
	c.start()
	m.state.v = float(m.object_stats("locomotive").speeds[0]) * 0.97
	for k in range(60 * 20): c.step(1.0 / 60.0)
	check(c.fuse_count("ok") == 3, "golden twists are not shaken")
	# --- secret: the soft start costs nothing and keeps the first overheat
	m = fresh()
	c = m.contactor()
	wire_all(m)
	before = charge(m)
	check(c.start(true) and is_equal_approx(before, charge(m)), "the soft start costs no charge")
	m.state.fleet_by_id.locomotive.temp = 0.9
	for k in range(200): c.step(1.0 / 60.0)
	check(c.fuse_count("ok") == 3 and m.message.contains("выдержал"), "the soft start keeps the first overheat")
	# --- secret: the rainbow order (red, yellow, blue for three wires) gives +15% pull for +25% drain
	m = fresh()
	c = m.contactor()
	for i in [0, 2, 1]:   # red, yellow, blue
		c.join(i, c.terminal_of(i))
		c.twist(i, 3.0)
	check(c.rainbow_order(), "red, yellow, blue: the rainbow order")
	c.start()
	check(is_equal_approx(c.power_factor(), 1.15) and is_equal_approx(c.drain_factor(), 1.25), "the rainbow start: +15% pull, +25% drain")
	m = fresh()
	c = m.contactor()
	for i in [1, 0, 2]:
		c.join(i, c.terminal_of(i))
		c.twist(i, 3.0)
	c.start()
	check(not bool(c.st().rainbow) and is_equal_approx(c.power_factor(), 1.0), "another order: an ordinary start")
	# --- secret: the wink on a descent doubles the regeneration for 30 s
	m = fresh()
	c = m.contactor()
	var hill: Array = []
	for x in range(-40, 3001): hill.append([float(x), 200.0 - float(maxi(0, x)) * 0.04, float(x)])
	m.route.points = hill
	m.route.length_m = 3000.0
	wire_all(m)
	c.start()
	m.state.v = 0.2
	check(not c.wink(), "standing: the wink gives nothing")
	m.state.v = 6.0
	check(c.wink() and is_equal_approx(c.regen_factor(), 2.0), "on a descent the wink doubles the regeneration")
	for k in range(60 * 31): c.step(1.0 / 60.0)
	check(is_equal_approx(c.regen_factor(), 1.0), "after 30 s it is over")
	# --- the pull: only with the switch up
	m = fresh()
	c = m.contactor()
	m.state.throttle = 1.0
	for k in range(60): m.physics_step(1.0 / 60.0)
	var v_off = float(m.state.v)
	check(not bool(m.state.engine), "switch down: no power")
	m.state.v = 0.0
	m.state.s = 400.0
	wire_all(m)
	c.start()
	for k in range(60): m.physics_step(1.0 / 60.0)
	check(float(m.state.v) > v_off + 0.1 and bool(m.state.engine), "switch up: it pulls (%.2f against %.2f)" % [float(m.state.v), v_off])
	# --- saved and restored
	c.st().fuses = ["burnt", "bug", "ok"]
	var back = Model.new()
	check(back.restore(JSON.parse_string(JSON.stringify(m.serialize()))) and str(back.contactor().fuses()[1]) == "bug" and back.contactor().is_on(), "fuses and the switch are saved")
	Model.contactor_rules = false
	Model.wear_rules = false
	print("CONTACTOR CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
