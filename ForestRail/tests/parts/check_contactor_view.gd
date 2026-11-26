extends Node
# «Скрутка» в окне (1.12, картинки П33): в кабине электровоза щелчок по дверце открывает шкафчик, концы проводов тащатся
# мышью к клеммам своего цвета, стык скручивается петлями курсора, рубильник в кабине вверх — пуск, вниз — стоп и провода
# разводятся; неверная скрутка даёт искру и сжигает предохранитель; рывками стык рвётся; щелчок по сгоревшему
# предохранителю ставит запасной; то же с клавиатуры. Шкафчик и рубильник помещаются в окне. Снимки при 1280 и 1600.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/core/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_contactor_view"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	game.update_hud()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	for i in range(3): await frame()
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func button(point: Vector2, pressed: bool) -> void:
	var e = InputEventMouseButton.new()
	e.position = point; e.global_position = point; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(e, true)
	await frame()

func move(point: Vector2, from: Vector2) -> void:
	var e = InputEventMouseMotion.new()
	e.position = point; e.global_position = point; e.relative = point - from; e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(e, true)
	await get_tree().process_frame

func key(code: int, pressed: bool = true, echo: bool = false) -> void:
	var e = InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = pressed; e.echo = echo
	game._input(e)

func click(point: Vector2) -> void:
	await button(point, true)
	await button(point, false)

func drag_wire(v, wire: int, terminal: int) -> void:
	var from = v.end_of(wire)
	var to = v.terminal(terminal)
	await button(from, true)
	for s in range(1, 7):
		await move(from.lerp(to, s / 6.0), from.lerp(to, (s - 1) / 6.0))
	await button(to, false)

# loops of the cursor round a joint, held down
func twist(v, wire: int, turns: float, sign: float = 1.0) -> void:
	var joint = v.terminal(v.c().at(wire))
	var start = joint + Vector2(0, -2)
	await button(start, true)
	var r = 26.0
	var prev = joint + Vector2(r, 0)
	await move(prev, start)
	var steps = int(turns * 16.0)
	for s in range(1, steps + 1):
		var a = TAU * float(s) / 16.0
		var p = joint + Vector2(cos(a), sign * sin(a)) * r
		await move(p, prev)
		prev = p
	await button(prev, false)

# a knotted end: through the ring of its colour, then on to its terminal, in one motion
func pull_through(v, wire: int) -> void:
	var from = v.end_of(wire)
	var ring = v.hook(wire)
	var to = v.terminal(v.c().terminal_of(wire))
	await button(from, true)
	var prev = from
	for s in range(1, 13):
		var p = from.lerp(ring, s / 6.0) if s <= 6 else ring.lerp(to, (s - 6) / 6.0)
		await move(p, prev)
		prev = p
	await button(to, false)

func switch_click() -> void:
	await click(game.electric_cab().switch_rect.get_center())

