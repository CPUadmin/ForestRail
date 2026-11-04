extends Node
# Веха 6, В6.11 этап «б»: блик у рельса на дороге (виден, берётся щелчком) и окно «Принесли с дороги» в итоге рейса.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_road_junk_view"

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
	game.junk_in_tests = true
	Model.junk_rules = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42, 2)
	game.model.state.money = 5000
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "locomotive")
	game.model.state.active = {"id": "test_trip", "title": "Тестовый рейс", "phase": "outbound", "dropoffs": []}
	game.model.casino().trip_start()
	var glint = game.model.casino().glints()[0]
	game.screen = "game"
	game.rebuild()
	game.model.state.phase = "route"
	game.model.state.s = float(glint.s) - 5.0
	game.model.state.v = 1.0
	game.model.state.direction = 1
	game.model.state.reverser = 1
	game.model.state.brake = 0.0
	game.camera_s = float(game.model.state.s)
	game.rebuild()
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		game.camera_s = float(game.model.state.s)
		game.queue_redraw()
		await shot("glint_%d" % size.y)
		check(not game.glint_hits.is_empty(), "(%d) the glint is on the screen and can be clicked" % size.y)
	# a click on it picks it up
	game.camera_s = float(game.model.state.s)
	game.queue_redraw()
	await shot("glint_before_click")
	check(not game.glint_hits.is_empty(), "the glint hit exists")
	var at: Vector2 = game.glint_hits[0].position
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	game._unhandled_input(click)
	check(bool(game.model.casino().glints()[0].taken), "a click on the glint takes it")
	check(game.model.casino().junk_count("track_spike") + game.model.casino().junk_count("golden_bolt") == 1, "and it is in the bag")
	game.queue_redraw()
	await shot("glint_taken")
	# the result window
	game.model.state.last_result = {"title": "Лесопилка", "reward": 240, "final": false, "late": false, "notes": ["раньше срока +10%"], "finds": [
		{"id": "rusty_bolt", "name": "Ржавый болт", "count": 5}, {"id": "tie_plate", "name": "Подкладка", "count": 2},
		{"id": "fishplate", "name": "Стыковая накладка", "count": 1}, {"id": "track_spike", "name": "Путевой костыль", "count": 1}], "left_on_warehouse": 0}
	game.show_modal("result")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		await shot("result_finds_%d" % size.y)
	Model.junk_rules = false
	print("ROAD JUNK VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
