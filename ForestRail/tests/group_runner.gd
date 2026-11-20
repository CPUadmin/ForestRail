extends Node
# A group of test scripts run one after another in ONE Godot (16.11.2026, docs/TESTS_JUDGEMENT_RU.md): starting the game
# costs 5–8 s, so 87 launches took a third of the whole run. The scripts live in tests/parts/ and stay as they were;
# they end with QaExit.quit, which hands the code back here. Between the scripts the group frees everything the
# script added to the root and puts the shared switches of the model back to their defaults.
# A group file: `extends "res://tests/group_runner.gd"` and `func parts() -> Array: return ["check_a", "check_b"]`.

const Model = preload("res://scripts/core/model.gd")

var results: Array = []
var current: Node = null
var before: Array = []
var done_code = -1

func parts() -> Array:
	return []

func _ready() -> void:
	call_deferred("run")

func reset_shared() -> void:
	Model.legacy_tanks = false
	Model.order_rules = false
	Model.live_effects = false
	Model.wear_rules = false
	Model.junk_rules = false
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().root.size = Vector2i(1600, 900)

func part_done(node: Node, code: int) -> void:
	if node == current and done_code < 0: done_code = code

func run() -> void:
	var root = get_tree().root
	root.set_meta("qa_group", self)
	for name in parts():
		reset_shared()
		before = root.get_children()
		done_code = -1
		var script = load("res://tests/parts/%s.gd" % name)
		if script == null:
			print("FAIL: GROUP part %s is missing" % name)
			results.append([name, 2])
			continue
		print("GROUP PART START ", name)
		var started = Time.get_ticks_msec()
		current = script.new()
		root.add_child(current)
		while done_code < 0:
			await get_tree().process_frame
		results.append([name, done_code])
		print("GROUP PART END %s code %d (%.1f s)" % [name, done_code, (Time.get_ticks_msec() - started) / 1000.0])
		current = null
		for child in root.get_children():
			if not child in before and child != self: child.queue_free()
		for i in range(3): await get_tree().process_frame
	root.remove_meta("qa_group")
	var failed = results.filter(func(r): return int(r[1]) != 0).map(func(r): return r[0])
	print("GROUP CHECKS %d parts; FAILED %s" % [results.size(), str(failed)])
	get_tree().quit(0 if failed.is_empty() else 1)
