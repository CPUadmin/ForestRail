extends "res://tests/group_runner.gd"
# Бензиновая: коробка, закрытые передачи, рычаги, вид. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_gearbox", "check_gears_unlock", "check_motor_controls", "check_petrol_view"]
