extends Node
# Gadgets are never sold, and a button that spends coins is grey and inert when the player cannot pay.
# Checks (needs a window): with 0 coins every buy button is disabled and says how many coins are missing; with enough coins it works;
# the creative mode disables nothing; a gadget without its card is absent from the workshop; with the card it offers «Установить по карте»;
# Model.upgrade refuses a gadget for coins. Pictures for the eyes.
const Fixtures = preload("res://tests/fixtures.gd")
const Model = preload("res://scripts/core/model.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_afford"

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition: failures.append(text); print("FAIL: ", text)

func _ready() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	for i in range(8):
		game.queue_redraw()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))
	print("VISUAL ", name)

func buttons(prefix: String) -> Array:
	var found: Array = []
	for b in game.ui.find_children("*", "Button", true, false):
		if str(b.text).begins_with(prefix): found.append(b)
	return found

func any_text(needle: String) -> bool:
	for node in game.ui.find_children("*", "", true, false):
		if (node is Label or node is Button) and needle in str(node.text): return true
	return false

func all_locked(prefix: String, what: String) -> void:
	var list = buttons(prefix)
	var locked = not list.is_empty()
	var tips = true
	for b in list:
		locked = locked and b.disabled
		tips = tips and str(b.tooltip_text).begins_with("Не хватает")
	check(locked, "%s: every «%s» is disabled without coins (%d buttons)" % [what, prefix, list.size()])
	check(tips and not list.is_empty(), "%s: «%s» says how many coins are missing" % [what, prefix])

func none_locked(prefix: String, what: String) -> void:
	var list = buttons(prefix)
	var open = not list.is_empty()
	for b in list: open = open and not b.disabled
	check(open, "%s: «%s» works with the money (%d buttons)" % [what, prefix, list.size()])

func open_place(place: String, tab: String = "") -> void:
	game.go_place(place)
	if tab != "": game.tab = tab
	game.rebuild()

func run() -> void:
	var args = Array(OS.get_cmdline_user_args()).filter(func(arg): return not arg.begins_with("--"))
	if not args.is_empty(): output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.test_mode = true
	game.live_in_tests = true
	game.set_physics_process(false)
	game.settings.fullscreen = false
	game.apply_settings()
	game.saves.directory = output_dir.path_join("profile")
	DirAccess.make_dir_recursive_absolute(game.saves.directory)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout

	game.begin_new()
	Model.wear_rules = true   # the wear card is built only with the wear rules on
	var m = game.model
	Fixtures.equip(m, "steam")
	m.state.chapter = 4
	m.state.phase = "depot"
	m.state.brake = 1.0
	m.state.v = 0.0
	m.state.fleet_by_id.steam.fuel = 0.0
	for def in m.wear().nodes_of("steam"): m.wear().set_condition("steam", str(def.id), 0.4)
	m.state.money = 0
	game.selected_object = "steam"

	# --- the workshop without coins
	open_place("workshop")
	game.selected_object = "steam"
	game.rebuild()
	all_locked("Улучшить ·", "workshop")
	all_locked("За ", "wear")
	all_locked("Починить всё", "wear")
	check(not any_text("ГАДЖЕТ") and not any_text("Установить гаджет") and not any_text("Карты пока нет"), "a gadget without its card is not shown at all")
	await shot("workshop_0_coins")
	check(buttons("Улучшить ·")[0].mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "the cursor shape is set; Godot shows the arrow over a disabled button")
	# --- the card makes the gadget appear
	m.casino().st().cards.append("magician")
	game.rebuild()
	check(any_text("ГАДЖЕТ") and not buttons("Установить по карте").is_empty(), "with the card the gadget shows «Установить по карте»")
	check(buttons("Установить гаджет").is_empty(), "no gadget is sold for coins")
	await shot("workshop_with_card")
	buttons("Установить по карте")[0].pressed.emit()
	check(int(m.object_state("steam").levels.get("steam_stoker", 0)) == 1, "the card installs the gadget")
	check(not buttons("Снять карту").is_empty(), "an installed gadget offers «Снять карту»")
	buttons("Снять карту")[0].pressed.emit()
	check(int(m.object_state("steam").levels.get("steam_stoker", 0)) == 0, "and removes it")
	# --- the model refuses to sell a gadget
	m.state.money = 100000
	check(not m.upgrade("steam", "steam_superheater") and m.message.contains("не продаётся"), "Model.upgrade refuses a gadget for coins")
	check(int(m.object_state("steam").levels.get("steam_superheater", 0)) == 0 and int(m.state.money) == 100000, "nothing is taken and nothing is installed")
	# --- enough coins
	game.rebuild()
	none_locked("Улучшить ·", "workshop")
	none_locked("За ", "wear")

	# --- the refill button and the wagon tab of the depot
	m.state.money = 0
	open_place("depot", "Рейсы")
	all_locked("Заправить", "depot")
	m.state.money = 500
	game.rebuild()
	none_locked("Заправить", "depot")
	m.state.money = 0
	open_place("depot", "Состав")
	all_locked("Купить", "wagons tab")
	m.state.money = 100000
	game.rebuild()
	none_locked("Купить", "wagons tab")
	m.state.money = 0
	open_place("depot", "Гараж")
	all_locked("Купить", "garage")
	m.state.money = 100000
	game.rebuild()
	none_locked("Купить", "garage")

	# --- the shop
	m.state.money = 120
	open_place("shop")
	var list = buttons("Купить")
	var locked_count = 0
	for b in list: if b.disabled and str(b.tooltip_text).begins_with("Не хватает"): locked_count += 1
	check(list.size() >= 2 and locked_count >= 2, "shop with little money: the dear machines and the wagon are grey (%d of %d)" % [locked_count, list.size()])
	await shot("shop_little_money")
	m.state.money = 100000
	game.rebuild()
	none_locked("Купить", "shop")

	# --- the creative mode: nothing is locked, the gadgets stay
	game.begin_new(-1, true)
	m = game.model
	check(m.creative(), "the creative game is on")
	open_place("workshop")
	for id in m.state.fleet_by_id.keys():
		game.selected_object = id
		game.rebuild()
		for b in game.ui.find_children("*", "Button", true, false):
			if str(b.text).contains("монет") and b.disabled: check(false, "creative: «%s» is disabled for %s" % [b.text, id])
	game.selected_object = "steam"
	game.rebuild()
	check(any_text("ГАДЖЕТ") and not buttons("Установить гаджет").is_empty(), "creative: the gadgets stay visible and installable")
	check(m.upgrade("steam", "steam_superheater"), "creative: a gadget is installed for free")
	open_place("shop")
	for b in buttons("Купить"): check(not b.disabled, "creative: the shop button is not grey")

	Model.wear_rules = false
	var failed = failures.size()
	print("AFFORD CHECKS: %d checks, %d failures" % [checks, failed])
	for f in failures: print("  ", f)
	preload("res://tests/qa_exit.gd").quit(self, 1 if failed > 0 else 0)
