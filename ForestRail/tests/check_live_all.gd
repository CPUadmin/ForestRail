extends "res://tests/group_runner.gd"
# Живой состав: сцепки, качание, груз; и как это видно. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_live", "check_live_view"]
