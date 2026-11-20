extends Node
# The ignition key of the petrol motorcar (owner 14.11 and 16.11, BRIEF_key): three positions ВЫКЛ -> ЗАЖИГАНИЕ ->
# СТАРТЕР, the starter held about a second, the spring back, the cough of a cold engine and the retry, at most two
# coughs in a row with the choke out, the choke going back in by itself, the creative mode always starting, ВЫКЛ
# stopping the engine, the key of the keyboard, the same dice for the same career. Pictures of the key in the cab
# and outside at 1280x720 and 1600x900 for the eyes.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/core/model.gd")
const Ignition = preload("res://scripts/vehicles/motorcar/ignition.gd")
const DT = 1.0 / 60.0

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_key_start"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func fixture(seed_number: int = 42, mode: String = "career"):
	var m = Model.new()
	m.new_game(seed_number, 2, mode)
	m.state.money = 10000
	Fixtures.equip(m, "motorcar")
	m.select_vehicle("motorcar")
	m.state.phase = "route"
	m.state.s = 100
	m.state.brake = 1.0
	m.state.throttle = 0.0
	m.state.gear = 0
	m.state.engine = false
	return m

func set_temp(m, temp: float) -> void:
	m.state.fleet_by_id.motorcar.temp = temp

# the first attempt number from `start` whose dice pass the test
func attempt_where(m, start: int, ok: Callable) -> int:
	for a in range(start, start + 20000):
		if ok.call(m.key_roll(a)): return a
	return -1

func steps(key, seconds: float) -> void:
	for i in range(roundi(seconds / DT)): key.update(DT, Vector2.ZERO)

