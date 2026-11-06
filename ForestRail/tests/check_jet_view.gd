extends Node
# В6.6: пульт реактивного поезда (scripts/jet_pult.gd): крышка, четыре предохранителя, пуск, табло отсчёта, тяга, парашют, форсаж; в мире и в кабине.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_jet_view"

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

func click(pos: Vector2, pressed: bool) -> void:
	var e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	if pressed: game._unhandled_input(e)
	else: game._input(e)

func tap(pos: Vector2) -> void:
	click(pos, true)
	click(Vector2.ZERO, false)

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
	game.model.new_game(42, 2)
	game.model.state.money = 200000
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "jet")
	game.screen = "game"
	game.model.state.phase = "route"
	game.model.state.brake = 1.0
	game.model.state.s = 400.0
	game.camera_s = 400.0
	game.camera_x = 1040
	game.rebuild()
	check(game.art.textures.has("vehicles/jet_body"), "the jet has its own body picture")
	check(game.world_control_ids().is_empty() and game.own_pult() == game.jpult, "no ordinary levers: the jet has its own pult")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.queue_redraw()
		await shot("jet_world_cold_%d" % size.y)
		var p = game.jpult
		check(game.get_viewport_rect().encloses(p.bounds()), "the pult fits the window %d" % size.y)
		# the cover first: a click on the closed cover opens it; the start button is under it
		check(not game.model.jet.cover_open, "the cap is closed at first")
		tap(p.cover_rect().get_center())
		check(game.model.jet.cover_open, "a click opens the cap")
		tap(p.cover_tab().get_center())
		check(not game.model.jet.cover_open, "the tab closes it again")
		tap(p.cover_rect().get_center())
		# the fuses: a click flips the toggle; the start stays locked until all four have been flipped
		tap(p.fuse_rect(0).get_center())
		tap(p.fuse_rect(2).get_center())
		check(game.model.jet.fuse_code() == "1010", "two clicks on the fuses give the code 1010 (%s)" % game.model.jet.fuse_code())
		tap(p.start_rect().get_center())
		check(not game.model.jet.counting, "the start button is locked while two toggles are not touched")
		game.queue_redraw()
		await shot("jet_world_locked_%d" % size.y)
		for i in [1, 3]:
			tap(p.fuse_rect(i).get_center())
			tap(p.fuse_rect(i).get_center())
		check(game.model.jet.start_unlocked() and game.model.jet.fuse_code() == "1010", "after all four are flipped the start opens and the code is kept")
		tap(p.start_rect().get_center())
		check(game.model.jet.counting and game.model.jet.mode.name == "Экономный", "the start begins the countdown in the mode of the fuses")
		game.queue_redraw()
		await shot("jet_world_countdown_%d" % size.y)
		# a fuse during the countdown cancels it
		tap(p.fuse_rect(3).get_center())
		check(not game.model.jet.counting, "a fuse flipped during the countdown cancels it")
		tap(p.fuse_rect(3).get_center())
		tap(p.fuse_rect(0).get_center())
		tap(p.fuse_rect(2).get_center())
		tap(p.start_rect().get_center())
		for i in range(60 * 11): game.model.jet.step(1.0 / 60.0)
		check(game.model.jet.started, "the engine is lit after the countdown")
		# the throttle slider holds
		var t0 = p.track(0)
		tap(Vector2(t0.get_center().x, t0.position.y + t0.size.y * 0.2))
		check(absf(float(game.model.state.throttle) - 0.8) < 0.05, "the thrust lever stays where it was left (%.2f)" % float(game.model.state.throttle))
		for i in range(60 * 8): game.model.jet.step(1.0 / 60.0)
		game.model.jet.throttle = 0.8
		game.queue_redraw()
		await shot("jet_world_lit_%d" % size.y)
		# the chute: one ring, no second button without the gadget
		tap(p.chute_button(false).get_center())
		check(game.model.jet.chutes_open == 1 and game.model.jet.chutes_left == 0, "the chute button pulls the ring")
		game.queue_redraw()
		await shot("jet_world_chute_%d" % size.y)
		game.cab_view = true
		game.update_pult_transform()
		for i in range(8): await get_tree().process_frame
		game.queue_redraw()
		await shot("jet_cab_%d" % size.y)
		check(game.get_viewport_rect().encloses(p.bounds()), "the pult fits the window in the cab %d" % size.y)
		game.cab_view = false
		game.model.jet.reset()
		game.model.state.throttle = 0.0
		game.model.state.brake = 1.0
	# the lesson line follows the state
	var Pult = preload("res://scripts/jet_pult.gd")
	var Jet = preload("res://scripts/jet.gd")
	var j = Jet.new()
	check("колпачок" in Pult.hint(j, 1.0, 0.0), "the lesson: open the cover")
	j.open_cover(true)
	check("тумблер" in Pult.hint(j, 1.0, 0.0), "the lesson: flip every toggle")
	for i in range(4): j.flip_fuse(i)
	check("Пуск" in Pult.hint(j, 1.0, 0.0), "the lesson: press the start")
	j.start()
	check("отсчёт" in Pult.hint(j, 1.0, 0.0), "the lesson: the countdown")
	for i in range(60 * 16): j.step(1.0 / 60.0)
	check("рычаг" in Pult.hint(j, 0.0, 0.0), "the lesson: the engine burns, raise the lever")
	print("JET VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
