extends Node
# Чистые кадры сцены без интерфейса (рейс, кабина, депо, погрузка) как фон для макетов нового интерфейса (суд интерфейса 14.11.2026).
# Запуск: godot --path ForestRail -- --qa-suite=probe_clean_scenes <папка>
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
var game

func _ready() -> void:
	call_deferred("run")

func shot(path: String, hide_ui: bool) -> void:
	game.set_process(true)
	for i in range(6):
		game.queue_redraw()
		await get_tree().process_frame
	if hide_ui:
		game.set_process(false)   # the game shows its interface again every frame: it waits while the picture is taken
		game.ui.visible = false
		game.overlay.visible = false
		game.clean_frame = true
		for i in range(3):
			game.queue_redraw()
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(path)
	game.clean_frame = false
	game.ui.visible = true
	game.overlay.visible = true
	game.set_process(true)

func career(kind: String) -> Model:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 1840
	m.state.chapter = 4
	Fixtures.equip(m, kind)
	m.weather_force = {"cloud": 0.2, "rain": 0.0, "fog": 0.0}
	return m

func run() -> void:
	var out = "user://qa_clean_scenes"
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"): out = a
	DirAccess.make_dir_recursive_absolute(out)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = out.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout
	var m = career("motorcar")
	m.accept_mission(m.current_mission())
	m.state.phase = "route"
	m.state.s = 400.0
	game.model = m
	game.screen = "game"
	game.camera_s = 400.0
	game.camera_y = m.route.sample(400.0).y
	game.camera_x = 1600 * 0.62
	game.rebuild()
	await shot(out.path_join("bg_road.png"), true)
	game.toggle_cab_view()
	await shot(out.path_join("bg_cab.png"), false)
	game.toggle_cab_view()
	var d = career("motorcar")
	d.state.phase = "depot"
	game.model = d
	game.screen = "depot"
	game.tab = "Рейсы"
	game.rebuild()
	await shot(out.path_join("bg_depot.png"), true)
	var l = career("motorcar")
	l.accept_mission(l.current_mission())
	game.model = l
	l.state.phase = "loading"
	game.enter_game_from_depot("loading")
	await shot(out.path_join("bg_loading.png"), true)
	print("CLEAN SCENES DONE ", out)
	get_tree().quit()
