extends "res://tests/group_runner.gd"
# Реактивный: ход, модель, пульт, пламя. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_jet", "check_jet_model", "check_jet_view", "check_jet_fx_view"]
