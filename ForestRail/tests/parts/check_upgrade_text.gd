extends Node
# D9: the upgrade cards never show a raw array of numbers like [1200.0, 1100.0]; owner 16.11: an endless card says
# what gets better in one or two plain phrases, without numbers and percent, and its title shows the level.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_upgrade_text"

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
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	game.model.new_game(42, 2)
	game.model.state.money = 5000
	game.model.state.chapter = 9
	for kind in ["motorcar", "steam", "locomotive", "pole"]:
		Fixtures.equip(game.model, kind)
		if kind == "motorcar": game.model.object_state(kind).levels["motorcar_engine"] = 3
		game.screen = "depot"
		game.tab = "Улучшения"
		game.selected_object = kind
		if kind == "steam":
			game.model.casino().st().cards.append("magician")
			game.workshop_branch = "steam_stoker"
		game.rebuild()
		await get_tree().process_frame
		if kind == "steam":
			var money = game.model.state.money
			press_workshop_button("Установить по карте")
			await get_tree().process_frame
			check(int(game.model.object_state(kind).levels.get("steam_stoker", 0)) == 1, "workshop installs the card's gadget")
			check(game.model.state.money == money, "the card installs for free")
		var texts: Array = []
		for label in game.find_children("*", "Label", true, false):
			texts.append(str(label.text))
			check(not str(label.text).contains("["), "%s: no raw array in the card (%s)" % [kind, str(label.text).substr(0, 70)])
		# owner 16.11: an endless card says one or two plain phrases, no numbers and no percent
		var seen = 0
		for branch in game.model.data.upgrade_catalog:
			if branch.target_type != kind or not game.model.branch_endless(branch): continue
			var line = game.depot_ui().upgrade_line(kind, branch)
			if line in texts: seen += 1
			check(line != "" and not line.contains("%") and not line.contains("→") and line.split("\n").size() <= 2, "%s: a short plain line (%s)" % [branch.id, line])
		check(seen > 0, "%s: the cards show what gets better" % kind)
		if kind == "motorcar": check("Двигатель · ур. 3" in texts, "the title shows the level (%s)" % str(texts.filter(func(t): return t.contains("ур."))))
		for k in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(output_dir.path_join("upgrades_%s.png" % kind))
		if kind == "steam":
			press_workshop_button("Снять карту")
			await get_tree().process_frame
			var level = int(game.model.object_state(kind).levels.get("steam_stoker", 0))
			check(level == 0 and game.model.casino().card_owned("magician"), "workshop removes the gadget and keeps the card (level %d, installed %s)" % [level, str(game.model.casino().st().installed)])
	# the helper itself
	check(game.stat_change(100.0, 115.0) == "100 → 115 (+15%)", "a number: before, after, percent (%s)" % game.stat_change(100.0, 115.0))
	check(game.stat_change([100.0, 200.0], [110.0, 220.0]) == "+10%", "a row of numbers: the mean change (%s)" % game.stat_change([100.0, 200.0], [110.0, 220.0]))
	check(game.depot_ui().places(1) == "1 место" and game.depot_ui().places(3) == "3 места" and game.depot_ui().places(12) == "12 мест", "places are counted in Russian")
	print("UPGRADE TEXT CHECKS ", checks, "; FAILURES ", failures)
	preload("res://tests/qa_exit.gd").quit(self, 0 if failures.is_empty() else 1)

func press_workshop_button(title: String) -> void:
	for button in game.find_children("*", "Button", true, false):
		if button.text == title and not button.disabled:
			button.pressed.emit()
			return
	check(false, "missing workshop button " + title)
