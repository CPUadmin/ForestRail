extends Node
# Веха 6, В6.11 этап «в»: кнопка «Приёмка» в депо, окно приёмки болтов и кнопка «Доплатить болтами» в мастерской.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_receiving_view"

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
	game.model.state.money = 300
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "motorcar")
	var casino = game.model.casino()
	casino.junk_add("rusty_bolt", 14)
	casino.junk_add("track_spike", 5)
	casino.junk_add("spark_plug", 3)
	casino.junk_add("brake_shoe", 2)
	casino.junk_add("golden_bolt", 1)
	game.screen = "depot"
	game.tab = "Улучшения"
	game.selected_object = "motorcar"
	game.rebuild()
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		game.rebuild()
		await shot("workshop_pay_bolts_%d" % size.y)
	var plan = casino.bolt_plan(int(game.model.data.upgrade_catalog[4].level_costs[0]))
	check(int(plan.count) > 0, "the workshop offers to pay with bolts (%d)" % int(plan.count))
	var found = false
	for button in game.find_children("*", "Button", true, false):
		if str(button.text).begins_with("Доплатить болтами"): found = true
	check(found, "the button 'Доплатить болтами' is on the screen")
	var desk = false
	game.tab = "Состав"
	game.rebuild()
	for button in game.find_children("*", "Button", true, false):
		if str(button.text).begins_with("Болты ("): desk = true
	check(desk, "the button 'Болты' (the desk) is in the depot")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		game.show_modal("receiving")
		await shot("receiving_%d" % size.y)
		var rows = 0
		for button in game.find_children("*", "Button", true, false):
			if str(button.text).begins_with("Продать 1"): rows += 1
		check(rows == 5, "(%d) every kind in the bag has its row (%d)" % [size.y, rows])
		game.close_modal()
	# a sale through the same action as the button
	var before = int(game.model.state.money)
	game.sell_bolts("rusty_bolt", 4, false)
	check(int(game.model.state.money) == before + 8 and casino.junk_count("rusty_bolt") == 10, "a sale by the button: +8 coins")
	print("RECEIVING VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
