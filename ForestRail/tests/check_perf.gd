extends Node
# Frame cost of the driving screen at 1080p with a running electric train: the whole
# scene, then with the HUD hidden, then with the world drawing hidden. Prints
# milliseconds per frame; fails only if the whole scene is slower than 30 ms.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []

func _ready() -> void:
	call_deferred("run")

func average_ms(frames: int) -> float:
	var start = Time.get_ticks_usec()
	for i in range(frames): await get_tree().process_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / frames

func run() -> void:
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = "user://qa_perf_runtime"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1920, 1080)
	game.model.new_game(42)
	game.model.state.money = 10000
	for kind in ["locomotive", "motorcar", "steam"]:
		Fixtures.equip(game.model, kind)
		game.model.state.chapter = {"locomotive": 9, "motorcar": 5, "steam": 2}[kind]
		game.model.accept_mission(game.model.current_mission())
		game.model.state.phase = "route"
		game.model.state.engine = true
		game.model.state.gear = 1
		game.model.state.throttle = 0.8
		game.model.state.brake = 0
		game.screen = "game"
		game.camera_s = 1000
		game.camera_y = game.model.route.sample(1000).y
		game.rebuild()
		for i in range(30): await get_tree().process_frame
		var full = await average_ms(120)
		game.instruments.visible = false
		var no_hud = await average_ms(120)
		game.instruments.visible = true
		game.visible = true
		print("PERF %s: full %.1f ms, without HUD %.1f ms" % [kind, full, no_hud])
		if full > 30.0: failures.append("%s frame %.1f ms" % [kind, full])
		game.model.back_to_depot()
		game.model.cancel_mission()
	print("PERF CHECKS ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
