extends "res://tests/group_runner.gd"
# 1.4.10 «Скрутка»: запуск электровоза в ящике КОНТАКТОР — модель и ящик в кабине. Части лежат в tests/parts/.

func parts() -> Array:
	return ["check_contactor", "check_contactor_view"]
