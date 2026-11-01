extends Node
# Windowed look at the petrol locomotive: outside with the engine on, and the pult.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_petrol_view"

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
	game.model.state.chapter = 4
	Fixtures.equip(game.model, "motorcar")
	game.model.accept_mission(game.model.current_mission())
	for i in range(mini(game.model.state.cargo.size(), game.model.slots().size())): game.model.transfer(game.model.state.cargo[i].id, game.model.slots()[i].key)
	game.screen = "game"
	game.camera_s = float(game.model.state.s)
	game.camera_x = 1040
	game.rebuild()
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model.state.engine = false
		await shot("petrol_off_%d" % size.y)
		game.model.start_engine(true)
		game.model.set_gear(2)
		game.model.state.throttle = 0.6
		await shot("petrol_on_%d" % size.y)
		game.cab_view = true
		game.update_pult_transform()
		for i in range(8): await get_tree().process_frame
		game.queue_redraw()
		await shot("petrol_pult_%d" % size.y)
		check(game.get_viewport_rect().encloses(game.pult_screen_rect()), "petrol pult fits %d" % size.y)
		check(game.control_ids() == ["brake", "throttle", "gear", "start"], "petrol pult has four controls %d" % size.y)
		game.cab_view = false
		game.update_pult_transform()
	print("PETROL VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
