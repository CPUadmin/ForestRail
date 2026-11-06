extends Node
# В6.6: реактивный (ракетный) поезд в модели игры (Model): скрыт из гаража, запуск с предохранителями и отсчётом через physics_step,
# тяга регулируется, состав из вагонов, парашют (один или оба с гаджетом), расход керосина, сохранение положений предохранителей.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func fresh(wagons: bool = true):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 200000
	m.state.chapter = 9
	Fixtures.equip(m, "jet")
	if not wagons:
		m.state.consist_ids.clear()
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.phase = "route"
	m.state.brake = 0.0
	m.state.s = 400.0
	return m

func run_seconds(m, seconds: float) -> void:
	for i in range(int(seconds * 60.0)): m.physics_step(1.0 / 60.0)

func touch_all(m) -> void:   # all four toggles on, in the natural order
	for i in range(4):
		if not m.jet.fuses[i]: m.flip_jet_fuse(i)

func light(m) -> void:
	m.state.brake = 1.0   # the brake holds the train on the grade during the countdown
	m.set_jet_cover(true)
	touch_all(m)
	m.jet_start()
	run_seconds(m, 10.6)
	m.state.brake = 0.0

func run() -> void:
	var m = fresh(false)
	check(m.vehicle_id() == "jet" and "jet" in m.HIDDEN_VEHICLE_IDS and "jet" not in m.VEHICLE_IDS, "the jet is a hidden machine until it is ready")
	check(int(m.vehicle_base("jet").cost) == 12000 and int(m.vehicle_base("jet").max_wagons) == 3, "the data: 12000 coins, up to three wagons")
	check(not m.jet_start(), "no start without the open cap")
	check(m.set_jet_cover(true) and not m.jet_start(), "under the open cap the start is locked until all four toggles are on")
	check("заблокирована" in m.message, "and the message says why (%s)" % m.message)
	touch_all(m)
	check(m.jet_start(), "then the start begins the countdown")
	m.state.throttle = 1.0
	m.state.brake = 1.0
	run_seconds(m, 9.0)
	check(absf(float(m.state.v)) < 0.1 and m.jet.counting, "during the countdown the machine stands even with the lever up")
	run_seconds(m, 1.6)
	m.state.brake = 0.0
	check(m.jet.started and bool(m.state.engine), "after the countdown the engine is lit")
	run_seconds(m, 40.0)
	check(float(m.state.v) * 3.6 > 150.0, "then it accelerates hard (%.0f km/h)" % (float(m.state.v) * 3.6))
	check(float(m.state.fleet_by_id.jet.fuel) < float(m.object_stats("jet").tank), "kerosene is burnt")
	# the fuses: the code is kept, and they cannot be touched while the engine runs
	var fuses = fresh(false)
	check(fuses.flip_jet_fuse(3) and fuses.flip_jet_fuse(2) and str(fuses.state.jet_fuses) == "43", "the toggles switch on and the order is kept in the state (%s)" % str(fuses.state.get("jet_fuses", "")))
	fuses.flip_jet_fuse(1)
	fuses.flip_jet_fuse(0)
	fuses.state.brake = 1.0
	fuses.set_jet_cover(true)
	touch_all(fuses)
	fuses.jet_start()
	check(fuses.jet.mode.name == "Экономный", "the order 4321 is the economy mode")
	run_seconds(fuses, 10.6)
	check(not fuses.flip_jet_fuse(1), "the fuses are not touched when the engine runs")
	# the save: the fuses, the lit engine and the chutes survive a load
	var loaded = Model.new()
	check(loaded.restore(fuses.serialize()), "a game with the jet loads")
	loaded.state.throttle = 0.5
	loaded.physics_step(1.0 / 60.0)
	check(str(loaded.state.jet_fuses) == "4321" and loaded.jet.started and loaded.jet.fuse_code() == "4321", "the order of the toggles and the lit engine are as they were")
	# the train: four wagons add weight, the machine still pulls
	var train = fresh(true)
	check(train.state.consist_ids.size() == 3 and train.train_mass() > 1900.0, "three wagons: the train weighs %.0f kg" % train.train_mass())
	light(train)
	train.state.throttle = 1.0
	run_seconds(train, 60.0)
	check(float(train.state.v) * 3.6 > 100.0, "and it still pulls it to %.0f km/h in a minute" % (float(train.state.v) * 3.6))
	# the chute: one, then the stop cuts it away
	var chute = fresh(false)
	light(chute)
	chute.state.throttle = 1.0
	run_seconds(chute, 60.0)
	chute.state.throttle = 0.0
	check(chute.pull_jet_chute(1), "the ring pulls the chute")
	check(not chute.pull_jet_chute(1), "and there is no second one without the gadget")
	var cut = false
	for i in range(60 * 240):
		chute.physics_step(1.0 / 60.0)
		if chute.events.has("jet_chute_cut"): cut = true
		if cut: break
	check(cut and float(chute.state.v) < 1.0, "the chute stops the train and is cut away")
	# two chutes with the gadget
	var pair = fresh(false)
	pair.object_state("jet").levels.jet_double_chute = 1
	pair.state.phase = "loading"
	pair.state.active = {"phase": "outbound", "dropoffs": [], "destination": "F"}
	pair.jet.double_chute_gadget = true
	pair.jet.new_trip()
	check(pair.jet.chutes_left == 2, "with the gadget the pack holds two chutes")
	pair.state.phase = "route"
	light(pair)
	pair.state.throttle = 1.0
	run_seconds(pair, 30.0)
	pair.state.throttle = 0.0
	check(pair.pull_jet_chute(2) and pair.jet.chutes_open == 2, "both can go out at once")
	# kerosene: only at A and F, a station with petrol alone does not fuel the jet
	var kerosene = fresh(false)
	check(kerosene.station_services("A").has("kerosene") and kerosene.station_services("F").has("kerosene"), "kerosene is sold at A and F")
	check(not kerosene.station_services("C").has("kerosene") and not kerosene.station_services("E").has("kerosene"), "and not at the stations in between")
	check(kerosene.fuel_service_mult(kerosene.station_services("A")) == 1.0 and kerosene.fuel_service_mult(kerosene.station_services("C")) < 0.0, "the jet fuels where there is kerosene and nowhere else")
	var petrol = Model.new()
	petrol.new_game(42, 2)
	check(petrol.fuel_service_mult({"fuel": 1.0, "kerosene": 1.0}) == 1.0, "the other machines still take the ordinary fuel service")
	print("JET MODEL CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
