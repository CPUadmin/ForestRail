extends Node
# Карточки Таро Михалыча (scripts/card_view.gd): 18 карточек гаджетов и 4 тайные рисуются в рамке без ошибок,
# у каждой своя цифра, название и реплика, невыбитая лежит рубашкой вверх. Контактный лист всех 22 карточек.
const CardView = preload("res://scripts/card_view.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_card_view"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

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
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42, 2)
	var cas = game.model.casino()
	var ids: Array = []
	for card in game.model.data.casino.cards: ids.append(str(card.id))
	check(ids.size() == 18, "eighteen cards of gadgets")
	var secret = ["moon", "sun", "judgement", "world"]
	var arcana: Dictionary = {}
	var quotes: Dictionary = {}
	var layer = Control.new()
	layer.size = Vector2(1600, 900)
	game.add_child(layer)
	var back = ColorRect.new()
	back.color = Color(0.09, 0.07, 0.05)
	back.size = layer.size
	layer.add_child(back)
	var all = ids + secret
	for i in range(all.size()):
		var view = CardView.new()
		view.game = game
		view.card_id = str(all[i])
		view.revealed = i % 5 != 4
		view.position = Vector2(10 + (i % 8) * 198, 10 + (i / 8) * 298)
		view.size = Vector2(188, 289)
		layer.add_child(view)
		var data = view.info()
		check(str(data.name) != "" and str(data.arcana) != "", "card %s has a name and a numeral" % view.card_id)
		check(not arcana.has(str(data.arcana)), "the numeral %s is unique" % str(data.arcana))
		arcana[str(data.arcana)] = true
		check(str(data.quote) != "" and not quotes.has(str(data.quote)), "card %s has its own line of Mikhalych" % view.card_id)
		quotes[str(data.quote)] = true
	check(arcana.size() == 22, "twenty two numerals in the album")
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join("cards_all.png"))
	print("VISUAL cards_all")
	print("CARD VIEW CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
