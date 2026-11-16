extends "res://tests/group_runner.gd"
# Линия: форма длинной линии, своя линия у каждой карьеры. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_line_v2", "check_line_spread"]
