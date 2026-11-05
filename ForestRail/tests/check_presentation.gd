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
		if game.grip_hits.size() != 2 or game.slot_hits.size() != 6:
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
	var result_panel := game.overlay.find_children("*", "PanelContainer", false, false)[0] as PanelContainer
	if result_panel.size.y >= game.get_viewport_rect().size.y - 160:
		failures.append("short result dialog should fit its content")
	game.show_modal("help")
	await shot("help_text150")
	var help_panel := game.overlay.find_children("*", "PanelContainer", false, false)[0] as PanelContainer
	var help_scroll := help_panel.get_child(0) as ScrollContainer
	if help_panel.size.y > game.get_viewport_rect().size.y - 160 or not help_scroll.get_v_scroll_bar().visible:
		failures.append("long help dialog should stay within the viewport and scroll")
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
	var fast_trial = await run_high_speed_trial()
	var file = FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "frames": frames, "performance": perf, "high_speed_trial": fast_trial}, "\t"))
	file.close()
	print("PRESENTATION ", failures, " PERFORMANCE ", perf)
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	quit(0 if failures.is_empty() else 1)

func run_high_speed_trial() -> Dictionary:
	const SPEED = 60.0
	const FRAMES = 240
	const WARMUP_FRAMES = 15
	game.set_physics_process(false)
	game.model.state.s = 1000.0
	game.model.state.v = SPEED
	game.model.state.direction = 1
	game.model.air_z = 0.7
	game.camera_s = 1000.0
	game.camera_y = game.model.route.sample(1000.0).y
	var advance := func():
		var step = SPEED / Engine.physics_ticks_per_second
		game.model.last_movement = step
		game.model.state.s += step
	get_tree().physics_frame.connect(advance)
	var previous = game.model.render_s()
	var startup_step = 0.0
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame
		var position: float = game.model.render_s()
		startup_step = maxf(startup_step, position - previous)
		previous = position
	var start = Time.get_ticks_usec()
	var worst_lag = 0.0
	var frame_steps: Array[float] = []
	var furthest_x = 0.0
	for frame_index in range(FRAMES):
		await get_tree().process_frame
		var position: float = game.model.render_s()
		worst_lag = maxf(worst_lag, absf(position - game.camera_s))
		frame_steps.append(position - previous)
		furthest_x = maxf(furthest_x, game.world_point(position).x)
		if position < previous - 0.01: failures.append("60 m/s interpolation moved backwards")
		previous = position
	var elapsed = (Time.get_ticks_usec() - start) / 1000000.0
	if worst_lag > 30.0: failures.append("60 m/s camera lag exceeded 30 m")
	if furthest_x > root.size.x * 0.90: failures.append("60 m/s camera should keep the head of the train inside the frame")
	await shot("high_speed_trial")
	get_tree().physics_frame.disconnect(advance)
	frame_steps.sort()
	var result = {
		"speed_m_s": SPEED, "average_fps": FRAMES / elapsed, "max_camera_lag_m": worst_lag,
		"startup_max_step_m": startup_step, "steady_max_step_m": frame_steps.back(),
		"steady_p95_step_m": frame_steps[ceili(FRAMES * 0.95) - 1], "max_head_screen_x": furthest_x,
	}
	print("HIGH SPEED TRIAL ", result)
	return result
