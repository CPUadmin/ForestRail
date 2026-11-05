extends Node
# B6.3: the wind of the line is in the picture: the smoke goes with the air that moves over the train, the pennants of the
# stations stream down the wind, the grass at the track bends. Frames of a strong wind from behind and from ahead.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_wind_view"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func run() -> void:
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42, 2)
	game.model.state.money = 5000
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "steam")
	Fixtures.fire_up(game.model)
	game.screen = "game"
	game.rebuild()
	var m = game.model
	m.state.phase = "route"
	m.state.engine = true
	m.state.throttle = 0.6
	m.state.direction = 1
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.2).timeout
	# a known wind: stand where the line has a strength, read the wind and set the speed
	m.state.s = float(m.service_stop(1)) + 3.0
	game.camera_s = float(m.state.s)
	var w = m.wind_here()
	check(w.length() > 1.0, "there is wind at the place (%.1f m/s)" % w.length())
	# the drift of the smoke follows the air over the train: wind minus speed
	m.state.v = 0.0
	m.state.throttle = 1.0
	var standing = game.art.smoke_drift(m)
	m.state.v = 12.0
	var running = game.art.smoke_drift(m)
	check(absf(standing - clampf(w.x * 0.42, -3.4, 3.4)) < 0.001, "a standing train: the smoke goes with the wind (%.2f)" % standing)
	check(running < standing - 1.0 or running <= -3.39, "a running train lays the smoke back (%.2f against %.2f)" % [running, standing])
	check(game.art.smoke_rise(3.4) < game.art.smoke_rise(0.0), "the smoke blown flat rises a little less")
	# the pennants know the side of the wind
	var wind_screen = game.art_world.wind_on_screen(float(m.state.s))
	check(absf(wind_screen.x * float(int(m.state.direction)) - w.x) < 0.001, "the wind on the screen agrees with the wind of the model")
	await shot("wind_station_standing")
	m.state.v = 8.0
	game.queue_redraw()
	await shot("wind_station_running")
	game.settings.reduce_motion = true
	game.queue_redraw()
	await shot("wind_reduced_motion")
	game.settings.reduce_motion = false
	print("WIND VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
