extends Node
# Probe (not a check): writes the motion of the suspension of every body to a CSV, to see it as curves.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var out = "user://probe_live.csv"
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): out = args[0]
	var game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.live_in_tests = true
	game.set_physics_process(false)
	game.model.new_game(42, 2)
	game.model.state.money = 5000
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "locomotive")
	game.screen = "game"
	game.rebuild()
	Model.live_effects = true
	var m = game.model
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.v = 0.0
	m.state.direction = 1
	m.state.reverser = 1
	m.state.brake = 0.0
	game.camera_s = 600.0
	var f = FileAccess.open(out, FileAccess.WRITE)
	f.store_line("t,v,phase,n,lift0,lift1,lift2,rock0,rock1,rock2,slack1,slack2,tension1")
	var t = 0.0
	var phase = "accelerate"
	m.state.throttle = 1.0
	for i in range(60 * 22):
		m.physics_step(1.0 / 60.0)
		t += 1.0 / 60.0
		if t > 8.0 and phase == "accelerate": phase = "cruise"
		if t > 15.0 and phase == "cruise":
			phase = "brake"
			m.state.throttle = 0.0
			m.state.brake = 1.0
		var L = m.live
		f.store_line("%.3f,%.3f,%s,%d,%.5f,%.5f,%.5f,%.6f,%.6f,%.6f,%.5f,%.5f,%.1f" % [t, float(m.state.v), phase, L.n, L.lift_m(0), L.lift_m(1), L.lift_m(2), L.rock_rad(0), L.rock_rad(1), L.rock_rad(2), L.slack_m(1), L.slack_m(2), float(L.tension[1]) if L.tension.size() > 1 else 0.0])
	f.close()
	Model.live_effects = false
	print("PROBE DONE ", out)
	get_tree().quit(0)
