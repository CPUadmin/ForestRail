extends "res://tests/group_runner.gd"
# Пневмовоз: модель, управление, вид. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_pneumatic", "check_pneumatic_controls", "check_pneumatic_view"]
