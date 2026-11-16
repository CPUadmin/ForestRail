extends "res://tests/group_runner.gd"
# Шестовая и кошка. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_pole", "check_pole_view", "check_grapnel", "check_grapnel_model", "check_grapnel_view"]
