extends Node
# Замер для шага 1.3.11: камера едет по всей трассе, каждый кадр дольше 25 мс записывается с местом и ближайшей станцией.
# Не тест с галочкой. Запуск (с окном): godot --path ForestRail -- --qa-suite=probe_route_frames
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const STEP_M = 1.5   # metres per frame: 90 m/s, fast-forward; a first-time cost shows up the same

var game

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = "user://qa_probe_route"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout
	for kind in ["motorcar", "locomotive"]:
		var m = Model.new()
		m.new_game(42, 2)
		m.state.money = 500000
		m.state.chapter = 9
		Fixtures.equip(m, kind)
		m.state.phase = "route"
		m.state.s = 0.0
		m.state.engine = true
		m.weather_force = {"cloud": 0.2, "rain": 0.0, "fog": 0.0}
		game.model = m
		game.screen = "game"
		game.cab_view = false
		game.camera_s = 0.0
		game.camera_x = game.get_viewport_rect().size.x * 0.65
		game.rebuild()
		for i in range(30): await get_tree().process_frame
		var t0 = Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("STILL frame %.1f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))
		var stations: Array = m.route.station_s
		var end = float(m.route.points[-1][2]) - 20.0
		var s = 0.0
		var torn = 0
		var frames = 0
		var worst = 0.0
		var last = Time.get_ticks_usec()
		while s < end:
			s += STEP_M
			m.state.s = s
			m.state.v = STEP_M * 60.0
			game.camera_s = s
			game.camera_y = m.route.sample(s).y
			game.perf_on = true
			game.perf_samples = {}
			var t_phys = Time.get_ticks_usec()
			game._physics_process(1.0 / 60.0)
			t_phys = Time.get_ticks_usec() - t_phys
			m.state.s = s
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var now = Time.get_ticks_usec()
			var ms = float(now - last) / 1000.0
			last = now
			frames += 1
			worst = maxf(worst, ms)
			if ms > 25.0:
				torn += 1
				var near = 0
				for i in range(stations.size()):
					if absf(float(stations[i]) - s) < absf(float(stations[near]) - s): near = i
				var parts = "phys %.1f" % (t_phys / 1000.0)
				for c in game.perf_samples: parts += "  %s %.1f" % [c, float(game.perf_samples[c][-1]) / 1000.0]
				print("TORN %s s=%.0f  %.1f ms  station %d at %+.0f m   | %s" % [kind, s, ms, near, float(stations[near]) - s, parts])
		print("ROUTE %s frames %d torn>25ms %d worst %.1f ms" % [kind, frames, torn, worst])
		# the approach at a real speed and the stop at every station (the station's buttons and boards appear)
		for k in range(1, stations.size()):
			var at = float(stations[k])
			var x = at - 160.0
			var worst_k = 0.0
			var where = ""
			last = Time.get_ticks_usec()
			for f in range(160 + 90):
				var moving = x < at
				if moving: x = minf(at, x + 8.0 / 60.0 * 8.0)   # 64 m/s of screen travel, slowed to a stop at the station
				m.state.s = x
				m.state.v = 8.0 if moving else 0.0
				game.camera_s = x
				game.camera_y = m.route.sample(x).y
				game._physics_process(1.0 / 60.0)
				m.state.s = x
				m.state.v = 8.0 if moving else 0.0
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var now = Time.get_ticks_usec()
				var ms = float(now - last) / 1000.0
				last = now
				if f > 2 and ms > worst_k:
					worst_k = ms
					where = "%+.0f m%s" % [x - at, "" if moving else " (stopped)"]
			print("STATION %s %d  worst %.1f ms at %s" % [kind, k, worst_k, where])
	get_tree().quit(0)
