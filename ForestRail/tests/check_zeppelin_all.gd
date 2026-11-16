extends "res://tests/group_runner.gd"
# Цеппелин: полёт, модель, пульт. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_zeppelin", "check_zeppelin_model", "check_zeppelin_view"]
