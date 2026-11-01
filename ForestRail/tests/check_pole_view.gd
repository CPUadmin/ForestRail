extends Node
# Windowed look at the pole train: outside with the valve open and the pipes frosted, and the pult.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_pole_view"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func run() -> void:
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42)
	game.model.state.money = 5000
	game.model.state.chapter = 2
	Fixtures.equip(game.model, "pole")
	game.screen = "game"
	game.camera_s = float(game.model.state.s)
	game.camera_x = 1040
	game.rebuild()
	game.model.state.phase = "route"
	game.model.state.s = 3000.0
	game.camera_s = 3000.0
	game.rebuild()
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model.pole_aim(2.0)
		for i in range(90): game.model.physics_step(1.0 / 60.0)
		game.queue_redraw()
		await shot("pole_carried_%d" % size.y)
		check(game.model.pole_plant(), "the pole is planted for the picture")
		game.model.pole_effort(0.6)
		for i in range(40): game.model.physics_step(1.0 / 60.0)
		game.camera_s = float(game.model.state.s)
		game.queue_redraw()
		await shot("pole_planted_%d" % size.y)
		game.model.pole_lift()
		game.model.state.v = 0.0
		game.model.state.s = 3000.0
	print("POLE VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
