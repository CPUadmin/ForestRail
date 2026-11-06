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

func set_fuses(j, code: String) -> void:
	for i in range(code.length()):
		if (code[i] == "1") != j.fuses[i]: j.flip_fuse(i)

# a lit engine (the given position of the fuses, the whole countdown)
func lit_jet(code: String = "0000"):
	var j = Jet.new()
	set_fuses(j, code)
	j.open_cover(true)
	j.start()
	run_steps(j, 16.0)
	return j

func run() -> void:
	# the start: the cover first, then the countdown, then the ignition, then the lever works
	var j = Jet.new()
	check(not j.start() and not j.counting, "the start does nothing under the closed cover")
	j.open_cover(true)
	check(j.start() and j.counting and absf(j.countdown - 10.0) < 0.01, "under the open cover the start begins a ten second countdown")
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
	# the fuses: a flip during the countdown cancels it
	var abort = Jet.new()
	abort.open_cover(true)
	abort.start()
	run_steps(abort, 4.0)
	abort.flip_fuse(2)
	check(not abort.counting and abort.countdown == 0.0, "flipping a fuse during the countdown cancels it")
	check(abort.fuse_code() == "0010", "the code of the fuses is read from left to right (%s)" % abort.fuse_code())
	# the secret codes
	var plain = lit_jet("0000")
	var eco = lit_jet("1010")
	var heavy = lit_jet("0101")
	check(plain.mode.name == "Обычный" and eco.mode.name == "Экономный" and heavy.mode.name == "Тяжёлый", "the position of the fuses at the start chooses the mode")
	for engine in [plain, eco, heavy]: engine.set_throttle(1.0)
	run_steps(plain, 8.0)
	run_steps(eco, 8.0)
	run_steps(heavy, 8.0)
	check(eco.thrust < plain.thrust * 0.9 and heavy.thrust > plain.thrust * 1.1, "the economy mode pulls less, the heavy one more (%.0f, %.0f, %.0f N)" % [eco.thrust, plain.thrust, heavy.thrust])
	check(eco.fuel_rate() < plain.fuel_rate() * 0.7 and heavy.fuel_rate() > plain.fuel_rate() * 1.4, "and burn less and more (%.2f, %.2f, %.2f l/s)" % [eco.fuel_rate(), plain.fuel_rate(), heavy.fuel_rate()])
	var quick = Jet.new()
	set_fuses(quick, "1100")
	quick.open_cover(true)
	quick.start()
	check(absf(quick.countdown - 5.0) < 0.01, "one code makes the countdown five seconds")
	var all_in = lit_jet("1111")
	check(all_in.afterburner_charges == 3, "one code gives an extra afterburner charge")
	var bad = Jet.new()
	set_fuses(bad, "1001")
	bad.open_cover(true)
	bad.start()
	run_steps(bad, 7.0)
	check(not bad.started and not bad.counting, "one code is a misfire: the engine does not light")
	check(bad.start(), "after a misfire the start can be tried again")
	var odd = Jet.new()
	set_fuses(odd, "0011")
	odd.open_cover(true)
	odd.start()
	check(odd.mode.name == "Обычный", "a position with no secret is the plain mode")
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
	loaded.set_train(3, 800.0)
	loaded.set_throttle(1.0)
	var t60 = -1.0
	for i in range(60 * 200):
		loaded.step(1.0 / 60.0)
		if t60 < 0.0 and loaded.v * 3.6 >= 60.0: t60 = float(i) / 60.0
	check(t60 > 0.0 and t60 < 20.0, "with three loaded wagons it still reaches 60 km/h in good time (%.1f s)" % t60)
	check(loaded.v * 3.6 > 150.0 and loaded.v * 3.6 < 190.0, "and runs at about 170 km/h with them (%.0f)" % (loaded.v * 3.6))
	check(loaded.total_mass() > 4000.0, "the train weighs four tonnes and more (%.0f kg)" % loaded.total_mass())
	loaded.set_train(9)
	check(loaded.wagons == 3, "no more than three wagons (all the wagons of the line)")
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
