extends Node
# Windowed look at the steam engine: outside with the fire lit, and the pult.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_steam_view"

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
	Fixtures.equip(game.model, "steam")
	game.model.accept_mission(game.model.current_mission())
	for i in range(mini(game.model.state.cargo.size(), game.model.slots().size())): game.model.transfer(game.model.state.cargo[i].id, game.model.slots()[i].key)
	game.screen = "game"
	game.camera_s = float(game.model.state.s)
	game.camera_x = 1040
	game.rebuild()
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model.cool_boiler()
		await shot("steam_cold_%d" % size.y)
		Fixtures.fire_up(game.model)
		game.model.set_door(true)
		game.model.depart() if game.model.state.phase == "loading" else null
		await shot("steam_fire_%d" % size.y)
		game.model.set_door(false)
		game.cab_view = true
		game.update_pult_transform()
		for i in range(8): await get_tree().process_frame
		game.queue_redraw()
		await shot("steam_pult_%d" % size.y)
		check(game.get_viewport_rect().encloses(game.pult_screen_rect()), "steam pult fits %d" % size.y)
		check(game.steam_hits.size() == 2, "steam pult has bucket and door %d" % size.y)
		game.cab_view = false
		game.update_pult_transform()
	game.model.state.stats.distance = 86.6
	game.model.state.s = 86.6
	game.model.state.v = 4.0
	game.camera_s = 86.6
	game.camera_y = game.model.route.sample(86.6).y
	game.toast_seconds = 0.0
	await shot("steam_smoke_ring")
	print("STEAM VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
