extends SceneTree

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	var suite = "check_model"
	for arg in args:
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
	if suite not in ["check_model", "check_physics", "check_interaction", "drive_campaign", "check_presentation", "check_handcar_revision", "scenarios"]:
		quit(2)
		return
	root.set_meta("qa_running", true)
	root.add_child.call_deferred(load("res://tests/" + suite + ".gd").new())
