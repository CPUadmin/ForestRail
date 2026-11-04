extends Node
# Веха 5: взгляд на живой состав в окне. Разгон, ход и торможение: сцепки, наклон кузовов, груз на ремнях.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_live_view"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for i in range(6): await get_tree().process_frame
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
	Fixtures.equip(game.model, "locomotive")
	var wagon = str(game.model.state.consist_ids[0])
	game.model.state.cargo = [
		{"id": "f1", "type": "fragile", "destination": "B", "slot": wagon + ":0", "delivered": false, "health": 1.0, "weight_kg": 60},
		{"id": "l1", "type": "logs", "destination": "B", "slot": wagon + ":1", "delivered": false, "health": 1.0, "weight_kg": 120},
	]
	game.screen = "game"
	game.rebuild()
	game.model.state.phase = "route"
	game.model.state.s = 600.0
	game.model.state.v = 0.0
	game.model.state.direction = 1
	game.model.state.reverser = 1
	game.model.state.brake = 0.0
	game.camera_s = 600.0
	game.rebuild()
	game.live_in_tests = true
	Model.live_effects = true
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.2).timeout
	game.model.state.throttle = 1.0
	var widest_gap = 0.0
	for i in range(60 * 3):
		game.model.physics_step(1.0 / 60.0)
		widest_gap = maxf(widest_gap, game.model.live.extension(1))
	game.camera_s = float(game.model.state.s)
	game.queue_redraw()
	await shot("live_accelerating")
	check(widest_gap > 0.05, "the couplers have stretched in the picture (%.3f m)" % widest_gap)
	for i in range(60 * 10): game.model.physics_step(1.0 / 60.0)
	game.camera_s = float(game.model.state.s)
	game.queue_redraw()
	await shot("live_cruising")
	game.model.state.throttle = 0.0
	game.model.state.brake = 1.0
	for i in range(40): game.model.physics_step(1.0 / 60.0)
	game.camera_s = float(game.model.state.s)
	game.queue_redraw()
	await shot("live_braking")
	check(game.model.live.rock_rad(0) < 0.0, "the nose dips while braking (%.4f)" % game.model.live.rock_rad(0))
	# B5.5: a hop off a knoll: the nose follows the flight, the shadow stays on the rail, the landing raises dust
	var knoll_x = float(game.model.route.knolls[0][0])
	game.model.state.throttle = 0.0
	game.model.state.brake = 0.0
	game.model.state.s = float(game.model.route.distance_at_x(knoll_x)) - 40.0
	game.model.state.v = 33.0
	var flew = false
	var shot_air = false
	var shot_land = false
	for i in range(60 * 6):
		game.model.physics_step(1.0 / 60.0)
		game.camera_s = float(game.model.state.s)
		if game.model.air_fly and float(game.model.air_z) > 0.08 and not shot_air:
			shot_air = true
			flew = true
			game.queue_redraw()
			await shot("jump_in_the_air")
		if shot_air and not shot_land and not game.model.air_fly and float(game.model.last_landing) > 0.4:
			shot_land = true
			game.land_dust = {"t": 0.12, "s": float(game.model.state.s), "power": 0.8}
			game.queue_redraw()
			await shot("jump_landing")
			break
	check(flew, "the train really flies off the knoll")
	check(shot_land, "and comes down")
	Model.live_effects = false
	print("LIVE VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
