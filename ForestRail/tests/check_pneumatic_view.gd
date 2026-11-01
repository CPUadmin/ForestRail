extends Node
# Windowed look at the pneumatic train: outside with the valve open and the pipes frosted, and the pult.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_pneumatic_view"

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
	Fixtures.equip(game.model, "pneumatic")
	game.model.accept_mission(game.model.current_mission())
	for i in range(mini(game.model.state.cargo.size(), game.model.slots().size())): game.model.transfer(game.model.state.cargo[i].id, game.model.slots()[i].key)
	game.screen = "game"
	game.camera_s = float(game.model.state.s)
	game.camera_x = 1040
	game.rebuild()
	check(game.art.textures.has("vehicles/pneumatic_body"), "the pneumatic train has its own body picture")
	check(game.art.assets["vehicles/pneumatic_body"].file.ends_with("pneumatic_body.png"), "it is the own file, not the steam one")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model.state.fleet_by_id.pneumatic.ice_spots = [0.0, 0.0, 0.0, 0.0]
		game.queue_redraw()
		await shot("pneumatic_clean_%d" % size.y)
		game.model.state.fleet_by_id.pneumatic.ice_spots = [0.9, 0.6, 0.35, 0.15]
		game.model.state.engine = true
		game.model.state.throttle = 0.8
		game.queue_redraw()
		await shot("pneumatic_frost_%d" % size.y)
		# B1.3: clicking the frost of a pipe chips that place only
		game.queue_redraw()
		await shot("pneumatic_ice_click_%d" % size.y)
		check(game.ice_hits.size() == 4, "four frosted places are clickable (%d)" % game.ice_hits.size())
		if game.ice_hits.size() == 4:
			var before = float(game.model.state.fleet_by_id.pneumatic.ice_spots[0])
			var other = float(game.model.state.fleet_by_id.pneumatic.ice_spots[1])
			var click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = game.ice_hits[0].position
			game._unhandled_input(click)
			var spots = game.model.state.fleet_by_id.pneumatic.ice_spots
			check(float(spots[0]) < before - 0.2 and absf(float(spots[1]) - other) < 0.0001, "a click chips a quarter off that place only (%.2f -> %.2f)" % [before, float(spots[0])])
		game.model.state.engine = false
		game.model.state.throttle = 0.0
		game.cab_view = true
		game.update_pult_transform()
		for i in range(8): await get_tree().process_frame
		game.queue_redraw()
		await shot("pneumatic_pult_%d" % size.y)
		check(game.get_viewport_rect().encloses(game.pult_screen_rect()), "pneumatic pult fits %d" % size.y)
		game.cab_view = false
		game.update_pult_transform()
	print("PNEUMATIC VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
