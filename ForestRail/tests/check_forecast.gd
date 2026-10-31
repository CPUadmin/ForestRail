extends Node
# N7.2: services exist only where the data says so, and the trip forecast covers what
# the model really burns on a full round trip (driven with the player's own inputs).
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const Driver = preload("res://tests/trip_driver.gd")

var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func at_station(m, id: String) -> void:
	var index = Driver.index_of(m, id)
	m.state.phase = "route"
	m.state.s = m.service_stop(index)
	m.state.v = 0.0
	m.state.brake = 1.0
	m.stationary_station = index
	m.stationary_seconds = 1.0

func fresh(kind: String):
	var m = Model.new()
	m.new_game(42)
	m.state.money = 100000
	Fixtures.equip(m, kind)
	return m

func run() -> void:
	var m = fresh("motorcar")
	check(m.station_services("A").has("fuel") and m.station_services("F").has("fuel") and m.station_services("D").has("water"), "services come from the data")
	check(m.station_services("B").is_empty() and m.station_services("C").is_empty() and m.station_services("E").is_empty(), "other stations offer nothing")
	# the longest stretch without a refill
	check(is_equal_approx(m.longest_leg(1000.0, []), 2000.0), "no service on the way: out and back")
	check(is_equal_approx(m.longest_leg(1700.0, [1700.0]), 1700.0), "service at the far end: one way")
	check(is_equal_approx(m.longest_leg(1700.0, [600.0, 1700.0]), 1100.0), "service in the middle splits the stretch")
	check(is_equal_approx(m.longest_leg(900.0, [600.0]), 600.0), "service before the far end: the dead end back and forth counts")
	# refuelling on the road
	m.state.fleet_by_id.motorcar.fuel = 0.5
	at_station(m, "C")
	check(m.service_offer().is_empty() and not m.refuel() and is_equal_approx(float(m.state.fleet_by_id.motorcar.fuel), 0.5), "a station without the service does not refuel")
	at_station(m, "F")
	var cost = m.refill_cost()
	check(cost == ceili((float(m.object_stats("motorcar").tank) - 0.5) * 18.0 * 1.5 - 0.0001), "the far station charges its multiplier (%d)" % cost)
	var money = int(m.state.money)
	check(m.refuel() and money - int(m.state.money) == cost and is_equal_approx(float(m.state.fleet_by_id.motorcar.fuel), float(m.object_stats("motorcar").tank)), "refuelling at the far station fills the tank for that price")
	m.state.brake = 0.0
	check(m.service_offer().is_empty(), "no service while the brake is off")
	var s = fresh("steam")
	s.state.fleet_by_id.steam.water = 100.0
	var coal = float(s.state.fleet_by_id.steam.fuel)
	s.state.fleet_by_id.steam.fuel = coal - 10.0
	var before = int(s.state.money)
	at_station(s, "D")
	check(s.refuel() and float(s.state.fleet_by_id.steam.water) >= float(s.object_stats("steam").water) - 0.001, "the lake station gives water")
	check(is_equal_approx(float(s.state.fleet_by_id.steam.fuel), coal - 10.0) and int(s.state.money) == before, "and no coal or charge there")
	check(not s.refuel(), "nothing left to take there")
	# forecast and the mission check follow the same numbers
	var mission = {"id": "T", "tier": "motorcar", "dropoffs": [{"station": "F", "cargo": [["sack", 1]]}]}
	var forecast = m.trip_forecast(mission)
	check(is_equal_approx(float(forecast.far_m), float(m.route.station_s[5])) and float(forecast.need) > 0.0, "forecast knows the far station and needs something")
	m.state.fleet_by_id.motorcar.fuel = 0.01
	check(m.mission_error(mission).begins_with("Запас мал"), "an almost empty tank is refused with the numbers")
	m.state.fleet_by_id.motorcar.fuel = float(m.object_stats("motorcar").tank)
	check(m.mission_error(mission) == "", "a full tank covers the trip")
	# the forecast against the real model: nothing to refill on the way, whole round trip
	for kind in ["motorcar", "locomotive", "steam"]:
		var trip = fresh(kind)
		trip.refuel()
		for station in trip.data.stations:
			if station.id != "A": station.services = {}
		var real = Driver.round_trip(trip, "F", 1)
		var predicted = trip.trip_forecast({"dropoffs": [{"station": "F", "cargo": [["sack", 1]]}]})
		check(bool(real.get("ok", false)), kind + " completes the round trip (" + str(real.get("why", "")) + ")")
		var used = float(real.get("used", 0.0))
		check(float(predicted.need) >= used and float(predicted.need) <= used * 3.0, "%s forecast %.3f covers the real %.3f without being absurd" % [kind, predicted.need, used])
		if kind == "steam":
			var water = float(real.get("water_used", 0.0))
			check(float(predicted.water_need) >= water and float(predicted.water_need) <= water * 3.0, "steam water forecast %.0f covers the real %.0f" % [predicted.water_need, water])
	print("FORECAST CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
