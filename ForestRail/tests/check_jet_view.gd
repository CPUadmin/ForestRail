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
	check(game.model.state.consist_ids.size() == 4, "the jet pulls four wagons")
	game.zoom_level = game.fit_train_zoom()
	var vp = game.get_viewport_rect().size
	var tail_x = vp.x * 0.65 - game.model.train_length() * 96.0 * game.view_scale()
	check(game.zoom_level >= 0.45 and tail_x > 0.0, "the whole train of the jet is in the window (zoom %.2f, window %d, the tail at %.0f)" % [game.zoom_level, int(vp.x), tail_x])
	# and on a narrow window the zoom goes out further (the formula of the fit)
	var narrow_zoom = clampf(minf(10.5 / maxf(10.5, game.model.train_length()), 0.62 * 1280.0 / (96.0 * game.model.train_length())), 0.45, 1.0)
	check(1280.0 * 0.65 - game.model.train_length() * 96.0 * narrow_zoom > 0.0, "and in a 1280 window too (zoom %.2f)" % narrow_zoom)
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
