extends "res://tests/group_runner.gd"
# Двор, вход в депо, перестановка вагонов. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_yard", "check_depot_entry", "check_interaction"]
