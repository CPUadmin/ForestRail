extends "res://tests/group_runner.gd"
# Физика: шаг, полёт с бугров, сцепление колёс. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_physics", "check_air", "check_grip"]
