extends "res://tests/group_runner.gd"
# Прогноз рейса: службы станций и экраны прогноза. Части лежат в tests/parts/ и идут в одном запуске Godot.

func parts() -> Array:
	return ["check_forecast", "check_forecast_view"]
