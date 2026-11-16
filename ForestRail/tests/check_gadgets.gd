extends "res://tests/group_runner.gd"
# Гаджеты всех машин. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_auto_gearbox", "check_auto_gearbox_view", "check_auto_reducer", "check_electric_gadgets", "check_nitro", "check_ratchet", "check_passive_gadgets", "check_gadget_art_view"]
