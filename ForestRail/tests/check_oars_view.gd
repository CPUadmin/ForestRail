extends Node
# Вёсла и гребец парусной (картинки П16): три позы по фазе гребка, весло качается в уключине; снимки для глаз.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var checks = 0
var failures: Array = []
var out_dir = "user://qa_oars_view"

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func frame() -> void:
	game.update_hud()
	game.art_world.update_view()
	game.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	for i in range(4): await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("VISUAL ", name)

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
	await get_tree().create_timer(0.15).timeout
	var m = Model.new()
	m.new_game(42, 2)
	m.state.money = 200000
	m.state.chapter = 9
	Fixtures.equip(m, "sail")
	m.object_state("sail").levels["sail_oars"] = 1
	for p in m.route.points: p[1] = 0.0
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.brake = 0.0
	game.model = m
	game.screen = "game"
	game.rebuild()
	game.camera_s = 600.0
	game.camera_y = 0.0
	game.zoom_level = 1.0
	game.camera_x = game.get_viewport_rect().size.x * 0.5
	for i in range(4): await frame()
	await shot("jet_cold")
	check(m.set_oars(true) and m.oars_out(), "the oars are out")
	for entry in [["catch", 1.2], ["recovery", 0.0], ["drive", -1.2]]:
		m.oars.phase = entry[1]
		await shot("oars_" + entry[0])
	check(game.art.ROWER.size() == 3, "the three poses are loaded")
	m.set_oars(false)
	await shot("oars_away")
	print("OARS VIEW CHECKS %d; FAILURES %s" % [checks, str(failures)])
	get_tree().quit(1 if not failures.is_empty() else 0)
