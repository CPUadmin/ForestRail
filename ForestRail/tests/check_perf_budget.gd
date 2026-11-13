extends Node
# Бюджет кадра (шаг 1.3.1, docs/CODE_AUDIT_RU.md раздел 7): сколько миллисекунд тратят рисование сцены, фон мира, HUD и физика.
# Окно настоящее, vsync выключен (старый check_perf с vsync мерил частоту экрана, а не стоимость кода).
# Бюджеты не придуманы: первый запуск на этой машине пишет базу (qa/perf_baseline.json, по имени процессора), дальше порог = база ×1,3 по медиане
# и ×1,6 по 95-му процентилю (плюс малый запас в миллисекундах от шума). Путь к базе: аргумент --perf-baseline=<файл>.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

const WARMUP = 30
const FRAMES = 240
const MEDIAN_K = 1.3
const P95_K = 1.6
const SLACK_MS = 0.25

var game
var failures: Array = []
var checks = 0
var baseline_path = ""
var results = {}   # scene -> counter -> {"median": ms, "p95": ms}

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func percentile(values: Array, p: float) -> float:
	if values.is_empty(): return 0.0
	var sorted = values.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(floor(float(sorted.size()) * p)))])

# A fixed small piece of work: how fast this machine is at this moment (after a long run the processor is hotter and slower; the budgets of the
# scenes are scaled by the ratio to the base, so that a slow moment is not taken for a slow code).
func bench_ms() -> float:
	var best = 1.0e9
	for round in range(5):
		var start = Time.get_ticks_usec()
		var sum = 0.0
		var items: Array = []
		for i in range(60000):
			sum += sin(float(i) * 0.013) * cos(float(i) * 0.007)
			if i % 40 == 0: items.append(Vector2(sum, float(i)))
		var spent = float(Time.get_ticks_usec() - start) / 1000.0
		best = minf(best, spent)
	return best

func prepare(kind: String, wagons: bool = true) -> void:
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 500000
	m.state.chapter = 9
	Fixtures.equip(m, kind)
	if not wagons: m.state.consist_ids.clear()
	m.state.phase = "route"
	m.state.s = 1000.0
	m.state.engine = true
	m.state.throttle = 0.6
	m.state.v = 6.0
	m.weather_force = {"cloud": 0.2, "rain": 0.0, "fog": 0.0}
	game.model = m
	game.screen = "game"
	game.cab_view = false
	game.camera_s = 1000.0
	game.camera_y = m.route.sample(1000.0).y
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	game.rebuild()
	for i in range(WARMUP): await get_tree().process_frame

# runs FRAMES frames with the counters on; physics steps are made by hand (one per frame) so that they are measured too
func measure(scene: String, physics: bool = true) -> void:
	game.perf_samples = {}
	game.perf_on = true
	var frame_ms: Array = []
	var last = Time.get_ticks_usec()
	for i in range(FRAMES):
		if physics: game._physics_process(1.0 / 60.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var now = Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
	game.perf_on = false
	var row = {}
	for counter in game.perf_samples:
		var ms: Array = []
		for usec in game.perf_samples[counter]: ms.append(float(usec) / 1000.0)
		row[counter] = {"median": percentile(ms, 0.5), "p95": percentile(ms, 0.95)}
	row["frame"] = {"median": percentile(frame_ms, 0.5), "p95": percentile(frame_ms, 0.95)}
	results[scene] = row
	var line = "PERF %-14s" % scene
	for counter in ["frame", "draw", "update_view", "hud", "physics"]:
		if row.has(counter): line += "  %s %.2f/%.2f" % [counter, float(row[counter].median), float(row[counter].p95)]
	var rough = 0
	for v in frame_ms: if float(v) > 25.0: rough += 1
	line += "  rough>25ms %d/%d" % [rough, frame_ms.size()]   # 1.3.9: torn frames are counted for the eye, not checked against the base
	print(line, "   (median/p95 ms)")
	var parts = ""
	for counter in ["cab_forward", "cab_nose", "cab_glass", "cab_frame", "cab_dash", "cab_gauges", "cab_rest", "f_bg", "f_ground", "f_beds", "f_ballast", "f_sleepers", "f_rails", "f_joints", "f_stations", "f_poles", "f_trees", "f_streaks"]:
		if row.has(counter): parts += "  %s %.2f" % [counter.trim_prefix("cab_"), float(row[counter].median)]
	if parts != "": print("PERF   cab parts:", parts)

func run() -> void:
	baseline_path = ProjectSettings.globalize_path("res://../qa/perf_baseline.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-baseline="): baseline_path = arg.trim_prefix("--perf-baseline=")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = "user://qa_perf_budget"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout
	# the scenes of the plan: the road with a machine and wagons, the same in the cab, the depot, the zeppelin at night
	await prepare("motorcar")
	await measure("road_motorcar")
	game.toggle_cab_view()
	for i in range(WARMUP): await get_tree().process_frame
	await measure("cab_motorcar")
	game.toggle_cab_view()
	await prepare("steam")
	await measure("road_steam")
	await prepare("zeppelin")
	game.model.state.stats.seconds = 18.0 * 60.0
	game.lamp_manual = 1
	await measure("night_zeppelin")
	game.lamp_manual = -1
	await prepare("locomotive")
	game.model.state.phase = "depot"
	game.screen = "depot"
	game.tab = "Рейсы"
	game.rebuild()
	for i in range(WARMUP): await get_tree().process_frame
	await measure("depot", false)
	# the base of this machine
	var machine = OS.get_processor_name()
	var speed_now = bench_ms()
	results["bench"] = {"ms": {"median": speed_now, "p95": speed_now}}
	var base_all = {}
	if FileAccess.file_exists(baseline_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		if parsed is Dictionary: base_all = parsed
	if not base_all.has(machine):
		base_all[machine] = results
		DirAccess.make_dir_recursive_absolute(baseline_path.get_base_dir())
		var file = FileAccess.open(baseline_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(base_all, "  "))
		file.close()
		print("PERF BASELINE WRITTEN for ", machine, " into ", baseline_path)
		check(true, "the base of this machine is written")
	else:
		var base = base_all[machine]
		var slow = 1.0
		if base.has("bench"):
			slow = maxf(1.0, speed_now / maxf(0.001, float(base.bench.ms.median)))
		else:
			# the base of the older run has no speed mark: it is added now (this run is taken as the calm one)
			base["bench"] = results["bench"]
			base_all[machine] = base
			var upgraded = FileAccess.open(baseline_path, FileAccess.WRITE)
			upgraded.store_string(JSON.stringify(base_all, "  "))
			upgraded.close()
		print("PERF speed of the machine now against the base: x%.2f" % slow)
		for scene in results:
			if scene == "bench" or not base.has(scene): continue
			for counter in results[scene]:
				if not base[scene].has(counter): continue
				var now = results[scene][counter]
				var was = base[scene][counter]
				check(float(now.median) <= float(was.median) * MEDIAN_K * slow + SLACK_MS, "%s %s: median %.2f ms against the base %.2f" % [scene, counter, float(now.median), float(was.median)])
				check(float(now.p95) <= float(was.p95) * P95_K * slow + SLACK_MS * 2.0, "%s %s: p95 %.2f ms against the base %.2f" % [scene, counter, float(now.p95), float(was.p95)])
	print("PERF BUDGET CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
