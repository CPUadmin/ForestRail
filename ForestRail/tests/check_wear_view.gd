extends Node
# Веха 5, В5.6: окно «Состояние» в мастерской депо: узлы шкалами, ремонт болтами и деньгами, в двух размерах окна.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_wear_view"

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
	game.live_in_tests = true
	Model.wear_rules = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42, 2)
	game.model.state.money = 5000
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "motorcar")
	var wear = game.model.wear()
	wear.set_condition("motorcar", "engine", 0.62)
	wear.set_condition("motorcar", "gearbox", 0.35)
	wear.set_condition("motorcar", "bearings", 0.12)
	wear.set_condition("motorcar", "brake", 0.8)
	game.model.casino().junk_add("rusty_bolt", 12)
	game.model.casino().junk_add("spark_plug", 3)
	game.model.casino().st().repair_kits = 1
	game.screen = "depot"
	game.tab = "Улучшения"
	game.selected_object = "motorcar"
	game.rebuild()
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		game.rebuild()
		await shot("wear_window_%d" % size.y)
	# a repair through the same actions as the buttons
	var before = wear.condition("motorcar", "bearings")
	var got = wear.repair_bolts_auto("motorcar", "bearings")
	check(got > 0.0 and wear.condition("motorcar", "bearings") > before, "the bolts of the bag mend the bearings (+%.0f%%)" % (got * 100.0))
	check(game.model.casino().junk_count("rusty_bolt") == 0, "the common bolts go first (cheapest in tokens per percent)")
	check(game.model.casino().junk_count("spark_plug") < 3, "and the plugs of the own machine finish the job")
	# 1.4.1: the badges over the train show the three worst parts below 40%, the worst first
	for node in ["engine", "gearbox", "bearings", "brake"]: wear.set_condition("motorcar", node, 1.0)
	wear.set_condition("motorcar", "engine", 0.35)
	wear.set_condition("motorcar", "gearbox", 0.1)
	wear.set_condition("motorcar", "bearings", 0.3)
	wear.set_condition("motorcar", "brake", 0.2)
	var parts = game.train_art().worn_parts(["motorcar"])
	check(parts.size() == 3, "no more than three badges over the train (%d)" % parts.size())
	check(parts.size() == 3 and parts[0][2] == "gearbox" and parts[1][2] == "brake" and parts[2][2] == "bearings", "the worst parts come first: %s" % str(parts))
	for part in parts: check(game.train_art().wear_icon(str(part[2])) != null, "the badge of %s has its picture" % part[2])
	wear.set_condition("motorcar", "gearbox", 0.9); wear.set_condition("motorcar", "brake", 0.9); wear.set_condition("motorcar", "bearings", 0.9); wear.set_condition("motorcar", "engine", 0.9)
	check(game.train_art().worn_parts(["motorcar"]).is_empty(), "a sound machine has no badges")
	Model.wear_rules = false
	print("WEAR VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
