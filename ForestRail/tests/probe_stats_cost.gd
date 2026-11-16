extends Node
# Замер для шага 1.3.3: сколько раз за кадр считаются характеристики машины (object_stats) и сколько стоит один подсчёт.
# Не тест с галочкой. Запуск: godot --path ForestRail -- --qa-suite=probe_stats_cost
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game

func _ready() -> void:
	call_deferred("run")

func prepare(kind: String) -> void:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 500000
	m.state.chapter = 9
	Fixtures.equip(m, kind)
	m.state.phase = "route"
	m.state.s = 1000.0
	m.state.engine = true
	m.state.throttle = 0.6
	m.state.v = 6.0
	game.model = m
	game.screen = "game"
	game.cab_view = false
	game.camera_s = 1000.0
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	game.rebuild()
	for i in range(20): await get_tree().process_frame

func count(scene: String) -> void:
	Model.stats_calls = 0
	var frames = 120
	for i in range(frames):
		game._physics_process(1.0 / 60.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var per_frame = float(Model.stats_calls) / float(frames)
	var m = game.model
	var start = Time.get_ticks_usec()
	for i in range(2000): m.object_stats(m.vehicle_id())
	var one = float(Time.get_ticks_usec() - start) / 2000.0
	start = Time.get_ticks_usec()
	for i in range(2000): m.effects(m.vehicle_id())
	var eff = float(Time.get_ticks_usec() - start) / 2000.0
	print("STATS %-12s calls/frame %.0f  one call %.1f us (effects %.1f us)  per frame %.2f ms" % [scene, per_frame, one, eff, per_frame * one / 1000.0])

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.saves.directory = "user://qa_stats_cost"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout
	Model.wear_rules = true
	for kind in ["motorcar", "steam", "locomotive"]:
		await prepare(kind)
		await count("road_" + kind)
		game.toggle_cab_view()
		for i in range(20): await get_tree().process_frame
		await count("cab_" + kind)
		game.toggle_cab_view()
	get_tree().quit(0)
