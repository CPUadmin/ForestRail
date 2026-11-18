extends Node
# The load factor of the trip forecast for the heavy test trip (six bundles of logs to D), per class. Not a check.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

func _ready() -> void:
	for kind in ["motorcar", "locomotive", "pneumatic"]:
		var m = Model.new()
		m.new_game(42, 2)
		m.state.money = 1000000
		Fixtures.equip(m, kind)
		var f = m.trip_forecast({"dropoffs": [{"station": "D", "cargo": [["logs", 6]]}]})
		print("LOAD %s need %.3f load_factor %.4f bodies %s" % [kind, f.need, f.load_factor, str(m.body_ids())])
	get_tree().quit(0)
