extends Node
# Пламя, дым и парашют реактивного (картинки П15): рисуются без ошибок при разной тяге, с форсажем и с раскрытым парашютом; снимки для глаз.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var checks = 0
var failures: Array = []
var out_dir = "user://qa_jet_fx"

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
	Fixtures.equip(m, "jet")
	for p in m.route.points: p[1] = 0.0
	m.state.phase = "route"
	m.state.s = 600.0
	m.state.brake = 1.0
	game.model = m
	game.screen = "game"
	game.rebuild()
	game.camera_s = 600.0
	game.camera_y = 0.0
	game.zoom_level = 0.6
	game.camera_x = game.get_viewport_rect().size.x * 0.65
	for i in range(4): await frame()
	await shot("jet_cold")
	m.jet.started = true
	for entry in [["idle", 800.0], ["mid", 4200.0], ["full", 11500.0]]:
		m.jet.thrust = entry[1]
		await shot("jet_flame_" + entry[0])
	m.jet.afterburner_time = 2.0
	m.jet.thrust = 48000.0
	await shot("jet_afterburner")
	# the afterburner gadget: its own small nozzle on the deck looks backward and fires with the rest
	m.object_state("jet").levels["jet_afterburner"] = 1
	await shot("jet_afterburner_gadget")
	m.object_state("jet").levels.erase("jet_afterburner")
	m.jet.afterburner_time = 0.0
	m.jet.thrust = 3000.0
	m.jet.chutes_open = 1
	m.jet.chute = 0.5
	await shot("jet_chute_opening")
	m.jet.chute = 1.0
	await shot("jet_chute_open")
	m.jet.chutes_open = 2
	await shot("jet_chute_two")
	check(game.art.JET_FX.size() == 4, "the smoke and chute pictures are loaded (the flame is drawn by code)")
	# the start panel in the cab: the painted cap, toggles, lamps and button
	m.jet.chutes_open = 0
	m.jet.chute = 0.0
	m.jet.started = false
	m.jet.thrust = 0.0
	game.toggle_cab_view()
	for i in range(8): await frame()
	check(game.cab_active(), "the cab is open")
	await shot("pult_cap_closed")
	m.jet.cover_open = true
	await shot("pult_cap_open")
	m.jet.fuses = [true, true, false, true]
	await shot("pult_toggles")
	m.jet.fuses = [true, true, true, true]
	await shot("pult_armed")
	m.jet.started = true
	await shot("pult_burning")
	print("JET FX VIEW CHECKS %d; FAILURES %s" % [checks, str(failures)])
	get_tree().quit(1 if not failures.is_empty() else 0)
