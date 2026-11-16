extends Node
# Снимки для глаз (шаг 1.4.2 «Ступени износа»): как выглядит усталая машина. Не тест с галочкой.
# Запуск: godot --path ForestRail -- --qa-suite=probe_wear_signs <папка_для_снимков>
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var out_dir = "user://qa_wear_signs"

func _ready() -> void:
	call_deferred("run")

func frame() -> void:
	game.update_hud()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frame()
	var head = game.body_transform(game.model.vehicle_id(), game.model.body_s_render(0)) * Vector2(0, -60)
	var image = get_tree().root.get_texture().get_image()
	var crop = Rect2i(int(head.x) - 560, int(head.y) - 300, 860, 400).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(crop).save_png(out_dir.path_join(name + ".png"))

func prepare(kind: String) -> void:
	var m = Model.new()
	m.new_game(42, 2, "creative")
	m.state.money = 500000
	m.state.chapter = 9
	Fixtures.equip(m, kind)
	Fixtures.fire_up(m)
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.v = 0.0
	m.state.brake = 0.0
	m.state.engine = true
	m.weather_force = {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
	m.state.stats.seconds = 7.0 * 60.0
	for p in m.route.points: p[1] = 0.0
	game.model = m
	game.screen = "game"
	game.cab_view = false
	game.camera_s = 600.0
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	game.rebuild()
	for i in range(4): await frame()
	game.fx().wind_scale = 0.0

# the train is moved by hand at a fixed speed; the effects step with it, a frame drawn every few steps
func drive(speed: float, seconds: float) -> void:
	var m = game.model
	var dt = 1.0 / 60.0
	for i in range(int(seconds * 60.0)):
		m.state.s = float(m.state.s) + speed * dt
		m.state.v = speed
		m.state.stats.distance = 10.0
		game.camera_s = float(m.state.s)
		game.fx().update(dt)
	await frame()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"): out_dir = arg
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.set_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = out_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.2).timeout
	for case in [["steam", "brake", 1.0], ["steam", "brake", 0.55], ["steam", "brake", 0.3], ["steam", "brake", 0.1], ["locomotive", "brake", 0.3]]:
		await prepare(case[0])
		game.model.wear().set_condition(case[0], case[1], case[2])
		game.model.state.throttle = 0.0
		game.model.state.brake = 0.8
		await drive(9.0, 1.2)
		await shot("%s_brake_%d" % [case[0], int(case[2] * 100)])
	for case in [["steam", "boiler", 1.0], ["steam", "boiler", 0.3], ["motorcar", "engine", 1.0], ["motorcar", "engine", 0.3], ["motorcar", "engine", 0.1]]:
		await prepare(case[0])
		game.model.wear().set_condition(case[0], case[1], case[2])
		game.model.state.throttle = 0.7
		await drive(6.0, 4.0)
		await shot("%s_power_%d" % [case[0], int(case[2] * 100)])
	print("WEAR SIGNS DONE ", out_dir)
	get_tree().quit(0)
