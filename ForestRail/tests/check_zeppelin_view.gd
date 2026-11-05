extends Node
# В6.5, шаг 3: кабина цеппелина: пульт (газ, шаг, ручка, тормоз, пуск, щитки) и приборы в мире и в кабине; рычаги держат положение.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_zeppelin_view"

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

func move(pos: Vector2) -> void:
	var e = InputEventMouseMotion.new()
	e.position = pos
	e.relative = Vector2(0, 1)
	game._input(e)

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
	game.model.state.money = 20000
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "zeppelin")
	game.screen = "game"
	game.model.state.phase = "route"
	game.model.state.engine = true
	game.camera_s = float(game.model.state.s)
	game.camera_x = 1040
	game.rebuild()
	check(game.art.textures.has("vehicles/zeppelin_body"), "the zeppelin has its own body picture")
	check(game.world_control_ids().is_empty(), "no ordinary levers on the zeppelin")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model.state.v = 20.0
		game.model.zep.v = 20.0
		game.model.state.throttle = 0.7
		game.model.set_zeppelin_pitch(0.4)
		game.model.zep.rpm = 2100.0
		game.queue_redraw()
		await shot("zeppelin_world_%d" % size.y)
		var z = game.zpult
		check(game.get_viewport_rect().encloses(z.bounds()), "the pult fits the window %d" % size.y)
		# the levers hold: grab the throttle in the middle, let go: it stays
		var t0 = z.track(0)
		click(t0.get_center(), true)
		check(game.drag == "zpult", "a click on the throttle takes the drag")
		move(Vector2(t0.get_center().x, t0.position.y + t0.size.y * 0.25))
		click(Vector2(t0.get_center().x, t0.position.y + t0.size.y * 0.25), false)
		check(game.drag == "", "released")
		check(absf(float(game.model.state.throttle) - 0.75) < 0.03, "the throttle stands where it was left (%.2f)" % float(game.model.state.throttle))
		var t2 = z.track(2)
		click(Vector2(t2.get_center().x, t2.end.y - t2.size.y * (9.5 / 18.0)), true)
		click(Vector2.ZERO, false)
		check(absf(game.model.zeppelin_stick() - 3.5) < 0.4, "the joystick holds +3.5 degrees (%.2f)" % game.model.zeppelin_stick())
		check(not bool(game.model.state.get("zep_air_brake", false)), "the air brake is off")
		click(z.air_button().get_center(), true)
		click(Vector2.ZERO, false)
		check(bool(game.model.state.get("zep_air_brake", false)), "a click on the flaps button turns the air brake on")
		click(z.air_button().get_center(), true)
		click(Vector2.ZERO, false)
		check(not bool(game.model.state.get("zep_air_brake", false)), "and off again")
		game.queue_redraw()
		await shot("zeppelin_world_set_%d" % size.y)
		game.cab_view = true
		game.update_pult_transform()
		for i in range(8): await get_tree().process_frame
		game.queue_redraw()
		await shot("zeppelin_cab_%d" % size.y)
		check(game.get_viewport_rect().encloses(z.bounds()), "the pult fits the window in the cab %d" % size.y)
		game.cab_view = false
		game.model.state.throttle = 0.0
		game.model.set_zeppelin_stick(0.0)
	# the movable parts: the stick up, the flaps open, the propeller turns: pictures of the machine close by
	game.cab_view = false
	game.screen = "game"
	game.model.state.phase = "route"
	game.model.state.s = 600.0
	game.camera_s = 600.0
	game.model.state.v = 30.0
	game.model.zep.v = 30.0
	game.model.state.engine = true
	game.model.state.throttle = 1.0
	game.model.zep.rpm = 2300.0
	game.zoom_level = 1.5
	game.model.zep.set_stick(-4.0)
	for i in range(90): game.model.zep.animate(1.0 / 60.0)
	game.queue_redraw()
	await shot("zeppelin_parts_down")
	game.model.zep.set_stick(10.0)
	game.model.zep.set_air_brake(true)
	for i in range(150): game.model.zep.animate(1.0 / 60.0)
	game.model.zep.rpm = 400.0
	game.queue_redraw()
	await shot("zeppelin_parts_up_flaps")
	check(game.model.zep.wing_angle < -30.0 and game.model.zep.tail_angle < -5.0, "the picture state follows the levers (wing %.1f, tail %.1f)" % [game.model.zep.wing_angle, game.model.zep.tail_angle])
	game.zoom_level = 1.0
	# the garage and the depot with the zeppelin chosen
	game.model.state.phase = "depot"
	game.screen = "depot"
	game.tab = "Гараж"
	game.animate_in_tests = false
	game.rebuild()
	for i in range(8): await get_tree().process_frame
	for scroll in game.ui.find_children("*", "ScrollContainer", true, false): scroll.scroll_vertical = 100000
	for i in range(6): await get_tree().process_frame
	game.queue_redraw()
	await shot("zeppelin_garage")
	game.tab = "Улучшения"
	game.rebuild()
	for i in range(8): await get_tree().process_frame
	await shot("zeppelin_workshop")
	print("ZEPPELIN VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
