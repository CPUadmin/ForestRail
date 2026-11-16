extends Node
# Узловая Лесная (docs/STATION_LOCATIONS_REWORK_RU.md): двор с четырьмя зданиями — главный экран между рейсами.
# Проверяет: двор открывается после новой игры и после рейса; у каждого здания есть кнопка; вход в мастерскую,
# магазин и депо; в каждом месте вкладки мест и «На узловую»; клавиши 1–4 и Backspace; казик открывается своим экраном;
# главная кнопка двора ведёт к погрузке; состав стоит на рельсах картинки. Снимки двора и мест — для глаз.
const Fixtures = preload("res://tests/fixtures.gd")

var game
var failures: Array = []
var checks = 0
var output_dir = "user://qa_yard"

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

func button_with_tooltip(text: String) -> Button:
	for b in game.ui.find_children("*", "Button", true, false):
		if str(b.tooltip_text) == text: return b
	return null

func key(code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._input(event)

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
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().create_timer(0.3).timeout

	game.begin_new()
	check(game.screen == "depot" and game.place == "yard", "a new game opens in the yard")
	game.model.state.money = 1840
	game.model.state.chapter = 4
	Fixtures.equip(game.model, "motorcar")
	game.rebuild()
	var doors = 0
	for name in ["Депо", "Мастерская", "Магазин", "Казик"]: if button_with_tooltip(name) != null: doors += 1
	check(doors == 4, "the yard has the four buildings (%d)" % doors)
	var go = false
	for b in game.ui.find_children("*", "Button", true, false): if str(b.text).begins_with("К погрузке"): go = true
	check(go, "the main button of the yard leads to the loading")
	var size = game.get_viewport_rect().size
	check(absf(game.rail_baseline() - game.yard_ui().rail_y(size)) < 0.5, "the train stands on the rails of the yard picture")
	await shot("yard_1600")

	check(is_equal_approx(game.view_scale(), game.fit_train_zoom()), "in the yard the train is as big as on the line")
	button_with_tooltip("Мастерская").pressed.emit()
	check(game.place == "workshop" and game.tab == "Улучшения", "the workshop opens from its building")
	check(button_with_tooltip("Во двор [Backspace]") != null, "the place has the way back to the yard")
	var tabs = 0
	for name in ["Депо [1]", "Мастерская [2]", "Магазин [3]", "Казик [4]"]: if button_with_tooltip(name) != null: tabs += 1
	check(tabs == 4, "the place has the four places as tabs (%d)" % tabs)
	check(is_equal_approx(game.view_scale(), game.fit_train_zoom()), "in the workshop the train is as big as on the line (%.2f, %.2f)" % [game.view_scale(), game.fit_train_zoom()])
	await shot("workshop_1600")
	key(KEY_3)
	check(game.place == "shop" and game.tab == "Магазин", "key 3 opens the shop")
	var buy = false
	for b in game.ui.find_children("*", "Button", true, false): if str(b.text).begins_with("Купить"): buy = true
	check(buy, "the shop sells")
	await shot("shop_1600")
	key(KEY_1)
	check(game.place == "depot", "key 1 opens the depot")
	check(is_equal_approx(game.view_scale(), game.fit_train_zoom()), "in the depot the train is as big as on the line")
	await shot("depot_1600")
	key(KEY_BACKSPACE)
	check(game.place == "yard", "Backspace leads back to the yard")
	button_with_tooltip("Казик").pressed.emit()
	await get_tree().process_frame
	check(game.modal_kind == "casino" and game.place == "yard", "the casino opens as its own screen over the yard")
	game.close_modal()

	# the casino entrance with its animation: the camera flies to the door, warm light, the casino out of the light
	game.animate_in_tests = true
	game.go_place("casino")
	check(game.depot_anim == "leave" and game.place_style == "casino_in" and game.modal_kind == "", "the casino entrance starts its flight")
	game.advance_depot_anim(0.3)
	check(game.casino_flight() > 0.3 and game.fade_rect != null, "the camera is on its way to the door")
	game.advance_depot_anim(0.4)
	check(game.depot_anim == "out" and game.modal_kind == "casino" and game.fade_rect.color.a > 0.9 and game.fade_rect.color.r > game.fade_rect.color.b, "the casino opens inside warm amber light, not black")
	game.advance_depot_anim(1.0)
	check(game.depot_anim == "" and game.place_style == "" and game.fade_rect.color.a == 0.0, "the entrance ends with the casino open and the screen clear")
	var angle_before = game.overlay.get_child(game.overlay.get_child_count() - 1).angle
	game.close_modal()
	game.go_place("casino")
	game.skip_depot_anim()
	check(game.depot_anim == "" and game.modal_kind == "casino" and game.fade_rect.color.a == 0.0, "a click skips the entrance to its end")
	var casino_screen = game.overlay.get_child(game.overlay.get_child_count() - 1)
	check(casino_screen.intro_t >= 0.0 and is_equal_approx(casino_screen.angle, angle_before), "the lazy turn of the wheel is only a look: the logical angle is not touched")
	game.leave_casino()
	check(game.depot_anim == "leave" and game.place_style == "casino_out", "leaving the casino starts a short warm fade")
	game.advance_depot_anim(0.2)
	check(game.modal_kind == "" and game.place == "yard", "the yard is back after the fade out")
	game.advance_depot_anim(0.3)
	check(game.depot_anim == "" and game.fade_rect.color.a == 0.0, "the fade back ends clear")
	game.settings.reduce_motion = true
	game.go_place("casino")
	check(game.place_style == "" and game.depot_anim == "leave", "with reduced motion the entrance is a plain quick fade")
	game.advance_depot_anim(0.3)
	game.advance_depot_anim(0.3)
	check(game.depot_anim == "" and game.modal_kind == "casino", "the plain fade is over in half a second")
	game.settings.reduce_motion = false
	game.animate_in_tests = false
	game.close_modal()

	# the evening: the lamps of the yard are lit
	game.model.state.stats.seconds = 13.0 * 3600.0 / 24.0 * float(game.model.DAY_SECONDS) / 3600.0
	game.rebuild()
	await shot("yard_evening")

	# home from a trip: the yard
	game.take_mission(game.model.current_mission())
	check(game.screen == "game", "the yard leads to the loading")
	game.model.cancel_mission()
	game.model.back_to_depot()
	game.place = "workshop"
	game.depot_anim = "in"
	game.depot_anim_t = 99.0
	game.advance_depot_anim(0.0)
	check(game.place == "yard", "coming home from the line opens the yard")

	for res in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = res
		await get_tree().create_timer(0.3).timeout
		game.screen = "depot"
		game.place = "yard"
		game.modal_kind = ""
		game.rebuild()
		await shot("yard_%d" % res.y)
		game.go_place("workshop")
		await shot("workshop_%d" % res.y)
	print("YARD CHECKS ", checks, "; FAILURES ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
