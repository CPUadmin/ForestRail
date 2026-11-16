extends "res://tests/group_runner.gd"
# Паровоз: модель и вид. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_steam", "check_steam_view"]
