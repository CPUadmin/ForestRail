extends Node
# Windowed look at the sail train: outside with the valve open and the pipes frosted, and the pult.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_sail_view"

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
	Fixtures.equip(game.model, "sail")
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
		for trim in [0.1, 0.5, 1.0]:
			game.model.set_sail_trim(trim)
			for i in range(120): game.model.physics_step(1.0 / 60.0)
			game.camera_s = float(game.model.state.s)
			game.queue_redraw()
			await shot("sail_trim_%d_%d" % [roundi(trim * 100), size.y])
		check(game.sail_rect.size.x > 40.0 and game.sail_rect.size.y > 40.0, "the sail can be taken with the mouse %d" % size.y)
		# holding the free end of the boom and moving the hand sets the trim, whatever the car does
		var grab = game.sail_rect.position + game.sail_rect.size * 0.5
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = grab
		game._unhandled_input(click)
		check(game.drag == "sail", "the sail is taken with the mouse %d" % size.y)
		var before = float(game.model.sail_trim)
		var step = InputEventMouseMotion.new()
		step.position = grab
		step.relative = Vector2(-60, 0)
		game._input(step)
		var after_back = float(game.model.sail_trim)
		check(after_back != before, "moving the hand changes the trim (%.2f to %.2f)" % [before, after_back])
		game.model.state.s += 25.0   # the car runs away from the camera while the mouse stays still
		game.camera_s = float(game.model.state.s) - 25.0
		var still = InputEventMouseMotion.new()
		still.position = grab + Vector2(0, 0)
		still.relative = Vector2.ZERO
		game._input(still)
		check(is_equal_approx(float(game.model.sail_trim), after_back), "a car running away from the camera does not move the sail by itself (%.3f vs %.3f, drag %s)" % [float(game.model.sail_trim), after_back, game.drag])
		check(game.model.sail_held, "the sail is in the hand while the button is held")
		# the camera keeps following the car while the sail is held (it used to freeze, and the car ran away)
		var camera_before = float(game.camera_s)
		game.model.state.s = float(game.model.state.s) + 30.0
		for i in range(40): game._process(0.016)
		check(float(game.camera_s) > camera_before + 10.0, "the camera follows the car while the sail is held (%.1f to %.1f)" % [camera_before, float(game.camera_s)])
		game.model.state.s = float(game.model.state.s) - 30.0
		# let go away from the cleat: the sail flogs
		var away = InputEventMouseButton.new()
		away.button_index = MOUSE_BUTTON_LEFT
		away.pressed = false
		away.position = grab + Vector2(300, -200)
		game._input(away)
		check(not game.model.sail_engaged() and game.drag == "", "let go in the air: nobody holds the sail")
		# take it again and let go over the cleat: the sheet is made fast
		game._unhandled_input(click)
		check(game.model.sail_held, "taken again")
		if game.sail_cleat_point != Vector2.ZERO:
			var at_cleat = InputEventMouseButton.new()
			at_cleat.button_index = MOUSE_BUTTON_LEFT
			at_cleat.pressed = false
			at_cleat.position = game.sail_cleat_point
			game._input(at_cleat)
			check(game.model.sail_cleated and not game.model.sail_held, "let go over the cleat: the sheet is fast")
			await shot("sail_cleated_%d" % size.y)
		game.model.sail_release()
		game.model.sail_cleated = false
		game.model.state.v = 0.0
		game.model.state.s = 3000.0
	print("SAIL VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
