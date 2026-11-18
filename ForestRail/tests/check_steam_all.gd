extends "res://tests/group_runner.gd"
# Паровоз: модель, вид снаружи и пульт, спичка (модель и коробок в кабине). Части лежат в tests/parts/ и идут в одном
# запуске Godot. 19.11 спичка (бывший check_matches_all) влита сюда: один запуск игры вместо двух.

func parts() -> Array:
	return ["check_steam", "check_steam_view", "check_matches", "check_matches_view"]