func fixture():
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	Fixtures.equip(m, "locomotive")
	m.select_vehicle("locomotive")
	m.object_state("locomotive").levels = {}   # three wires
	m.state.phase = "route"
	m.state.s = 100
	m.state.brake = 1.0
	m.state.throttle = 0.0
	m.contactor().stop()
	return m

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
	game.contactor_in_tests = true
	Model.contactor_rules = true
	for size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		var tag = str(size.x)
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		game.model = fixture()
		game.screen = "game"
		game.rebuild()
		game.camera_s = 100; game.camera_y = 0; game.camera_x = game.get_viewport_rect().size.x * 0.65
		game.toggle_cab_view()
		for i in range(8): await frame()
		check(game.cab_active() and game.electric_cab().revised(), "the new cab of the electric locomotive opens " + tag)
		var hatch = Rect2()
		for hit in game.cab_hits:
			if hit.id == "contactor": hatch = hit.rect
		check(hatch.size.x > 10.0, "the cabinet door can be clicked " + tag)
		await shot("cab_closed_" + tag)
		await click(hatch.get_center())
		var v = game.contactor_view()
		check(v.open, "a click on the door opens the cabinet " + tag)
		for i in range(6): await frame()
		var view = Rect2(Vector2.ZERO, game.get_viewport_rect().size)
		var sw: Rect2 = game.electric_cab().switch_rect
		check(view.encloses(v.box_rect()) and view.encloses(v.door_rect()) and not v.box_rect().intersects(sw) and not v.door_rect().intersects(sw), "the cabinet fits in the window and leaves the knife switch free " + tag)
		var c = game.model.contactor()
		check(c.count() == 3 and not c.all_joined(), "three free wires inside " + tag)
		await shot("box_open_" + tag)
		for w in range(c.count()):
			await drag_wire(v, w, c.terminal_of(w))
		check(c.all_joined() and not c.ready(), "the mouse brings every end to its terminal; not twisted yet " + tag)
		await shot("box_joined_" + tag)
		await twist(v, 0, 1.3)
		check(c.twisted(0) and not c.tight(0), "one loop: a weak twist " + tag)
		for w in range(c.count()):
			await twist(v, w, 3.3)
		check(c.ready() and c.tight(0) and c.tight(2), "three loops round each joint: tight twists, the lamp ГОТОВ " + tag)
		await shot("box_ready_" + tag)
		await switch_click()
		check(c.is_on() and bool(game.model.state.engine), "the knife switch starts it " + tag)
		await shot("box_on_" + tag)
		await switch_click()
		check(not c.is_on() and not c.all_joined(), "the switch again stops it and the wires come apart " + tag)
		# a yank tears a twist
		await drag_wire(v, 0, c.terminal_of(0))
		await twist(v, 0, 1.2)
		var joint = v.terminal(c.at(0))
		var scraps = c.scraps()
		await button(joint, true)
		var prev = joint
		for y in range(8):   # no frame between the yanks: under a loaded run a frame each made them «slow»
			var p = joint + Vector2(90.0 if y % 2 == 0 else -90.0, 0)
			var e = InputEventMouseMotion.new()
			e.position = p; e.global_position = p; e.relative = p - prev; e.button_mask = MOUSE_BUTTON_MASK_LEFT
			get_tree().root.push_input(e, true)
			prev = p
		await button(prev, false)
		check(not c.joined(0) and c.scraps() == scraps + 1, "yanking the held joint tears it, a scrap is left " + tag)
		# a wrong twist: a spark, a fuse burns
		await drag_wire(v, 0, c.terminal_of(1))
		await drag_wire(v, 1, c.terminal_of(0))
		await drag_wire(v, 2, c.terminal_of(2))
		for w in range(3): await twist(v, w, 3.3)
		await switch_click()
		check(not c.is_on() and v.spark_t > 0.0 and game.toast.contains("Искра") and c.fuse_count("burnt") == 1, "a wrong twist sparks and burns a fuse " + tag)
		await shot("box_spark_" + tag)
		var slot = (c.fuses() as Array).find("burnt")
		var spares = c.spares()
		await click(v.holder(slot).get_center())
		check(c.fuse_count("burnt") == 0 and c.spares() == spares - 1, "a click on the burnt fuse puts a spare in " + tag)
		# after a repair the ends lie in a knot: each is pulled through the ring of its colour, then to its terminal
		c.stop()
		c.st().knot = [0, 1, 2]
		await shot("box_knot_" + tag)
		await drag_wire(v, 0, c.terminal_of(0))
		check(not c.joined(0) and c.knotted(0), "a knotted end does not take to its terminal " + tag)
		for w in range(3): await pull_through(v, w)
		check(c.knot_left() == 0 and c.all_joined(), "pulled through their rings, the ends take to their terminals " + tag)
		# a loop the other way takes the last one off
		await twist(v, 0, 3.3)
		var loops = c.turns(0)
		await twist(v, 0, 1.2, -1.0)
		check(is_equal_approx(c.turns(0), loops - 1.0), "a loop the other way takes a loop off (%s from %s) %s" % [c.turns(0), loops, tag])
		c.st().loops[1] = [1.0, 0.55, 0.42]   # a slack twist: its weakest loop blinks red, the line says what to do
		c.st().loops[2] = [1.0, 1.0, 1.0]
		check(v.weak_wire() == 1 and c.weakest(1) == 2, "a slack twist shows its weakest loop " + tag)
		await shot("box_loops_" + tag)
		# the keyboard: a digit for the wire, a digit for the terminal, the space held twists, Enter is the switch
		c.stop()
		for w in range(c.count()):
			key(KEY_1 + w)
			key(KEY_1 + c.terminal_of(w))
			for r in range(40): key(KEY_SPACE, true, r > 0)
		check(c.ready(), "the keyboard wires and twists them too " + tag)
		key(KEY_ENTER)
		check(c.is_on(), "Enter is the switch " + tag)
		key(KEY_ESCAPE)
		check(not v.open, "Esc closes the cabinet " + tag)
		await shot("cab_live_" + tag)
		c.stop()
		game.cab_view = false
		game.update_pult_transform()
	Model.contactor_rules = false
	print("CONTACTOR VIEW CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
