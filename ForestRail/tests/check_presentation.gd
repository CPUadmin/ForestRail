extends Node
const Fixtures = preload("res://tests/fixtures.gd")

var root: Window:
	get: return get_tree().root

func quit(code: int = 0) -> void:
	get_tree().quit(code)



var game
var failures: Array = []
var frames: Array = []
var output_dir = "user://qa_visual"

func _ready() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png(output_dir.path_join(name + ".png"))
	frames.append({"name": name, "width": image.get_width(), "height": image.get_height()})
	print("VISUAL ", name, " ", image.get_size())

func run() -> void:
	var args = OS.get_cmdline_user_args()
	args = Array(args).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = "user://qa_visual_runtime"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42)
	game.model.accept_mission(game.model.current_mission())
	game.screen = "game"
	game.camera_s = 0
	game.camera_x = 1040
	game.model.pump_angle = 0.23
	game.rebuild()
	await shot("handcar_mechanism")
	for i in range(2): game.model.transfer(game.model.state.cargo[i].id, game.model.slots()[i].key)
	await shot("handcar_loaded")
	game.model.back_to_depot()
	game.model.cancel_mission()
	game.model.state.money = 5000
	Fixtures.equip(game.model, "motorcar")
	game.rebuild()
	await shot("petrol_motorcar")
	Fixtures.equip(game.model, "locomotive")
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = size
		game.screen = "menu"
		game.rebuild()
		await shot("menu_" + str(size.y))
		game.screen = "depot"
		game.tab = "Состав"
		game.camera_x = 600
		game.rebuild()
		await shot("depot_" + str(size.y))
		game.model.state.chapter = 9
		game.model.accept_mission(game.model.current_mission())
		game.screen = "game"
		game.zoom_level = 0.85
		game.camera_x = 1040
		game.rebuild()
		await shot("loading_" + str(size.y))
		if game.grip_hits.size() != 4 or game.slot_hits.size() != 6:
			failures.append("missing input regions " + str(size.y))
		for hit in game.slot_hits + game.grip_hits:
			var p = hit.position if hit.has("position") else hit.rect.get_center()
			if not game.get_viewport_rect().has_point(p): failures.append("offscreen control " + str(size.y))
		game.model.back_to_depot()
		game.model.cancel_mission()
	game.settings.text_scale = 1.5
	game.screen = "menu"
	game.rebuild()
	await shot("menu_text150")
	game.screen = "depot"
	game.tab = "Улучшения"
	game.selected_object = "W01"
	game.rebuild()
	await shot("upgrades_text150")
	game.show_modal("settings")
	await shot("settings_text150")
	game.close_modal()
	game.model.state.finale = true
	game.model.state.last_result = {"title": "Поезд до Дальнего бора", "reward": 500, "final": true}
	game.show_modal("result")
	await shot("finale")
	game.settings.text_scale = 1.0
	game.close_modal()
	game.model.state.chapter = 9
	game.model.accept_mission(game.model.current_mission())
	for i in range(game.model.state.cargo.size()): game.model.transfer(game.model.state.cargo[i].id, game.model.slots()[i].key)
	game.model.depart()
	game.model.state.s = 1000
	game.model.state.v = 6
	game.model.state.engine = true
	game.model.state.gear = 2
	game.model.state.throttle = 0.8
	game.model.state.brake = 0
	game.screen = "game"
	game.camera_s = 1000
	game.camera_y = game.model.route.sample(1000).y
	game.rebuild()
	var start = Time.get_ticks_usec()
	for i in range(180): await get_tree().process_frame
	var seconds = (Time.get_ticks_usec() - start) / 1000000.0
	var perf = {"frames": 180, "seconds": seconds, "average_fps": 180.0 / seconds, "renderer": RenderingServer.get_video_adapter_name()}
	await shot("electric_1080")
	var file = FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "frames": frames, "performance": perf}, "\t"))
	file.close()
	print("PRESENTATION ", failures, " PERFORMANCE ", perf)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	quit(0 if failures.is_empty() else 1)