func model_checks() -> void:
	# the three positions and the spring
	var m = fixture()
	var key = Ignition.new(m)
	check(key.pos == Ignition.OFF, "the key starts at ВЫКЛ")
	key.press()
	check(key.pos == Ignition.ON, "a press turns ВЫКЛ to ЗАЖИГАНИЕ")
	steps(key, 0.2)
	check(key.pos == Ignition.ON, "a short hold stays on ЗАЖИГАНИЕ")
	key.release()
	check(key.pos == Ignition.ON, "a click leaves the key on ЗАЖИГАНИЕ")
	steps(key, 0.5)
	check(absf(key.angle - Ignition.ANGLES[Ignition.ON]) < 0.02, "the drawn key stands on the ЗАЖИГАНИЕ mark")
	key.press()
	steps(key, 0.1)
	key.release()
	check(key.pos == Ignition.OFF, "a click on ЗАЖИГАНИЕ turns it back to ВЫКЛ")
	key.drag_to(Ignition.ANGLES[Ignition.START])
	check(key.pos == Ignition.START, "dragging round the lock reaches СТАРТЕР")
	key.drag_to(Ignition.ANGLES[Ignition.ON])
	check(key.pos == Ignition.ON, "and back to ЗАЖИГАНИЕ")

	# a warm engine: held a second on the starter it catches; it springs back to ЗАЖИГАНИЕ when let go
	m = fixture()
	set_temp(m, 0.5)
	check(is_equal_approx(m.key_start_chance(), 0.95), "a warm engine catches at about 95%")
	m.state.start_tries = attempt_where(m, 0, func(r): return r < 0.95)
	key = Ignition.new(m)
	key.press()
	steps(key, 0.35)
	check(key.pos == Ignition.START and key.cranking(), "held past ЗАЖИГАНИЕ the key goes on to СТАРТЕР and cranks")
	steps(key, 0.8)
	check(not m.state.engine, "the starter turns about a second before the engine catches")
	steps(key, 0.3)
	check(m.state.engine and "catch" in m.events, "held a second on the starter the warm engine catches")
	key.release()
	check(key.pos == Ignition.ON, "let go, the key springs back to ЗАЖИГАНИЕ")
	steps(key, 0.02)
	check(key.angle < Ignition.ANGLES[Ignition.START], "the key is on its way back")
	steps(key, 0.5)
	check(absf(key.angle - Ignition.ANGLES[Ignition.ON]) < 0.02 and m.state.engine, "it rests on ЗАЖИГАНИЕ, the engine runs")
	key.press()
	steps(key, 0.05)
	key.release()
	check(key.pos == Ignition.OFF and not m.state.engine, "turned to ВЫКЛ the engine stops")

	# a cold engine without the choke coughs, a retry catches
	m = fixture()
	set_temp(m, Model.TEMP_AMBIENT)
	check(is_equal_approx(m.key_start_chance(), 0.4), "a cold engine without the choke catches at about 40%")
	var bad = attempt_where(m, 0, func(r): return r >= 0.4 and r < 0.8)
	m.state.start_tries = bad
	m.events.clear()
	check(not m.key_crank() and not m.state.engine and "cough" in m.events, "the cold engine coughs")
	check(m.message.contains("подсос"), "the cough of a cold engine names the choke")
	m.state.start_tries = bad
	m.set_choke(true)
	check(is_equal_approx(m.key_start_chance(), 0.8), "the choke out makes it about 80%")
	check(m.key_crank() and m.state.engine, "the same dice with the choke out catch")

	# never more than two coughs in a row with the choke out
	m = fixture()
	set_temp(m, Model.TEMP_AMBIENT)
	m.set_choke(true)
	var unlucky = -1
	for a in range(0, 50000):
		if m.key_roll(a) >= 0.8 and m.key_roll(a + 1) >= 0.8 and m.key_roll(a + 2) >= 0.8:
			unlucky = a
			break
	check(unlucky >= 0, "there is a run of three bad dice to test the cap")
	m.state.start_tries = unlucky
	var results = []
	for i in range(3):
		results.append(m.key_crank())
	check(results == [false, false, true], "with the choke out the third try always catches (%s)" % str(results))
	# without the choke the same dice keep coughing
	m = fixture()
	set_temp(m, Model.TEMP_AMBIENT)
	m.state.start_tries = unlucky
	results = []
	for i in range(3): results.append(m.key_crank())
	check(results == [false, false, false], "without the choke there is no such help (%s)" % str(results))

	# the choke goes back in by itself after half a minute of running
	m = fixture()
	m.set_choke(true)
	m.start_engine(true)
	for i in range(roundi(20.0 / DT)): m.physics_step(DT)
	check(m.choke_out(), "the choke stays out for the first 20 s of running")
	for i in range(roundi(11.0 / DT)): m.physics_step(DT)
	check(not m.choke_out() and "choke_in" in m.events, "after about 30 s of running it goes back in with a click")

	# the creative mode always starts
	m = fixture(42, "creative")
	set_temp(m, Model.TEMP_AMBIENT)
	var all = true
	for i in range(30):
		m.state.engine = false
		if not m.key_crank(): all = false
	check(all, "the creative mode always starts")

	# the rules keep their refusals
	m = fixture()
	m.state.throttle = 0.5
	key = Ignition.new(m)
	key.press()
	steps(key, 1.5)
	check(not m.state.engine and "refused" in key.events and m.message.contains("0%"), "the throttle not at zero keeps its refusal")
	check(not key.cranking(), "a refused start does not crank")

	# the same dice for the same career and attempt; another career has other dice
	var a1 = fixture(7)
	var a2 = fixture(7)
	var b1 = fixture(8)
	var same = true
	var other = false
	for a in range(40):
		if a1.key_roll(a) != a2.key_roll(a): same = false
		if a1.key_roll(a) != b1.key_roll(a): other = true
	check(same and other, "the dice depend on the career seed and the attempt only")
	var c1 = fixture(7)
	var c2 = fixture(7)
	var r1 = []
	var r2 = []
	for i in range(10):
		c1.state.engine = false
		c2.state.engine = false
		r1.append(c1.key_crank())
		r2.append(c2.key_crank())
	check(r1 == r2, "two runs of the same career start alike")

	# an old save without the key fields
	m = fixture()
	for field in ["choke", "choke_run", "start_tries", "start_fails"]: m.state.erase(field)
	set_temp(m, 0.5)
	check(not m.choke_out(), "an old save has the choke in")
	m.key_crank()
	check(int(m.state.start_tries) == 1, "an old save counts its attempts from zero")

	# the fob is a pendulum: a turn of the key sets it swinging, it settles again
	m = fixture()
	key = Ignition.new(m)
	key.press()
	var peak = 0.0
	for i in range(30):
		key.update(DT, Vector2.ZERO)
		peak = maxf(peak, absf(key.fob_theta))
	check(peak > 0.02, "a turn of the key swings the fob (%.3f)" % peak)
	key.release()
	steps(key, 6.0)
	check(absf(key.fob_theta) < 0.01, "the fob settles (%.4f)" % key.fob_theta)
	key.reduce_motion = true
	key.press()
	steps(key, 0.5)
	check(key.fob_theta == 0.0 and key.shake_offset() == Vector2.ZERO, "less motion: no swing and no shake")

