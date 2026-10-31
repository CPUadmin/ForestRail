extends Node
# N7.3 + N10 on the long line: every class drives the whole round trip A -> F -> A with the
# player's own inputs; the forecast covers what it really cost, and the tank is enough for
# one round trip but not for two.
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

func run() -> void:
	for kind in ["motorcar", "locomotive", "steam"]:
		var m = Model.new()
		m.new_game(42, 2)
		m.state.money = 1000000
		Fixtures.equip(m, kind)
		m.refuel()
		for station in m.data.stations:
			if station.id != "A": station.services = {}
		var mission = {"dropoffs": [{"station": "F", "cargo": [["sack", 1]]}]}
		var forecast = m.trip_forecast(mission)
		var tank = float(m.object_stats(kind).tank)
		check(float(forecast.need) <= tank, "%s: the forecast %.2f fits the tank %.2f for one round trip to F" % [kind, forecast.need, tank])
		check(m.mission_error({"id": "T", "tier": kind, "free": true, "reward": 0, "dropoffs": mission.dropoffs}) == "", kind + ": the round trip is accepted with a full tank")
		var real = Driver.round_trip(m, "F", 1)
		check(bool(real.get("ok", false)), "%s completes the round trip to F and back (%s, %.0f s)" % [kind, str(real.get("why", "")), float(real.get("seconds", 0))])
		var used = float(real.get("used", 0.0))
		print("LONG ", kind, " used ", snappedf(used, 0.001), " forecast ", snappedf(float(forecast.need), 0.001), " tank ", snappedf(tank, 0.001), " water ", snappedf(float(real.get("water_used", 0)), 0.1), "/", snappedf(float(m.object_stats(kind).water), 0.1))
		check(float(forecast.need) >= used and float(forecast.need) <= used * 1.6, "%s: forecast %.3f covers the real %.3f and is not absurd" % [kind, forecast.need, used])
		check(used <= tank and used * 1.9 >= tank, "%s: one round trip fits the tank but two would not (%.2f of %.2f)" % [kind, used, tank])
		if kind == "steam":
			var water = float(real.get("water_used", 0.0))
			var water_tank = float(m.object_stats("steam").water)
			check(float(forecast.water_need) >= water and float(forecast.water_need) <= water * 1.6 and water <= water_tank, "steam water: forecast %.0f, real %.0f, tank %.0f" % [forecast.water_need, water, water_tank])
	print("FORECAST LONG CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
