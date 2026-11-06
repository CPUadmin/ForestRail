extends Node
# Автоматическая КПП в кабине: вместо кулисы селектор Д/Н/З, настоящая мышь двигает его, отпускание ставит режим.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var checks = 0
var failures: Array = []
var out_dir = "user://qa_auto_gearbox"

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
	for i in range(6): await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func mouse(point: Vector2, pressed: bool) -> void:
	var e = InputEventMouseButton.new()
	e.position = point
	e.global_position = point
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	get_tree().root.push_input(e, true)
	await frame()

# the knob of the selector goes to the given place (-1 D, 0 N, 1 R) by a real drag
func drag_selector(to_y: float) -> void:
	var point = Vector2.ZERO
	for hit in game.grip_hits:
		if hit.id == "gear" and hit.get("closeup", false): point = hit.position
	check(point != Vector2.ZERO, "the selector knob is there to take")
	await mouse(point, true)
	check(game.drag == "gear", "the mouse captures the selector")
	var rect = game.gate_rect(true)
	var current = game.gate_local(rect, game.gate_pos)
	var target = game.gate_local(rect, Vector2(1, to_y))
	var e = InputEventMouseMotion.new()
	e.position = game.pult_t * target
	e.relative = game.pult_t.basis_xform(target - current)
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(e, true)
	await frame()
	await mouse(game.pult_t * target, false)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out_dir = arg
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.set_process(false)
	game.saves.directory = out_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.15).timeout
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	m.state.chapter = 9
	Fixtures.equip(m, "motorcar")
	m.object_state("motorcar").levels["motorcar_automatic"] = 1
	for p in m.route.points: p[1] = 0.0
	m.state.phase = "route"
	m.state.s = 100.0
	m.state.brake = 0.0
	game.model = m
	game.screen = "game"
	game.rebuild()
	game.camera_s = 100
	game.camera_y = 0
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	for i in range(6): await frame()
	for b in game.ui.find_children("*", "Button", true, false):
		if b.text == "Кабина [E]":
			var point = b.get_global_rect().get_center()
			await mouse(point, true)
			await mouse(point, false)
	for i in range(8): await frame()
	check(game.cab_active(), "the cab opens")
	check(game.control_ids() == ["brake", "throttle", "gear", "start"], "the pult keeps its four controls")
	check(game.gate_slot_pos(0) == Vector2(1, 0) and game.gate_slot_pos(3) == Vector2(1, -1) and game.gate_slot_pos(6) == Vector2(1, 1), "the selector places: N middle, D up, R down")
	check(game.selector_gear_of(-0.9) == 1 and game.selector_gear_of(0.0) == 0 and game.selector_gear_of(0.9) == 6, "the selector reads D, N, R")
	await shot("selector_neutral")
	check(m.start_engine(true), "the engine starts")
	await drag_selector(-1.0)
	check(game.drag == "" and int(m.state.gear) == 1 and m.selector_gear() == 1, "the mouse puts D (gear %d)" % int(m.state.gear))
	await shot("selector_drive")
	await drag_selector(0.0)
	check(game.drag == "" and int(m.state.gear) == 0, "and back to N")
	await drag_selector(1.0)
	check(int(m.state.gear) == 6, "and R at a stop")
	await shot("selector_reverse")
	print("AUTO GEARBOX VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(1 if not failures.is_empty() else 0)
