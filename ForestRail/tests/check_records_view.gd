extends Node
# В6.6д: вкладка «Рекорды» в депо: в творческом режиме открыта всегда, в карьере только после финала; таблица по всем машинам с лучшим временем и скоростью.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_records_view"

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

func all_text(node: Node) -> String:
	var out = ""
	if node is Label: out += (node as Label).text + "\n"
	if node is Button: out += (node as Button).tooltip_text + "\n"
	for child in node.get_children(): out += all_text(child)
	return out

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
	# the career before the finale: no tab
	game.model.new_game(42, 2)
	game.screen = "depot"
	game.tab = "Рейсы"
	game.rebuild()
	check("Рекорды" not in all_text(game.ui), "in the career before the finale the tab of the records is not there")
	# the creative mode: the tab is there, the table shows the records
	game.model.new_game(42, 2, "creative")
	Fixtures.equip(game.model, "steam")
	var table = game.model.state.records
	table["steam"] = {"a_f": 154.3, "f_a": 161.8, "top_kmh": 63.4}
	table["jet"] = {"a_f": 71.2, "f_a": 0.0, "top_kmh": 412.0}
	game.screen = "depot"
	game.tab = "Рекорды"
	game.rebuild()
	var text = all_text(game.ui)
	check("Рекорды" in text, "in the creative mode the tab of the records is there")
	check("2:34.3" in text and "2:41.8" in text and "63 км/ч" in text, "the table shows the times and the speed of the steam engine")
	check("1:11.2" in text and "412 км/ч" in text, "and of the jet")
	check(game.model.record_rows().size() == game.model.VEHICLE_IDS.size(), "a line for every machine")
	await shot("records_tab")
	# the career after the finale: the tab is there
	game.model.new_game(42, 2)
	game.model.state.finale = true
	game.screen = "depot"
	game.tab = "Рекорды"
	game.rebuild()
	check("Рекорды" in all_text(game.ui), "after the finale the tab is there in the career too")
	# the news of a record reaches the screen
	game.screen = "game"
	game.model.last_record_text = "Рекорд линии! Лесная → Дальний лог за 1:11.2"
	game.model.events.append("record")
	await get_tree().process_frame   # the main loop takes the event: no error
	print("RECORDS VIEW CHECKS %d; FAILURES %s" % [checks, str(failures)])
	get_tree().quit(1 if not failures.is_empty() else 0)
