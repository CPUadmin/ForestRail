extends Node
# В6.6: реактивный: снаружи обычные рычаги (тормоз и газ), пульт запуска только в кабине (scripts/jet_pult.gd): колпачок, четыре тумблера с лампочками,
# пуск после переключения каждого, табло отсчёта, тяга, парашют, форсаж; вид из кабины.
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
	# outside the cab: the usual levers, no own pult
	check(not game.has_own_pult() and game.world_control_ids() == ["brake", "throttle"], "outside the cab the jet has the usual brake and throttle")
	check(not game.zpult_world_visible(), "and no pult in the world")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.cab_view = false
		game.queue_redraw()
		await shot("jet_world_levers_%d" % size.y)
		# the cab: the pult appears on the dashboard
		game.cab_view = true
		game.update_pult_transform()
		for i in range(8): await get_tree().process_frame
		game.queue_redraw()
		await shot("jet_cab_cold_%d" % size.y)
		check(game.has_own_pult() and game.own_pult() == game.jpult, "in the cab the jet has its pult")
		var p = game.jpult
		check(game.get_viewport_rect().encloses(p.bounds()), "the pult fits the window in the cab %d" % size.y)
		check(not game.model.jet.cover_open, "the cap is closed at first")
		tap(p.cover_rect().get_center())
		check(game.model.jet.cover_open, "a click opens the cap")
		tap(p.cover_tab().get_center())
		check(not game.model.jet.cover_open, "the tab closes it again")
		tap(p.fuse_rect(1).get_center())
		check(game.model.jet.fuse_code() == "" and game.model.jet.cover_open, "a click where the toggle is under a closed cap opens the cap and switches nothing on")
		# the toggles: the order of switching on is the code; the start opens only when all four are on
		tap(p.fuse_rect(3).get_center())
		tap(p.fuse_rect(2).get_center())
		check(game.model.jet.fuse_code() == "43" and game.model.jet.fuses_on() == 2, "two clicks switch two toggles on in that order (%s)" % game.model.jet.fuse_code())
		tap(p.start_rect().get_center())
		check(not game.model.jet.counting, "the start button is locked while two toggles are off")
		game.queue_redraw()
		await shot("jet_cab_locked_%d" % size.y)
		tap(p.fuse_rect(1).get_center())
		tap(p.fuse_rect(0).get_center())
		check(game.model.jet.start_unlocked() and game.model.jet.fuse_code() == "4321", "after all four are on the start opens and the order is kept (%s)" % game.model.jet.fuse_code())
		tap(p.start_rect().get_center())
		check(game.model.jet.counting and game.model.jet.mode.name == "Экономный", "the start begins the countdown in the mode of this order")
		game.queue_redraw()
		await shot("jet_cab_countdown_%d" % size.y)
		tap(p.fuse_rect(3).get_center())
		check(not game.model.jet.counting, "a toggle switched off during the countdown cancels it")
		tap(p.fuse_rect(3).get_center())   # on again: now it is the last in the order
		check(game.model.jet.fuse_code() == "3214", "and on again it goes last in the order (%s)" % game.model.jet.fuse_code())
		tap(p.start_rect().get_center())
		for i in range(60 * 11): game.model.jet.step(1.0 / 60.0)
		check(game.model.jet.started, "the engine is lit after the countdown")
		var t0 = p.track(0)
		tap(Vector2(t0.get_center().x, t0.position.y + t0.size.y * 0.2))
		check(absf(float(game.model.state.throttle) - 0.8) < 0.05, "the thrust lever stays where it was left (%.2f)" % float(game.model.state.throttle))
		for i in range(60 * 8): game.model.jet.step(1.0 / 60.0)
		game.queue_redraw()
		await shot("jet_cab_lit_%d" % size.y)
		tap(p.chute_button(false).get_center())
		check(game.model.jet.chutes_open == 1 and game.model.jet.chutes_left == 0, "the chute button pulls the ring")
		game.queue_redraw()
		await shot("jet_cab_chute_%d" % size.y)
		game.cab_view = false
		game.update_pult_transform()
		game.queue_redraw()
		await shot("jet_world_lit_%d" % size.y)
		game.model.jet.reset()
		game.model.state.throttle = 0.0
		game.model.state.brake = 1.0
	# the throttle without a lit engine says where the start is
	var cold = game.model
	cold.state.throttle = 0.5
	cold.message = ""
	cold.jet_hint_cd = 0.0
	cold.state.phase = "route"
	cold.physics_step(1.0 / 60.0)
	check("кабину" in cold.message, "the lever without a lit engine says where the start is (%s)" % cold.message)
	cold.state.throttle = 0.0
	# the lesson line follows the state
	var Pult = preload("res://scripts/jet_pult.gd")
	var Jet = preload("res://scripts/jet.gd")
	var j = Jet.new()
	check("колпачок" in Pult.hint(j, 1.0, 0.0), "the lesson: open the cap")
	j.open_cover(true)
	check("тумблер" in Pult.hint(j, 1.0, 0.0), "the lesson: switch all the toggles on")
	for i in range(4): j.flip_fuse(i)
	check("Пуск" in Pult.hint(j, 1.0, 0.0), "the lesson: press the start")
	j.start()
	check("отсчёт" in Pult.hint(j, 1.0, 0.0), "the lesson: the countdown")
	for i in range(60 * 16): j.step(1.0 / 60.0)
	check("рычаг" in Pult.hint(j, 0.0, 0.0), "the lesson: the engine burns, raise the lever")
	print("JET VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
