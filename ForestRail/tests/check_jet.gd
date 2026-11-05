extends Node
# В6.6б (заготовка): ходовая модель реактивного поезда (scripts/jet.gd) по предложению docs/JET_PROPOSAL_RU.md: потолок 200 км/ч, разгон,
# тяга нарастает не сразу, пуск под крышкой, расход керосина, парашют (один за рейс), форсаж гаджета, пустой бак. В игре машины ещё нет.
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

func started_jet():
	var j = Jet.new()
	j.open_cover(true)
	j.start()
	run_steps(j, 3.2)
	return j

func run() -> void:
	# the start: only under the open cover
	var j = Jet.new()
	check(not j.start() and not j.started, "the start does nothing under the closed cover")
	j.open_cover(true)
	check(j.start() and j.started, "under the open cover the start works")
	j.set_throttle(1.0)
	run_steps(j, 1.0)
	check(j.thrust == 0.0, "the turbine spools up for three seconds: no thrust yet")
	run_steps(j, 2.5)
	check(j.thrust > 0.0, "after the spool-up the thrust comes")
	# the thrust grows, it is not instant
	var slow = started_jet()
	slow.set_throttle(1.0)
	run_steps(slow, 0.5)
	check(slow.thrust > 500.0 and slow.thrust < 1700.0, "half a second after the lever: the thrust is still low (%.0f N)" % slow.thrust)
	run_steps(slow, 4.0)
	check(is_equal_approx(slow.thrust, 9000.0), "and it reaches 9000 N")
	# the speed of 100 km/h and the top speed of 200 km/h
	var run = started_jet()
	run.set_throttle(1.0)
	var t100 = -1.0
	for i in range(60 * 150):
		run.step(1.0 / 60.0)
		if t100 < 0.0 and run.v * 3.6 >= 100.0: t100 = float(i) / 60.0
	check(t100 > 3.0 and t100 < 9.0, "0 to 100 km/h in a few seconds (%.1f s)" % t100)
	check(absf(run.v * 3.6 - 200.0) < 6.0, "the top speed is about 200 km/h (%.1f)" % (run.v * 3.6))
	# the fuel: the record run A to F, 6.8 km at full thrust
	var fuel_run = started_jet()
	fuel_run.set_throttle(1.0)
	var distance = 0.0
	var before = fuel_run.fuel
	while distance < 6800.0:
		fuel_run.step(1.0 / 60.0)
		distance += fuel_run.v / 60.0
	var burnt = before - fuel_run.fuel
	check(burnt > 120.0 and burnt < 260.0, "A to F burns about 190 litres (%.0f)" % burnt)
	check(fuel_run.fuel > 150.0, "the full tank is enough for the run there and back")
	# the chute: opens over a second, brakes a lot, one per trip
	var chute_run = started_jet()
	chute_run.set_throttle(1.0)
	run_steps(chute_run, 90.0)
	chute_run.set_throttle(0.0)
	var start_speed = chute_run.v
	check(chute_run.pull_chute() and chute_run.chutes_left == 0, "the ring pulls the chute, one per trip")
	check(not chute_run.pull_chute(), "a second chute is not there")
	var stopped_at = 0.0
	var travelled = 0.0
	for i in range(60 * 120):
		chute_run.step(1.0 / 60.0)
		travelled += chute_run.v / 60.0
		if chute_run.v < 5.0: break
	check(chute_run.chute > 0.99 and travelled < 600.0, "the chute brings it from 200 to 18 km/h in under 600 m (%.0f m)" % travelled)
	var with_pads = started_jet()
	with_pads.set_throttle(1.0)
	run_steps(with_pads, 90.0)
	with_pads.set_throttle(0.0)
	with_pads.pull_chute()
	with_pads.set_pad_brake(1.0)
	var travelled_pads = 0.0
	for i in range(60 * 120):
		with_pads.step(1.0 / 60.0)
		travelled_pads += with_pads.v / 60.0
		if with_pads.v < 5.0: break
	check(travelled_pads < travelled * 0.9 and travelled_pads < 400.0, "chute and pads together stop it sooner (%.0f m)" % travelled_pads)
	var coast = started_jet()
	coast.set_throttle(1.0)
	run_steps(coast, 90.0)
	coast.set_throttle(0.0)
	var travelled_coast = 0.0
	for i in range(60 * 120):
		coast.step(1.0 / 60.0)
		travelled_coast += coast.v / 60.0
		if coast.v < 5.0: break
	check(travelled_coast > travelled * 1.8, "without the chute it rolls on much farther (%.0f m against %.0f m with the chute)" % [travelled_coast, travelled])
	# the afterburner: only with the gadget, x4 thrust for 3 s, x5 petrol, two charges
	var burn = started_jet()
	burn.set_throttle(1.0)
	run_steps(burn, 6.0)
	check(not burn.fire_afterburner(), "no afterburner without the gadget")
	burn.afterburner_gadget = true
	var fuel_before = burn.fuel
	var plain_rate = burn.fuel_rate()
	check(burn.fire_afterburner() and burn.afterburner_charges == 1, "with the gadget the afterburner fires")
	run_steps(burn, 1.0)
	check(burn.thrust > 15000.0 and burn.fuel_rate() > plain_rate * 1.2, "the thrust jumps and the petrol goes faster (%.0f N)" % burn.thrust)
	run_steps(burn, 3.0)
	check(burn.afterburner_time == 0.0 and burn.thrust < 36001.0, "after three seconds it is over")
	burn.new_trip()
	check(burn.afterburner_charges == 2 and burn.chutes_left == 1, "the depot repacks the chute and refills the afterburner")
	# an empty tank: no thrust, the speed goes down by itself
	var dry = started_jet()
	dry.fuel = 0.0
	dry.set_throttle(1.0)
	run_steps(dry, 5.0)
	check(dry.thrust == 0.0 and dry.v == 0.0, "an empty tank gives no thrust")
	# the heat: a long full thrust standing on the brake overheats the turbine and shuts it down
	var hot = started_jet()
	hot.set_throttle(0.65)
	hot.set_pad_brake(1.0)
	var overheated = false
	for i in range(60 * 240):
		hot.step(1.0 / 60.0)
		if hot.events.has("overheat"): overheated = true
	check(overheated and not hot.started, "a long thrust standing on the brakes overheats the turbine and shuts it down")
	var cool = started_jet()
	cool.set_throttle(1.0)
	run_steps(cool, 120.0)
	check(cool.started and cool.temp < 0.8, "at speed the air cools it (%.2f)" % cool.temp)
	print("JET CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
