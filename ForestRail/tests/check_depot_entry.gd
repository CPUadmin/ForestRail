extends Node
# B1.2a: entering the depot is a short scene: the train rolls to its mark, the view closes in, the
# screen fades to black, the depot opens, and fades in. Any key skips the rolling part.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var checks = 0
var failures: Array = []
var output_dir = "user://qa_depot_entry"

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAIL: ", label)

func at_depot_platform() -> void:
	game.model.new_game(42, 2)
	game.model.state.phase = "route"
	game.model.state.s = game.model.service_stop(0) - 5.0
	game.model.state.v = 0.0
	game.model.state.brake = 1.0
	game.screen = "game"
	game.zoom_level = 1.0
	game.rebuild()

func run_frames(seconds: float) -> void:
	for i in range(int(seconds / 0.016)): game._process(0.016)

func run() -> void:
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.set_physics_process(false)
	game.saves.directory = "user://qa_depot_entry"
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	at_depot_platform()
	# a moving train cannot enter
	game.model.state.v = 3.0
	game.start_depot_entry()
	check(game.depot_anim == "", "a moving train does not enter")
	game.model.state.v = 0.0
	# away from the depot platform there is nothing to enter
	game.model.state.s = float(game.model.route.station_s[2])
	game.start_depot_entry()
	check(game.depot_anim == "", "only the home station has a depot")
	at_depot_platform()
	var start = float(game.model.state.s)
	game.start_depot_entry()
	check(game.depot_anim == "in" and game.fade_rect != null, "the entry scene starts")
	run_frames(0.8)
	var mid = float(game.model.state.s)
	check(game.depot_anim == "in" and mid > start and game.zoom_level > 1.0 and game.screen == "game", "halfway: the train is rolling in and the view is closing in")
	run_frames(0.6)
	run_frames(0.4)
	check(game.fade_rect.color.a > 0.2 or game.depot_anim == "out", "the screen fades to black")
	run_frames(0.6)
	check(game.screen == "depot" and game.model.state.phase == "depot" and absf(game.zoom_level - 1.0) < 0.001, "the depot opens and the zoom is restored")
	run_frames(0.7)
	check(game.depot_anim == "" and game.fade_rect.color.a == 0.0, "then the screen is clear again")
	# a key press skips the rolling part
	at_depot_platform()
	game.start_depot_entry()
	run_frames(0.2)
	var key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	game._input(key)
	run_frames(0.6)
	check(game.screen == "depot", "a key press skips the rolling and the depot opens sooner")
	run_frames(0.7)
	# the inside of the depot: pictured places to choose from, and a look at each size and place
	check(game.screen == "depot", "the depot is open for the pictures")
	for size in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = size
		await get_tree().create_timer(0.2).timeout
		for place in ["Гараж", "Состав", "Улучшения", "Рейсы"]:
			game.tab = place
			game.rebuild()
			for i in range(8): await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_tree().root.get_texture().get_image().save_png(output_dir.path_join("depot_%s_%d.png" % [place, size.y]))
	# B1.2c: the workshop shows the improvable parts on the machine, a click on one picks its card
	game.tab = "Улучшения"
	game.selected_object = game.model.vehicle_id()
	game.workshop_branch = ""
	game.rebuild()
	for i in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(game.workshop_hits.size() == 4, "the handcar shows four improvable parts on the machine (%d)" % game.workshop_hits.size())
	if game.workshop_hits.size() == 4:
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = game.workshop_hits[2].position
		var wanted = str(game.workshop_hits[2].branch)
		game._unhandled_input(click)
		check(game.workshop_branch == wanted, "a click on a part picks its card (%s)" % wanted)
		for i in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(output_dir.path_join("workshop_%d.png" % get_tree().root.size.y))
	# B1.2d: the job board shows notices with a route, goods, reward and the road
	game.tab = "Рейсы"
	game.rebuild()
	for i in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join("board_%d.png" % get_tree().root.size.y))
	var rewards = 0
	var roads = 0
	for node in game.ui.find_children("*", "Label", true, false):
		if node.text.begins_with("Награда до"): rewards += 1
		if node.text.begins_with("Ровный путь") or node.text.begins_with("Подъёмы до") or node.text.begins_with("Крутой подъём"): roads += 1
	check(rewards >= 2 and rewards == roads, "every notice on the board shows its reward and its road (%d, %d)" % [rewards, roads])
	# B1.2d: leaving the depot with an order or just driving, both through the fading scene
	game.animate_in_tests = true
	game.model.new_game(42, 2)
	game.screen = "depot"
	game.tab = "Рейсы"
	game.rebuild()
	var driving = false
	for node in game.ui.find_children("*", "Button", true, false): if node.text.begins_with("Просто поехать"): driving = true
	check(driving, "the depot offers 'just drive' when there is no order under way")
	game.take_free_ride()
	check(game.depot_anim == "leave" and game.screen == "depot", "leaving starts with the fade, the depot is still on screen")
	run_frames(0.7)
	check(game.screen == "game" and game.model.state.phase == "route" and game.model.state.active.is_empty() and game.model.state.cargo.is_empty(), "then the road: no order, no cargo, on the line")
	run_frames(0.7)
	check(game.depot_anim == "" and game.fade_rect.color.a == 0.0, "and the screen is clear")
	check(float(game.model.state.brake) == 0.0 and absf(float(game.model.state.s) - game.model.service_stop(0)) < 0.5, "it stands at the depot platform with the brake free")
	# the order way
	game.model.new_game(42, 2)
	game.screen = "depot"
	game.rebuild()
	game.take_mission(game.model.current_mission())
	check(game.depot_anim == "leave" and game.model.state.phase == "loading", "taking an order starts the fade, the loading is ready")
	run_frames(0.7)
	check(game.screen == "game" and game.model.state.phase == "loading", "then the loading platform")
	run_frames(0.7)
	# a free ride cannot start over an order under way
	game.model.new_game(42, 2)
	game.model.accept_mission(game.model.current_mission())
	game.model.state.phase = "depot"
	check(not game.model.start_free_ride(), "no free ride over an order under way")
	game.animate_in_tests = false
	game.model.new_game(42, 2)
	game.screen = "depot"
	game.tab = "Гараж"
	game.rebuild()
	for i in range(4): await get_tree().process_frame
	var tiles = 0
	for node in game.ui.find_children("*", "Button", true, false): if node.tooltip_text in ["Гараж", "Состав", "Мастерская", "Доска заказов"]: tiles += 1
	check(tiles == 4, "four pictured places in the depot (%d)" % tiles)
	print("DEPOT ENTRY CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
