extends Node
# N7.2 screens: the depot panel with the trip forecast and the map with station services.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var checks = 0
var failures: Array = []
var out_dir = ""

func _ready() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func frame(count: int = 2) -> void:
	for i in range(count):
		game.update_hud(); game.art_world.update_view(); game.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await frame()
	get_tree().root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func run() -> void:
	out_dir = ProjectSettings.globalize_path("res://../qa/v3_p7")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = load("res://main.tscn").instantiate(); game.test_mode = true
	get_tree().root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.saves.directory = out_dir.path_join("isolated_profile_fc"); DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.settings.fullscreen = false; game.apply_settings()
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.15).timeout
	for id in ["motorcar", "steam", "locomotive"]:
		for scale in [1.0, 1.5]:
			game.settings.text_scale = scale
			game.modal_kind = ""; game.paused = false
			game.model.new_game(42); game.model.state.money = 10000
			Fixtures.equip(game.model, id)
			game.screen = "depot"; game.rebuild()
			await frame(6)
			var text = game.forecast_line(game.model.current_mission())
			check(text.contains("хватит") or text.contains("НЕ ХВАТИТ"), "%s %s depot forecast line has a verdict" % [id, str(scale)])
			var service_top = game.get_viewport_rect().size.y - 150.0
			check(game.depot_info_rect.end.y <= service_top + 1.0, "%s %s depot info stays above the service buttons (%.0f vs %.0f)" % [id, str(scale), game.depot_info_rect.end.y, service_top])
			if scale == 1.0 or id == "steam": await shot("fc_depot_%s_%d" % [id, int(scale * 100)])
	game.settings.text_scale = 1.0
	game.model.new_game(42); game.model.state.money = 10000
	Fixtures.equip(game.model, "steam")
	game.screen = "game"; game.rebuild()
	game.show_modal("map")
	await frame(4)
	await shot("fc_map_steam")
	check(game.service_text("D").contains("вода") and game.service_text("A").contains("заправка"), "map shows services per station")
	game.close_modal()
	# the menu's new game gives the long line, the depot shows the longer pay
	game.begin_new(7)
	await frame(4)
	check(game.model.route.version == 2 and game.screen == "depot" and float(game.model.route.station_x[5]) == 6800.0, "a new career starts on the long line")
	check(int(game.model.current_mission().reward) == 360, "and the first order pays for it")
	# creative mode from the menu path
	game.begin_new(8, true)
	await frame(4)
	check(game.model.creative() and game.screen == "depot" and int(game.model.state.money) > 1000000, "the creative mode starts from the same place as a career")
	await shot("creative_depot")
	print("FORECAST VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
