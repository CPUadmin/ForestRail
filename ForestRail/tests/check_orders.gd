extends "res://tests/group_runner.gd"
# Заказы: сроки и бонусы, погрузка без цепочки, выбор груза. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_deadlines", "check_loading_flow", "check_loading_selection"]
