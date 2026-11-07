extends Node
# Визуальная приёмка перед выпуском (не тест с галочкой, а снимки для глаз): каждая машина днём, ночью с фонарём, на ходу и при торможении.
# Кадры режутся вокруг головы поезда, чтобы мелочи (фонарь, колёса, пламя, искры) было видно крупно.
# Запуск: godot --path ForestRail -- --qa-suite=probe_visual_audit <папка_для_снимков>
# Потом tools/visual_audit_sheet.py склеивает листы; смотреть листы глазами, а не по хэшам.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")
const KINDS = ["handcar", "pole", "sail", "steam", "motorcar", "pneumatic", "locomotive", "zeppelin", "jet"]

var game
var out_dir = "user://qa_visual_audit"

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	game.update_hud()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String, head: Vector2) -> void:
	for i in range(6): await frame()
	var image = get_tree().root.get_texture().get_image()
	var crop = Rect2i(int(head.x) - 520, int(head.y) - 230, 780, 330).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(crop).save_png(out_dir.path_join(name + ".png"))

func prepare(kind: String) -> void:
	var m = Model.new()
	m.new_game(42, 2, "creative")
	m.state.money = 500000
	m.state.chapter = 9
	Fixtures.equip(m, kind)
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.v = 0.0
	m.state.brake = 0.0
	m.state.engine = true
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	for p in m.route.points: p[1] = 0.0
	game.model = m
	game.screen = "game"
	game.cab_view = false
	game.lamp_manual = -1
	game.camera_s = 600.0
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	game.rebuild()
	for i in range(6): await frame()

func head_point(kind: String) -> Vector2:
	var outer = game.body_transform(kind, game.model.body_s_render(0))
	return outer * Vector2(0, game.art.axis_height(kind) - 0.5 * game.art.PX)

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
	await get_tree().create_timer(0.2).timeout
	for kind in KINDS:
		await prepare(kind)
		var head = head_point(kind)
		game.model.state.stats.seconds = 7.0 * 60.0
		await shot("%s_1_day" % kind, head)
		game.model.state.stats.seconds = 18.0 * 60.0
		game.lamp_manual = 1
		await shot("%s_2_night_lamp" % kind, head)
		game.lamp_manual = -1
		game.model.state.stats.seconds = 7.0 * 60.0
		game.model.state.throttle = 0.7
		for i in range(90): game.model.physics_step(1.0 / 60.0)
		game.camera_s = float(game.model.state.s)
		await shot("%s_3_running" % kind, head_point(kind))
		game.model.state.throttle = 0.0
		game.model.state.brake = 1.0
		for i in range(20): game.model.physics_step(1.0 / 60.0)
		await shot("%s_4_braking" % kind, head_point(kind))
		game.model.wheel_lock = true   # the skid: the wheels stand, sparks fly
		await shot("%s_5_skid" % kind, head_point(kind))
		game.model.wheel_lock = false
	# the depot: every machine with the wagons, the tab of the trips (the machine must not look small or run into the panels)
	for kind in KINDS:
		await prepare(kind)
		game.model.state.phase = "depot"
		game.screen = "depot"
		game.tab = "Рейсы"
		game.rebuild()
		for i in range(8): await frame()
		get_tree().root.get_texture().get_image().save_png(out_dir.path_join("depot_%s.png" % kind))
	print("VISUAL AUDIT DONE ", out_dir)
	get_tree().quit(0)
