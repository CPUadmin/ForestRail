extends Node
# 1.3.9: what a rebuild of the depot costs: the call itself and the frame after it (the layout of the labels happens
# there). Not a check with a tick. Run: godot --path ForestRail -- --qa-suite=probe_depot_rebuild <folder>
const Fixtures = preload("res://tests/fixtures.gd")

var game

func _ready() -> void:
	call_deferred("run")

func median(values: Array) -> float:
	var sorted = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]

func run() -> void:
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	var dir = "user://qa_depot_rebuild"
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): dir = arg
	game.saves.directory = dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout
	game.model.new_game(42, 2)
	game.model.state.money = 5000
	Fixtures.equip(game.model, "steam")
	game.screen = "depot"
	game.place = "depot"
	for tab in ["Рейсы", "Улучшения", "Гараж"]:
		game.tab = tab
		var calls: Array = []
		var frames: Array = []
		for i in range(25):
			var t0 = Time.get_ticks_usec()
			game.rebuild()
			var t1 = Time.get_ticks_usec()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var t2 = Time.get_ticks_usec()
			if i >= 5:
				calls.append((t1 - t0) / 1000.0)
				frames.append((t2 - t1) / 1000.0)
		var labels = game.ui.find_children("*", "Label", true, false).size()
		var theme_ms: Array = []
		var build_ms: Array = []
		for i in range(10):
			var a = Time.get_ticks_usec()
			game.setup_theme()
			var b = Time.get_ticks_usec()
			game.clear_children(game.ui)
			game.clear_children(game.overlay)
			var c = Time.get_ticks_usec()
			if tab == "Гараж" or tab == "Улучшения" or tab == "Рейсы": game.build_depot(game.get_viewport_rect().size)
			var d = Time.get_ticks_usec()
			theme_ms.append((b - a) / 1000.0)
			build_ms.append((d - c) / 1000.0)
			await get_tree().process_frame
		print("  parts: setup_theme %.2f ms, build_depot %.2f ms" % [median(theme_ms), median(build_ms)])
		var d_ui = game.depot_ui()
		var size = game.get_viewport_rect().size
		var parts = {"header": [], "nav": [], "room": []}
		for i in range(10):
			game.clear_children(game.ui)
			var a = Time.get_ticks_usec()
			d_ui.build_header(size, "Депо")
			var b = Time.get_ticks_usec()
			d_ui.build_place_nav(size)
			var c = Time.get_ticks_usec()
			d_ui.build_place_room(size)
			var d = Time.get_ticks_usec()
			parts.header.append((b - a) / 1000.0); parts.nav.append((c - b) / 1000.0); parts.room.append((d - c) / 1000.0)
			await get_tree().process_frame
		print("  depot: header %.2f, nav %.2f, room %.2f ms" % [median(parts.header), median(parts.nav), median(parts.room)])
		print("DEPOT %s: rebuild %.2f ms, next frame %.2f ms, labels %d" % [tab, median(calls), median(frames), labels])
	get_tree().quit(0)
