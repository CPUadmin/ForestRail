extends Node
# 1.4.10 «Скрутка» в окне: в кабине электровоза клик по крышке КОНТАКТОР открывает ящик, концы проводов тащатся мышью
# к клеммам своего цвета, стык скручивается кругами курсора, ПУСК включает, СТОП выключает и разводит провода; неверная
# пара даёт искру; то же с клавиатуры. Ящик и кнопка помещаются в окне. Снимки для глаз при 1280x720 и 1600x900.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

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

# drag the end of a wire to a terminal, a few steps of motion on the way
func drag_wire(v, wire: int, terminal: int) -> void:
	var from = v.end_of(wire)
	var to = v.terminal(terminal)
	await button(from, true)
	for s in range(1, 7):
		await move(from.lerp(to, s / 6.0), from.lerp(to, (s - 1) / 6.0))
	await button(to, false)

# circle the cursor round a joint, held down
func twist(v, wire: int, turns: float) -> void:
	var joint = v.terminal(v.c().at(wire))
	var start = joint + Vector2(0, -2)
	await button(start, true)
	var r = 26.0
	var prev = joint + Vector2(r, 0)
	await move(prev, start)
	var steps = int(turns * 16.0)
	for s in range(1, steps + 1):
		var a = TAU * float(s) / 16.0
		var p = joint + Vector2(cos(a), sin(a)) * r
		await move(p, prev)
		prev = p
	await button(prev, false)

func fixture(levels: Dictionary):
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	Fixtures.equip(m, "locomotive")
	m.select_vehicle("locomotive")
	m.object_state("locomotive").levels = levels
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
		game.model = fixture({"locomotive_engine": 2})   # three wires
		game.screen = "game"
		game.rebuild()
		game.camera_s = 100; game.camera_y = 0; game.camera_x = game.get_viewport_rect().size.x * 0.65
		game.toggle_cab_view()
		for i in range(8): await frame()
		check(game.cab_active(), "the cab of the electric locomotive opens " + tag)
		var hatch = Rect2()
		for hit in game.cab_hits:
			if hit.id == "contactor": hatch = hit.rect
		check(hatch.size.x > 10.0, "the lid КОНТАКТОР can be clicked " + tag)
		await shot("cab_closed_" + tag)
		await click(hatch.get_center())
		var v = game.contactor_view()
		check(v.open, "a click on the lid opens the box " + tag)
		for i in range(6): await frame()
		var view = Rect2(Vector2.ZERO, game.get_viewport_rect().size)
		check(view.encloses(v.box_rect()) and view.encloses(v.button_plate()) and view.encloses(v.lid_rect()), "the box, its lid and the button fit in the window " + tag)
		var c = game.model.contactor()
		check(c.count() == 3 and not c.all_joined(), "three free wires inside " + tag)
		await shot("box_open_" + tag)
		# the mouse: each wire to the terminal of its colour, then twisted
		for w in range(c.count()):
			await drag_wire(v, w, c.terminal_of(w))
		check(c.all_joined() and not c.ready(), "the mouse brings every end to its terminal; not twisted yet " + tag)
		await shot("box_joined_" + tag)
		for w in range(c.count()):
			await twist(v, w, 2.3)
		check(c.ready(), "circling the joints twice twists them: the lamp ГОТОВ " + tag)
		await shot("box_ready_" + tag)
		await click(v.button_rect().get_center())
		check(c.is_on() and bool(game.model.state.engine), "the button ПУСК switches the contactor on " + tag)
		await shot("box_on_" + tag)
		await click(v.button_rect().get_center())
		check(not c.is_on() and not c.all_joined(), "the same button is СТОП and the wires come apart " + tag)
		# a wrong pair: a spark, the box shows it
		await drag_wire(v, 0, c.terminal_of(1))
		await drag_wire(v, 1, c.terminal_of(0))
		await drag_wire(v, 2, c.terminal_of(2))
		for w in range(3): await twist(v, w, 2.3)
		await click(v.button_rect().get_center())
		check(not c.is_on() and v.spark_t > 0.0 and game.toast.contains("Искра"), "a wrong pair sparks and says so " + tag)
		await shot("box_spark_" + tag)
		# the keyboard: a digit for the wire, a digit for the terminal, the space held twists, Enter is ПУСК
		c.stop()
		for w in range(c.count()):
			key(KEY_1 + w)
			key(KEY_1 + c.terminal_of(w))
			for r in range(30): key(KEY_SPACE, true, r > 0)
		check(c.ready(), "the keyboard wires and twists them too " + tag)
		key(KEY_ENTER)
		check(c.is_on(), "Enter is ПУСК " + tag)
		key(KEY_ESCAPE)
		check(not v.open, "Esc closes the box " + tag)
		c.press()
		game.cab_view = false
		game.update_pult_transform()
	Model.contactor_rules = false
	print("CONTACTOR VIEW CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)
