extends Node
# Снимки для 1.4.15: облачко воздушной песочницы у колёс пневмовоза и подпись «песок: N» в пульте.
# Не проверка с галочкой. Запуск: godot --path ForestRail -- --qa-suite=probe_sand_view <папка>
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var out_dir = "user://qa_sand_view"

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	game.update_hud()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

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
	await get_tree().create_timer(0.3).timeout
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 100000
	Fixtures.equip(m, "pneumatic")
	m.select_vehicle("pneumatic")
	var steep: Array = []
	for x in range(-40, 3001): steep.append([float(x), float(maxi(0, x)) * 0.06, float(x)])
	m.route.points = steep
	m.route.length_m = 3000.0
	m.state.phase = "route"
	m.state.s = 400.0
	m.state.v = -2.0
	m.state.brake = 0.0
	m.state.throttle = 1.0
	game.model = m
	game.screen = "game"
	game.cab_view = false
	game.camera_s = 400.0
	game.camera_y = m.route.sample(400.0).y
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	game.rebuild()
	for i in range(10): await frame()
	var shot = false
	for i in range(240):
		m.physics_step(1.0 / 60.0)
		game.camera_s = float(m.state.s)
		game.camera_y = m.route.sample(game.camera_s).y
		game._process(1.0 / 60.0)
		await frame()
		if not shot and not game.sand_puff.is_empty() and float(game.sand_puff.t) > 0.12:
			get_tree().root.get_texture().get_image().save_png(out_dir.path_join("sand_puff.png"))
			print("SHOT sand_puff sand_left=", m.sand_left())
			shot = true
	m.state.v = 0.0
	m.state.throttle = 0.0
	game.toggle_cab_view()
	for i in range(8): await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join("cab_sand_label.png"))
	print("SHOT cab")
	get_tree().quit(0)
