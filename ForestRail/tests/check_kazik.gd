extends "res://tests/group_runner.gd"
# Казик: правила, приёмка болтов, болты с дороги. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_casino", "check_receiving", "check_road_junk"]
