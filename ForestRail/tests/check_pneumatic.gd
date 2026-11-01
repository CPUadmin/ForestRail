extends Node
# N12, first step of the pneumatic train: the model only (it is not shown to the player yet).
# Air pressure limits the pull, frost builds on the pipes and is chipped off by clicks, the
# compressor is a station service, the energy is paid for by work on the shaft.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func at_station(m, id: String) -> void:
	var index = 0
	for i in range(m.data.stations.size()):
		if m.data.stations[i].id == id: index = i
	m.state.phase = "route"
	m.state.s = m.service_stop(index)
	m.state.v = 0.0
	m.state.brake = 1.0
	m.stationary_station = index
	m.stationary_seconds = 1.0

func run() -> void:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	Fixtures.equip(m, "pneumatic")
	var stats = m.object_stats("pneumatic")
	check(m.vehicle_id() == "pneumatic" and is_equal_approx(float(stats.tank), 150.0), "a pneumatic train of 150 bar")
	check("pneumatic" not in Model.VEHICLE_IDS and bool(m.vehicle_base("pneumatic").get("hidden", false)), "it is hidden from the player for now")
	check(is_equal_approx(float(m.state.fleet_by_id.pneumatic.fuel), 150.0) and m.max_wagons("pneumatic") == 2 and m.rank("pneumatic") == 2, "bought with a full tank, two wagons, the rank of the petrol one")
	check(m.top_speed_kmh("pneumatic") == 60.0, "stated top speed 60 km/h")
	# pressure and frost shape the pull
	check(is_equal_approx(m.pneumatic_factor(), 1.0), "a full tank, no frost: full pull")
	m.state.fleet_by_id.pneumatic.fuel = 30.0
	check(is_equal_approx(m.pneumatic_factor(), 0.5), "30 bar: half the pull")
	m.state.fleet_by_id.pneumatic.fuel = 150.0
	m.state.fleet_by_id.pneumatic.ice_spots = [1.0, 1.0, 1.0, 1.0]
	check(is_equal_approx(m.pneumatic_factor(), 0.3), "full frost: 30% of the pull")
	check(is_equal_approx(m.frost(), 1.0), "the frost is the mean of four spots")
	# frost grows while it runs, melts at a standstill
	m.state.fleet_by_id.pneumatic.ice_spots = [0.0, 0.0, 0.0, 0.0]
	m.state.v = 10.0
	m.state.throttle = 1.0
	var fleet = m.state.fleet_by_id.pneumatic
	for i in range(20): m.update_frost(fleet, 1.0)
	var grown = m.frost()
	check(grown > 0.1 and grown < 0.5, "frost grows under power (%.2f after 20 s)" % grown)
	check(float(fleet.ice_spots[0]) > float(fleet.ice_spots[3]), "unevenly: some spots frost first")
	m.state.v = 10.0
	m.state.throttle = 0.0
	for i in range(20): m.update_frost(fleet, 1.0)
	check(is_equal_approx(m.frost(), grown), "no frost grows without the valve open, and it does not melt on the move")
	m.state.v = 0.0
	for i in range(10): m.update_frost(fleet, 1.0)
	check(m.frost() < grown - 0.05, "it melts at a standstill (%.2f)" % m.frost())
	# chipping
	fleet.ice_spots = [1.0, 0.5, 0.04, 0.0]
	var before = m.frost()
	check(m.chip_ice(0) and is_equal_approx(float(fleet.ice_spots[0]), 0.75), "a click takes a quarter off a frosted spot")
	check(not m.chip_ice(2) and not m.chip_ice(3) and not m.chip_ice(9), "a clean spot, or none, gives nothing")
	check(m.frost() < before and is_equal_approx(before - m.frost(), 0.0625), "the mean falls by a quarter of one spot")
	# the compressor is a station service
	check(m.station_services("D").has("air") and not m.station_services("D").has("fuel"), "the lake station has a compressor, not fuel")
	fleet.fuel = 100.0
	at_station(m, "D")
	check(not m.service_offer().is_empty() and m.refill_cost() == ceili(50.0 * 1.5 - 0.0001), "air at the lake station costs the bar price (%d)" % m.refill_cost())
	var money = int(m.state.money)
	check(m.refuel() and float(fleet.fuel) >= 150.0 - 0.001 and money - int(m.state.money) == ceili(50.0 * 1.5 - 0.0001), "the compressor fills the tank for that price")
	at_station(m, "F")
	fleet.fuel = 100.0
	check(m.refill_cost() == ceili(50.0 * 1.5 * 1.5 - 0.0001), "the far station charges its multiplier")
	at_station(m, "C")
	check(m.service_offer().is_empty(), "no service at a station without one")
	var steam = Model.new()
	steam.new_game(42, 2)
	steam.state.money = 100000
	Fixtures.equip(steam, "steam")
	at_station(steam, "D")
	check(steam.fuel_service_mult(steam.station_services("D")) < 0.0, "the steam locomotive finds no fuel at the lake station")
	# legs: with a compressor halfway the pneumatic train needs a shorter stretch
	var mission = {"dropoffs": [{"station": "F", "cargo": [["sack", 1]]}]}
	check(float(m.trip_forecast(mission).leg_m) < float(steam.trip_forecast(mission).leg_m), "the compressor at D shortens the longest stretch against the steam locomotive")
	# work on the shaft pays for the air; it never goes below zero
	var flat = Model.new()
	flat.new_game(42, 1)
	flat.state.money = 100000
	Fixtures.equip(flat, "pneumatic")
	var points: Array = []
	for x in range(-40, 20001): points.append([float(x), 0.0, float(x)])
	flat.route.points = points
	flat.route.length_m = 20000.0
	flat.state.phase = "route"
	flat.state.s = 100.0
	flat.state.brake = 0.0
	flat.state.throttle = 1.0
	var start_air = float(flat.state.fleet_by_id.pneumatic.fuel)
	for i in range(60 * 30): flat.physics_step(1.0 / 60.0)
	var spent = start_air - float(flat.state.fleet_by_id.pneumatic.fuel)
	check(spent > 0.5 and float(flat.state.v) > 8.0, "30 s of running spends air (%.2f bar) and moves the train" % spent)
	check(float(flat.motor_energy.used_j) > 0.0, "the energy report counts the work")
	flat.state.fleet_by_id.pneumatic.fuel = 0.0
	for i in range(60 * 20): flat.physics_step(1.0 / 60.0)
	check(float(flat.state.fleet_by_id.pneumatic.fuel) >= 0.0 and not bool(flat.state.engine), "an empty tank stops the drive and never goes negative")
	var stopped_speed = float(flat.state.v)
	flat.state.throttle = 1.0
	for i in range(60 * 30): flat.physics_step(1.0 / 60.0)
	check(float(flat.state.v) < stopped_speed + 0.01, "without air it only rolls down")
	# saving
	m.state.phase = "depot"
	m.state.active = {}
	m.state.cargo = []
	fleet.ice_spots = [0.5, 0.25, 0.0, 1.0]
	var other = Model.new()
	check(other.restore(m.serialize()) and other.state.fleet_by_id.pneumatic.ice_spots == [0.5, 0.25, 0.0, 1.0], "the frost survives saving and loading")
	print("PNEUMATIC CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
