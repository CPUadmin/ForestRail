extends "res://tests/group_runner.gd"
# Казик: экраны, карточки, альбом, приёмка, блики. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_casino_view", "check_card_view", "check_album_view", "check_receiving_view", "check_road_junk_view"]
