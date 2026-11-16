extends "res://tests/group_runner.gd"
# Рекорды: модель и вкладка. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_records", "check_records_view"]
