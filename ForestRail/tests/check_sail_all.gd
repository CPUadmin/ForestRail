extends "res://tests/group_runner.gd"
# Парусная: парус, ветер, вёсла. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_sail", "check_sail_view", "check_wind_view", "check_oars", "check_oars_view"]
