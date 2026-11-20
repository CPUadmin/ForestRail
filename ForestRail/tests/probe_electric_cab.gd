extends Node
# Снимки новой кабины электровоза (1.12): мёртвая до пуска, живая на ходу, ночь с фарой и дворниками, 1280 и 1600.
# Не проверка с галочкой. Запуск: godot --path ForestRail -- --qa-suite=probe_electric_cab <папка>
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var out_dir = "user://qa_electric_cab"

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	game.update_hud()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	for i in range(4): await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

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
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		var m = Model.new()
		m.new_game(42, 2)
		m.state.money = 100000
		Fixtures.equip(m, "locomotive")
		m.select_vehicle("locomotive")
		m.state.phase = "route"
		m.state.s = 300.0
		m.state.v = 0.0
		m.state.brake = 1.0
		m.state.engine = false
		game.model = m
		game.screen = "game"
		game.camera_s = 300.0
		game.camera_y = m.route.sample(300.0).y
		game.camera_x = game.get_viewport_rect().size.x * 0.65
		game.rebuild()
		game.toggle_cab_view()
		await shot("dead_%d" % size.x)
		m.state.engine = true
		m.state.brake = 0.0
		m.state.throttle = 0.7
		m.state.v = 9.0
		m.state.fleet_by_id.locomotive.fuel = float(m.object_stats("locomotive").tank) * 0.62
		for i in range(80):
			game._process(1.0 / 60.0)
			m.state.v = 9.0
			await frame()
		await shot("live_%d" % size.x)
		m.state.stats.seconds = Model.DAY_SECONDS * 0.9
		game.lamp_manual = 1
		game.wiper_on = true
		for i in range(25):
			game._process(1.0 / 60.0)
			await frame()
		await shot("night_%d" % size.x)
		game.wiper_on = false
		game.lamp_manual = 0
		m.state.stats.seconds = 0.0
		game.toggle_cab_view()
	get_tree().quit(0)
