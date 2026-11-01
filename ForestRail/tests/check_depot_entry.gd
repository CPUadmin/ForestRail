extends Node
# B1.2a: entering the depot is a short scene: the train rolls to its mark, the view closes in, the
# screen fades to black, the depot opens, and fades in. Any key skips the rolling part.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var checks = 0
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func at_depot_platform() -> void:
	game.model.new_game(42, 2)
	game.model.state.phase = "route"
	game.model.state.s = game.model.service_stop(0) - 5.0
	game.model.state.v = 0.0
	game.model.state.brake = 1.0
	game.screen = "game"
	game.zoom_level = 1.0
	game.rebuild()

func run_frames(seconds: float) -> void:
	for i in range(int(seconds / 0.016)): game._process(0.016)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.saves.directory = "user://qa_depot_entry"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	at_depot_platform()
	# a moving train cannot enter
	game.model.state.v = 3.0
	game.start_depot_entry()
	check(game.depot_anim == "", "a moving train does not enter")
	game.model.state.v = 0.0
	# away from the depot platform there is nothing to enter
	game.model.state.s = float(game.model.route.station_s[2])
	game.start_depot_entry()
	check(game.depot_anim == "", "only the home station has a depot")
	at_depot_platform()
	var start = float(game.model.state.s)
	game.start_depot_entry()
	check(game.depot_anim == "in" and game.fade_rect != null, "the entry scene starts")
	run_frames(0.8)
	var mid = float(game.model.state.s)
	check(game.depot_anim == "in" and mid > start and game.zoom_level > 1.0 and game.screen == "game", "halfway: the train is rolling in and the view is closing in")
	run_frames(0.6)
	run_frames(0.4)
	check(game.fade_rect.color.a > 0.2 or game.depot_anim == "out", "the screen fades to black")
	run_frames(0.6)
	check(game.screen == "depot" and game.model.state.phase == "depot" and absf(game.zoom_level - 1.0) < 0.001, "the depot opens and the zoom is restored")
	run_frames(0.7)
	check(game.depot_anim == "" and game.fade_rect.color.a == 0.0, "then the screen is clear again")
	# a key press skips the rolling part
	at_depot_platform()
	game.start_depot_entry()
	run_frames(0.2)
	var key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	game._input(key)
	run_frames(0.6)
	check(game.screen == "depot", "a key press skips the rolling and the depot opens sooner")
	run_frames(0.7)
	print("DEPOT ENTRY CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
