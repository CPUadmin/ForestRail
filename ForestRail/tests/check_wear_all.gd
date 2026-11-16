extends "res://tests/group_runner.gd"
# Износ: модель и окно состояния. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_wear", "check_wear_view"]
