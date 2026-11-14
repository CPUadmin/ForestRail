extends Node
# Тур по экранам для суда интерфейса (14.11.2026): снимает КАЖДЫЙ экран и окно игры в обычной карьере (середина прохождения),
# чтобы разбирать интерфейс по снимкам. Не проверка с галочкой, а кадры для глаз.
# Запуск: godot --path ForestRail -- --qa-suite=probe_ui_tour <папка_для_снимков>   (или python tools/ui_tour.py)
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var out_dir = "user://qa_ui_tour"
var index = 0

func _ready() -> void:
	call_deferred("run")

func frame(n: int = 6) -> void:
	for i in range(n):
		game.update_hud()
		game.queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frame()
	index += 1
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [index, name]))

func career(kind: String) -> Model:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 1840
	m.state.chapter = 4
	Fixtures.equip(m, kind)
	m.weather_force = {"cloud": 0.2, "rain": 0.0, "fog": 0.0}
	return m

func on_road(m: Model, s: float) -> void:
	m.state.phase = "route"
	m.state.s = s
	game.model = m
	game.screen = "game"
	game.cab_view = false
	game.camera_s = s
	game.camera_y = m.route.sample(s).y
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	game.rebuild()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out_dir = arg
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.live_in_tests = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = out_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout

	# --- menu, settings, help
	game.model = career("motorcar")
	game.screen = "menu"
	game.rebuild()
	await shot("menu")
	for tab in game.SETTINGS_TABS:
		game.settings_tab = tab
		game.show_modal("settings")
		await shot("settings_" + tab)
	game.close_modal()
	game.show_modal("help")
	await shot("help")
	game.close_modal()

	# --- depot, every tab
	var m = career("motorcar")
	m.state.phase = "depot"
	game.model = m
	game.screen = "depot"
	for tab in [["Гараж", "garage"], ["Состав", "consist"], ["Улучшения", "workshop"], ["Рейсы", "orders"], ["Казик", "casino_tab"], ["Рекорды", "records"]]:
		game.tab = tab[0]
		game.rebuild()
		await shot("depot_" + tab[1])
	game.show_modal("receiving")
	await shot("depot_bolts_desk")
	game.close_modal()
	game.show_modal("casino")
	await shot("casino")
	game.close_modal()
	game.show_modal("album")
	await shot("album")
	game.close_modal()

	# --- loading at the home station
	m = career("motorcar")
	game.model = m
	m.accept_mission(m.current_mission())
	m.state.phase = "loading"
	game.screen = "game"
	game.enter_game_from_depot("loading")
	await shot("loading")

	# --- on the road, the map, the pause, the cab of every powered machine
	m = career("motorcar")
	m.accept_mission(m.current_mission())
	on_road(m, 400.0)
	await shot("road_motorcar")
	game.toggle_map()
	await shot("map")
	game.toggle_map()
	game.pause_game()
	await shot("pause")
	game.close_modal()
	for kind in ["handcar", "pole", "sail", "steam", "motorcar", "pneumatic", "locomotive", "zeppelin", "jet"]:
		var mk = career(kind)
		on_road(mk, 400.0)
		await shot("road_" + kind)
		if kind not in ["handcar", "pole", "sail"]:
			game.toggle_cab_view()
			await shot("cab_" + kind)
			game.toggle_cab_view()

	# --- at a station with cargo to unload
	m = career("motorcar")
	m.accept_mission(m.current_mission())
	on_road(m, 0.0)
	m.state.s = m.service_stop(1)
	m.state.v = 0.0
	m.state.brake = 1.0
	game.camera_s = m.state.s
	game.camera_y = m.route.sample(game.camera_s).y
	for i in range(30): game._physics_process(1.0 / 60.0)
	game.rebuild()
	await shot("station")

	# --- the result of a trip
	m.state.last_result = {"title": "Мешки муки в Сосновый разъезд", "reward": 360}
	game.show_modal("result")
	await shot("result")
	game.close_modal()

	print("UI TOUR DONE ", index, " screens in ", out_dir)
	get_tree().quit(0)
