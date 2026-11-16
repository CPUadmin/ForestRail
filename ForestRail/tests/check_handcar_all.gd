extends "res://tests/group_runner.gd"
# Ручная дрезина: езда, ввод, механизм. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_handcar_drive", "check_handcar_input", "check_handcar_revision", "check_mechanism", "check_mechanism_bench"]
