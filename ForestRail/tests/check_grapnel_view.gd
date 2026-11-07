extends Node
# Кошка с лебёдкой на экране: кнопка «Кошка [G]» у шестовой с гаджетом, опоры вдоль линии, крюк и трос рисуются без ошибок в полёте, на опоре и после срыва.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var checks = 0
var failures: Array = []
var out_dir = "user://qa_grapnel_view"

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func frame() -> void:
	game.update_hud()
	game.art_world.update_view()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	for i in range(4): await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func button_named(prefix: String):
	for b in game.ui.find_children("*", "Button", true, false):
		if b.text.begins_with(prefix): return b
	return null

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out_dir = arg
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = out_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.15).timeout
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "pole")
	for p in m.route.points: p[1] = 0.0
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.v = 0.0
	m.state.brake = 0.0
	game.model = m
	game.screen = "game"
	game.rebuild()
	game.camera_s = 600.0
	game.camera_y = 0.0
	game.camera_x = game.get_viewport_rect().size.x * 0.3
	game.zoom_level = game.fit_train_zoom()
	for i in range(4): await frame()
	check(button_named("Кошка") == null, "without the gadget there is no button")
	m.object_state("pole").levels["pole_grapnel"] = 1
	game.zoom_level = game.fit_train_zoom()
	check(game.zoom_level <= 0.7, "with the grapnel the view goes out (%.2f)" % game.zoom_level)
	game.rebuild()
	for i in range(4): await frame()
	var button = button_named("Кошка")
	check(button != null and not button.disabled, "with the gadget the button is there")
	m.physics_step(1.0 / 60.0)
	m.grapnel.anchors = [{"s": 593.0, "type": "bush"}, {"s": 611.0, "type": "post"}, {"s": 618.0, "type": "tree"}, {"s": 624.0, "type": "rock"}, {"s": 630.0, "type": "stump"}]
	await shot("grapnel_stowed")
	# the mouse: the dotted arc follows the cursor, the right button throws at it, the right button again lets go
	var outer = game.body_transform("pole", m.body_s_render(0))
	var at: Vector2 = outer * (Vector2(11.0, 0.21 - 1.6) * game.art.PX)
	Input.warp_mouse(at)
	for i in range(3): await frame()
	await shot("grapnel_aim")
	var aim = game.grapnel_aim_local(at)
	check(absf(aim.x - 11.0) < 1.5 and absf(aim.y - 1.6) < 0.3, "the cursor is turned into metres ahead and above the rail (%s)" % str(aim))
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = at
	game._unhandled_input(press)
	check(m.grapnel.mode == "flying" and m.grapnel.throws == 1, "the right button throws at the cursor")
	for i in range(60 * 2): m.physics_step(1.0 / 60.0)
	check(m.grapnel.mode == "hooked", "aimed at the post, the hook is on it (%s)" % m.grapnel.mode)
	game._unhandled_input(press)
	check(m.grapnel.mode == "dropped", "the right button again lets go")
	for i in range(80): m.physics_step(1.0 / 60.0)
	m.state.s = 600.0
	m.state.v = 0.0
	m.grapnel.reset()
	for attempt in range(20):   # a throw is a throw: some miss, the test takes one that catches
		m.grapnel.throws = attempt * 7
		game.try_grapnel()
		if m.grapnel.catch_t >= 0.0: break
		m.grapnel.reset()
	check(m.grapnel.mode == "flying" and m.grapnel.catch_t >= 0.0, "the button throws the hook")
	for i in range(18): m.physics_step(1.0 / 60.0)
	game.camera_s = float(m.state.s)
	await shot("grapnel_flying")
	for i in range(60 * 2): m.physics_step(1.0 / 60.0)
	game.camera_s = float(m.state.s)
	check(m.grapnel.mode == "hooked", "the hook is on the post")
	for i in range(3): await frame()
	button = button_named("Снять")
	check(button != null, "the button says: let go")
	await shot("grapnel_hooked")
	game.try_grapnel()
	check(m.grapnel.mode == "dropped", "the same button lets the hook go")
	await shot("grapnel_dropped")
	print("GRAPNEL VIEW CHECKS %d; FAILURES %s" % [checks, str(failures)])
	get_tree().quit(1 if not failures.is_empty() else 0)
