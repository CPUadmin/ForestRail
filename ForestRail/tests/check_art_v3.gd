extends Node

const Art = preload("res://scripts/art_v3.gd")
var failures: Array = []
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("FAIL: ", message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var art = Art.new()
	for id in art.assets:
		check(art.textures[id] != null, "texture available in build " + id)
		if art.assets[id].has("scale_at_128_px_per_m"):
			check(art.scale_for(id) > 0, "positive physical scale " + id)
	var length = float(art.rig.rod_length)
	var error = 0.0
	for i in range(1441):
		var pose = art.forward_pose(i * TAU / 1440)
		error = maxf(error, absf(pose.rocker_pin.distance_to(pose.crank_pin) - length))
		check(absf(pose.rocker.distance_to(pose.rocker_pin) - float(art.rig.rocker_pin_radius)) < 0.001, "rocker pin rigid")
		check(absf(pose.crank.distance_to(pose.crank_pin) - float(art.rig.crank_radius)) < 0.001, "crank pin rigid")
	check(error < 0.001, "connecting rod keeps length for full rotation")
	for direction in [-1,1]:
		for motion in [-1,1]:
			for i in range(281):
				var pose = art.pose(deg_to_rad(-28 + i*0.2),motion,direction)
				check(absf(pose.rocker_pin.distance_to(pose.crank_pin)-length)<0.001,"mouse-driven linkage remains joined")
	for id in ["handcar","motorcar","locomotive","W01"]:
		var radius = art.PX * (0.55 if id=="locomotive" else 0.42)*0.5
		for position in art.wheel_positions(id):
			check(absf(position.y+radius+3)<0.01,"wheel rim meets rail "+id)
		for i in range(4 if id.begins_with("W") else 2):
			var slot = art.slot_position(id,i,4 if id.begins_with("W") else 2)
			check(absf(slot.x)<art.body_width(id)*0.5,"cargo stays above deck "+id)
	var result = {"checks":checks,"failures":failures,"max_rod_error_at_128px":error}
	DirAccess.make_dir_recursive_absolute("user://qa_model")
	var file = FileAccess.open("user://qa_model/art_v3_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("ART V3 CHECKS ",checks,"; FAILURES ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