func frame() -> void:
	game.update_hud()
	game.art_world.update_view()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	for i in range(3): await frame()
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func key_event(pressed: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = int(game.settings.keys.ignition)
	event.physical_keycode = int(game.settings.keys.ignition)
	event.pressed = pressed
	game._input(event)

func game_steps(seconds: float) -> void:
	for i in range(roundi(seconds / DT)): game.ignition_step(DT)

func mouse(point: Vector2, pressed: bool) -> void:
	var e = InputEventMouseButton.new()
	e.position = point; e.global_position = point; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed
	get_tree().root.push_input(e, true)
	await frame()

func game_checks() -> void:
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.set_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	for size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model = fixture()
		set_temp(game.model, 0.5)
		game.model.state.start_tries = attempt_where(game.model, 0, func(r): return r < 0.95)
		game.ignition_cache = null
		game.screen = "game"
		game.rebuild()
		game.camera_s = 100; game.camera_y = 0; game.camera_x = game.get_viewport_rect().size.x * 0.65
		for i in range(4): await frame()
		var tag = str(size.x)
		await shot("outside_off_" + tag)
		# the keyboard: holding the key turns it on to the starter, the engine catches, letting go springs it back
		key_event(true)
		check(game.ignition().held and game.ignition().pos == Ignition.ON, "the keyboard key takes the ignition key " + tag)
		game_steps(0.6)
		check(game.ignition().pos == Ignition.START, "held, the keyboard key turns it to СТАРТЕР " + tag)
		await shot("outside_start_" + tag)
		game_steps(0.8)
		key_event(false)
		check(game.model.state.engine and game.ignition().pos == Ignition.ON, "the keyboard way starts the engine and springs back " + tag)
		key_event(true)
		game.pause_game()
		key_event(false)
		game.close_modal()
		check(game.model.state.engine and not game.ignition().held, "interrupting a short press does not switch off a running engine " + tag)
		game_steps(0.15)
		await shot("outside_fob_swing_" + tag)
		game_steps(1.0)
		game.model.set_choke(true)
		await shot("outside_on_choke_" + tag)
		# the cab: the painted lock, key, fob and choke in the pult
		game.toggle_cab_view()
		for i in range(8): await frame()
		check(game.cab_active(), "the cab opens " + tag)
		await shot("cab_on_choke_out_" + tag)
		# a click on the key (mouse) turns it to ВЫКЛ
		var lock = Vector2.ZERO
		for hit in game.grip_hits:
			if hit.id == "start" and hit.get("closeup", false): lock = hit.position
		check(lock != Vector2.ZERO, "the key has its place in the cab pult " + tag)
		await mouse(lock, true)
		game_steps(0.05)
		await mouse(lock, false)
		game_steps(0.6)
		check(not game.model.state.engine and game.ignition().pos == Ignition.OFF, "a click on the key in the cab stops the engine " + tag)
		# the choke knob clicks in and out
		var choke = Rect2()
		for hit in game.ignition_hits: choke = hit.rect
		check(choke.size.x > 10.0, "the choke knob is there " + tag)
		await mouse(choke.get_center(), true)
		await mouse(choke.get_center(), false)
		check(not game.model.choke_out(), "a click pushes the choke in " + tag)
		await shot("cab_off_choke_in_" + tag)
		await mouse(lock, true)
		game_steps(0.6)
		check(game.ignition().pos == Ignition.START, "the mouse held on the key reaches СТАРТЕР " + tag)
		await shot("cab_start_" + tag)
		await mouse(lock, false)
		game_steps(0.12)
		await shot("cab_fob_swing_" + tag)
		key_event(true)
		game_steps(0.55)
		game.test_mode = false
		game.on_window_focus_exited()
		game.test_mode = true
		key_event(false)
		game.close_modal()
		game_steps(1.5)
		check(not game.ignition().held and not game.model.state.engine, "a key released while the window is away cannot start the engine after resuming " + tag)
		game.cab_view = false
		game.update_pult_transform()

func run() -> void:
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	model_checks()
	await game_checks()
	print("KEY START CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
