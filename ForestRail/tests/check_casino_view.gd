extends Node
# Веха 6, В6.11 этап «г»: экран казика (scripts/casino_view.gd): вкладка в депо, колесо останавливается на выпавшем секторе,
# «деп» превращает шлак в жетоны, кнопки по состоянию кармана. Кадры в двух размерах окна.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_casino_view"

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
	game.settings.reduce_motion = true
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42, 2)
	game.model.state.money = 5000
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "motorcar")
	var cas = game.model.casino()
	cas.junk_add("rusty_bolt", 12)
	cas.junk_add("track_spike", 5)
	cas.junk_add("golden_bolt", 1)
	cas.st().tokens = 30
	game.screen = "depot"
	game.tab = "Казик"
	game.rebuild()
	# the tab shows the way in and the honest odds
	var enter = false
	var odds = false
	for button in game.find_children("*", "Button", true, false):
		if str(button.text).begins_with("Войти в казик"): enter = true
	for label in game.find_children("*", "Label", true, false):
		if str(label.text).contains("Честные шансы"): odds = true
	check(enter and odds, "the tab of the casino has the way in and the honest odds")
	game.show_modal("casino")
	await get_tree().process_frame
	var view = game.overlay.get_child(game.overlay.get_child_count() - 1)
	check(view.has_method("on_spin") and view.spin_button != null, "the casino screen is open")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.3).timeout
		game.rebuild()
		game.show_modal("casino")
		await get_tree().process_frame
		view = game.overlay.get_child(game.overlay.get_child_count() - 1)
		await shot("casino_%d" % size.y)
	check(not view.dep_button.disabled and not view.spin_button.disabled, "with tokens and bolts both buttons work")
	# the wheel: its sectors are as wide as their weights, the whole circle
	var sum = 0.0
	for i in range(view.sectors().size()):
		var b = view.sector_bounds(i)
		sum += b.y - b.x
	check(absf(sum - TAU) < 0.0001, "the sectors fill the whole circle")
	check(view.sector_at(0.0) == 0 and view.sector_at(-0.01) == 0, "at the start the pointer is on the first sector")
	# the deposit: common bolts become tokens, the rare find stays
	var before_tokens = cas.tokens()
	var expect = 12 * 1 + 5 * 2
	view.on_deposit()
	check(cas.tokens() == before_tokens + expect and cas.junk_count("rusty_bolt") == 0 and cas.junk_count("golden_bolt") == 1, "the deposit gives %d tokens and keeps the golden bolt (%d)" % [expect, cas.tokens() - before_tokens])
	check(view.dep_button.disabled, "no common bolts, no deposit button")
	# twelve turns: the wheel stops exactly on the sector that fell
	cas.st().tokens = 200
	var seen: Dictionary = {}
	for k in range(12):
		var tokens_before = cas.tokens()
		view.on_spin()
		check(view.spin_t >= 0.0 and cas.tokens() <= tokens_before - 5 + 400, "the turn %d starts" % (k + 1))
		for step in range(40): view._process(0.05)
		check(view.spin_t < 0.0, "the turn %d ends" % (k + 1))
		var index = view.sector_index(str(view.result.sector))
		check(view.sector_at(view.angle) == index, "the wheel stopped on the sector that fell (%s)" % str(view.result.sector))
		seen[str(view.result.sector)] = true
	check(seen.size() >= 3, "different sectors fell (%d kinds)" % seen.size())
	cas.st().tokens = 2
	view.refresh_buttons()
	check(view.spin_button.disabled, "with two tokens the turn is closed")
	await shot("casino_after")
	print("CASINO VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
