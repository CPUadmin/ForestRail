extends Node
# В6.6б (заготовка): ходовая модель реактивного (ракетного) поезда (scripts/jet.gd) по docs/JET_PROPOSAL_RU.md и решениям владельца 06.11.2026:
# запуск как у ракеты (крышка, четыре предохранителя с тайными кодами, обратный отсчёт, зажигание), мощность регулируется, потолок 200 км/ч,
# тянет тяжёлый состав, парашют одноразовый, гаджет даёт второй (один или оба сразу), форсаж гаджета, пустой бак. В игре машины ещё нет.
const Jet = preload("res://scripts/jet.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func run_steps(j, seconds: float, slope: float = 0.0, wind: float = 0.0) -> void:
	for i in range(int(seconds * 60.0)): j.step(1.0 / 60.0, slope, wind)

# the toggles are switched on in the given order (digits 1 to 4, from left to right): the order is the code of the start
func set_fuses(j, code: String) -> void:
	for ch in code:
		j.flip_fuse(int(ch) - 1)

# the secret blink: a toggle is switched on and at once off again; then the rest are switched on in the given order (digits)
func blink_then(j, blink: int, rest: String) -> void:
	j.flip_fuse(blink - 1)
	j.flip_fuse(blink - 1)
	for ch in rest:
		j.flip_fuse(int(ch) - 1)

# a lit engine (the given order of the toggles, the whole countdown)
func lit_jet(code: String = "1234"):
	var j = Jet.new()
	set_fuses(j, code)
	j.open_cover(true)
	j.start()
	run_steps(j, 16.0)
	return j

func run() -> void:
	# the start: the cover first, then the countdown, then the ignition, then the lever works
	var j = Jet.new()
	check(not j.start() and not j.counting, "the start does nothing under the closed cap")
	j.open_cover(true)
	check(not j.start() and not j.start_unlocked(), "under the open cap the start is still locked until all four toggles are on")
	j.flip_fuse(0)
	j.flip_fuse(1)
	j.flip_fuse(2)
	check(not j.start() and j.fuses_on() == 3, "three toggles of four are not enough")
	j.flip_fuse(2)
	check(j.fuses_on() == 2 and j.fuse_code() == "12", "a toggle switched off leaves the order (%s)" % j.fuse_code())
	j.flip_fuse(2)
	j.flip_fuse(3)
	check(j.start_unlocked() and j.fuse_code() == "1234", "all four on, the order is the code (%s): the start opens" % j.fuse_code())
	check(j.start() and j.counting and absf(j.countdown - 10.0) < 0.01, "under the open cap the start begins a ten second countdown")
	j.set_throttle(1.0)
	run_steps(j, 9.0)
	check(j.counting and j.thrust == 0.0 and not j.started, "during the countdown there is no thrust, even with the lever up")
	run_steps(j, 1.5)
	check(j.started and not j.counting, "after the countdown the engine is lit")
	run_steps(j, 0.5)
	check(j.thrust > 0.0 and j.thrust < 4000.0, "the thrust grows after the ignition, not at once (%.0f N)" % j.thrust)
	run_steps(j, 6.0)
	check(is_equal_approx(j.thrust, 12000.0), "and reaches the full 12000 N")
	j.set_throttle(0.5)
	run_steps(j, 4.0)
	check(is_equal_approx(j.thrust, 6000.0), "the power can be set: half a lever is half the thrust")
	# a toggle switched off during the countdown cancels it
	var abort = Jet.new()
	set_fuses(abort, "1234")
	abort.open_cover(true)
	abort.start()
	run_steps(abort, 4.0)
	abort.flip_fuse(2)
	check(not abort.counting and abort.countdown == 0.0, "touching a toggle during the countdown cancels it")
	check(abort.fuse_code() == "124", "and the toggle is off (%s)" % abort.fuse_code())
	# the official modes: the order of the toggles at the start chooses one of three
	var plain = lit_jet("1234")
	var eco = lit_jet("4321")
	var quick = Jet.new()
	set_fuses(quick, "1324")
	quick.open_cover(true)
	quick.start()
	check(plain.mode.name == "Обычный" and eco.mode.name == "Экономный" and quick.mode.name == "Быстрый старт", "the order of the toggles at the start chooses the official mode")
	for engine in [plain, eco]: engine.set_throttle(1.0)
	run_steps(plain, 8.0)
	run_steps(eco, 8.0)
	check(eco.thrust < plain.thrust * 0.9 and eco.fuel_rate() < plain.fuel_rate() * 0.7, "the economy mode pulls less and burns much less (%.0f against %.0f N)" % [eco.thrust, plain.thrust])
	check(absf(quick.countdown - 5.0) < 0.01, "the quick start makes the countdown five seconds")
	# the secret: a blink first, then the start opens with three toggles, and the toggle left off chooses a secret mode
	var plain_three = Jet.new()
	plain_three.open_cover(true)
	set_fuses(plain_three, "123")
	check(not plain_three.start_unlocked() and not plain_three.start(), "three toggles without the secret do not open the start")
	var tractive = Jet.new()
	tractive.open_cover(true)
	blink_then(tractive, 2, "234")
	check(tractive.start_unlocked() and tractive.fuses_on() == 3 and tractive.start(), "after the secret blink the start opens with three toggles")
	check(tractive.mode.name == "Тяговый" and tractive.mode.thrust > 1.1, "with the first toggle left off it is the tractive secret mode")
	var all_in = Jet.new()
	all_in.open_cover(true)
	blink_then(all_in, 1, "123")
	all_in.start()
	check(all_in.mode.name == "Всё включено" and absf(all_in.countdown - 15.0) < 0.01, "with the last toggle left off it is the all-in secret mode")
	for i in range(60 * 16): all_in.step(1.0 / 60.0)
	check(all_in.started and all_in.afterburner_charges == 3, "and it gives an extra afterburner charge")
	var other_off = Jet.new()
	other_off.open_cover(true)
	blink_then(other_off, 1, "134")
	other_off.start()
	check(other_off.start_unlocked() == false or other_off.mode.name == "Обычный", "a blink with another toggle left off is the plain mode")
	var late_blink = Jet.new()
	late_blink.open_cover(true)
	late_blink.flip_fuse(0)
	late_blink.flip_fuse(1)
	late_blink.flip_fuse(1)
	late_blink.flip_fuse(2)
	check(not late_blink.start_unlocked(), "a blink that is not the first thing done is no secret")
	# all four on after a blink: the order still chooses the official mode
	var blink_four = Jet.new()
	blink_four.open_cover(true)
	blink_four.flip_fuse(0)
	blink_four.flip_fuse(0)
	set_fuses(blink_four, "4321")
	blink_four.start()
	check(blink_four.mode.name == "Экономный", "a blink and then all four on in the economy order is the economy mode")
	# the rules are in the data file: they can be changed, added and deleted without code
	var rules = Jet.load_modes("res://data/jet_modes.json")
	check(Jet.validate_modes(rules).is_empty(), "the data file of the modes is valid (%s)" % str(Jet.validate_modes(rules)))
	var broken = {"plain": {"name": "x"}, "modes": [{"id": "a", "name": "A", "when": {"order": "1123"}}, {"id": "a", "name": "B", "when": {"off": [9]}}, {"id": "c", "name": "C", "when": {}}]}
	check(Jet.validate_modes(broken).size() >= 4, "mistakes in a file are found (%d problems)" % Jet.validate_modes(broken).size())
	var custom_path = "user://jet_modes_test.json"
	var file = FileAccess.open(custom_path, FileAccess.WRITE)
	file.store_string('{"blink_unlocks_on": 3, "plain": {"name": "Обычный", "thrust": 1.0, "fuel": 1.0, "countdown": 10.0}, "modes": [{"id": "ox", "name": "Бык", "when": {"order": "2413"}, "thrust": 2.0, "countdown": 3.0}]}')
	file.close()
	var edited = Jet.new({"modes_path": custom_path})
	set_fuses(edited, "2413")
	edited.open_cover(true)
	edited.start()
	check(edited.mode.name == "Бык" and absf(edited.countdown - 3.0) < 0.01 and edited.mode.fuel == 1.0, "a new rule in the file works at once, the numbers it does not give are the plain ones")
	var removed = Jet.new({"modes_path": custom_path})
	set_fuses(removed, "4321")
	removed.open_cover(true)
	removed.start()
	check(removed.mode.name == "Обычный", "a rule deleted from the file is gone: that order is plain now")
	var missing = Jet.new({"modes_path": "res://data/no_such_file.json"})
	set_fuses(missing, "4321")
	missing.open_cover(true)
	check(missing.start() and missing.mode.name == "Обычный", "a missing file leaves the plain mode and the game works")
	var odd = Jet.new()
	set_fuses(odd, "1243")
	odd.open_cover(true)
	odd.start()
	check(odd.mode.name == "Обычный", "an order with no secret is the plain mode")
	var re_order = Jet.new()
	set_fuses(re_order, "1234")
	re_order.flip_fuse(0)
	re_order.flip_fuse(0)
	check(re_order.fuse_code() == "2341", "switching a toggle off and on again puts it last in the order (%s)" % re_order.fuse_code())
	# the speed of 100 km/h and the top speed of 200 km/h
	var run = lit_jet()
	run.set_throttle(1.0)
	var t100 = -1.0
	for i in range(60 * 150):
		run.step(1.0 / 60.0)
		if t100 < 0.0 and run.v * 3.6 >= 100.0: t100 = float(i) / 60.0
	check(t100 > 2.0 and t100 < 8.0, "0 to 100 km/h in a few seconds (%.1f s)" % t100)
	check(absf(run.v * 3.6 - 200.0) < 6.0, "the top speed is about 200 km/h (%.1f)" % (run.v * 3.6))
	# the heavy train: the strongest machine tows a lot
	var loaded = lit_jet()
	loaded.set_train(4, 800.0)
	loaded.set_throttle(1.0)
	var t60 = -1.0
	for i in range(60 * 200):
		loaded.step(1.0 / 60.0)
		if t60 < 0.0 and loaded.v * 3.6 >= 60.0: t60 = float(i) / 60.0
	check(t60 > 0.0 and t60 < 20.0, "with four loaded wagons it still reaches 60 km/h in good time (%.1f s)" % t60)
	check(loaded.v * 3.6 > 140.0 and loaded.v * 3.6 < 190.0, "and runs at about 170 km/h with them (%.0f)" % (loaded.v * 3.6))
	check(loaded.total_mass() > 4000.0, "the train weighs four tonnes and more (%.0f kg)" % loaded.total_mass())
	loaded.set_train(9)
	check(loaded.wagons == 4, "no more than four wagons")
	# the fuel: the record run A to F, 6.8 km at full thrust, and the tank holds the run there and back
	var fuel_run = lit_jet()
	fuel_run.set_throttle(1.0)
	var distance = 0.0
	var before = fuel_run.fuel
	while distance < 6800.0:
		fuel_run.step(1.0 / 60.0)
		distance += fuel_run.v / 60.0
	var burnt = before - fuel_run.fuel
	check(burnt > 150.0 and burnt < 320.0, "A to F burns about 230 litres (%.0f)" % burnt)
	check(fuel_run.fuel > 250.0, "the full tank is enough for the run there and back")
	# one chute: opens over a second, one per trip, brakes a lot, cut away at the stop
	var chute_run = lit_jet()
	chute_run.set_throttle(1.0)
	run_steps(chute_run, 90.0)
	chute_run.set_throttle(0.0)
	check(chute_run.pull_chute() and chute_run.chutes_left == 0, "the ring pulls the chute, one per trip")
	check(not chute_run.pull_chute(), "a second chute is not there")
	var cut = false
	for i in range(60 * 400):
		chute_run.step(1.0 / 60.0)
		if chute_run.events.has("chute_cut"): cut = true
	check(cut and chute_run.chutes_open == 0 and chute_run.chute == 0.0, "after the stop the chute is cut away and gone")
	check(chute_run.v < 1.0, "the train has stopped on the chute (%.2f m/s)" % chute_run.v)
	chute_run.new_trip()
	check(chute_run.chutes_left == 1, "the depot packs a new chute")
	# two chutes (the gadget): one out, or both at once, and both brake faster
	var pair = Jet.new()
	pair.double_chute_gadget = true
	pair.reset()
	check(pair.chutes_left == 2, "with the gadget there are two chutes in the pack")
	var one = lit_jet()
	one.double_chute_gadget = true
	one.chutes_left = 2
	one.set_throttle(1.0)
	run_steps(one, 90.0)
	one.set_throttle(0.0)
	check(one.pull_chute(1) and one.chutes_left == 1 and one.chutes_open == 1, "one chute out, one stays in the pack")
	var both = lit_jet()
	both.double_chute_gadget = true
	both.chutes_left = 2
	both.set_throttle(1.0)
	run_steps(both, 90.0)
	both.set_throttle(0.0)
	check(both.pull_chute(2) and both.chutes_left == 0 and both.chutes_open == 2, "or both at once")
	var d_one = 0.0
	var d_both = 0.0
	for i in range(60 * 120):
		one.step(1.0 / 60.0)
		both.step(1.0 / 60.0)
		if one.v > 5.0: d_one += one.v / 60.0
		if both.v > 5.0: d_both += both.v / 60.0
	check(d_both < d_one * 0.8, "two chutes stop it sooner (%.0f m against %.0f m)" % [d_both, d_one])
	# the afterburner: only with the gadget, x4 thrust for 3 s, x5 petrol, two charges
	var burn = lit_jet()
	burn.set_throttle(1.0)
	run_steps(burn, 6.0)
	check(not burn.fire_afterburner(), "no afterburner without the gadget")
	burn.afterburner_gadget = true
	var plain_rate = burn.fuel_rate()
	check(burn.fire_afterburner() and burn.afterburner_charges == 1, "with the gadget the afterburner fires")
	run_steps(burn, 1.0)
	check(burn.thrust > 20000.0 and burn.fuel_rate() > plain_rate * 1.2, "the thrust jumps and the petrol goes faster (%.0f N)" % burn.thrust)
	run_steps(burn, 3.0)
	check(burn.afterburner_time == 0.0, "after three seconds it is over")
	# an empty tank: no thrust
	var dry = lit_jet()
	dry.fuel = 0.0
	dry.set_throttle(1.0)
	run_steps(dry, 5.0)
	check(dry.thrust == 0.0 and dry.v == 0.0, "an empty tank gives no thrust")
	# the heat: a long full thrust held in place overheats the engine and shuts it down
	var hot = lit_jet()
	hot.set_throttle(1.0)
	var overheated = false
	for i in range(60 * 240):
		hot.v = 0.0   # held at the buffer stop
		hot.step(1.0 / 60.0)
		if hot.events.has("overheat"): overheated = true
	check(overheated and not hot.started, "a long full thrust held in place overheats the engine and shuts it down")
	var cool = lit_jet()
	cool.set_throttle(1.0)
	run_steps(cool, 120.0)
	check(cool.started and cool.temp < 0.8, "at speed the air cools it (%.2f)" % cool.temp)
	print("JET CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
