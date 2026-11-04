extends Node
# Этап «д»: альбом карточек Таро (scripts/album_view.gd): 22 места, выбитые лицом, остальные рубашкой; щелчок открывает карточку крупно.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_album_view"

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
	game.model.state.chapter = 9
	Fixtures.equip(game.model, "motorcar")
	var cas = game.model.casino()
	cas.st().cards = ["fool", "magician", "priestess"]
	game.screen = "depot"
	game.tab = "Казик"
	game.rebuild()
	var button_text = ""
	for button in game.find_children("*", "Button", true, false):
		if str(button.text).begins_with("Альбом карточек"): button_text = str(button.text)
	check(button_text.contains("3 из 22"), "the tab of the casino shows the album with 3 of 22 (%s)" % button_text)
	game.show_modal("album")
	await get_tree().process_frame
	var view = game.overlay.get_child(game.overlay.get_child_count() - 1)
	check(view.has_method("show_card") and view.views.size() == 22, "the album has 22 places")
	var shown = 0
	for id in view.views:
		if view.views[id].revealed: shown += 1
	check(shown == 3 and view.views.fool.revealed and not view.views.tower.revealed, "only the three owned cards lie face up")
	await shot("album")
	view.show_card("magician")
	check(view.detail != null, "a click opens the big card")
	await shot("album_detail")
	view.on_close()
	check(view.detail == null, "the first back closes the big card")
	print("ALBUM VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
