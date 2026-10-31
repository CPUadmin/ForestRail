extends "res://tests/drive_campaign.gd"
# The whole career (10 orders and 3 free runs) driven on the long line of about 6.8 km.

func _ready() -> void:
	line = 2
	call_deferred("run")
